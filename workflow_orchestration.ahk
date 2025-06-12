#Requires AutoHotkey v2.0

;------------------------------------------------------------------------------
; WORKFLOW MANAGEMENT FUNCTIONS
;------------------------------------------------------------------------------
; Creates a new empty workflow
; Triggered by the New button in Workflow section
NewWorkflow(*) {
    global g_CurrentWorkflow, g_CurrentWorkflowName
    
    ; Clear the current workflow and name
    g_CurrentWorkflow := []
    g_CurrentWorkflowName := ""
    myGui["WorkflowNameInput"].Value := ""
    myGui["WorkflowSavedAtText"].Text := ""  ; Clear the saved timestamp
    UpdateWorkflowFlowsList()
}

; Saves the current workflow to the workflows collection
; Workflow name is taken from the GUI input
; Triggered by the Save button in Workflow section
SaveCurrentWorkflow(*) {
    global g_CurrentWorkflow, g_Workflows, g_CurrentWorkflowName, g_WorkflowsFilePath
    
    workflowName := myGui["WorkflowNameInput"].Value
    if (workflowName = "") {
        MsgBox "Please enter a name for the workflow.", "Workflow Name Required", "Icon!"
        return
    }
    
    ; Save the workflow
    g_CurrentWorkflowName := workflowName
    g_Workflows[workflowName] := g_CurrentWorkflow.Clone()
    SaveWorkflowsToFile()
    UpdateWorkflowsList()
    
    ; Get current time for the saved timestamp
    currentTime := FormatTime(, "HH:mm:ss")
    myGui["WorkflowSavedAtText"].Text := "Saved at " . currentTime
}

; Executes all flows in the current workflow in sequence
; Triggered by the Run button in Workflow section
RunWorkflow(*) {
    global g_CurrentWorkflow, g_Flows
    
    ; Check if there are any flows in the workflow
    if (g_CurrentWorkflow.Length = 0) {
        MsgBox "No flows to run in this workflow.", "Run Error", "Icon!"
        return
    }
    
    ; Initialize success tracking
    allFlowsSucceeded := true
    failedFlows := []
    currentFlowIndex := 0
    
    OutputDebug("[RunWorkflow] Starting workflow with " g_CurrentWorkflow.Length " flows")
    
    ; Run each flow in the workflow in sequence
    for i, flowName in g_CurrentWorkflow {
        currentFlowIndex := i
        
        if (!g_Flows.Has(flowName)) {
            OutputDebug("[RunWorkflow] Flow not found: " flowName)
            MsgBox "Flow not found: " flowName, "Run Error", "Icon!"
            
            ; Track failure
            allFlowsSucceeded := false
            failedFlows.Push(Map("index", i, "name", flowName, "reason", "Flow not found"))
            
            ; Ask if user wants to continue
            if MsgBox("Flow '" flowName "' not found. Continue with remaining flows?", 
                     "Flow Missing", "YesNo Icon!") = "No" {
                break
            }
            continue
        }
        
        ; Get the flow steps
        flowSteps := g_Flows[flowName]
        
        ; Display which flow is running
        OutputDebug("[RunWorkflow] Running flow " i " of " g_CurrentWorkflow.Length ": " flowName)
        
        ; Initialize flow success tracking
        flowSucceeded := true
        failedSteps := []
        
        ; Run each step in the flow
        for j, step in flowSteps {
            OutputDebug("[RunWorkflow] Running step " j "/" flowSteps.Length " in flow '" flowName "'")
            
            ; Define step failure callback
            stepFailureCallback(resultObj) {
                OutputDebug("[RunWorkflow] Step " j " in flow '" flowName "' failed: " resultObj["message"])
            }
            
            ; Run the step with improved error handling
            if !RunStep(step, stepFailureCallback) {
                flowSucceeded := false
                failedSteps.Push(Map("index", j, "name", step["name"] ? step["name"] : "Step " j))
                
                ; Ask if user wants to continue with this flow
                if MsgBox("Step " j " in flow '" flowName "' failed. Continue with remaining steps in this flow?", 
                         "Step Failed", "YesNo Icon!") = "No" {
                    break
                }
            }
            
            ; Small delay between steps for stability
            Sleep 100
        }
        
        ; Track flow success/failure
        if (!flowSucceeded) {
            allFlowsSucceeded := false
            failedFlows.Push(Map(
                "index", i, 
                "name", flowName, 
                "reason", "Steps failed: " failedSteps.Length "/" flowSteps.Length,
                "failedSteps", failedSteps
            ))
            
            ; Ask if user wants to continue to next flow
            if MsgBox("Flow '" flowName "' completed with " failedSteps.Length " failed steps. Continue with next flow?", 
                     "Flow Partially Failed", "YesNo Icon!") = "No" {
                break
            }
        } else {
            OutputDebug("[RunWorkflow] Flow '" flowName "' completed successfully")
        }
        
        ; Small delay between flows
        Sleep 500
    }
    
    ; Display completion message with results
    if (allFlowsSucceeded) {
        OutputDebug("[RunWorkflow] All flows completed successfully")
        MsgBox "Workflow executed successfully.", "Workflow Complete", "Icon!"
    } else {
        ; Build detailed failure message
        OutputDebug("[RunWorkflow] Workflow completed with errors in " failedFlows.Length " flows")
        
        failMsg := "Workflow execution completed with errors. The following flows had issues:`n`n"
        for i, failedFlow in failedFlows {
            failMsg .= "Flow " failedFlow["index"] ": " failedFlow["name"] " - " failedFlow["reason"] "`n"
            
            ; Add step details if available
            if (failedFlow.Has("failedSteps") && failedFlow["failedSteps"].Length > 0) {
                failMsg .= "    Failed steps: "
                
                for j, failedStep in failedFlow["failedSteps"] {
                    failMsg .= failedStep["name"] 
                    if (j < failedFlow["failedSteps"].Length)
                        failMsg .= ", "
                }
                
                failMsg .= "`n"
            }
        }
        
        MsgBox failMsg, "Workflow Completed With Errors", "Icon!"
    }
}

; Loads a selected workflow from the workflows list
; Triggered when a workflow is selected in the workflows list
SelectWorkflow(*) {
    global g_CurrentWorkflow, g_Workflows
    
    ; Check if there are any workflows in the list
    if (myGui["WorkflowsList"].GetCount() = 0)
        return
    
    ; Get the selected row
    row := myGui["WorkflowsList"].GetNext()
    if (row = 0)
        return
        
    ; Get the name from the first column
    selected := myGui["WorkflowsList"].GetText(row, 1)
    if (selected && g_Workflows.Has(selected)) {
        ; Load the selected workflow and update the GUI
        g_CurrentWorkflow := g_Workflows[selected].Clone()
        g_CurrentWorkflowName := selected
        myGui["WorkflowNameInput"].Value := selected
        myGui["WorkflowSavedAtText"].Text := ""  ; Clear the saved timestamp when loading a different workflow
        UpdateWorkflowFlowsList()
    }
}

; Adds a flow to the current workflow
; Opens a selection dialog for the user to choose a flow
; Triggered by the Add Flow button
AddFlowToWorkflow(*) {
    global g_CurrentWorkflow, g_Flows
    
    ; Check if there are any flows to add
    if (g_Flows.Count = 0) {
        MsgBox "No flows available. Create some flows first.", "Add Flow Error", "Icon!"
        return
    }
    
    ; Create a small selection dialog
    flowSelectGui := Gui("+AlwaysOnTop +ToolWindow", "Select Flow")
    flowSelectGui.SetFont("s10", "Segoe UI")
    
    ; Add a prompt text
    flowSelectGui.AddText("x10 y10", "Select a flow to add:")
    
    ; Add a listbox instead of combobox for better visibility of all flows
    flowList := flowSelectGui.AddListBox("x10 y+10 w250 h200 vSelectedFlow")
    
    ; Populate the list with flow names
    flowNames := []
    for flowName, _ in g_Flows {
        flowNames.Push(flowName)
    }
    
    ; Sort flow names alphabetically for easier selection
    arraySort(flowNames)
    
    ; Add flows to the listbox
    for _, flowName in flowNames {
        flowList.Add([flowName])
    }
    
    ; Select the first flow by default if available
    if (flowNames.Length > 0) {
        flowList.Choose(1)
    }
    
    ; Add description text to explain how to use
    flowSelectGui.AddText("x10 y+10 w250", "Double-click to add immediately, or")
    
    ; Add OK and Cancel buttons
    okButton := flowSelectGui.AddButton("x10 y+5 w80 Default", "Add")
    okButton.OnEvent("Click", FlowSelectOK)
    
    cancelButton := flowSelectGui.AddButton("x+10 w80", "Cancel")
    cancelButton.OnEvent("Click", FlowSelectCancel)
    
    ; Add event for double-click to immediately add the selected flow
    flowList.OnEvent("DoubleClick", FlowSelectOK)
    
    ; Store references for the handlers
    flowSelectGui.g_CurrentWorkflow := g_CurrentWorkflow
    
    ; Center the dialog on screen
    flowSelectGui.Show("Center")
}

; Helper function to sort arrays (not built into AHK v2)
arraySort(arr) {
    n := arr.Length
    Loop n - 1 {
        i := A_Index
        Loop n - i {
            j := A_Index + i
            if (arr[j] < arr[j-1]) {
                temp := arr[j]
                arr[j] := arr[j-1]
                arr[j-1] := temp
            }
        }
    }
    return arr
}

; Handler for the flow selection dialog OK button
FlowSelectOK(ctrl, *) {
    flowSelectGui := ctrl.Gui
    selectedFlow := flowSelectGui["SelectedFlow"].Text
    
    if (selectedFlow = "") {
        ; If nothing is selected, try to get the selected item directly
        selectedIndex := flowSelectGui["SelectedFlow"].Value
        if (selectedIndex > 0) {
            selectedFlow := flowSelectGui["SelectedFlow"].Text
        }
    }
    
    if (selectedFlow != "") {
        ; Add the selected flow to the workflow
        flowSelectGui.g_CurrentWorkflow.Push(selectedFlow)
        UpdateWorkflowFlowsList()
    } else {
        MsgBox "Please select a flow to add.", "No Flow Selected", "Icon!"
        return
    }
    
    flowSelectGui.Destroy()
}

; Handler for the flow selection dialog Cancel button
FlowSelectCancel(ctrl, *) {
    ctrl.Gui.Destroy()
}

; Removes the selected flow from the current workflow
; Triggered by the Remove button
RemoveFlowFromWorkflow(*) {
    global g_CurrentWorkflow
    
    ; Check if there are any flows in the list
    if (myGui["WorkflowFlowsList"].GetCount() = 0)
        return
    
    ; Get the selected row
    row := myGui["WorkflowFlowsList"].GetNext()
    if (row > 0) {
        ; Remove the flow at that index and update the GUI
        g_CurrentWorkflow.RemoveAt(row)
        UpdateWorkflowFlowsList()
    }
}

; Moves the selected flow up in the workflow order
; Triggered by the Move Up button
MoveFlowUp(*) {
    global g_CurrentWorkflow
    
    ; Check if there are any flows in the list
    if (myGui["WorkflowFlowsList"].GetCount() = 0)
        return
    
    ; Get the selected row
    row := myGui["WorkflowFlowsList"].GetNext()
    if (row > 1) {  ; Can't move up if already at the top
        ; Swap with the flow above
        temp := g_CurrentWorkflow[row - 1]
        g_CurrentWorkflow[row - 1] := g_CurrentWorkflow[row]
        g_CurrentWorkflow[row] := temp
        UpdateWorkflowFlowsList()
        
        ; Keep the same flow selected after moving
        myGui["WorkflowFlowsList"].Modify(row - 1, "Select")
    }
}

; Moves the selected flow down in the workflow order
; Triggered by the Move Down button
MoveFlowDown(*) {
    global g_CurrentWorkflow
    
    ; Check if there are any flows in the list
    if (myGui["WorkflowFlowsList"].GetCount() = 0)
        return
    
    ; Get the selected row
    row := myGui["WorkflowFlowsList"].GetNext()
    if (row > 0 && row < g_CurrentWorkflow.Length) {  ; Can't move down if already at the bottom
        ; Swap with the flow below
        temp := g_CurrentWorkflow[row + 1]
        g_CurrentWorkflow[row + 1] := g_CurrentWorkflow[row]
        g_CurrentWorkflow[row] := temp
        UpdateWorkflowFlowsList()
        
        ; Keep the same flow selected after moving
        myGui["WorkflowFlowsList"].Modify(row + 1, "Select")
    }
}

; Updates the list of workflows displayed in the GUI
; Called after workflows are loaded or when a new workflow is saved
UpdateWorkflowsList() {
    global g_Workflows
    
    ; Clear existing items in the list
    myGui["WorkflowsList"].Delete()
    
    ; Add workflows to the list
    for workflowName, flowsArray in g_Workflows {
        myGui["WorkflowsList"].Add(, workflowName, flowsArray.Length, "Sequence of " flowsArray.Length " flows")
    }
}

; Updates the list of flows displayed in the GUI for the current workflow
; Called when flows are added, removed, or a workflow is selected
UpdateWorkflowFlowsList() {
    global g_CurrentWorkflow
    
    ; Clear existing items in the list
    myGui["WorkflowFlowsList"].Delete()
    
    ; Add flows to the list with their order
    for i, flowName in g_CurrentWorkflow {
        myGui["WorkflowFlowsList"].Add(, flowName, i)
    }
}

; Saves all workflows to the JSON file specified in g_WorkflowsFilePath
; Called after a workflow is saved or modified
SaveWorkflowsToFile() {
    global g_Workflows, g_WorkflowsFilePath
    
    try {
        ; Encode the workflows to JSON using our custom encoder
        workflowsJson := SimpleJsonEncode(g_Workflows)
        
        ; Ensure the file path is valid
        workflowsPath := CombinePath(g_WorkingDir, "workflows.json")
        
        ; Only try to delete the file if it exists before writing new content
        if FileExist(workflowsPath)
            FileDelete(workflowsPath)
        
        ; Save the JSON to the file
        FileAppend(workflowsJson, workflowsPath)
    } catch as e {
        MsgBox "Error saving workflows to file: " e.Message, "Save Error", "Icon!"
    }
}

; Loads workflows from the JSON file specified in g_WorkflowsFilePath
; Called when the GUI is initialized
LoadWorkflowsFromFile() {
    global g_Workflows, g_WorkflowsFilePath
    
    ; Initialize empty workflows map
    g_Workflows := Map()
    
    ; Ensure the file path is valid
    workflowsPath := CombinePath(g_WorkingDir, "workflows.json")
    
    ; Check if file exists
    if !FileExist(workflowsPath) {
        OutputDebug("Workflows file does not exist: " workflowsPath)
        return
    }
    
    try {
        ; Read the file contents
        fileContent := FileRead(workflowsPath)
        
        ; Check if file is empty
        if (fileContent = "") {
            OutputDebug("Workflows file is empty")
            return
        }
        
        ; Use our custom decoder to parse the JSON
        parsed := SimpleJsonDecode(fileContent)
        
        ; Process each workflow in the parsed data
        for workflowName, flowsArray in parsed {
            ; Only process if flowsArray is actually an array
            if (Type(flowsArray) = "Array") {
                flowArray := []
                
                ; Add each flow name to the workflow
                for i, flowName in flowsArray {
                    if (Type(flowName) = "String") {
                        flowArray.Push(flowName)
                    }
                }
                
                g_Workflows[workflowName] := flowArray
            }
        }
        
        ; If we loaded successfully, update the UI
        if (g_Workflows.Count > 0) {
            OutputDebug("Loaded " g_Workflows.Count " workflows successfully")
            if IsObject(myGui) {
                UpdateWorkflowsList()
            }
        } else {
            OutputDebug("No flows were loaded")
        }
    } catch as e {
        errMsg := "Error loading workflows from file: " e.Message
        OutputDebug(errMsg)
        MsgBox errMsg, "Load Error", "Icon!"
    }
}
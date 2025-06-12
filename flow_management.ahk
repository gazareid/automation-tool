#Requires AutoHotkey v2.0

;------------------------------------------------------------------------------
; FLOW MANAGEMENT FUNCTIONS
;------------------------------------------------------------------------------
; Creates a new step object for a flow
; Parameters:
;   imagePath: Path to the image to find on screen
;   waitTime: Time to wait in milliseconds before executing the step
;   subSteps: Array of subSteps to execute after clicking the image
;   clickPosition: Where to click on the image (upper left, lower left, upper right, lower right, center)
;   name: Name of the step (optional)
;   description: Description of the step (optional)
;   actionType: 'click' or 'hover' (default 'click')
;   clickType: 'image' or 'coordinates' (default 'image')
;   clickX: X coordinate for coordinate-based clicking (optional)
;   clickY: Y coordinate for coordinate-based clicking (optional)
; Returns: A Map object representing the step
CreateFlowStep(imagePath, waitTime := 0, subSteps := [], clickPosition := "center", name := "", description := "", actionType := "click", clickType := "image", clickX := 0, clickY := 0) {
    ; Ensure consistent path formatting for storage
    imagePath := StandardizeImagePath(imagePath)
    
    return Map(
        "imagePath", imagePath,
        "waitTime", waitTime,
        "subSteps", subSteps,
        "clickPosition", clickPosition,
        "name", name,
        "description", description,
        "actionType", actionType,
        "clickType", clickType,
        "clickX", clickX,
        "clickY", clickY
    )
}

; Saves the current flow to the flows collection
; Flow name is taken from the GUI input
; Triggered by the Save button
SaveCurrentFlow(*) {
    global g_CurrentFlow, g_Flows, g_CurrentFlowName, g_FlowsFilePath, g_SelectedStepIndex
    
    flowName := myGui["FlowNameInput"].Value
    if (flowName = "") {
        MsgBox "Please enter a name for the flow.", "Flow Name Required", "Icon!"
        return
    }

    ; If a step is selected, update it with the current configuration values
    if (IsSet(g_SelectedStepIndex) && g_SelectedStepIndex > 0 && g_SelectedStepIndex <= g_CurrentFlow.Length) {
        stepName := myGui["StepNameInput"].Value
        description := myGui["StepDescriptionInput"].Value
        imagePath := myGui["ImagePathInput"].Value
        waitTime := myGui["WaitTimeInput"].Value
        clickPosition := myGui["ClickPositionInput"].Text
        actionType := myGui["ActionTypeInput"].Text
        clickType := myGui["ClickTypeInput"].Text
        clickX := myGui["XCoordInput"].Value
        clickY := myGui["YCoordInput"].Value
        ; Use g_EditingSubSteps for subSteps
        subSteps := g_EditingSubSteps.Clone()
        
        ; Validate based on click type
        if (clickType = "Image") {
            ; Validate image path (required field for image-based clicking)
            if (imagePath = "") {
                MsgBox "Image path is required for image-based clicking.", "Input Error", "Icon!"
                return
            }
        } else {
            ; Validate coordinates for coordinate-based clicking
            if (clickX = "" || clickY = "") {
                MsgBox "Both X and Y coordinates are required for coordinate-based clicking.", "Input Error", "Icon!"
                return
            }
            ; Convert coordinates to numbers and validate
            try {
                clickX := Integer(clickX)
                clickY := Integer(clickY)
            } catch as err {
                MsgBox "X and Y coordinates must be valid numbers.", "Input Error", "Icon!"
                return
            }
        }
        
        g_CurrentFlow[g_SelectedStepIndex] := CreateFlowStep(imagePath, waitTime, subSteps, clickPosition, stepName, description, actionType, clickType, clickX, clickY)
        UpdateStepsList()
        myGui["SavedAtText"].Text := "Step updated at " . FormatTime(, "HH:mm:ss")
    }
    
    ; Save the original button text and update it to "Saving"
    saveButton := myGui["SaveButton"]
    originalText := saveButton.Text
    
    ; Get the start time
    startTime := A_TickCount
    
    ; Animate the saving text directly - simpler approach to avoid timer issues
    saveButton.Text := "Saving"
    
    ; Do the actual save operation first
    g_CurrentFlowName := flowName
    g_Flows[flowName] := g_CurrentFlow.Clone()

    ; Update image dimensions for all images in the flow
    UpdateFlowImageDimensions(g_CurrentFlow)
    
    SaveFlowsToFile()
    UpdateFlowList()
    StepRec_UpdateFlowsDropdown()
    
    ; Get current time for the saved timestamp
    currentTime := FormatTime(, "HH:mm:ss")
    myGui["SavedAtText"].Text := "Saved at " . currentTime
    
    ; Now do the ellipsis animation for visual feedback
    ; Make sure it runs for at least 1 second total
    elapsedTime := A_TickCount - startTime
    
    ; Direct animation with Sleep between steps - no timer needed
    try {
        Loop 3 {
            Sleep 200
            saveButton.Text := "Saving" . StrRepeat(".", A_Index)
        }
        
        ; Make sure we've animated for at least 1 second
        elapsedTime := A_TickCount - startTime
        if (elapsedTime < 1000)
            Sleep(1000 - elapsedTime)
            
        ; Restore the original button text
        saveButton.Text := originalText
    } catch as err {
        ; If any errors occur, just restore the button
        OutputDebug("Error during save animation: " err.Message)
        try {
            saveButton.Text := originalText
        }
    }
}

; Helper function to repeat a string n times
StrRepeat(str, n) {
    result := ""
    Loop n
        result .= str
    return result
}

; Saves all flows to the JSON file specified in g_FlowsFilePath
; Called after a flow is saved or modified
SaveFlowsToFile() {
    global g_Flows, g_FlowsFilePath
    
    try {
        ; Convert our flows into a format suitable for JSON encoding
        jsonObj := Map()
        
        ; Add each flow to the JSON object
        for flowName, flowSteps in g_Flows {
            ; For debugging - log the flow steps before encoding
            OutputDebug("Saving flow: " flowName " with " flowSteps.Length " steps")
            
            ; Create a copy of the flow steps to ensure all properties are included
            flowStepsCopy := []
            for i, step in flowSteps {
                ; Log each step to verify all properties are present
                stepName := step.Has("name") ? step["name"] : ""
                stepDesc := step.Has("description") ? step["description"] : ""
                OutputDebug("Step " i ": name='" stepName "', desc='" stepDesc "', path='" step["imagePath"] "', action='" step["actionType"] "', wait='" step["waitTime"] "', click='" step["clickPosition"] "'")
                
                ; Create a new step map with all properties explicitly included
                newStep := Map(
                    "imagePath", step["imagePath"],
                    "waitTime", step["waitTime"],
                    "subSteps", step["subSteps"],
                    "clickPosition", step["clickPosition"],
                    "name", step["name"],
                    "description", step["description"],
                    "actionType", step["actionType"],
                    "clickType", step.Has("clickType") ? step["clickType"] : "Image",
                    "clickX", step.Has("clickX") ? step["clickX"] : 0,
                    "clickY", step.Has("clickY") ? step["clickY"] : 0
                )
                
                ; The path is already standardized by BrowseForImage, no need to modify it here
                if (newStep["imagePath"] != "") {
                    OutputDebug("Using existing image path: " newStep["imagePath"])
                }
                
                flowStepsCopy.Push(newStep)
            }
            
            ; Store the explicitly copied steps
            jsonObj[flowName] := flowStepsCopy
        }
        
        ; Encode the object to JSON using our custom encoder
        ; TIP: If you need more complex JSON handling, consider using a dedicated JSON library
        flowsJson := SimpleJsonEncode(jsonObj)
        
        ; Log a sample of the JSON output for debugging
        OutputDebug("JSON sample: " SubStr(flowsJson, 1, 200) "...")
        
        ; Only try to delete the file if it exists before writing new content
        if FileExist(g_FlowsFilePath)
            FileDelete(g_FlowsFilePath)
        
        ; Save the JSON to the file
        FileAppend(flowsJson, g_FlowsFilePath)
        
        ; Verify the write was successful
        if FileExist(g_FlowsFilePath) {
            fileContent := FileRead(g_FlowsFilePath)
            OutputDebug("Written flows.json size: " StrLen(fileContent) " bytes")
        } else {
            OutputDebug("Failed to create flows.json file")
        }
    } catch as e {
        OutputDebug("Error saving flows: " e.Message " at line " e.Line)
        MsgBox "Error saving flows to file: " e.Message, "Save Error", "Icon!"
    }
}

; Loads flows from the JSON file specified in g_FlowsFilePath
; Called when the GUI is initialized
LoadFlowsFromFile() {
    global g_Flows, g_FlowsFilePath
    
    ; Initialize empty flows map
    g_Flows := Map()
    
    ; Check if file exists
    if !FileExist(g_FlowsFilePath) {
        OutputDebug("Flows file does not exist: " g_FlowsFilePath)
        return
    }
    
    try {
        ; Read the file contents
        fileContent := FileRead(g_FlowsFilePath)
        OutputDebug("Read flows file, length: " StrLen(fileContent))
        
        ; Check if file is empty
        if (fileContent = "") {
            OutputDebug("Flows file is empty")
            return
        }
        
        ; Log the content for debugging
        OutputDebug("File content: " SubStr(fileContent, 1, 100) (StrLen(fileContent) > 100 ? "..." : ""))
            
        ; Use our custom decoder to parse the JSON
        parsed := SimpleJsonDecode(fileContent)
        OutputDebug("Parsed JSON, found " (IsObject(parsed) ? parsed.Count : 0) " flows")
        
        ; Process each flow in the parsed data
        for flowName, flowSteps in parsed {
            OutputDebug("Processing flow: " flowName)
            stepArray := []
            
            ; Only process if flowSteps is actually an array
            if (Type(flowSteps) = "Array") {
                OutputDebug("Flow has " flowSteps.Length " steps")
                for i, step in flowSteps {
                    ; Create step with defaults for any missing properties
                    imagePath := step.Has("imagePath") ? step["imagePath"] : ""
                    waitTime := step.Has("waitTime") ? step["waitTime"] : 0
                    subSteps := step.Has("subSteps") ? step["subSteps"] : []
                    clickPosition := step.Has("clickPosition") ? step["clickPosition"] : "center"
                    name := step.Has("name") ? step["name"] : ""
                    description := step.Has("description") ? step["description"] : ""
                    actionType := step["actionType"]
                    
                    stepArray.Push(CreateFlowStep(imagePath, waitTime, subSteps, clickPosition, name, description, actionType))
                    OutputDebug("Added step " i " with image: " imagePath)
                }
            } else {
                OutputDebug("Flow steps is not an array: " Type(flowSteps))
            }
            
            g_Flows[flowName] := stepArray
        }
        
        ; Initialize dimensions for all images in all flows
        InitAllFlowImageDimensions()
        
        ; If we loaded successfully, update the UI
        if (g_Flows.Count > 0) {
            OutputDebug("Loaded " g_Flows.Count " flows successfully")
            if IsObject(myGui) {
                UpdateFlowList()
            }
        } else {
            OutputDebug("No flows were loaded")
        }
    } catch as e {
        errMsg := "Error loading flows from file: " e.Message
        OutputDebug(errMsg)
        OutputDebug("Error at line: " e.Line)
        MsgBox errMsg, "Load Error", "Icon!"
    }
}

; Updates the list of flows displayed in the GUI
; Called after flows are loaded or when a new flow is saved
UpdateFlowList() {
    global g_Flows, g_FlowFilter
    
    ; Clear existing items in the list
    myGui["FlowsList"].Delete()
    
    ; Add flows to the list, filtered by the current filter text
    for flowName, _ in g_Flows {
        if (g_FlowFilter = "" || InStr(flowName, g_FlowFilter)) {
            myGui["FlowsList"].Add(, flowName)
        }
    }
}

; Filter the flows list based on the filter text
FilterFlows(*) {
    global g_FlowFilter
    g_FlowFilter := myGui["FlowFilterInput"].Value
    UpdateFlowList()
}

; Adds a step to the current flow based on GUI inputs
; Triggered by the Add Step button
AddFlowStep(*) {
    global g_CurrentFlow
    
    ; Get values from the GUI inputs
    stepName := myGui["StepNameInput"].Value
    description := myGui["StepDescriptionInput"].Value
    imagePath := myGui["ImagePathInput"].Value
    waitTime := myGui["WaitTimeInput"].Value
    clickPosition := myGui["ClickPositionInput"].Text
    actionType := myGui.HasProp("ActionTypeInput") ? myGui["ActionTypeInput"].Text : "click"
    
    ; Validate image path (required field)
    if (imagePath = "") {
        MsgBox "Image path is required.", "Input Error", "Icon!"
        return
    }
    
    ; Create and add the step to the current flow
    step := CreateFlowStep(imagePath, waitTime, g_EditingSubSteps.Clone(), clickPosition, stepName, description, actionType)
    g_CurrentFlow.Push(step)
    
    ; Update the steps list in the GUI
    UpdateStepsList()
    
    ; Clear the inputs for the next step
    myGui["StepNameInput"].Value := ""
    myGui["StepDescriptionInput"].Value := ""
    myGui["ImagePathInput"].Value := ""
    myGui["WaitTimeInput"].Value := "0"
    myGui["ClickPositionInput"].Choose(1)  ; Reset to "center"
    if myGui.HasProp("ActionTypeInput")
        myGui["ActionTypeInput"].Choose(1)
    SaveCurrentFlow()
}

; Updates the list of steps displayed in the GUI for the current flow
; Called when steps are added, removed, or a flow is selected
UpdateStepsList() {
    global g_CurrentFlow
    myGui["StepsList"].Delete()
    for i, step in g_CurrentFlow {
        subStepsSummary := ""
        if (step.Has("subSteps") && step["subSteps"].Length > 0) {
            for _, subStep in step["subSteps"] {
                subStepsSummary .= subStep["type"] ":" subStep["value"] "; "
            }
            if (subStepsSummary != "")
                subStepsSummary := SubStr(subStepsSummary, 1, -2) ; Remove trailing semicolon and space
        }
        actionType := step.Has("actionType") ? step["actionType"] : "click"
        myGui["StepsList"].Add(, i, step["name"], step["description"], step["imagePath"], step["clickPosition"], actionType, step["waitTime"], subStepsSummary)
    }
}

; Function to clear all step details fields
ClearStepDetailsFields() {
    ; Clear step name and description
    myGui["StepNameInput"].Value := ""
    myGui["StepDescriptionInput"].Value := ""
    
    ; Clear image path and coordinates
    myGui["ImagePathInput"].Value := ""
    myGui["XCoordInput"].Value := "0"
    myGui["YCoordInput"].Value := "0"
    
    ; Reset click type to default (Image)
    myGui["ClickTypeInput"].Choose(1)
    
    ; Reset wait time
    myGui["WaitTimeInput"].Value := "0"
    
    ; Reset click position to center
    myGui["ClickPositionInput"].Choose(1)
    
    ; Reset action type to click
    myGui["ActionTypeInput"].Choose(1)
    
    ; Clear sub steps
    global g_EditingSubSteps := []
    UpdateSubStepsList()
    
    ; Clear selected step text
    myGui["SelectedStepText"].Text := ""
    
    ; Clear image preview by setting it to an empty string
    try {
        myGui["ImagePreview"].Value := ""
    } catch as err {
        OutputDebug("[ClearStepDetailsFields] Error clearing image preview: " err.Message)
    }
}

; Loads a selected flow from the flows list
; Triggered when a flow is selected in the flows list
SelectFlow(*) {
    global g_CurrentFlow, g_Flows
    
    ; Check if there are any flows in the list
    if (myGui["FlowsList"].GetCount() = 0)
        return
    
    ; Get the selected row
    row := myGui["FlowsList"].GetNext()
    if (row = 0)
        return
        
    ; Get the name from the first column
    selected := myGui["FlowsList"].GetText(row, 1)
    if (selected && g_Flows.Has(selected)) {
        ; Clear step details fields before loading new flow
        ClearStepDetailsFields()
        
        ; Load the selected flow and update the GUI
        g_CurrentFlow := g_Flows[selected].Clone()
        g_CurrentFlowName := selected
        myGui["FlowNameInput"].Value := selected
        myGui["SavedAtText"].Text := ""  ; Clear the saved timestamp when loading a different flow
        myGui["SelectedFlowText"].Text := selected  ; Update the selected flow text in Steps tab
        UpdateStepsList()
    }
}

; Loads the selected step's details into the configuration fields
; Triggered when a step is selected in the steps list
SelectStep(*) {
    global g_CurrentFlow, g_SelectedStepIndex, g_ImageDimensions
    
    ; Check if there are any steps in the list
    if (myGui["StepsList"].GetCount() = 0)
        return
    
    ; Get the selected row
    row := myGui["StepsList"].GetNext()
    if (row = 0)
        return
    
    ; Store the selected step index globally
    g_SelectedStepIndex := row
    
    ; Get the step from the current flow array
    if (row <= g_CurrentFlow.Length) {
        step := g_CurrentFlow[row]
        
        ; Update the selected step text
        stepName := step["name"] ? step["name"] : "Step " . row
        myGui["SelectedStepText"].Text := stepName
        
        ; Populate the step configuration fields
        myGui["StepNameInput"].Value := step["name"]
        myGui["StepDescriptionInput"].Value := step["description"]
        myGui["ImagePathInput"].Value := step["imagePath"]
        myGui["WaitTimeInput"].Value := step["waitTime"]
        
        ; Set click type and update UI (case-insensitive)
        clickType := step.Has("clickType") ? step["clickType"] : "Image"
        clickTypeLower := StrLower(clickType)
        if (clickTypeLower = "image") {
            myGui["ClickTypeInput"].Choose(1)
        } else {
            myGui["ClickTypeInput"].Choose(2)
        }
        UpdateClickTypeUI()
        
        ; Set coordinates if they exist
        if (step.Has("clickX") && step.Has("clickY")) {
            myGui["XCoordInput"].Value := step["clickX"]
            myGui["YCoordInput"].Value := step["clickY"]
        }
        
        ; Set click position if it exists
        if (step.Has("clickPosition")) {
            positions := ["center", "upper left", "upper right", "lower left", "lower right"]
            for i, pos in positions {
                if (pos = step["clickPosition"]) {
                    myGui["ClickPositionInput"].Choose(i)
                    break
                }
            }
        }
        
        ; Set action type if it exists
        if (step.Has("actionType")) {
            actionType := step["actionType"]
            types := ["click", "hover"]
            for i, type in types {
                if (type = actionType) {
                    myGui["ActionTypeInput"].Choose(i)
                    break
                }
            }
        }
        
        ; Set g_EditingSubSteps and call UpdateSubStepsList
        global g_EditingSubSteps := step.Has("subSteps") ? step["subSteps"].Clone() : []
        UpdateSubStepsList()
        
        ; Update image preview if it's an image-based step
        if (clickTypeLower = "image" && step["imagePath"] != "") {
            absPath := ResolveImagePath(step["imagePath"])
            if (absPath != "") {
                try {
                    myGui["ImagePreview"].Value := absPath
                } catch as err {
                    OutputDebug("[SelectStep] Error setting image preview: " err.Message)
                }
            }
        }
    }
}

SelectSubStep(*) {
    row := myGui["SubStepsList"].GetNext()
    OutputDebug("[SelectSubStep] Selected sub step Type: " g_EditingSubSteps[row]["type"])
    
    if (row > 0) {
        type := g_EditingSubSteps[row]["type"]
        types := ["text", "key", "scroll"]
        index := 1
        for i, v in types {
            if (v = type) {
                index := i
                break
            }
        }
        myGui["SubStepTypeInput"].Value := index
        myGui["SubStepValueInput"].Value := g_EditingSubSteps[row]["value"]
    }
}

; Updates the selected step with the current configuration values
; Triggered by the Update Step button
UpdateSelectedStep(*) {
    global g_CurrentFlow, g_SelectedStepIndex
    
    ; Check if a step is selected
    if (!IsSet(g_SelectedStepIndex) || g_SelectedStepIndex = 0 || g_SelectedStepIndex > g_CurrentFlow.Length) {
        MsgBox "Please select a step to update.", "Update Error", "Icon!"
        return
    }
    
    ; Get values from the GUI inputs
    stepName := myGui["StepNameInput"].Value
    description := myGui["StepDescriptionInput"].Value
    imagePath := myGui["ImagePathInput"].Value
    waitTime := myGui["WaitTimeInput"].Value
    clickPosition := myGui["ClickPositionInput"].Text
    actionType := myGui.HasProp("ActionTypeInput") ? myGui["ActionTypeInput"].Text : "click"
    
    ; Validate image path (required field)
    if (imagePath = "") {
        MsgBox "Image path is required.", "Input Error", "Icon!"
        return
    }
    
    ; Standardize the image path for storage
    imagePath := StandardizeImagePath(imagePath)
    
    ; Update the step in the current flow
    g_CurrentFlow[g_SelectedStepIndex] := CreateFlowStep(imagePath, waitTime, g_EditingSubSteps.Clone(), clickPosition, stepName, description, actionType)
    
    ; Update the steps list in the GUI
    UpdateStepsList()
    
    ; Update the selected step text
    myGui["SelectedStepText"].Text := stepName ? stepName : "Step " . g_SelectedStepIndex
    
    ; Provide feedback
    myGui["SavedAtText"].Text := "Step updated at " . FormatTime(, "HH:mm:ss")
}

; Creates a new empty flow
; Triggered by the New button
NewFlow(*) {
    global g_CurrentFlow, g_CurrentFlowName, g_Flows
    
    ; Prompt for a new flow name
    input := InputBox("Enter a name for the new flow:", "New Flow", "w400 h120")
    if (input.Result = "Cancel" || input.Value = "") {
        return  ; User cancelled or entered nothing
    }
    flowName := input.Value
    
    ; If a flow with this name already exists, optionally prompt to overwrite or just select it
    if (g_Flows.Has(flowName)) {
        MsgBox "A flow with this name already exists. Please choose a different name.", "Duplicate Flow Name", "Icon!"
        return
    }
    
    ; Create and save the new flow
    g_CurrentFlow := []
    g_CurrentFlowName := flowName
    g_Flows[flowName] := g_CurrentFlow.Clone()
    myGui["FlowNameInput"].Value := flowName
    myGui["SavedAtText"].Text := ""
    myGui["SelectedFlowText"].Text := flowName  ; Update the selected flow text in Steps tab
    UpdateStepsList()
    SaveFlowsToFile()
    UpdateFlowList()
    StepRec_UpdateFlowsDropdown()
}

; Removes the selected step from the current flow
; Triggered by the Remove Selected button
RemoveSelectedStep(*) {
    global g_CurrentFlow
    
    ; Check if there are any steps in the list
    if (myGui["StepsList"].GetCount() = 0)
        return
    
    ; Get the selected row
    row := myGui["StepsList"].GetNext()
    if (row > 0) {
        ; Remove the step at that index and update the GUI
        g_CurrentFlow.RemoveAt(row)
        UpdateStepsList()
        myGui["SelectedStepText"].Text := ""  ; Clear the selected step text
    }
    SaveCurrentFlow()
}

; Executes all flows in the current flow
; Triggered by the Run button or Ctrl+Alt+R hotkey
RunFlow(*) {
    global g_CurrentFlow
    
    ; Check if there are any steps to run
    if (g_CurrentFlow.Length = 0) {
        MsgBox "No steps to run.", "Run Error", "Icon!"
        return
    }
    
    ; Initialize success flag and error tracking
    allStepsSucceeded := true
    failedSteps := []
    
    ; Run each step in the flow in sequence
    for i, step in g_CurrentFlow {
        OutputDebug("[RunFlow] Running step " i "/" g_CurrentFlow.Length ": " step["name"])
        
        ; Define a failure callback for detailed reporting
        stepFailureCallback(resultObj) {
            OutputDebug("[RunFlow] Step failed: " resultObj["message"])
        }
        
        ; Run the step with error handling
        if !RunStep(step, stepFailureCallback) {
            allStepsSucceeded := false
            failedSteps.Push(Map("index", i, "name", step["name"]))
            
            ; Ask user if they want to continue after a failed step
            if MsgBox("Step " i ": '" step["name"] "' failed. Continue with remaining steps?", 
                     "Step Failed", "YesNo Icon!") = "No" {
                break
            }
        }
        
        ; Small delay between steps for stability
        Sleep 100
    }
    
    ; Show completion message with results
    if (allStepsSucceeded) {
        ; Flow completed successfully - no message box needed
        return
    } else {
        ; Build detailed failure message
        failMsg := "Flow execution completed with errors. The following steps failed:`n`n"
        for i, failedStep in failedSteps {
            failMsg .= "Step " failedStep["index"] ": " failedStep["name"] "`n"
        }
        
        MsgBox failMsg, "Flow Completed With Errors", "Icon!"
    }
}

; Runs a step with improved error handling
; Parameters:
;   step: The step to run
;   failCallback: Optional callback function to call on failure for detailed reporting
; Returns: true if successful, false if failed
RunStep(step, failCallback := "") {
    stepName := step.Has("name") && step["name"] != "" ? step["name"] : "Unnamed Step"
    imagePath := step["imagePath"]
    waitTime := step["waitTime"]
    actionType := step.Has("actionType") ? step["actionType"] : "click"
    clickType := step.Has("clickType") ? step["clickType"] : "Image"
    clickX := step.Has("clickX") ? step["clickX"] : 0
    clickY := step.Has("clickY") ? step["clickY"] : 0
    OutputDebug("[RunStep] Executing step: " stepName)
    
    if (waitTime > 0) {
        OutputDebug("[RunStep] Waiting for " waitTime "ms before action")
        Sleep waitTime
    }

    success := false
    if (clickType = "Image") {
        OutputDebug("[RunStep] Looking for image: " imagePath)
        timeoutMs := 10000  ; 10 second timeout for finding images
        
        if (actionType = "hover") {
            success := FindAndHover(imagePath, step["clickPosition"], timeoutMs, failCallback)
        } else {
            success := FindAndClick(imagePath, step["clickPosition"], timeoutMs, failCallback)
        }
    } else {
        OutputDebug("[RunStep] Clicking at coordinates: " clickX "," clickY)
        try {
            if (actionType = "hover") {
                MouseMove(clickX, clickY)
                success := true
            } else {
                Click(clickX " " clickY)
                success := true
            }
        } catch as err {
            if (failCallback != "") {
                failCallback(Map("message", "Failed to click at coordinates: " err.Message))
            } else {
                MsgBox "Failed to click at coordinates: " err.Message, "Run Error", "Icon!"
            }
            success := false
        }
    }

    if !success {
        if (failCallback = "") {
            if (clickType = "Image") {
                MsgBox "Failed to find image for step: " stepName "`nImage path: " imagePath, "Run Error", "Icon!"
            } else {
                MsgBox "Failed to click at coordinates for step: " stepName, "Run Error", "Icon!"
            }
        }
        return false
    }

    ; Execute sub steps
    if (step.Has("subSteps") && step["subSteps"].Length > 0) {
        for _, subStep in step["subSteps"] {
            if (subStep["type"] = "text") {
                OutputDebug("[RunStep] Sending text: " subStep["value"])
                Sleep 100
                Loop Parse, subStep["value"] {
                    SendInput "{Raw}" A_LoopField
                    Sleep 20
                }
            } else if (subStep["type"] = "key") {
                OutputDebug("[RunStep] Sending key: " subStep["value"])
                Sleep 100
                key := subStep["value"]
                keyMap := Map("Tab", "{Tab}", "Enter", "{Enter}", "Esc", "{Esc}", "Space", "{Space}", "Backspace", "{Backspace}", "Delete", "{Delete}", "Up", "{Up}", "Down", "{Down}", "Left", "{Left}", "Right", "{Right}", "Home", "{Home}", "End", "{End}", "PgUp", "{PgUp}", "PgDn", "{PgDn}")
                if keyMap.Has(key)
                    key := keyMap[key]
                else if RegExMatch(key, "i)^(Ctrl|Alt|Shift)\+([A-Z0-9])$", &m)
                    key := "{" m[1] " Down}" m[2] "{" m[1] " Up}"
                SendInput key
            } else if (subStep["type"] = "scroll") {
                OutputDebug("[RunStep] Scrolling " subStep["value"])
                Sleep 100
                if (StrLower(subStep["value"]) = "up") {
                    SendInput "{WheelUp 3}"  ; Scroll up 3 notches
                } else {
                    SendInput "{WheelDown 3}"  ; Scroll down 3 notches
                }
            }
            Sleep 100
        }
    }
    OutputDebug("[RunStep] Step completed successfully: " stepName)
    return true
}

; Executes a single step from the current flow
; Triggered by the Run Step button
RunSingleStep(*) {    
    ; Check if a step is selected
    if (!IsSet(g_SelectedStepIndex) || g_SelectedStepIndex = 0 || g_SelectedStepIndex > g_CurrentFlow.Length) {
        MsgBox "Please select a step to run.", "Run Error", "Icon!"
        return
    }
    
    ; Get the selected step
    step := g_CurrentFlow[g_SelectedStepIndex]
    
    ; Define a failure callback for detailed reporting
    stepFailureCallback(resultObj) {
        errorMsg := "Step failed: " resultObj["message"]
        OutputDebug("[RunSingleStep] " errorMsg)
        MsgBox errorMsg, "Step Failed", "Icon!"
    }
    
    ; Run the step with error handling
    if RunStep(step, stepFailureCallback) {
        MsgBox "Step executed successfully.", "Step Complete", "Icon!"
    }
}

AddSubStep(*) {
    type := myGui["SubStepTypeInput"].Text
    value := myGui["SubStepValueInput"].Value
    if (value = "") {
        MsgBox "Please enter a value for the sub step.", "Input Error", "Icon!"
        return
    }
    ; Validate key names for 'key' type
    if (type = "key" && !IsValidKeyName(value)) {
        MsgBox "Invalid key name. Use keys like Tab, Enter, Esc, Ctrl+C, etc.", "Input Error", "Icon!"
        return
    }
    ; Validate scroll direction for 'scroll' type
    if (type = "scroll" && !IsValidScrollDirection(value)) {
        MsgBox "Invalid scroll direction. Use 'up' or 'down'.", "Input Error", "Icon!"
        return
    }
    g_EditingSubSteps.Push(Map("type", type, "value", value))
    UpdateSubStepsList()
    myGui["SubStepValueInput"].Value := ""
}

; Validates allowed key names for 'key' sub steps
IsValidKeyName(key) {
    static validKeys := ["Tab", "Enter", "Esc", "Space", "Backspace", "Delete", "Up", "Down", "Left", "Right", "Home", "End", "PgUp", "PgDn"]
    if RegExMatch(key, "i)^(Ctrl|Alt|Shift)\+[A-Z0-9]$")
        return true
    for _, k in validKeys
        if (StrLower(key) = StrLower(k))
            return true
    return false
}

; Validates scroll direction for 'scroll' sub steps
IsValidScrollDirection(direction) {
    return StrLower(direction) = "up" || StrLower(direction) = "down"
}

RemoveSubStep(*) {
    row := myGui["SubStepsList"].GetNext()
    if (row > 0) {
        g_EditingSubSteps.RemoveAt(row)
        UpdateSubStepsList()
    }
}

MoveSubStepUp(*) {
    row := myGui["SubStepsList"].GetNext()
    if (row > 1) {
        temp := g_EditingSubSteps[row - 1]
        g_EditingSubSteps[row - 1] := g_EditingSubSteps[row]
        g_EditingSubSteps[row] := temp
        UpdateSubStepsList()
        myGui["SubStepsList"].Modify(row - 1, "Select Focus")
    }
}

MoveSubStepDown(*) {
    row := myGui["SubStepsList"].GetNext()
    if (row > 0 && row < g_EditingSubSteps.Length) {
        temp := g_EditingSubSteps[row + 1]
        g_EditingSubSteps[row + 1] := g_EditingSubSteps[row]
        g_EditingSubSteps[row] := temp
        UpdateSubStepsList()
        myGui["SubStepsList"].Modify(row + 1, "Select Focus")
    }
}

UpdateSubStepsList() {
    OutputDebug("[UpdateSubStepsList] Updating sub steps list: " g_EditingSubSteps.Length)
    myGui["SubStepsList"].Delete()
    for i, subStep in g_EditingSubSteps {
        myGui["SubStepsList"].Add(, i, subStep["type"], subStep["value"])
    }
}

; Copies the selected step to another flow
; Triggered by the Copy Step button
CopyStepToFlow(*) {
    global g_CurrentFlow, g_Flows, g_SelectedStepIndex, g_FlowFilter
    
    ; Check if a step is selected
    if (!IsSet(g_SelectedStepIndex) || g_SelectedStepIndex = 0 || g_SelectedStepIndex > g_CurrentFlow.Length) {
        MsgBox "Please select a step to copy.", "Copy Error", "Icon!"
        return
    }
    
    ; Get the selected step
    stepToCopy := g_CurrentFlow[g_SelectedStepIndex]
    
    ; Create a list of available flows (excluding current flow)
    availableFlows := []
    for flowName, _ in g_Flows {
        if (flowName != g_CurrentFlowName) {
            availableFlows.Push(flowName)
        }
    }
    
    ; Check if there are any other flows to copy to
    if (availableFlows.Length = 0) {
        MsgBox "There are no other flows to copy this step to. Please create a new flow first.", "Copy Error", "Icon!"
        return
    }
    
    ; Create a wider dropdown list for flow selection
    flowSelectGui := Gui("+Owner" myGui.Hwnd " +ToolWindow", "Select Target Flow")
    flowSelectGui.SetFont("s10", "Segoe UI")
    flowSelectGui.AddText("x20 y20 w360", "Select the flow to copy this step to:")
    ; Add filter text field
    flowSelectGui.AddText("x20 y+10 w60", "Filter:")
    flowSelectGui.AddEdit("x85 yp w295 vFlowFilterInput", g_FlowFilter).OnEvent("Change", FilterCopyDialogFlows)
    ; Add dropdown with filtered flows
    flowSelectGui.AddDropDownList("x20 y+10 w360 vTargetFlow", availableFlows)
    
    ; Store the step to copy as a hidden control
    flowSelectGui.AddText("x0 y+1 w0 h0 Hidden vStepToCopy", SimpleJsonEncode(stepToCopy))
    
    ; Define the copy callback function with access to flowSelectGui
    flowSelectGui.AddButton("x60 y+10 w120 h32 Default", "Copy").OnEvent("Click", CopyStepToSelectedFlow)
    flowSelectGui.AddButton("x+20 w120 h32", "Cancel").OnEvent("Click", (*) => flowSelectGui.Destroy())
    
    ; Set a larger window size to accommodate the filter
    flowSelectGui.Show("w400 h180")
}

; Filter the flows in the copy dialog
FilterCopyDialogFlows(ctrl, *) {
    global g_FlowFilter
    flowSelectGui := ctrl.Gui
    g_FlowFilter := flowSelectGui["FlowFilterInput"].Value
    
    ; Get the dropdown control
    dropdown := flowSelectGui["TargetFlow"]
    
    ; Clear and repopulate the dropdown with filtered items
    dropdown.Delete()
    for flowName, _ in g_Flows {
        if (flowName != g_CurrentFlowName && (g_FlowFilter = "" || InStr(flowName, g_FlowFilter))) {
            dropdown.Add([flowName])
        }
    }
    
    ; Select the first item if available
    if (dropdown.Value != "")
        dropdown.Choose(1)
}

; Callback function for copying step to selected flow
CopyStepToSelectedFlow(btn, *) {
    flowSelectGui := btn.Gui
    targetFlow := flowSelectGui["TargetFlow"].Text
    stepToCopy := SimpleJsonDecode(flowSelectGui["StepToCopy"].Text)
    g_Flows[targetFlow].Push(stepToCopy)
    SaveFlowsToFile()
    flowSelectGui.Destroy()
    MsgBox "Step copied successfully to flow: " targetFlow, "Copy Complete", "Icon!"
}

; Updates the UI based on the selected click type
UpdateClickTypeUI(*) {
    clickType := myGui["ClickTypeInput"].Text
    
    ; Show/hide image-related controls
    myGui["ImagePathLabel"].Visible := clickType = "Image"
    myGui["ImagePathInput"].Visible := clickType = "Image"
    myGui["BrowseButton"].Visible := clickType = "Image"
    myGui["ClickPositionLabel"].Visible := clickType = "Image"
    myGui["ClickPositionInput"].Visible := clickType = "Image"
    myGui["ImagePreviewLabel"].Visible := clickType = "Image"
    myGui["ImagePreview"].Visible := clickType = "Image"
    
    ; Show/hide coordinate-related controls
    myGui["XCoordLabel"].Visible := clickType = "X & Y"
    myGui["XCoordInput"].Visible := clickType = "X & Y"
    myGui["YCoordLabel"].Visible := clickType = "X & Y"
    myGui["YCoordInput"].Visible := clickType = "X & Y"
}

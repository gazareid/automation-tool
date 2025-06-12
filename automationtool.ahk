#Requires AutoHotkey v2.0.19  ; Requires at least version 2.0.19 of AutoHotkey v2
#SingleInstance Force      ; Ensures only one instance of the script is running at a time
SetWorkingDir A_ScriptDir  ; Sets the working directory to the directory where the script is located

; Initialize global path variable
global g_WorkingDir := A_WorkingDir  ; Set this first so it's available to all modules
global g_FlowFilter := ""  ; Store the current flow filter text
global g_StepRecFlowFilter := ""  ; Store the current step recorder flow filter text

; Import JSON handling functions
#Include json_handler.ahk

; Import path utility functions
#Include path_utils.ahk

; import workflow orchestration functions
#Include workflow_orchestration.ahk

; import core functions
#Include core_functions.ahk

; import flow management functions
#Include flow_management.ahk

; import settings management functions
#Include settings_manager.ahk

; import action recorder module
#Include action_recorder.ahk

; Set a custom tray icon
TraySetIcon("images/automationtoolcropped.ico")

;------------------------------------------------------------------------------
; SCRIPT INITIALIZATION
;------------------------------------------------------------------------------
; These settings adjust how the script interacts with the UI
; Reduce these values for faster interactions or increase for more reliability
SetKeyDelay(5)     ; Sets a minimal delay between simulated keystrokes (in milliseconds)
SetMouseDelay(5)   ; Sets a minimal delay between simulated mouse movements (in milliseconds)
; Set coordinate mode to be relative to the screen (more reliable for image search)
CoordMode "Pixel", "Screen"
CoordMode "Mouse", "Screen"

;------------------------------------------------------------------------------
; GLOBAL VARIABLES
;------------------------------------------------------------------------------
; These variables are accessible throughout the entire script
global myGui := ""                ; Will hold the GUI object when created
global g_Flows := Map()           ; A Map object to store all automation flows
global g_CurrentFlow := []        ; An Array to store steps of the flow currently being edited
global g_CurrentFlowName := ""    ; Name of the current flow being edited
global g_FlowsFilePath := CombinePath(g_WorkingDir, "flows.json")  ; Path where flows are saved/loaded from
global g_SaveButtonText := ""
global g_SaveAnimationActive := false
global g_SaveComplete := false
global g_SaveStartTime := 0
global g_SaveButton := ""  ; Global reference to save button
global g_SelectedStepIndex := 0  ; Index of the selected step in the steps list
global g_Workflows := Map()      ; A Map object to store all workflows (sequences of flows)
global g_CurrentWorkflow := []   ; An Array to store flows of the workflow being edited
global g_CurrentWorkflowName := "" ; Name of the current workflow being edited
global g_WorkflowsFilePath := CombinePath(g_WorkingDir, "workflows.json") ; Path where workflows are saved
global g_KeyPressDelay := 5      ; Default key press delay in milliseconds
global g_CaptureDelay := 1000    ; Default capture delay in milliseconds
global g_ImageSearchAttempts := 3 ; Number of attempts for image search before failing
global g_ImageDimensions := Map() ; Map to store image dimensions
global g_ImageDetailsPath := CombinePath(g_WorkingDir, "tools", "image_details.json") ; Path to image details JSON
global g_EditingSubSteps := []

; Initialize settings
InitSettings()

; Initialize image dimensions database
InitImageDimensions()

; Auto-launch the GUI when the script runs
ShowHotkeysGui()

;------------------------------------------------------------------------------
; GUI INTERFACE
;------------------------------------------------------------------------------
; Creates and displays the main GUI for the application
; This function sets up all tabs, controls, and event handlers
; It runs automatically when the script starts and can also be triggered with Ctrl+Alt+H
ShowHotkeysGui() {
    ; Ensure necessary directories exist for storing images
    if !DirExist("images")
        DirCreate("images")
    
    ; Create a GUI with resize capability
    ; Use simple +Resize and avoid setting scrollbars directly
    global myGui := Gui("+Resize +MinSize600x500", "Automation Tool")
    myGui.BackColor := "FFFFFF"  ; White background for web-like appearance
    myGui.SetFont("s10", "Segoe UI")  ; Default font for all controls
    
    ; Add handler for the resize event
    myGui.OnEvent("Size", GuiResize)

    ; Add refresh button in the top-right corner
    refreshBtn := myGui.AddButton("x510 y10 w60 h25 vRefreshBtn", "Reload")
    refreshBtn.OnEvent("Click", (*) => Reload())  ; Reload the script when clicked

    ; Create a tab control to organize the interface - making it taller to maximize space
    tabs := myGui.AddTab3("x10 y10 w580 h570 vMainTabs", ["Workflows", "Flows", "Steps", "Step Details", "Settings", "Flow Rec", "Step Rec"])

    ;-----------------------
    ; WORKFLOW ORCHESTRATION TAB
    ;-----------------------
    tabs.UseTab(1)
    myGui.SetFont("s12 bold c0066CC")  ; Blue, bold font for section headers
    myGui.AddText("x20 y40 w540", "Create and Manage Workflows")
    myGui.SetFont("s10 norm")
    
    ; Workflow name input - with more space and clearer layout
    myGui.AddText("x20 y+15", "Workflow Name:")
    myGui.AddEdit("x120 y+0 w400 vWorkflowNameInput", g_CurrentWorkflowName)
    myGui.AddText("x20 y+5 w500 vWorkflowSavedAtText", "")  ; Text to show "saved at" message

    ; Workflow operation buttons - better aligned and spaced
    myGui.AddButton("x20 y+15 w100 h30", "New").OnEvent("Click", NewWorkflow)
    myGui.AddButton("x+20 w100 h30", "Save").OnEvent("Click", SaveCurrentWorkflow)
    myGui.AddButton("x+20 w100 h30", "Run").OnEvent("Click", RunWorkflow)

    ; Workflow list - shows all saved workflows with expand/collapse capability
    myGui.SetFont("s11 bold")
    myGui.AddText("x20 y+20", "Saved Workflows:")
    myGui.SetFont("s10 norm")
    myGui.AddListView("x20 y+5 w540 h150 -Multi +Grid vWorkflowsList", ["Workflow Name", "# of Flows", "Description"])
    myGui["WorkflowsList"].ModifyCol(1, 250)  ; Workflow name column
    myGui["WorkflowsList"].ModifyCol(2, 90)   ; Flow count column
    myGui["WorkflowsList"].ModifyCol(3, 200)  ; Description column
    myGui["WorkflowsList"].OnEvent("ItemSelect", SelectWorkflow)  ; Selection handler

    ; Add a section for managing flows in the selected workflow
    myGui.SetFont("s11 bold")
    myGui.AddText("x20 y+15", "Flows in Selected Workflow:")
    myGui.SetFont("s10 norm")
    myGui.AddListView("x20 y+5 w430 h150 -Multi +Grid vWorkflowFlowsList", ["Flow Name", "Order"])
    myGui["WorkflowFlowsList"].ModifyCol(1, 330)  ; Flow name column
    myGui["WorkflowFlowsList"].ModifyCol(2, 100)  ; Order column

    ; Add buttons to manipulate flows in the workflow - vertically aligned for better organization
    myGui.AddButton("x+10 y-150 w100 h30", "Add Flow").OnEvent("Click", AddFlowToWorkflow)
    myGui.AddButton("x+10 y+10 w100 h30", "Remove").OnEvent("Click", RemoveFlowFromWorkflow)
    myGui.AddButton("x+10 y+10 w100 h30", "Move Up").OnEvent("Click", MoveFlowUp)
    myGui.AddButton("x+10 y+10 w100 h30", "Move Down").OnEvent("Click", MoveFlowDown)

    ;-----------------------
    ; FLOW MANAGEMENT TAB
    ;-----------------------
    tabs.UseTab(2)
    myGui.SetFont("s12 bold c0066CC")  ; Blue, bold font for section headers
    myGui.AddText("x20 y40 w540", "Create and Manage Flows")
    myGui.SetFont("s10 norm")

    ; Flow name input - with more space and clearer layout, on one line
    myGui.AddText("x20 y+10 w80", "Flow Name:")
    myGui.AddEdit("x105 yp w320 vFlowNameInput", g_CurrentFlowName)
    myGui.AddText("x20 y+2 w500 vSavedAtText", "")  ; Text to show "saved at" message

    ; Flow operation buttons - better aligned and side-by-side
    myGui.AddButton("x20 y+5 w100 h28", "New").OnEvent("Click", NewFlow)
    myGui.AddButton("x+10 w100 h28 vSaveButton", "Save").OnEvent("Click", SaveCurrentFlow)
    myGui.AddButton("x+10 w100 h28", "Run").OnEvent("Click", RunFlow)
    myGui.AddButton("x+10 w100 h28", "Delete").OnEvent("Click", DeleteFlow)

    ; Flow list - shows all saved flows with 5 rows
    myGui.SetFont("s10 bold")
    myGui.AddText("x20 y+5", "Saved Flows:")
    myGui.SetFont("s10 norm")
    ; Add filter text field
    myGui.AddText("x20 y+5 w60", "Filter:")
    myGui.AddEdit("x85 yp w475 vFlowFilterInput", g_FlowFilter).OnEvent("Change", FilterFlows)
    myGui.AddListView("x20 y+5 w540 h340 -Multi +Grid vFlowsList", ["Flow Name"])
    myGui["FlowsList"].ModifyCol(1, 540)  ; Auto-size to fill width
    myGui["FlowsList"].OnEvent("ItemSelect", SelectFlow)  ; Selection handler

    ;-----------------------
    ; STEPS TAB (NEW)
    ;-----------------------
    tabs.UseTab(3)
    myGui.SetFont("s10 bold")
    myGui.AddText("x20 y+5", "Selected Flow:")
    myGui.SetFont("s10 norm")
    myGui.AddText("x120 yp w400 vSelectedFlowText", g_CurrentFlowName)
    myGui.SetFont("s10 bold")
    myGui.AddText("x20 y+15", "Steps in Flow:")
    myGui.SetFont("s10 norm")
    myGui.AddListView("x20 y+5 w540 h300 -Multi +Grid +LV0x1000 vStepsList", ["#", "Name", "Description", "Image Path", "Click Pos", "Action", "Wait", "Text"])
    myGui["StepsList"].ModifyCol(1, 30)   ; # column
    myGui["StepsList"].ModifyCol(2, 100)  ; Name
    myGui["StepsList"].ModifyCol(3, 120)  ; Description
    myGui["StepsList"].ModifyCol(4, 120)  ; Image Path
    myGui["StepsList"].ModifyCol(5, 60)   ; Click Position
    myGui["StepsList"].ModifyCol(6, 60)   ; Action
    myGui["StepsList"].ModifyCol(7, 40)   ; Wait time
    myGui["StepsList"].ModifyCol(8, 70)   ; Text
    myGui["StepsList"].OnEvent("ItemSelect", SelectStep)  ; Add selection handler for steps

    ; Step operation buttons - moved from Step Details tab
    myGui.AddButton("x20 y+5 w70 h28", "Add Step").OnEvent("Click", AddFlowStep)
    myGui.AddButton("x100 yp w130 h28", "Remove Selected").OnEvent("Click", RemoveSelectedStep)
    myGui.AddButton("x240 yp w70 h28", "Move Up").OnEvent("Click", MoveStepUp)
    myGui.AddButton("x320 yp w90 h28", "Move Down").OnEvent("Click", MoveStepDown)
    myGui.AddButton("x420 yp w70 h28", "Copy Step").OnEvent("Click", CopyStepToFlow)
    myGui.AddButton("x500 yp w70 h28", "Run Step").OnEvent("Click", RunSingleStep)

    ;-----------------------
    ; STEP DETAILS TAB (NEW)
    ;-----------------------
    tabs.UseTab(4)
    myGui.SetFont("s10 bold")
    myGui.AddText("x20 y+5", "Selected Step:")
    myGui.SetFont("s10 norm")
    myGui.AddText("x120 yp w400 vSelectedStepText", "")
    myGui.SetFont("s10 bold")
    myGui.AddText("x20 y+15", "Step Configuration:")
    myGui.SetFont("s10 norm")
    myGui.AddButton("x+340 yp w100 h28 vUpdateStepButton", "update step").OnEvent("Click", SaveCurrentFlow)

    ; First row: Step name and description side by side
    stepNameText := myGui.AddText("x20 y+5 w80", "Step Name:")
    stepNameText.GetPos(&xPos, &yPos, &width, &height)
    myGui.AddEdit("x105 yp w180 vStepNameInput")
    myGui.AddText("x300 yp w80", "Description:")
    myGui.AddEdit("x385 yp w150 vStepDescriptionInput")

    ; Second row: Click type selection
    myGui.AddText("x20 y+5 w80", "Click On:")
    myGui.AddDropDownList("x105 yp w120 vClickTypeInput", ["Image", "X & Y"]).OnEvent("Change", UpdateClickTypeUI)
    myGui["ClickTypeInput"].Choose(1)  ; Default to "Image"

    ; Third row: Image path with browse button (shown/hidden based on click type)
    myGui.AddText("x20 y+5 w80 vImagePathLabel", "Image Path:")
    myGui.AddEdit("x105 yp w350 vImagePathInput")
    myGui.AddButton("x465 yp w80 h24 vBrowseButton", "Browse").OnEvent("Click", BrowseForImage)

    ; Fourth row: Wait time, Click position (shown/hidden based on click type)
    myGui.AddText("x20 y+5 w80 vWaitTimeLabel", "Wait Time (ms):")
    myGui.AddEdit("x105 yp w80 vWaitTimeInput", "0")
    myGui.AddText("x200 yp w80 vClickPositionLabel", "Click Position:")
    myGui.AddDropDownList("x290 yp w90 Choose1 vClickPositionInput", ["center", "upper left", "upper right", "lower left", "lower right"])
    myGui.AddText("x390 yp w80", "Action Type:")
    myGui.AddDropDownList("x475 yp w70 Choose1 vActionTypeInput", ["click", "hover"])

    ; Fifth row: X & Y coordinates (shown/hidden based on click type)
    myGui.AddText("x20 y+5 w80 vXCoordLabel Hidden", "X Coordinate:")
    myGui.AddEdit("x105 yp w80 vXCoordInput", "0")
    myGui.AddText("x200 yp w80 vYCoordLabel Hidden", "Y Coordinate:")
    myGui.AddEdit("x290 yp w80 vYCoordInput", "0")

    ; Sixth row: Sub Steps section
    myGui.AddText("x20 y+15 w80", "Sub Steps:")
    myGui.AddListView("x20 y+5 w350 h150 -Multi +Grid vSubStepsList", ["#", "Type", "Value"])
    myGui["SubStepsList"].ModifyCol(1, 30)
    myGui["SubStepsList"].ModifyCol(2, 80)
    myGui["SubStepsList"].ModifyCol(3, 220)
    myGui["SubStepsList"].OnEvent("ItemSelect", SelectSubStep)
    ; Controls to add a sub step
    myGui.AddDropDownList("x20 y+5 w80 vSubStepTypeInput", ["text", "key", "scroll"])
    myGui.AddEdit("x+5 yp w150 vSubStepValueInput")
    myGui.AddButton("x+5 yp w60 h24", "Add").OnEvent("Click", AddSubStep)
    myGui.AddButton("x+5 yp w60 h24", "Remove").OnEvent("Click", RemoveSubStep)
    myGui.AddButton("x+5 yp w60 h24", "Up").OnEvent("Click", MoveSubStepUp)
    myGui.AddButton("x+5 yp w60 h24", "Down").OnEvent("Click", MoveSubStepDown)
    ; Key options
    myGui.SetFont("s8 norm")
    myGui.AddText("x20 y+5 w500", "Allowed keys: Tab, Enter, Esc, Space, Backspace, Delete, arrows, Home,End, PgUp, PgDn, or Ctrl/Alt/Shift+<key>. For scroll type, use 'up' or 'down'.")
    myGui.SetFont("s10 norm")

    ; Add image preview section at the bottom (shown/hidden based on click type)
    myGui.SetFont("s10 bold")
    myGui.AddText("x20 y+5 vImagePreviewLabel", "Image Preview:")
    myGui.SetFont("s10 norm")
    try {
        myGui.AddPicture("x20 y+5 Border vImagePreview", "HICON:0")  ; Use border to make images visible
        SendMessage(0x5001, 0, 0xE0E0E0, myGui["ImagePreview"].Hwnd)  ; WM_CTLCOLORDLG trick
    } catch as err {
        myGui.AddPicture("x20 y+5 Border vImagePreview")
    }

    ;-----------------------
    ; SETTINGS TAB
    ;-----------------------
    tabs.UseTab(5)
    myGui.SetFont("s12 bold c0066CC")
    myGui.AddText("x20 y80 w540", "Application Settings")
    myGui.SetFont("s10 norm")
    
    ; Add application settings here - without credentials section
    myGui.SetFont("s11 bold")
    myGui.AddText("x20 y+20", "General Settings:")
    myGui.SetFont("s10 norm")
    
    ; Add some general settings options
    myGui.AddCheckBox("x20 y+15 w400 vAutoStartCheck", "Auto-start on Windows login")
    myGui.AddCheckBox("x20 y+10 w400 vShowNotificationsCheck", "Show notifications during workflow execution")
    myGui.AddCheckBox("x20 y+10 w400 vConfirmRunCheck", "Confirm before running workflows")
    
    ; Image capture settings
    myGui.SetFont("s11 bold")
    myGui.AddText("x20 y+20", "Image Capture Settings:")
    myGui.SetFont("s10 norm")
    
    myGui.AddText("x20 y+15 w100", "Default Folder:")
    myGui.AddEdit("x130 yp w350 vDefaultImageFolder", GetSetting("DefaultImageFolder"))
    myGui.AddButton("x490 yp w80 h24", "Browse").OnEvent("Click", BrowseForImageFolder)
    
    myGui.AddText("x20 y+15 w150", "Capture Delay (ms):")
    myGui.AddEdit("x180 yp w100 vCaptureDelay", GetSetting("CaptureDelay"))
    
    ; Keyboard settings section
    myGui.SetFont("s11 bold")
    myGui.AddText("x20 y+20", "Keyboard Settings:")
    myGui.SetFont("s10 norm")
    
    myGui.AddText("x20 y+15 w150", "Key Press Delay (ms):")
    myGui.AddEdit("x180 yp w100 vKeyPressDelay", GetSetting("KeyPressDelay"))

    ; Add save and reset buttons for settings
    myGui.AddButton("x20 y+30 w100 h30", "Save Settings").OnEvent("Click", SaveSettingsFromGui)
    myGui.AddButton("x+20 w100 h30", "Reset to Defaults").OnEvent("Click", ResetSettingsFromGui)

    ; Create the Flow Recorder tab (should be the 6th tab)
    CreateFlowRecorderTab(tabs)
    ; Create the Step Recorder tab (should be the 7th tab)
    CreateStepRecorderTab(tabs)

    ; Load existing flows and workflows from file
    LoadFlowsFromFile()
    StepRec_UpdateFlowsDropdown()
    UpdateFlowList()
    LoadWorkflowsFromFile()
    UpdateWorkflowsList()

    ; Show the GUI with a default size but allow resizing
    tabs.UseTab()  ; Reset tab focus
    myGui.Show("w600 h600")  ; Make the window taller to use more screen space
}

; Function to browse for an image file to use in automation steps
BrowseForImage(*) {
    imagesDir := CombinePath(A_ScriptDir, "images")
    if !DirExist(imagesDir) {
        try {
            DirCreate(imagesDir)
        } catch as e {
            MsgBox "Failed to create images folder: " e.Message, "Error", "Icon!"
            return
        }
    }
    initialDir := DirExist(imagesDir) ? imagesDir : A_WorkingDir
    selectedFile := FileSelect("1", initialDir, "Select Image", "Images (*.png; *.jpg; *.jpeg; *.bmp; *.gif)")
    if (selectedFile = "")
        return
    selectedFile := NormalizePath(selectedFile)
    imagesDir := NormalizePath(imagesDir)
    SplitPath selectedFile, &fileName, &fileDir
    ; LOGGING
    OutputDebug("[BrowseForImage] selectedFile: " selectedFile)
    OutputDebug("[BrowseForImage] fileName: " fileName)
    OutputDebug("[BrowseForImage] fileDir: " fileDir)
    ; Fallback: If fileName is empty or looks like a path, extract after last /
    if (!fileName || InStr(fileName, "/") || InStr(fileName, "\\")) {
        arr := StrSplit(selectedFile, "/")
        fileName := arr[arr.Length]
        OutputDebug("[BrowseForImage] Fallback fileName: " fileName)
    }
    myGui["ImagePathInput"].Value := "images/" . fileName
    if (NormalizePath(fileDir) != imagesDir) {
        targetPath := CombinePath(imagesDir, fileName)
        try {
            FileCopy(selectedFile, targetPath, 1)
            if !FileExist(targetPath) {
                throw Error("File copy failed")
            }
        } catch as e {
            MsgBox "Failed to copy image to images folder: " e.Message "`n`nUsing original file path instead.", "Error", "Icon!"
        }
    }
}

; Function to browse for a folder to store images
BrowseForImageFolder(*) {
    ; Open folder selection dialog
    selectedFolder := DirSelect("*" . A_WorkingDir, 3, "Select Default Image Folder")
    
    if (selectedFolder = "")
        return  ; User cancelled the selection
    
    ; Update the input field with the selected folder
    myGui["DefaultImageFolder"].Value := selectedFolder
}

;------------------------------------------------------------------------------
; GUI RESIZE HANDLER
;------------------------------------------------------------------------------
; Handles the resizing of the GUI and its contents
GuiResize(thisGui, minMax, width, height) {
    static initialWidth := 600
    static initialHeight := 900  ; Updated to match new default height
    
    if minMax = -1  ; The window has been minimized. No action needed.
        return
    
    ; Calculate scale factors based on the window size change
    widthScale := width / initialWidth
    heightScale := height / initialHeight
    
    ; Position the refresh button in the top-right corner
    if thisGui.HasProp("RefreshBtn") {
        btnX := width - 90
        thisGui["RefreshBtn"].Move(btnX, 10)
    }
    
    ; Resize the main tab control to fill most of the window
    if thisGui.HasProp("MainTabs") {
        tabWidth := width - 20
        tabHeight := height - 20  ; Maximize the tab height
        thisGui["MainTabs"].Move(10, 10, tabWidth, tabHeight)
    }
    
    ; Resize the list views to fill the available width
    newWidth := width - 60  ; 30px margins on each side
    
    ; Resize list views and their columns
    for _, controlName in ["WorkflowsList", "WorkflowFlowsList", "FlowsList", "StepsList", "RecordedStepsList"] {
        if thisGui.HasProp(controlName) {
            ; Adjust width only - don't change Y position because of tab control
            thisGui[controlName].GetPos(&ctrlX, &ctrlY, &ctrlWidth)
            thisGui[controlName].Move(, , newWidth)
            
            ; Adjust column widths for each list
            if (controlName = "FlowsList") {
                thisGui[controlName].ModifyCol(1, newWidth) ; Just one column
            } else if (controlName = "WorkflowsList") {
                thisGui[controlName].ModifyCol(1, Ceil(newWidth * 0.46)) ; Name column
                thisGui[controlName].ModifyCol(2, Ceil(newWidth * 0.16)) ; Flow count column
                thisGui[controlName].ModifyCol(3, Ceil(newWidth * 0.38)) ; Description column
            } else if (controlName = "WorkflowFlowsList") {
                flowListWidth := newWidth - 110 ; Leave space for buttons
                thisGui[controlName].Move(, , flowListWidth)
                thisGui[controlName].ModifyCol(1, Ceil(flowListWidth * 0.75)) ; Flow name column
                thisGui[controlName].ModifyCol(2, Ceil(flowListWidth * 0.25)) ; Order column
            } else if (controlName = "StepsList") {
                thisGui[controlName].ModifyCol(1, 30)   ; ID column is fixed
                thisGui[controlName].ModifyCol(2, Ceil(newWidth * 0.15))  ; Name
                thisGui[controlName].ModifyCol(3, Ceil(newWidth * 0.20))  ; Description
                thisGui[controlName].ModifyCol(4, Ceil(newWidth * 0.20))  ; Image path
                thisGui[controlName].ModifyCol(5, Ceil(newWidth * 0.10))  ; Click Position
                thisGui[controlName].ModifyCol(6, Ceil(newWidth * 0.10))  ; Wait time
                thisGui[controlName].ModifyCol(7, Ceil(newWidth * 0.15))  ; Text
            } else if (controlName = "RecordedStepsList") {
                thisGui[controlName].ModifyCol(1, 40)   ; # column
                thisGui[controlName].ModifyCol(2, Ceil(newWidth * 0.40))  ; Name
                thisGui[controlName].ModifyCol(3, Ceil(newWidth * 0.20))  ; Wait time
                thisGui[controlName].ModifyCol(4, Ceil(newWidth * 0.40))  ; Image
            }
        }
    }
    
    ; Resize text input fields (keep aligned with their labels)
    inputWidth := newWidth - 120  ; Account for labels
    
    ; These fields should all be resized proportionally
    for _, controlName in ["StepNameInput", "StepDescriptionInput", "TextToSendInput", 
                          "FlowNameInput", "WorkflowNameInput"] {
        if thisGui.HasProp(controlName) {
            thisGui[controlName].GetPos(&ctrlX, &ctrlY, &ctrlWidth)
            thisGui[controlName].Move(, , inputWidth)
        }
    }
    
    ; Special case for image path (has browse button)
    if thisGui.HasProp("ImagePathInput") {
        thisGui["ImagePathInput"].GetPos(&ctrlX, &ctrlY, &ctrlWidth)
        thisGui["ImagePathInput"].Move(, , inputWidth - 90)  ; Leave room for Browse button
    }
}

;------------------------------------------------------------------------------
; HELPER FUNCTIONS
;------------------------------------------------------------------------------
; Reload() - Built-in AutoHotkey function that restarts the script
; Used by the Refresh button to reload all script definitions and the GUI
; This is useful after making changes to configuration or when the script gets in a bad state

; Moves the selected step up in the flow order
; Triggered by the Move Up button for steps
MoveStepUp(*) {
    global g_CurrentFlow
    
    ; Check if there are any steps in the list
    if (myGui["StepsList"].GetCount() = 0)
        return
    
    ; Get the selected row
    row := myGui["StepsList"].GetNext()
    if (row > 1) {  ; Can't move up if already at the top
        ; Swap with the step above
        temp := g_CurrentFlow[row - 1]
        g_CurrentFlow[row - 1] := g_CurrentFlow[row]
        g_CurrentFlow[row] := temp
        UpdateStepsList()
        
        ; Keep the same step selected after moving
        myGui["StepsList"].Modify(row - 1, "Select Focus")
        ; Update the g_SelectedStepIndex to reflect the new position
        g_SelectedStepIndex := row - 1
    }
}

; Moves the selected step down in the flow order
; Triggered by the Move Down button for steps
MoveStepDown(*) {
    global g_CurrentFlow
    
    ; Check if there are any steps in the list
    if (myGui["StepsList"].GetCount() = 0)
        return
    
    ; Get the selected row
    row := myGui["StepsList"].GetNext()
    if (row > 0 && row < g_CurrentFlow.Length) {  ; Can't move down if already at the bottom
        ; Swap with the step below
        temp := g_CurrentFlow[row + 1]
        g_CurrentFlow[row + 1] := g_CurrentFlow[row]
        g_CurrentFlow[row] := temp
        UpdateStepsList()
        
        ; Keep the same step selected after moving
        myGui["StepsList"].Modify(row + 1, "Select Focus")
        ; Update the g_SelectedStepIndex to reflect the new position
        g_SelectedStepIndex := row + 1
    }
}

; Function to initialize dimensions for all images in all flows
InitAllFlowImageDimensions() {
    global g_Flows
    
    OutputDebug("Initializing dimensions for all flows")
    
    for flowName, flowSteps in g_Flows {
        OutputDebug("Processing dimensions for flow: " flowName)
        UpdateFlowImageDimensions(flowSteps)
    }
}

; Add DeleteFlow function
DeleteFlow(*) {
    global g_Flows, g_CurrentFlow, g_CurrentFlowName
    
    ; Check if there are any flows in the list
    if (myGui["FlowsList"].GetCount() = 0)
        return
    
    ; Get the selected row
    row := myGui["FlowsList"].GetNext()
    if (row = 0)
        return
        
    ; Get the name from the first column
    selected := myGui["FlowsList"].GetText(row, 1)
    
    ; Confirm deletion
    if MsgBox("Are you sure you want to delete the flow '" selected "'?", "Confirm Deletion", "YesNo Icon!") = "Yes" {
        ; Remove the flow from the flows map
        g_Flows.Delete(selected)
        
        ; If the deleted flow was the current flow, clear it
        if (selected = g_CurrentFlowName) {
            g_CurrentFlow := []
            g_CurrentFlowName := ""
            myGui["FlowNameInput"].Value := ""
            myGui["SavedAtText"].Text := ""
            myGui["SelectedFlowText"].Text := ""  ; Clear the selected flow text in Steps tab
        }
        
        ; Save changes to file and update the GUI
        SaveFlowsToFile()
        UpdateFlowList()
        UpdateStepsList()
        StepRec_UpdateFlowsDropdown()
    }
}

; Initialize image dimensions from JSON file (canonical keys)
InitImageDimensions() {
    global g_ImageDimensions, g_ImageDetailsPath
    g_ImageDimensions := Map()
    try {
        if FileExist(g_ImageDetailsPath) {
            jsonContent := FileRead(g_ImageDetailsPath)
            imageDetails := SimpleJsonDecode(jsonContent)
            for fileName, dims in imageDetails {
                ; Store dimensions using the exact key format from the JSON
                g_ImageDimensions[fileName] := dims
            }
            OutputDebug("Loaded image dimensions for " imageDetails.Count " images from " g_ImageDetailsPath)
            
            ; Check if we need to sync (file exists but is empty or no images found)
            if (imageDetails.Count = 0) {
                OutputDebug("Image details file is empty, syncing with images directory...")
                SyncImageDimensions()
                ; Reload the dimensions after syncing
                jsonContent := FileRead(g_ImageDetailsPath)
                imageDetails := SimpleJsonDecode(jsonContent)
                g_ImageDimensions := Map()
                for fileName, dims in imageDetails {
                    g_ImageDimensions[fileName] := dims
                }
            }
        } else {
            OutputDebug(g_ImageDetailsPath " does not exist, syncing with images directory...")
            SyncImageDimensions()
            ; Load the newly created dimensions
            if FileExist(g_ImageDetailsPath) {
                jsonContent := FileRead(g_ImageDetailsPath)
                imageDetails := SimpleJsonDecode(jsonContent)
                for fileName, dims in imageDetails {
                    g_ImageDimensions[fileName] := dims
                }
            }
        }
    } catch as err {
        MsgBox("Error loading image dimensions: " . err.Message)
        OutputDebug("Error loading image dimensions: " . err.Message)
        try {
            ; Attempt to sync as a recovery mechanism
            SyncImageDimensions()
        } catch as syncErr {
            OutputDebug("Failed to sync image dimensions: " . syncErr.Message)
        }
    }
}

; Function to save settings from GUI
SaveSettingsFromGui(*) {
    ; Update settings from GUI values
    UpdateSetting("AutoStart", myGui["AutoStartCheck"].Value)
    UpdateSetting("ShowNotifications", myGui["ShowNotificationsCheck"].Value)
    UpdateSetting("ConfirmRun", myGui["ConfirmRunCheck"].Value)
    UpdateSetting("DefaultImageFolder", myGui["DefaultImageFolder"].Value)
    UpdateSetting("CaptureDelay", myGui["CaptureDelay"].Value)
    UpdateSetting("KeyPressDelay", myGui["KeyPressDelay"].Value)
    
    ; Save to file
    if SaveSettings() {
        MsgBox "Settings saved successfully.", "Settings Saved", "Icon!"
        ApplySettings()  ; Apply the new settings
    } else {
        MsgBox "Failed to save settings.", "Error", "Icon!"
    }
}

; Function to reset settings from GUI
ResetSettingsFromGui(*) {
    if MsgBox("Are you sure you want to reset all settings to defaults?", "Confirm Reset", "YesNo Icon!") = "Yes" {
        if ResetSettings() {
            ; Update GUI with default values
            myGui["AutoStartCheck"].Value := GetSetting("AutoStart")
            myGui["ShowNotificationsCheck"].Value := GetSetting("ShowNotifications")
            myGui["ConfirmRunCheck"].Value := GetSetting("ConfirmRun")
            myGui["DefaultImageFolder"].Value := GetSetting("DefaultImageFolder")
            myGui["CaptureDelay"].Value := GetSetting("CaptureDelay")
            myGui["KeyPressDelay"].Value := GetSetting("KeyPressDelay")
            
            MsgBox "Settings have been reset to defaults.", "Settings Reset", "Icon!"
        } else {
            MsgBox "Failed to reset settings.", "Error", "Icon!"
        }
    }
}

; Helper function to get directory path from a file path
GetDirectoryPath(filePath) {
    SplitPath filePath, , &dirPath
    return dirPath
}

; SelectFlow function is defined in flow_management.ahk

#Requires AutoHotkey v2.0

; Include GDI+ library for screen capture
#Include path_utils.ahk
#Include Gdip_All.ahk

; Define any missing GDI+ functions
Gdip_SetCompositingQuality(pGraphics, Quality) {
    return DllCall("gdiplus\GdipSetCompositingQuality", "UPtr", pGraphics, "int", Quality)
}

;------------------------------------------------------------------------------
; ACTION RECORDER MODULE
;------------------------------------------------------------------------------
; Global variables for action recording
global g_IsRecording := false
global g_RecordedSteps := []
global g_LastCaptureTick := A_TickCount
global g_RecordingStatusText := ""
global g_RecordingControlsEnabled := true
global g_CaptureCount := 0

; Global variable to track if we're waiting for a capture click
global g_WaitingForCapture := false

; Global variables for Step Recorder
global g_StepRec_FlowsDropdown := ""
global g_StepRec_ImagePath := ""
global g_StepRec_ClickX := 0
global g_StepRec_ClickY := 0
global g_StepRec_Recording := false
global g_StepRec_StepName := ""
global g_StepRec_ClickType := ""
global g_StepRecFlowFilter := ""

;------------------------------------------------------------------------------
; HOTKEYS FOR RECORDING
;------------------------------------------------------------------------------
; Start recording hotkey (Ctrl+Alt+R)
^!r::StartRecording()

; End recording hotkey (Ctrl+Alt+E)
^!e::StopRecordingAndSave()

; Hover capture hotkey (Ctrl+Alt+H)
^!h::CaptureHover()

; Interactive capture hotkey (Ctrl+Alt+I)
^!i::InteractiveCapture()

; Intercept left clicks during recording
#HotIf g_IsRecording
~LButton::
{
    MouseGetPos(&mouseX, &mouseY)
    RecordClick(0, mouseX, mouseY)
}
#HotIf

;------------------------------------------------------------------------------
; RECORDING FUNCTIONS
;------------------------------------------------------------------------------
; Starts the recording process
; Sets up global variables and indicators for recording mode
; Parameters:
;   sender: The control that triggered the event
;   info: Additional event info
StartRecording(sender := 0, info := "") {
    global g_IsRecording, g_RecordedSteps, g_LastCaptureTick, g_CaptureCount
    
    ; Check if already recording
    if (g_IsRecording) {
        OutputDebug("Recording already in progress")
        return
    }
    
    ; Initialize recording variables
    g_IsRecording := true
    g_RecordedSteps := []
    g_LastCaptureTick := A_TickCount
    g_CaptureCount := 0
    
    ; Update UI to show recording status
    UpdateRecordingStatus("Recording in progress...")
    EnableRecordingControls(false)
    
    OutputDebug("Recording started")
}

; Captures a mouse click during recording
; Parameters:
;   dummy: Unused parameter from the hotkey
;   x: X-coordinate of the mouse
;   y: Y-coordinate of the mouse
RecordClick(dummy, x, y) {
    global g_IsRecording, g_RecordedSteps, g_LastCaptureTick
    
    if (!g_IsRecording)
        return
    
    OutputDebug("Recording click at: " x "," y)
    
    ; Calculate time since last capture
    currentTick := A_TickCount
    waitTime := currentTick - g_LastCaptureTick
    g_LastCaptureTick := currentTick
    
    ; Capture the screen region and create a step
    imagePath := CaptureScreenRegion(x, y)
    if (imagePath) {
        ; Standardize the image path for storage
        imagePath := StandardizeImagePath(imagePath)
        ; Update image dimensions in the global tracking and image_details.json
        dims := GetImageDimensions(imagePath)
        UpdateImageDimensions(imagePath, dims["width"], dims["height"])
        
        step := CreateFlowStep(
            imagePath,      ; image path
            waitTime,       ; wait time before this step
            "",             ; no text to send in recorder v1
            "center",       ; default click position
            "Click " x "," y, ; step name
            "Recorded click",  ; description
            "click"           ; actionType
        )
        g_RecordedSteps.Push(step)
        UpdateRecordedStepsList()
    }
}

; Captures a hover position explicitly requested by the user
; Parameters:
;   sender: The control that triggered the event (if called from GUI)
;   info: Additional event info (if called from GUI)
CaptureHover(sender := 0, info := "") {
    global g_IsRecording, g_RecordedSteps, g_LastCaptureTick
    
    if (!g_IsRecording)
        return
    
    ; Get current mouse position
    MouseGetPos(&x, &y)
    OutputDebug("Recording hover at: " x "," y)
    
    ; Calculate time since last capture
    currentTick := A_TickCount
    waitTime := currentTick - g_LastCaptureTick
    g_LastCaptureTick := currentTick
    
    ; Pause briefly to allow user to position cursor properly
    Sleep(100)
    
    ; Capture the screen region and create a step
    imagePath := CaptureScreenRegion(x, y)
    if (imagePath) {
        ; Standardize the image path for storage
        imagePath := StandardizeImagePath(imagePath)
        ; Update image dimensions in the global tracking and image_details.json
        dims := GetImageDimensions(imagePath)
        UpdateImageDimensions(imagePath, dims["width"], dims["height"])
        
        step := CreateFlowStep(
            imagePath,      ; image path
            waitTime,       ; wait time before this step
            "",             ; no text to send in recorder v1
            "center",       ; default click position
            "Hover " x "," y, ; step name
            "Recorded hover",  ; description
            "hover"           ; actionType
        )
        g_RecordedSteps.Push(step)
        UpdateRecordedStepsList()
    }
}

; Stops recording and prompts to save the recorded flow
; Parameters:
;   sender: The control that triggered the event
;   info: Additional event info
StopRecordingAndSave(sender := 0, info := "") {
    global g_IsRecording, g_RecordedSteps, g_Flows, g_CurrentFlow, g_CurrentFlowName
    
    if (!g_IsRecording)
        return
    
    g_IsRecording := false
    UpdateRecordingStatus("Recording stopped")
    EnableRecordingControls(true)
    
    OutputDebug("Recording stopped with " g_RecordedSteps.Length " steps")
    
    ; Check if we have any steps to save
    if (g_RecordedSteps.Length = 0) {
        MsgBox("No actions recorded.", "Recording Empty", "Icon!")
        return
    }
    
    ; Prompt for flow name
    flowName := InputBox("Enter a name for this recorded flow:", "Save Recording", "w400 h120")
    if (flowName.Result = "Cancel" || flowName.Value = "") {
        UpdateRecordingStatus("Recording discarded")
        return
    }
    
    ; Set this as the current flow
    g_CurrentFlow := g_RecordedSteps.Clone()
    g_CurrentFlowName := flowName.Value
    
    ; Save to the flows collection
    g_Flows[flowName.Value] := g_RecordedSteps.Clone()
    SaveFlowsToFile()
    
    ; Update UI
    if (IsSet(myGui) && myGui != "") {
        myGui["FlowNameInput"].Value := flowName.Value
        myGui["SavedAtText"].Text := "Saved at " . FormatTime(, "HH:mm:ss")
        UpdateFlowList()
        UpdateStepsList()
        
        ; Switch to the Flow Management tab
        myGui["MainTabs"].Value := 2  ; Second tab (Flow Management)
    }
    
    UpdateRecordingStatus("Recording saved as '" flowName.Value "'")
    OutputDebug("Recording saved as: " flowName.Value)
}

;------------------------------------------------------------------------------
; SCREEN CAPTURE FUNCTIONS
;------------------------------------------------------------------------------
; Captures a region of the screen centered on the specified coordinates using PrintScreen
; Parameters:
;   x: X-coordinate to center on
;   y: Y-coordinate to center on
;   quality: Image quality (1-100, default 100 for highest quality)
;   format: Image format ("png", "jpg", "bmp", default is "png")
;   cropSize: Size of the square capture region (default 100px)
; Returns: Path to the saved image file, or empty string on failure
CaptureScreenRegion(x, y, quality := 100, format := "png", cropSize := 100) {
    global g_CaptureCount
    
    try {
        ; Ensure GDI+ is initialized
        if !pToken := Gdip_Startup() {
            OutputDebug("GDI+ startup failed")
            return ""
        }
        
        ; Clear the clipboard before taking screenshot
        A_Clipboard := ""
        
        ; Send PrintScreen key to capture screen to clipboard
        Send "{PrintScreen}"
        
        ; Wait for clipboard to contain the image (timeout after 1 second)
        Sleep(1000)
        
        ; Create a bitmap from clipboard data
        screenBitmap := Gdip_CreateBitmapFromClipboard()
        if (!screenBitmap) {
            OutputDebug("Failed to create bitmap from clipboard")
            Gdip_Shutdown(pToken)
            return ""
        }
        
        ; Get dimensions of captured screen
        screenWidth := Gdip_GetImageWidth(screenBitmap)
        screenHeight := Gdip_GetImageHeight(screenBitmap)

        OutputDebug("Screen dimensions: " screenWidth "x" screenHeight)
        
        ; Calculate the crop region (square centered on x,y)
        cropX := x - (cropSize // 2)
        cropY := y - (cropSize // 2)

        OutputDebug("Crop region: " cropX "," cropY)
        
        ; Ensure crop region is within screen bounds
        if (cropX < 0) 
            cropX := 0
        if (cropY < 0) 
            cropY := 0
            
        ; Calculate final width and height of crop
        width := cropSize
        height := cropSize
        
        ; Adjust if too close to screen edges
        if (cropX + width > screenWidth)
            width := screenWidth - cropX
            
        if (cropY + height > screenHeight)
            height := screenHeight - cropY
            
        OutputDebug("Crop region: " cropX "," cropY " to " width "x" height)
        
        ; Create a high-quality bitmap for the cropped region
        ; Use Format24bppRGB (0x21808) to avoid alpha channel issues with ImageSearch
        croppedBitmap := Gdip_CreateBitmap(width, height, 0x21808)  ; Format24bppRGB

        OutputDebug("Cropped bitmap: " width "x" height)
        
        ; Create graphics for drawing with highest quality settings
        G := Gdip_GraphicsFromImage(croppedBitmap)

        OutputDebug("DLLCall completed")
        
        ; Draw the cropped region from the clipboard screenshot
        Gdip_DrawImage(G, screenBitmap, 0, 0, width, height, cropX, cropY, width, height)
        
        OutputDebug("Image drawn")
        
        ; Generate filename with timestamp and counter
        g_CaptureCount++
        timestamp := FormatTime(, "yyyyMMdd_HHmmss")

        OutputDebug("Timestamp: " timestamp)
        
        ; Use jpeg extension for jpg format
        if (format = "jpg")
            format := "jpeg"
            
        fileName := CombinePath("images", "rec_" . timestamp . "_" . g_CaptureCount . "." . format)
        
        OutputDebug("File name: " fileName)
        
        ; Make sure images directory exists
        EnsureDirectoryExists("images")
            
        ; Save the cropped image with specified quality
        fullPath := GetAbsolutePath(fileName)
        
        OutputDebug("Full path: " fullPath)
        
        ; Clamp quality between 1-100
        quality := Max(1, Min(100, quality))
        
        ; Get encoder CLSID based on format
        if (format = "bmp") {
            ; For BMP, quality parameter is ignored
            Gdip_SaveBitmapToFile(croppedBitmap, fullPath)
        } else {
            ; For PNG and JPEG, use the quality parameter
            Gdip_SaveBitmapToFile(croppedBitmap, fullPath, quality)
        }
        
        OutputDebug("Saved bitmap to: " fullPath)
        
        ; Clean up GDI+ resources
        Gdip_DeleteGraphics(G)
        Gdip_DisposeImage(croppedBitmap)
        Gdip_DisposeImage(screenBitmap)
        Gdip_Shutdown(pToken)
        
        ; Update image dimensions immediately in image_details.json
        UpdateImageDetailsJson(fileName)
        OutputDebug("Captured screen region to: " fileName " with quality: " quality ", format: " format)
        
        return fileName
    } catch as err {
        OutputDebug("Error capturing screen region: " err.Message)
        try Gdip_Shutdown(pToken)
        return ""
    }
}

; Updates the image_details.json file with dimensions for the specified image
; Parameters:
;   imagePath: Path to the image file to update dimensions for
; Returns: True if successful, false otherwise
UpdateImageDetailsJson(imagePath) {
    try {
        ; Get the image dimensions
        dimensions := GetImageDimensions(imagePath)
        
        ; Standardize the key for consistency
        standardKey := StandardizeImagePath(imagePath)
        
        ; Path to the image_details.json file - use global path for consistency
        jsonPath := g_ImageDetailsPath
        
        ; Read existing JSON or create new map
        if FileExist(jsonPath) {
            OutputDebug("Reading existing image_details.json")
            jsonContent := FileRead(jsonPath)
            imageDetails := SimpleJsonDecode(jsonContent)
        } else {
            OutputDebug("Creating new image_details.json")
            imageDetails := Map()
        }
        
        ; Update the dimensions in the map
        imageDetails[standardKey] := Map(
            "width", dimensions["width"],
            "height", dimensions["height"]
        )
        
        ; Make sure we can write to the directory
        EnsureDirectoryExists(GetDirectoryPath(jsonPath))
        
        ; Write back to the JSON file
        FileDelete(jsonPath)
        jsonString := SimpleJsonEncode(imageDetails)
        FileAppend(jsonString, jsonPath)
        
        OutputDebug("Updated image_details.json for " imagePath ": " dimensions["width"] "x" dimensions["height"])
        return true
    } catch as err {
        OutputDebug("Error updating image_details.json: " err.Message)
        return false
    }
}

;------------------------------------------------------------------------------
; INTERACTIVE CAPTURE
;------------------------------------------------------------------------------
; Captures the screen and lets the user click where they need to for the test
; Especially useful for elements that change visual state when hovered over
; Parameters:
;   sender: The control that triggered the event (if called from GUI)
;   info: Additional event info (if called from GUI)
InteractiveCapture(sender := 0, info := "") {
    global g_IsRecording, g_RecordedSteps, g_LastCaptureTick
    
    if (!g_IsRecording)
        return
    
    OutputDebug("Starting interactive capture...")
    
    ; Temporarily pause recording to prevent additional steps during capture
    wasRecording := g_IsRecording
    g_IsRecording := false
    
    ; Calculate time since last capture
    currentTick := A_TickCount
    waitTime := currentTick - g_LastCaptureTick
    
    ; Initialize GDI+
    if !pToken := Gdip_Startup() {
        OutputDebug("GDI+ startup failed")
        return
    }
    
    try {
        ; Capture the entire screen with high quality
        screenBitmap := Gdip_BitmapFromScreen()
        if (!screenBitmap) {
            OutputDebug("Screen capture failed")
            Gdip_Shutdown(pToken)
            return
        }
        
        ; Get screen dimensions
        screenWidth := Gdip_GetImageWidth(screenBitmap)
        screenHeight := Gdip_GetImageHeight(screenBitmap)
        
        ; Create a temporary file for the screenshot
        timestamp := FormatTime(, "yyyyMMdd_HHmmss")
        tempFileName := A_Temp "\temp_capture_" timestamp ".png"
        
        ; Save the screenshot to temp file with high quality
        Gdip_SaveBitmapToFile(screenBitmap, tempFileName, 100)
        
        ; Clean up GDI+ resources
        Gdip_DisposeImage(screenBitmap)
        Gdip_Shutdown(pToken)
        
        ; Create a window with scrollbars, caption and proper controls
        captureGui := Gui("+Resize +MaximizeBox")
        captureGui.Title := "Interactive Capture - Click where needed or press Esc to cancel"
        
        ; Get the work area (screen minus taskbar)
        MonitorGetWorkArea(, &workLeft, &workTop, &workRight, &workBottom)
        workWidth := workRight - workLeft
        workHeight := workBottom - workTop
        
        ; Add instructions
        captureGui.SetFont("s12 bold", "Arial")
        captureGui.AddText("x10 y10 w" (workWidth-20) " Center", "Click where you need to click for the test. Press Esc to cancel.")
        
        ; Add the screenshot as a picture with scrollbars
        pic := captureGui.AddPicture("x0 y40 w" screenWidth " h" screenHeight " +Border +HScroll +VScroll +BackgroundTrans", tempFileName)
        
        ; Set up the click handler
        pic.OnEvent("Click", HandleInteractiveClick)
        
        ; Add explicit close and escape key handling
        captureGui.OnEvent("Close", CloseInteractiveCapture)
        captureGui.OnEvent("Escape", CloseInteractiveCapture)
        
        ; Add a cancel button as an additional way to close
        captureGui.AddButton("x" (workWidth//2-50) " y" (workHeight-40) " w100 h30", "Cancel").OnEvent("Click", CloseInteractiveCapture)
        
        ; Show the GUI maximized but not fullscreen
        captureGui.Show("w" workWidth " h" workHeight " x" workLeft " y" workTop " Maximize")
        
        ; Store GUI and capture details in global variables for the click handler to use
        global g_InteractiveCaptureGui := captureGui
        global g_InteractiveCaptureWaitTime := waitTime
        global g_InteractiveCaptureTime := currentTick
        global g_WasRecording := wasRecording
    }
    catch as err {
        OutputDebug("Error in interactive capture: " err.Message)
        try Gdip_Shutdown(pToken)
        ; Restore recording state if there was an error
        g_IsRecording := wasRecording
    }
}

; Handles the closing of the interactive capture window
; Parameters:
;   sender: The control that triggered the close
;   info: Additional event info
CloseInteractiveCapture(sender, info := "") {
    global g_InteractiveCaptureGui, g_WasRecording, g_IsRecording
    
    ; Close the GUI
    try g_InteractiveCaptureGui.Destroy()
    
    ; Restore recording state
    g_IsRecording := g_WasRecording
    
    OutputDebug("Interactive capture cancelled")
}

; Handles the click on the interactive capture image
; Parameters:
;   sender: The control that was clicked
;   info: Event info parameter - for OnEvent handler, this is different from what we expected
HandleInteractiveClick(sender, info) {
    global g_IsRecording, g_RecordedSteps, g_InteractiveCaptureGui, g_InteractiveCaptureWaitTime, g_InteractiveCaptureTime, g_LastCaptureTick, g_WasRecording
    
    ; Get mouse position instead of using info parameter
    MouseGetPos(&mouseX, &mouseY)
    
    ; Convert to coordinates relative to the control
    try {
        ControlGetPos(&controlX, &controlY, , , sender)
        mouseX := mouseX - controlX
        mouseY := mouseY - controlY
    } catch as err {
        OutputDebug("Error converting coordinates: " err.Message)
    }
    
    ; Close the capture GUI
    g_InteractiveCaptureGui.Destroy()
    
    OutputDebug("Interactive click at: " mouseX "," mouseY)
    
    ; Update last capture tick
    g_LastCaptureTick := g_InteractiveCaptureTime
    
    ; Restore recording state
    g_IsRecording := g_WasRecording
    
    ; Pause briefly to allow UI to settle after GUI closes
    Sleep(200)
    
    ; Capture the screen region and create a step
    imagePath := CaptureScreenRegion(mouseX, mouseY)
    if (imagePath) {
        ; Standardize the image path for storage
        imagePath := StandardizeImagePath(imagePath)
        ; Update image dimensions in the global tracking and image_details.json
        dims := GetImageDimensions(imagePath)
        UpdateImageDimensions(imagePath, dims["width"], dims["height"])
        
        step := CreateFlowStep(
            imagePath,      ; image path
            g_InteractiveCaptureWaitTime,  ; wait time before this step
            "",             ; no text to send in recorder v1
            "center",       ; default click position
            "Interactive " mouseX "," mouseY, ; step name
            "Interactive capture click",  ; description
            "click"           ; actionType
        )
        g_RecordedSteps.Push(step)
        UpdateRecordedStepsList()
    }
}

;------------------------------------------------------------------------------
; UI FUNCTIONS
;------------------------------------------------------------------------------
; Creates the Flow Recorder tab in the GUI
; Called when initializing the main GUI
CreateFlowRecorderTab(tabs) {
    global g_RecordingStatusText
    ; Switch to the Flow Recorder tab (6th tab)
    tabs.UseTab(4)
    ; Add header
    myGui.SetFont("s12 bold c0066CC")
    myGui.AddText("x20 y40 w540", "Flow Recorder")
    myGui.SetFont("s10 norm")
    ; Add status indicator
    myGui.AddText("x20 y+15 w540 vRecordingStatusText", "Ready to record")
    g_RecordingStatusText := myGui["RecordingStatusText"]
    ; Add recording controls
    myGui.AddButton("x20 y+20 w120 h40 vStartRecordingBtn", "Start Recording (Ctrl+Alt+R)")
        .OnEvent("Click", StartRecording.Bind())
    myGui.AddButton("x+20 w120 h40 vStopRecordingBtn", "Stop Recording (Ctrl+Alt+E)")
        .OnEvent("Click", StopRecordingAndSave.Bind())
    myGui.AddButton("x+20 w120 h40 vCaptureHoverBtn", "Capture Hover (Ctrl+Alt+H)")
        .OnEvent("Click", CaptureHover.Bind())
    myGui.AddButton("x+20 w120 h40 vInteractiveCaptureBtn", "Interactive Capture (Ctrl+Alt+I)")
        .OnEvent("Click", InteractiveCapture.Bind())
    ; Add info text
    myGui.SetFont("s10 italic")
    myGui.AddText("x20 y+15 w540", "Click anywhere to record actions. Press Ctrl+Alt+H to capture hover positions or Ctrl+Alt+I for interactive capture.")
    myGui.SetFont("s10 norm")
    ; Add recorded steps list view
    myGui.SetFont("s10 bold")
    myGui.AddText("x20 y+15", "Recorded Steps:")
    myGui.SetFont("s10 norm")
    myGui.AddListView("x20 y+5 w540 h250 -Multi +Grid vRecordedStepsList", ["#", "Name", "Wait Time", "Image"])
    myGui["RecordedStepsList"].ModifyCol(1, 40)   ; # column
    myGui["RecordedStepsList"].ModifyCol(2, 200)  ; Name
    myGui["RecordedStepsList"].ModifyCol(3, 100)  ; Wait Time
    myGui["RecordedStepsList"].ModifyCol(4, 200)  ; Image
    ; Add buttons to manipulate the recorded steps
    myGui.AddButton("x20 y+10 w120 h30 vRemoveStepBtn", "Remove Selected")
        .OnEvent("Click", RemoveRecordedStep.Bind())
    myGui.AddButton("x+20 w120 h30 vMoveUpBtn", "Move Up")
        .OnEvent("Click", MoveRecordedStepUp.Bind())
    myGui.AddButton("x+20 w120 h30 vMoveDownBtn", "Move Down")
        .OnEvent("Click", MoveRecordedStepDown.Bind())
}

; Creates the Step Recorder tab in the GUI (full implementation)
CreateStepRecorderTab(tabs) {
    global g_StepRec_ImagePath, g_StepRec_ImagePreview, g_StepRec_SelectedFlow, g_StepRec_StepType, g_StepRec_FlowsDropdown, g_StepRec_ClickType
    tabs.UseTab(5)
    myGui.SetFont("s12 bold c0066CC")
    myGui.AddText("x20 y40 w540", "Step Recorder")
    myGui.SetFont("s10 norm")
    ; Flow selection dropdown (initially empty, will be populated after flows are loaded)
    myGui.AddText("x20 y+20 w120", "Target Flow:")
    ; Add filter text field
    myGui.AddText("x20 y+5 w60", "Filter:")
    myGui.AddEdit("x85 yp w250 vStepRecFlowFilterInput", g_StepRecFlowFilter).OnEvent("Change", StepRec_FilterFlows)
    g_StepRec_FlowsDropdown := myGui.AddDropDownList("x20 y+5 w250 vStepRecFlowDropdown", [])
    ; Click type selection
    myGui.AddText("x20 y+15 w120", "Click Type:")
    g_StepRec_ClickType := myGui.AddDropDownList("x120 yp w120 vStepRecClickType", ["Image", "X & Y"])
    g_StepRec_ClickType.Choose(1)  ; Default to "Image"
    g_StepRec_ClickType.OnEvent("Change", StepRec_UpdateClickTypeUI)
    ; Step type selection
    myGui.AddText("x20 y+15 w120", "Step Type:")
    g_StepRec_StepType := myGui.AddDropDownList("x120 yp w120 vStepRecStepType", ["click", "hover"])
    g_StepRec_StepType.Choose(1)
    ; Step name input (required)
    myGui.AddText("x20 y+15 w120", "Step Name:")
    myGui.AddEdit("x120 yp w250 vStepRecStepName")
    ; Capture button
    myGui.AddButton("x20 y+20 w120 h40 vStepRecCaptureBtn", "Capture Step").OnEvent("Click", StepRec_CaptureStep)
    ; Image preview (shown/hidden based on click type)
    myGui.AddText("x20 y+20 w540 vStepRecImagePreviewLabel", "Image Preview:")
    g_StepRec_ImagePreview := myGui.AddPicture("x20 y+5 w100 h100 Border vStepRecImagePreview", "")
    ; Save button
    myGui.AddButton("x20 y+20 w120 h30 vStepRecSaveBtn", "Save Step").OnEvent("Click", StepRec_SaveStep)
    ; Status text
    myGui.AddText("x160 yp w400 vStepRecStatusText", "")
}

; Updates the UI based on selected click type
StepRec_UpdateClickTypeUI(*) {
    global g_StepRec_ClickType
    clickType := g_StepRec_ClickType.Text
    if (clickType = "Image") {
        myGui["StepRecImagePreviewLabel"].Visible := true
        myGui["StepRecImagePreview"].Visible := true
    } else {
        myGui["StepRecImagePreviewLabel"].Visible := false
        myGui["StepRecImagePreview"].Visible := false
    }
}

; Handler for capturing a step in Step Recorder
StepRec_CaptureStep(*) {
    global g_StepRec_ImagePath, g_StepRec_ImagePreview, g_StepRec_StepType, g_StepRec_ClickType, g_WaitingForCapture
    
    ; Show status that we're waiting for click
    myGui["StepRecStatusText"].Text := "Click anywhere to capture the step..."
    
    ; Set the flag to indicate we're waiting for a capture
    g_WaitingForCapture := true
}

; Global click handler for capture
~LButton:: {
    global g_WaitingForCapture, g_StepRec_ImagePath, g_StepRec_ImagePreview, g_StepRec_StepType, g_StepRec_ClickType
    
    ; Only proceed if we're waiting for a capture
    if (!g_WaitingForCapture)
        return
        
    ; Reset the flag immediately
    g_WaitingForCapture := false
    
    ; Get mouse position
    MouseGetPos(&x, &y)
    
    ; Store coordinates for coordinate-based clicking
    g_StepRec_ClickX := x
    g_StepRec_ClickY := y
    
    ; If using image-based clicking, capture the image
    if (g_StepRec_ClickType.Text = "Image") {
        imagePath := CaptureScreenRegion(x, y)
        if (imagePath) {
            imagePath := StandardizeImagePath(imagePath)
            dims := GetImageDimensions(imagePath)
            UpdateImageDimensions(imagePath, dims["width"], dims["height"])
            g_StepRec_ImagePath := imagePath
            ; Show preview
            absPath := ResolveImagePath(imagePath)
            if (absPath != "")
                g_StepRec_ImagePreview.Value := absPath
            myGui["StepRecStatusText"].Text := "Step captured. Preview below."
        } else {
            myGui["StepRecStatusText"].Text := "Failed to capture image."
        }
    } else {
        ; For coordinate-based clicking, just show the coordinates
        myGui["StepRecStatusText"].Text := "Coordinates captured: " x "," y
    }
}

; Handler for saving the step to the selected flow
StepRec_SaveStep(*) {
    global g_StepRec_ImagePath, g_StepRec_StepType, g_StepRec_FlowsDropdown, g_StepRec_ClickType, g_StepRec_ClickX, g_StepRec_ClickY, g_Flows
    
    flowName := g_StepRec_FlowsDropdown.Text
    if (flowName = "(No Flows)") {
        myGui["StepRecStatusText"].Text := "No target flow selected."
        return
    }
    
    stepName := myGui["StepRecStepName"].Value
    if (stepName = "") {
        myGui["StepRecStatusText"].Text := "Step name is required."
        return
    }
    
    stepType := g_StepRec_StepType.Text
    clickType := g_StepRec_ClickType.Text
    
    ; Validate based on click type
    if (clickType = "Image" && (!IsSet(g_StepRec_ImagePath) || g_StepRec_ImagePath = "")) {
        myGui["StepRecStatusText"].Text := "No image captured."
        return
    }
    
    ; Create step with appropriate parameters
    step := CreateFlowStep(
        g_StepRec_ImagePath,  ; image path (empty for coordinate-based)
        0,                    ; wait time
        [],                   ; no sub steps
        "center",             ; click position
        stepName,             ; step name
        "Recorded via Step Recorder",  ; description
        stepType,             ; action type
        clickType,            ; click type
        g_StepRec_ClickX,     ; X coordinate
        g_StepRec_ClickY      ; Y coordinate
    )
    
    ; Add to flow
    if (!g_Flows.Has(flowName))
        g_Flows[flowName] := []
    g_Flows[flowName].Push(step)
    SaveFlowsToFile()
    UpdateFlowList()
    myGui["StepRecStatusText"].Text := "Step saved to flow '" flowName "'."
    
    ; Clear inputs
    g_StepRec_ImagePreview.Value := ""
    g_StepRec_ImagePath := ""
    myGui["StepRecStepName"].Value := ""
}

; Updates the recording status text in the UI
; Parameters:
;   status: The status text to display
UpdateRecordingStatus(status) {
    global g_RecordingStatusText
    
    if (IsSet(myGui) && myGui && myGui.HasProp("RecordingStatusText")) {
        myGui["RecordingStatusText"].Text := status
    }
}

; Updates the recorded steps list view with current steps
UpdateRecordedStepsList() {
    global g_RecordedSteps
    
    if (IsSet(myGui) && myGui && myGui.HasProp("RecordedStepsList")) {
        ; Clear the list
        myGui["RecordedStepsList"].Delete()
        
        ; Add all recorded steps
        for i, step in g_RecordedSteps {
            myGui["RecordedStepsList"].Add(, i, step["name"], step["waitTime"], step["imagePath"])
        }
    }
}

; Enables or disables recording controls
; Parameters:
;   enable: True to enable controls, false to disable
EnableRecordingControls(enable) {
    global g_RecordingControlsEnabled
    
    g_RecordingControlsEnabled := enable
    
    if (IsSet(myGui) && myGui) {
        if (myGui.HasProp("StartRecordingBtn"))
            myGui["StartRecordingBtn"].Enabled := enable
            
        if (myGui.HasProp("StopRecordingBtn"))
            myGui["StopRecordingBtn"].Enabled := !enable  ; Opposite of others
            
        if (myGui.HasProp("CaptureHoverBtn"))
            myGui["CaptureHoverBtn"].Enabled := !enable  ; Only enabled during recording
    }
}

; Removes the selected step from the recorded steps
; Parameters:
;   sender: The control that triggered the event
;   info: Additional event info
RemoveRecordedStep(sender := 0, info := "") {
    global g_RecordedSteps
    
    ; Check if there are any steps in the list
    if (!IsSet(myGui) || !myGui || !myGui.HasProp("RecordedStepsList"))
        return
        
    if (myGui["RecordedStepsList"].GetCount() = 0)
        return
    
    ; Get the selected row
    row := myGui["RecordedStepsList"].GetNext()
    if (row > 0) {
        ; Remove the step at that index and update the list
        g_RecordedSteps.RemoveAt(row)
        UpdateRecordedStepsList()
    }
}

; Moves the selected recorded step up in the list
; Parameters:
;   sender: The control that triggered the event
;   info: Additional event info
MoveRecordedStepUp(sender := 0, info := "") {
    global g_RecordedSteps
    
    ; Check if there are any steps in the list
    if (!IsSet(myGui) || !myGui || !myGui.HasProp("RecordedStepsList"))
        return
        
    if (myGui["RecordedStepsList"].GetCount() = 0)
        return
    
    ; Get the selected row
    row := myGui["RecordedStepsList"].GetNext()
    if (row > 1) {  ; Can't move up if already at the top
        ; Swap with the step above
        temp := g_RecordedSteps[row - 1]
        g_RecordedSteps[row - 1] := g_RecordedSteps[row]
        g_RecordedSteps[row] := temp
        UpdateRecordedStepsList()
        
        ; Keep the same step selected after moving
        myGui["RecordedStepsList"].Modify(row - 1, "Select Focus")
    }
}

; Moves the selected recorded step down in the list
; Parameters:
;   sender: The control that triggered the event
;   info: Additional event info
MoveRecordedStepDown(sender := 0, info := "") {
    global g_RecordedSteps
    
    ; Check if there are any steps in the list
    if (!IsSet(myGui) || !myGui || !myGui.HasProp("RecordedStepsList"))
        return
        
    if (myGui["RecordedStepsList"].GetCount() = 0)
        return
    
    ; Get the selected row
    row := myGui["RecordedStepsList"].GetNext()
    if (row > 0 && row < g_RecordedSteps.Length) {  ; Can't move down if already at the bottom
        ; Swap with the step below
        temp := g_RecordedSteps[row + 1]
        g_RecordedSteps[row + 1] := g_RecordedSteps[row]
        g_RecordedSteps[row] := temp
        UpdateRecordedStepsList()
        
        ; Keep the same step selected after moving
        myGui["RecordedStepsList"].Modify(row + 1, "Select Focus")
    }
}

; Call this after LoadFlowsFromFile or when flows are updated
StepRec_UpdateFlowsDropdown() {
    global g_StepRec_FlowsDropdown, g_Flows, g_StepRecFlowFilter
    if (!IsSet(g_StepRec_FlowsDropdown) || !g_StepRec_FlowsDropdown)
        return
    g_StepRec_FlowsDropdown.Delete()
    arr := []
    for name, _ in g_Flows {
        if (g_StepRecFlowFilter = "" || InStr(name, g_StepRecFlowFilter)) {
            arr.Push(name)
        }
    }
    if arr.Length = 0
        arr.Push("(No Flows)")
    g_StepRec_FlowsDropdown.Add(arr)
    g_StepRec_FlowsDropdown.Choose(1)
}

; Filter the flows in the step recorder dropdown
StepRec_FilterFlows(*) {
    global g_StepRecFlowFilter
    g_StepRecFlowFilter := myGui["StepRecFlowFilterInput"].Value
    StepRec_UpdateFlowsDropdown()
} 
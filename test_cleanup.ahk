#Requires AutoHotkey v2.0.19

; Import required modules
#Include json_handler.ahk
#Include path_utils.ahk
#Include settings_manager.ahk

; Set working directory
SetWorkingDir A_ScriptDir
global g_WorkingDir := A_WorkingDir

; Initialize settings
InitSettings()

; Load test flows (simplified version)
global g_Flows := Map()
g_Flows["Test Flow"] := [
    Map("imagePath", "images/sign_in.png"),
    Map("imagePath", "images/username_asdf.png")
]

; Test the cleanup function
OutputDebug("Testing cleanup function...")
deletedCount := CleanupUnusedImages()
OutputDebug("Cleanup completed. Deleted " deletedCount " unused images")

; Show result
MsgBox("Cleanup test completed. Deleted " deletedCount " unused images.", "Test Result") 
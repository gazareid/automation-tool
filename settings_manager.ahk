#Requires AutoHotkey v2.0

;------------------------------------------------------------------------------
; SETTINGS MANAGEMENT FUNCTIONS
;------------------------------------------------------------------------------

; Global settings map
global g_Settings := Map()

; Default settings values
global g_DefaultSettings := Map(
    "KeyPressDelay", 5,           ; Default key press delay in milliseconds
    "CaptureDelay", 1000,         ; Default capture delay in milliseconds
    "ImageSearchAttempts", 3,     ; Number of attempts for image search before failing
    "AutoStart", false,           ; Auto-start on Windows login
    "ShowNotifications", true,    ; Show notifications during flow execution
    "ConfirmRun", true,           ; Confirm before running flows
    "DefaultImageFolder", "images", ; Default folder for images
    "AutoCleanupImages", false    ; Auto-cleanup unused images on startup
)

; Initialize settings from file or use defaults
InitSettings() {
    global g_Settings, g_DefaultSettings
    
    ; Start with default settings
    g_Settings := g_DefaultSettings.Clone()
    
    ; Try to load settings from file
    settingsPath := CombinePath(g_WorkingDir, "settings.json")
    if FileExist(settingsPath) {
        try {
            jsonContent := FileRead(settingsPath)
            loadedSettings := SimpleJsonDecode(jsonContent)
            
            ; Merge loaded settings with defaults
            for key, value in loadedSettings {
                if g_Settings.Has(key)
                    g_Settings[key] := value
            }
        } catch as err {
            OutputDebug("Error loading settings: " . err.Message)
        }
    }
    
    ; Apply settings to global variables
    ApplySettings()
}

; Save current settings to file
SaveSettings() {
    global g_Settings
    
    try {
        settingsPath := CombinePath(g_WorkingDir, "settings.json")
        jsonContent := SimpleJsonEncode(g_Settings)
        FileDelete(settingsPath)
        FileAppend(jsonContent, settingsPath)
        return true
    } catch as err {
        OutputDebug("Error saving settings: " . err.Message)
        return false
    }
}

; Apply settings to global variables
ApplySettings() {
    global g_Settings, g_KeyPressDelay, g_CaptureDelay, g_ImageSearchAttempts
    
    ; Apply settings to global variables
    g_KeyPressDelay := g_Settings["KeyPressDelay"]
    g_CaptureDelay := g_Settings["CaptureDelay"]
    g_ImageSearchAttempts := g_Settings["ImageSearchAttempts"]
}

; Update a single setting
UpdateSetting(key, value) {
    global g_Settings
    
    if g_Settings.Has(key) {
        g_Settings[key] := value
        return true
    }
    return false
}

; Get a setting value
GetSetting(key) {
    global g_Settings
    
    if g_Settings.Has(key)
        return g_Settings[key]
    return ""
}

; Reset settings to defaults
ResetSettings() {
    global g_Settings, g_DefaultSettings
    
    g_Settings := g_DefaultSettings.Clone()
    ApplySettings()
    return SaveSettings()
}

; Cleanup unused images from the images folder
; Parameters: none
; Returns: Number of images deleted
CleanupUnusedImages() {
    global g_Flows, g_WorkingDir
    
    try {
        imagesDir := CombinePath(g_WorkingDir, "images")
        if !DirExist(imagesDir) {
            OutputDebug("[CleanupUnusedImages] Images directory does not exist: " imagesDir)
            return 0
        }
        
        ; Collect all image paths used in flows
        usedImages := Map()
        
        for flowName, flowSteps in g_Flows {
            for step in flowSteps {
                if (step.Has("imagePath") && step.imagePath != "") {
                    ; Standardize the path for comparison
                    standardPath := StandardizeImagePath(step.imagePath)
                    if (standardPath != "") {
                        usedImages[standardPath] := true
                        OutputDebug("[CleanupUnusedImages] Found used image: " standardPath)
                    }
                }
            }
        }
        
        OutputDebug("[CleanupUnusedImages] Found " usedImages.Count " used images")
        
        ; Scan images directory for unused files
        deletedCount := 0
        imagesDir := StrReplace(imagesDir, "/", "\")  ; Convert to backslashes for Loop Files
        
        Loop Files imagesDir "\*.*" {
            file := A_LoopFileFullPath
            fileName := GetFileName(file)
            
            ; Skip non-image files
            fileExt := GetFileExtension(file)
            if (fileExt != ".png" && fileExt != ".jpg" && fileExt != ".jpeg" && fileExt != ".bmp" && fileExt != ".gif") {
                continue
            }
            
            ; Create standardized path for comparison
            standardPath := StandardizeImagePath(CombinePath("images", fileName))
            
            ; Check if this image is used
            if !usedImages.Has(standardPath) {
                try {
                    FileDelete(file)
                    OutputDebug("[CleanupUnusedImages] Deleted unused image: " fileName)
                    deletedCount++
                } catch as err {
                    OutputDebug("[CleanupUnusedImages] Failed to delete " fileName ": " err.Message)
                }
            }
        }
        
        OutputDebug("[CleanupUnusedImages] Cleanup completed. Deleted " deletedCount " unused images")
        return deletedCount
        
    } catch as err {
        OutputDebug("[CleanupUnusedImages] Error during cleanup: " err.Message)
        return 0
    }
} 
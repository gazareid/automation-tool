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
    "ShowNotifications", true,    ; Show notifications during workflow execution
    "ConfirmRun", true,           ; Confirm before running workflows
    "DefaultImageFolder", "images" ; Default folder for images
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
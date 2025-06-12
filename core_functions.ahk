#Requires AutoHotkey v2.0

#Include Gdip_All.ahk

;------------------------------------------------------------------------------
; CORE FUNCTIONS - IMAGE RECOGNITION AND CLICKING
;------------------------------------------------------------------------------


GetImageDimensions(imagePath) {
    try {
        ; Normalize path for display in logs
        inputPath := imagePath
        
        ; Use the normalized path with forward slashes
        imagePath := NormalizePath(imagePath)
        
        if !FileExist(imagePath) {
            OutputDebug("File not found: " inputPath)
            return Map("width", 1, "height", 1)
        }

        ; Only add the working directory if this isn't already an absolute path
        fullPath := GetAbsolutePath(imagePath)

        if !pToken := Gdip_Startup() {
            OutputDebug("GDI+ startup failed")
            return Map("width", 1, "height", 1)
        }

        pBitmap := Gdip_CreateBitmapFromFile(fullPath)
        if !pBitmap {
            OutputDebug("Failed to load image via GDI+: " fullPath)
            Gdip_Shutdown(pToken)
            return Map("width", 1, "height", 1)
        }

        width  := Gdip_GetImageWidth(pBitmap)
        height := Gdip_GetImageHeight(pBitmap)
        Gdip_DisposeImage(pBitmap)
        Gdip_Shutdown(pToken)

        if (width <= 0 || height <= 0) {
            OutputDebug("Got invalid dimensions from GDI+ for: " fullPath)
            return Map("width", 1, "height", 1)
        }

        OutputDebug("GDI+ got dimensions for " fullPath ": " width "x" height)
        return Map("width", width, "height", height)

    } catch as err {
        OutputDebug("Exception in GDI+ GetImageDimensions: " err.Message)
        return Map("width", 1, "height", 1)
    }
}





; Function to update image dimensions for all images in a flow
UpdateFlowImageDimensions(flow) {
    global g_ImageDimensions
    
    OutputDebug("Updating image dimensions for flow with " flow.Length " steps")
    
    for i, step in flow {
        imagePath := step["imagePath"]
        if (imagePath != "") {
            ; Use the centralized image path resolver
            fullPath := ResolveImagePath(imagePath)
            
            if (fullPath != "") {
                ; Update dimensions in the global map
                dimensions := GetImageDimensions(fullPath)
                
                ; Create standardized key using the original path for consistency with JSON storage
                standardKey := StandardizeImagePath(imagePath)
                
                ; Store dimensions with standardized key
                g_ImageDimensions[standardKey] := dimensions
                
                OutputDebug("Updated dimensions for " standardKey ": " dimensions["width"] "x" dimensions["height"])
            } else {
                OutputDebug("Could not resolve image path: " imagePath)
            }
        }
    }
}

; Function to find and click an image on the screen with enhanced reliability
; Parameters:
;   imagePath: Path to the image file to search for
;   clickPosition: Where to click on the image (upper left, lower left, upper right, lower right, center)
;   timeoutMs: Maximum time to search in milliseconds (0 = use default attempts without timeout)
;   failCallback: Function to call when search fails (optional)
; Returns: 
;   success: true if image was found and clicked, false otherwise
;   resultObj: Map with detailed results (when verbose is true)
FindAndClick(imagePath, clickPosition := "center", timeoutMs := 0, failCallback := "") {
    global g_ImageSearchAttempts, g_ImageDimensions
    
    ; Start timing for performance tracking
    startTime := A_TickCount
    
    ; Initialize detailed result object
    resultObj := Map(
        "success", false,
        "message", "",
        "attempts", 0,
        "searchTime", 0,
        "positionFound", "",
        "toleranceUsed", 0,
        "imagePath", imagePath
    )
    
    ; Ensure image path is valid
    resolvedPath := ResolveImagePath(imagePath)
    if (resolvedPath = "") {
        errMsg := "Could not resolve image path: " imagePath
        OutputDebug("[FindAndClick] " errMsg)
        resultObj["message"] := errMsg
        
        ; Call failure callback if provided
        if (Type(failCallback) = "Func" || IsObject(failCallback) && failCallback.Call)
            failCallback(resultObj)
        
        return false
    }
    
    standardKey := StandardizeImagePath(imagePath)
    resultObj["resolvedPath"] := resolvedPath
    resultObj["standardKey"] := standardKey
    
    ; Get image dimensions first to log them
    if g_ImageDimensions.Has(standardKey) {
        width := g_ImageDimensions[standardKey]["width"]
        height := g_ImageDimensions[standardKey]["height"]
        OutputDebug("[FindAndClick] Image dimensions from cache: " width "x" height)
        resultObj["width"] := width
        resultObj["height"] := height
    } else {
        ; Try to get dimensions dynamically
        dimensions := GetImageDimensions(resolvedPath)
        width := dimensions["width"]
        height := dimensions["height"]
        g_ImageDimensions[standardKey] := dimensions
        OutputDebug("[FindAndClick] Image dimensions loaded dynamically: " width "x" height)
        resultObj["width"] := width
        resultObj["height"] := height
    }
    
    ; Define the virtual screen area (all monitors)
    VirtualLeft := 0, VirtualTop := 0
    VirtualWidth := A_ScreenWidth, VirtualHeight := A_ScreenHeight
    
    ; Optimized search strategy - try faster methods first
    searchConfigs := [
        ; Fastest search first - low tolerance, fast variant
        {tolerance: 10, variant: "*Fast", name: "Fast"},
        
        ; Standard search with moderate tolerance
        {tolerance: 20, variant: "", name: "Standard"},
        
        ; Higher tolerance for more flexible matching
        {tolerance: 30, variant: "", name: "Standard"},
        
        ; Last resort - high tolerance with transparency
        {tolerance: 40, variant: "*Trans", name: "Transparent"}
    ]
    
    ; Use a timeout approach if specified
    endTime := timeoutMs > 0 ? startTime + timeoutMs : 0
    
    ; Initialize attempt counter
    attemptCount := 0
    
    ; Try each search configuration
    for i, config in searchConfigs {
        OutputDebug("Attempt " i " of " searchConfigs.Length)
        OutputDebug("Config: " config.tolerance " " config.variant)
        attemptCount++  ; Increment attempt counter
        ; Check if we've exceeded the timeout (if any)
        if (endTime > 0 && A_TickCount > endTime) {
            timeoutMsg := "Search timed out after " (A_TickCount - startTime) "ms"
            OutputDebug("[FindAndClick] " timeoutMsg)
            resultObj["message"] := timeoutMsg
            break
        }
        
        ; Construct search parameters
        searchOptions := "*" config.tolerance " " config.variant
        
        try {
            ; Try to find the image with current configuration
            if ImageSearch(&foundX, &foundY, VirtualLeft, VirtualTop, 
                           VirtualLeft+VirtualWidth-1, VirtualTop+VirtualHeight-1, 
                           searchOptions " " resolvedPath) {
                
                ; Calculate elapsed time
                elapsedTime := A_TickCount - startTime
                resultObj["searchTime"] := elapsedTime
                
                ; Log success with details
                foundMsg := "Found image at: " foundX "," foundY . 
                            " (Attempt " i "/" searchConfigs.Length . 
                            ", Strategy=" config.name . 
                            ", Tolerance=" config.tolerance . 
                            ", Time=" elapsedTime "ms)"
                OutputDebug("[FindAndClick] " foundMsg)
                
                ; Calculate click coordinates based on clickPosition
                if (clickPosition = "center") {
                    clickX := foundX + width // 2
                    clickY := foundY + height // 2
                } else if (clickPosition = "upper right") {
                    clickX := foundX + width - 1
                    clickY := foundY
                } else if (clickPosition = "lower left") {
                    clickX := foundX
                    clickY := foundY + height - 1
                } else if (clickPosition = "lower right") {
                    clickX := foundX + width - 1
                    clickY := foundY + height - 1
                } else {  ; upper left or default
                    clickX := foundX
                    clickY := foundY
                }
                
                ; Click the found image
                OutputDebug("[FindAndClick] Clicking at: " clickX "," clickY)
                Click(clickX, clickY)
                
                ; Update result object with success data
                resultObj["success"] := true
                resultObj["message"] := foundMsg
                resultObj["positionFound"] := foundX "," foundY
                resultObj["clickPosition"] := clickX "," clickY
                resultObj["toleranceUsed"] := config.tolerance
                resultObj["strategyUsed"] := config.name
                
                return true
            } else {
                ; Only log detailed failure in debug mode (when not compiled)
                if (!A_IsCompiled) {
                    OutputDebug("[FindAndClick] Image not found with " . 
                                "Strategy=" config.name . 
                                ", Tolerance=" config.tolerance)
                }
            }
        } catch as err {
            ; Only log errors in debug mode (when not compiled)
            if (!A_IsCompiled) {
                errMsg := "Error in ImageSearch: " err.Message " (Line: " err.Line ")"
                OutputDebug("[FindAndClick] " errMsg)
                resultObj["lastError"] := errMsg
            }
        }
        
        ; Shorter delay between attempts for faster searching
        if (i < searchConfigs.Length) {
            Sleep 20
        }
    }
    
    ; Calculate total search time
    totalTime := A_TickCount - startTime
    resultObj["searchTime"] := totalTime
    
    ; All attempts failed
    plural := attemptCount = 1 ? "" : "s"
    failMsg := "Failed to find image after " attemptCount " attempt" plural 
                ": " (imagePath ? imagePath : "[no path]") " (Total search time: " totalTime " ms)"
    OutputDebug("[FindAndClick] " failMsg)
    resultObj["message"] := failMsg
    
    ; Call failure callback if provided
    if (Type(failCallback) = "Func" || IsObject(failCallback) && failCallback.Call)
        failCallback(resultObj)
    
    return false
}

; Function to find and hover (move mouse) over an image on the screen
; Parameters:
;   imagePath: Path to the image file to search for
;   hoverPosition: Where to move the mouse on the image (upper left, lower left, upper right, lower right, center)
;   timeoutMs: Maximum time to search in milliseconds (0 = use default attempts without timeout)
;   failCallback: Function to call when search fails (optional)
; Returns: true if image was found and mouse moved, false otherwise
FindAndHover(imagePath, hoverPosition := "center", timeoutMs := 0, failCallback := "") {
    global g_ImageSearchAttempts, g_ImageDimensions
    startTime := A_TickCount
    resultObj := Map(
        "success", false,
        "message", "",
        "attempts", 0,
        "searchTime", 0,
        "positionFound", "",
        "toleranceUsed", 0,
        "imagePath", imagePath
    )
    resolvedPath := ResolveImagePath(imagePath)
    if (resolvedPath = "") {
        errMsg := "Could not resolve image path: " imagePath
        OutputDebug("[FindAndHover] " errMsg)
        resultObj["message"] := errMsg
        if (Type(failCallback) = "Func" || IsObject(failCallback) && failCallback.Call)
            failCallback(resultObj)
        return false
    }
    standardKey := StandardizeImagePath(imagePath)
    resultObj["resolvedPath"] := resolvedPath
    resultObj["standardKey"] := standardKey
    if g_ImageDimensions.Has(standardKey) {
        width := g_ImageDimensions[standardKey]["width"]
        height := g_ImageDimensions[standardKey]["height"]
        OutputDebug("[FindAndHover] Image dimensions from cache: " width "x" height)
        resultObj["width"] := width
        resultObj["height"] := height
    } else {
        dimensions := GetImageDimensions(resolvedPath)
        width := dimensions["width"]
        height := dimensions["height"]
        g_ImageDimensions[standardKey] := dimensions
        OutputDebug("[FindAndHover] Image dimensions loaded dynamically: " width "x" height)
        resultObj["width"] := width
        resultObj["height"] := height
    }
    VirtualLeft := 0, VirtualTop := 0
    VirtualWidth := A_ScreenWidth, VirtualHeight := A_ScreenHeight
    searchConfigs := [
        {tolerance: 10, variant: "*Fast", name: "Fast"},
        {tolerance: 20, variant: "", name: "Standard"},
        {tolerance: 30, variant: "", name: "Standard"},
        {tolerance: 40, variant: "*Trans", name: "Transparent"}
    ]
    endTime := timeoutMs > 0 ? startTime + timeoutMs : 0
    attemptCount := 0
    for i, config in searchConfigs {
        OutputDebug("[FindAndHover] Attempt " i " of " searchConfigs.Length)
        OutputDebug("[FindAndHover] Config: " config.tolerance " " config.variant)
        attemptCount++
        if (endTime > 0 && A_TickCount > endTime) {
            timeoutMsg := "Search timed out after " (A_TickCount - startTime) "ms"
            OutputDebug("[FindAndHover] " timeoutMsg)
            resultObj["message"] := timeoutMsg
            break
        }
        searchOptions := "*" config.tolerance " " config.variant
        try {
            if ImageSearch(&foundX, &foundY, VirtualLeft, VirtualTop, 
                           VirtualLeft+VirtualWidth-1, VirtualTop+VirtualHeight-1, 
                           searchOptions " " resolvedPath) {
                elapsedTime := A_TickCount - startTime
                resultObj["searchTime"] := elapsedTime
                foundMsg := "Found image at: " foundX "," foundY . 
                            " (Attempt " i "/" searchConfigs.Length . 
                            ", Strategy=" config.name . ", Tolerance=" config.tolerance . ", Time=" elapsedTime "ms)"
                OutputDebug("[FindAndHover] " foundMsg)
                if (hoverPosition = "center") {
                    moveX := foundX + width // 2
                    moveY := foundY + height // 2
                } else if (hoverPosition = "upper right") {
                    moveX := foundX + width - 1
                    moveY := foundY
                } else if (hoverPosition = "lower left") {
                    moveX := foundX
                    moveY := foundY + height - 1
                } else if (hoverPosition = "lower right") {
                    moveX := foundX + width - 1
                    moveY := foundY + height - 1
                } else {
                    moveX := foundX
                    moveY := foundY
                }
                OutputDebug("[FindAndHover] Moving mouse to: " moveX "," moveY)
                MouseMove(moveX, moveY)
                resultObj["success"] := true
                resultObj["message"] := foundMsg
                resultObj["positionFound"] := foundX "," foundY
                resultObj["movePosition"] := moveX "," moveY
                resultObj["toleranceUsed"] := config.tolerance
                resultObj["strategyUsed"] := config.name
                return true
            } else {
                if (!A_IsCompiled) {
                    OutputDebug("[FindAndHover] Image not found with " . 
                                "Strategy=" config.name . ", Tolerance=" config.tolerance)
                }
            }
        } catch as err {
            if (!A_IsCompiled) {
                errMsg := "Error in ImageSearch: " err.Message " (Line: " err.Line ")"
                OutputDebug("[FindAndHover] " errMsg)
                resultObj["lastError"] := errMsg
            }
        }
        if (i < searchConfigs.Length) {
            Sleep 20
        }
    }
    totalTime := A_TickCount - startTime
    resultObj["searchTime"] := totalTime
    plural := attemptCount = 1 ? "" : "s"
    failMsg := "Failed to find image after " attemptCount " attempt" plural 
                ": " (imagePath ? imagePath : "[no path]") " (Total search time: " totalTime " ms)"
    OutputDebug("[FindAndHover] " failMsg)
    resultObj["message"] := failMsg
    if (Type(failCallback) = "Func" || IsObject(failCallback) && failCallback.Call)
        failCallback(resultObj)
    return false
}

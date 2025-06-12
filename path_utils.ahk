#Requires AutoHotkey v2.0

;------------------------------------------------------------------------------
; PATH UTILITY FUNCTIONS
;------------------------------------------------------------------------------
; This module provides centralized path handling to ensure consistency across the application

; Global variables
global g_WorkingDir := A_WorkingDir  ; Store the working directory consistently

; Normalize a path to use forward slashes consistently
; Parameters:
;   path: The path to normalize
; Returns: Normalized path with forward slashes
NormalizePath(path) {
    ; Handle null or empty path
    if (path = "" || !IsSet(path))
        return ""
        
    ; Replace backslashes with forward slashes for consistency
    normalized := StrReplace(path, "\", "/")
    
    ; Remove any duplicate slashes (e.g., "//" becomes "/")
    while InStr(normalized, "//")
        normalized := StrReplace(normalized, "//", "/")
        
    return normalized
}

; Get the absolute path from a potentially relative path
; Parameters:
;   path: The path to resolve (relative or absolute)
; Returns: Absolute path with forward slashes
GetAbsolutePath(path) {
    ; Handle null or empty path
    if (path = "" || !IsSet(path))
        return ""
        
    ; Normalize input path
    path := NormalizePath(path)
    
    ; If already an absolute path (starts with drive letter or UNC path), return as is
    if RegExMatch(path, "^[A-Za-z]:(/|\\)") || SubStr(path, 1, 2) = "\\" {
        return path
    }
    
    ; Get and normalize working directory
    workDir := NormalizePath(g_WorkingDir)
    
    ; Combine paths with proper handling of trailing slashes
    if SubStr(workDir, 0) = "/" {
        return workDir . path
    } else {
        return workDir . "/" . path
    }
}

; Get the relative path from an absolute path, relative to working directory
; Parameters:
;   path: The absolute path to convert to relative
; Returns: Path relative to working directory with forward slashes
GetRelativePath(path) {
    ; Handle null or empty path
    if (path = "" || !IsSet(path))
        return ""
        
    ; Normalize both paths
    path := NormalizePath(path)
    workDir := NormalizePath(g_WorkingDir)
    
    ; Ensure working directory has trailing slash for proper comparison
    if SubStr(workDir, 0) != "/"
        workDir .= "/"
    
    ; If the path starts with the working directory, remove it
    if InStr(path, workDir) = 1 {
        return SubStr(path, StrLen(workDir) + 1)
    }
    
    ; If not within the working directory, return the original path
    return path
}

; Resolve image path consistently
; This centralized function handles various image path formats
; Parameters:
;   imagePath: Path to an image file (may be relative or with different separators)
; Returns: Fully resolved absolute path that exists, or empty string if not found
ResolveImagePath(imagePath) {
    ; Handle null or empty path
    if (imagePath = "" || !IsSet(imagePath))
        return ""
        
    ; Log original path for debugging
    OutputDebug("[ResolveImagePath] Original path: " imagePath)
    
    ; First normalize the path to use forward slashes
    imagePath := NormalizePath(imagePath)
    OutputDebug("[ResolveImagePath] Normalized path: " imagePath)
    
    ; Try different ways to resolve the path
    
    ; 1. Check if the file exists as specified (absolute or relative to working dir)
    if FileExist(imagePath) {
        absPath := GetAbsolutePath(imagePath)
        OutputDebug("[ResolveImagePath] Path exists: " absPath)
        return absPath
    }
    
    ; 2. Check if it's in the images directory
    imagesPath := CombinePath("images", imagePath)
    if FileExist(imagesPath) {
        absPath := GetAbsolutePath(imagesPath)
        OutputDebug("[ResolveImagePath] Found in images directory: " absPath)
        return absPath
    }
    
    ; 3. Try to get just the filename and check in images directory
    SplitPath imagePath, &fileName
    if (fileName && fileName != imagePath) {
        imagesPath := CombinePath("images", fileName)
        if FileExist(imagesPath) {
            absPath := GetAbsolutePath(imagesPath)
            OutputDebug("[ResolveImagePath] Found in images directory by filename: " absPath)
            return absPath
        }
    }
    
    ; 4. If we have a full path but it doesn't exist, return it anyway
    ; (it might be a new file we're about to create)
    if (SubStr(imagePath, 1, 1) = "/" || SubStr(imagePath, 2, 2) = ":/" || SubStr(imagePath, 1, 2) = "\\") {
        OutputDebug("[ResolveImagePath] Returning non-existent absolute path: " imagePath)
        return imagePath
    }
    
    ; If all attempts failed, return empty string
    OutputDebug("[ResolveImagePath] Could not resolve path: " imagePath)
    return ""
}

; Standardize an image path for storage in JSON and databases
; Ensures all image paths follow the same format
; Parameters:
;   imagePath: Path to an image file
; Returns: Standardized path for storage (relative to working dir when possible)
StandardizeImagePath(imagePath) {
    if (imagePath = "" || !IsSet(imagePath))
        return ""
    OutputDebug("[StandardizeImagePath] Original path: " imagePath)
    imagePath := NormalizePath(imagePath)
    ; If already in the form images/<filename>, return as is
    if RegExMatch(imagePath, "^images/[^/]+$") {
        OutputDebug("[StandardizeImagePath] Already in correct format: " imagePath)
        return imagePath
    }
    ; Otherwise, extract just the filename and prepend images/
    SplitPath imagePath, &fileName
    if (fileName) {
        relativePath := "images/" . fileName
        OutputDebug("[StandardizeImagePath] Using filename in images dir: " relativePath)
        return relativePath
    }
    OutputDebug("[StandardizeImagePath] Using normalized path: " imagePath)
    return imagePath
}

; Gets the file extension from a path
; Parameters:
;   path: The file path
; Returns: The file extension including the dot (e.g., ".png")
GetFileExtension(path) {
    ; Handle null or empty path
    if (path = "" || !IsSet(path))
        return ""
        
    SplitPath path, , , &ext
    if (ext != "") {
        return "." . ext
    }
    return ""
}

; Get just the filename from a path
; Parameters:
;   path: The file path
; Returns: Just the filename without the path
GetFileName(path) {
    ; Handle null or empty path
    if (path = "" || !IsSet(path))
        return ""
        
    SplitPath path, &fileName
    return fileName
}

; Ensure directory exists, create if not
; Parameters:
;   dirPath: Directory path to check/create
; Returns: True if exists or successfully created, false otherwise
EnsureDirectoryExists(dirPath) {
    ; Handle null or empty path
    if (dirPath = "" || !IsSet(dirPath))
        return false
        
    try {
        ; Normalize path for consistency
        dirPath := NormalizePath(dirPath)
        
        ; Convert back to backslashes for DirExist/DirCreate which may work better with backslashes on Windows
        dirPath := StrReplace(dirPath, "/", "\")
        
        if !DirExist(dirPath) {
            OutputDebug("[EnsureDirectoryExists] Creating directory: " dirPath)
            DirCreate(dirPath)
        }
        return true
    } catch as err {
        OutputDebug("[EnsureDirectoryExists] Error creating directory: " dirPath ": " err.Message)
        return false
    }
}

; Combines path segments safely
; Parameters:
;   basePath: The base path
;   segments: Additional path segments to add (variadic)
; Returns: Combined path with proper forward slash separators
CombinePath(basePath, segments*) {
    ; Handle null or empty base path
    if (basePath = "" || !IsSet(basePath))
        return ""
        
    combinedPath := NormalizePath(basePath)
    
    for segment in segments {
        ; Skip empty segments
        if (segment = "" || !IsSet(segment))
            continue
            
        ; Normalize this segment
        segment := NormalizePath(segment)
        
        ; Ensure we don't have double slashes
        if SubStr(combinedPath, 0) = "/" {
            if SubStr(segment, 1, 1) = "/" {
                segment := SubStr(segment, 2)  ; Remove leading slash
            }
        } else {
            if SubStr(segment, 1, 1) != "/" {
                combinedPath .= "/"  ; Add slash if needed
            }
        }
        
        combinedPath .= segment
    }
    
    return combinedPath
}

; Update image dimensions in the global map and JSON file
; Parameters:
;   imagePath: Path to the image file
;   width: Image width in pixels
;   height: Image height in pixels 
; Returns: True if successful, false otherwise
UpdateImageDimensions(imagePath, width, height) {
    global g_ImageDimensions, g_ImageDetailsPath
    
    ; Handle null or empty path
    if (imagePath = "" || !IsSet(imagePath))
        return false
        
    try {
        OutputDebug("[UpdateImageDimensions] Called with imagePath=" imagePath ", width=" width ", height=" height)
        
        ; Standardize the image path for consistent storage
        standardKey := StandardizeImagePath(imagePath)
        
        ; Skip if we couldn't generate a standard key
        if (standardKey = "") {
            OutputDebug("[UpdateImageDimensions] Could not generate standard key for: " imagePath)
            return false
        }
        
        ; Update the dimensions in the global map
        g_ImageDimensions[standardKey] := Map(
            "width", width,
            "height", height
        )
        OutputDebug("[UpdateImageDimensions] Updated g_ImageDimensions for " standardKey)
        
        ; Update the JSON file
        if FileExist(g_ImageDetailsPath) {
            OutputDebug("[UpdateImageDimensions] " g_ImageDetailsPath " exists, reading file...")
            jsonContent := FileRead(g_ImageDetailsPath)
            imageDetails := SimpleJsonDecode(jsonContent)
        } else {
            OutputDebug("[UpdateImageDimensions] " g_ImageDetailsPath " does not exist, creating new Map")
            imageDetails := Map()
        }
        
        ; Store with standardized key in the JSON
        imageDetails[standardKey] := Map(
            "width", width,
            "height", height
        )
        OutputDebug("[UpdateImageDimensions] Set imageDetails[" standardKey "]")
        
        ; Make sure we can write to the directory
        EnsureDirectoryExists(GetDirectoryPath(g_ImageDetailsPath))
        
        ; Write back to the JSON file
        FileDelete(g_ImageDetailsPath)
        encoded := SimpleJsonEncode(imageDetails)
        FileAppend(encoded, g_ImageDetailsPath)
        OutputDebug("[UpdateImageDimensions] Wrote dimensions to JSON file")
        
        return true
    } catch as err {
        OutputDebug("[UpdateImageDimensions] Exception: " err.Message)
        return false
    }
}

; Synchronize image_details.json with actual files in images/ directory
; Parameters: none
; Returns: True if successful, false otherwise
SyncImageDimensions() {
    global g_ImageDetailsPath
    
    try {
        imagesDir := CombinePath(g_WorkingDir, "images")
        OutputDebug("[SyncImageDimensions] Scanning images directory: " imagesDir)
        
        ; Read or create the map
        if FileExist(g_ImageDetailsPath) {
            OutputDebug("[SyncImageDimensions] Reading existing image_details.json")
            jsonContent := FileRead(g_ImageDetailsPath)
            imageMap := SimpleJsonDecode(jsonContent)
        } else {
            OutputDebug("[SyncImageDimensions] Creating new image_details.json")
            imageMap := Map()
        }
        
        ; Track which keys are present
        foundKeys := Map()
        
        ; Enumerate all files in images dir
        ; Convert backslashes to forward slashes for consistent paths
        imagesDir := StrReplace(imagesDir, "/", "\")  ; Convert to backslashes for Loop Files
        
        OutputDebug("[SyncImageDimensions] Using path for Loop Files: " imagesDir)
        
        Loop Files imagesDir "\*.*" {
            file := A_LoopFileFullPath
            fileName := GetFileName(file)
            
            ; Skip files with certain extensions
            fileExt := GetFileExtension(file)
            if (fileExt = ".db" || fileExt = ".tmp" || fileExt = ".bak") {
                OutputDebug("[SyncImageDimensions] Skipping non-image file: " file)
                continue
            }
            
            ; Create standardized key
            standardKey := StandardizeImagePath(CombinePath("images", fileName))
            
            foundKeys[standardKey] := true
            dims := GetImageDimensions(file)
            
            ; Only update if dimensions changed or don't exist
            if (!imageMap.Has(standardKey) || 
                imageMap[standardKey]["width"] != dims["width"] || 
                imageMap[standardKey]["height"] != dims["height"]) {
                
                imageMap[standardKey] := Map("width", dims["width"], "height", dims["height"])
                OutputDebug("[SyncImageDimensions] Updated dimensions for: " standardKey)
            }
        }
        
        ; Prune any entry not in foundKeys
        for k, _ in imageMap.Clone() {
            if !foundKeys.Has(k) {
                OutputDebug("[SyncImageDimensions] Removing outdated entry: " k)
                imageMap.Delete(k)
            }
        }
        
        ; Make sure we can write to the directory
        EnsureDirectoryExists(GetDirectoryPath(g_ImageDetailsPath))
        
        ; Write back to JSON
        FileDelete(g_ImageDetailsPath)
        jsonString := SimpleJsonEncode(imageMap)
        FileAppend(jsonString, g_ImageDetailsPath)
        
        OutputDebug("[SyncImageDimensions] Synchronized image_details.json with " foundKeys.Count " images")
        
        ; Return the number of images found
        return foundKeys.Count
    } catch as err {
        OutputDebug("[SyncImageDimensions] Error: " err.Message)
        return false
    }
} 
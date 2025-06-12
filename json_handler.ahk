#Requires AutoHotkey v2.0.19

;------------------------------------------------------------------------------
; JSON HANDLING FUNCTIONS
;------------------------------------------------------------------------------
; Custom JSON encoder - converts AutoHotkey objects to JSON string format
; obj: The object to convert to JSON (Map, Array, or primitive value)
; Returns: A JSON-formatted string
; TIP: For larger projects, consider using a dedicated JSON library
SimpleJsonEncode(obj) {
    try {
        if IsObject(obj) {
            if obj is Array {
                ; Handle arrays: [value1, value2, ...]
                result := "["
                try {
                    for i, value in obj {
                        if i > 1
                            result .= ","
                        result .= SimpleJsonEncode(value)
                    }
                } catch as err {
                    OutputDebug("Error in array iteration: " err.Message " at line " err.Line)
                    throw Error("Failed to iterate array: " err.Message)
                }
                result .= "]"
                return result
            } else if obj is Map {
                ; Handle objects/maps: {"key1": value1, "key2": value2, ...}
                result := "{"
                propCount := 0
                try {
                    for key, value in obj {
                        if propCount > 0
                            result .= ","
                        ; Escape the key - important for special characters
                        escapedKey := StrReplace(key, "\", "\\")
                        escapedKey := StrReplace(escapedKey, Chr(34), "\" . Chr(34))
                        result .= Chr(34) . escapedKey . Chr(34) . ":" . SimpleJsonEncode(value)
                        propCount += 1
                    }
                } catch as err {
                    OutputDebug("Error in object iteration: " err.Message " at line " err.Line)
                    throw Error("Failed to iterate object: " err.Message)
                }
                result .= "}"
                return result
            } else {
                ; Not a Map or Array, so not enumerable. Encode as string or throw error.
                OutputDebug("Non-enumerable object encountered in SimpleJsonEncode. Type: " Type(obj))
                throw Error("Cannot encode non-enumerable object of type: " Type(obj))
            }
        } else if obj is Number {
            ; Numbers are added directly without quotes
            return obj
        } else if obj is String {
            ; Strings need to be quoted and escaped
            escapedStr := StrReplace(obj, "\", "\\")
            
            ; If this looks like a file path, ensure it uses forward slashes for consistency
            if (InStr(obj, "\") || InStr(obj, "/")) {
                ; Use the path normalization function to ensure forward slashes
                if (IsSet(NormalizePath)) {
                    escapedStr := NormalizePath(obj)
                    ; For JSON, we still need to escape the forward slashes
                    escapedStr := StrReplace(escapedStr, "\", "\\")
                } else {
                    ; Fallback if NormalizePath is not available
                    escapedStr := StrReplace(obj, "\", "/")
                    ; For JSON, we still need to escape the forward slashes
                    escapedStr := StrReplace(escapedStr, "\\", "\\\\")
                }
            }
            
            escapedStr := StrReplace(escapedStr, Chr(34), "\" . Chr(34))
            
            ; Also escape control characters
            escapedStr := StrReplace(escapedStr, "`n", "\n")
            escapedStr := StrReplace(escapedStr, "`r", "\r")
            escapedStr := StrReplace(escapedStr, "`t", "\t")
            escapedStr := StrReplace(escapedStr, "`b", "\b")
            
            return Chr(34) . escapedStr . Chr(34)
        } else if obj = true {
            ; Boolean true
            return "true"
        } else if obj = false {
            ; Boolean false
            return "false"
        } else {
            ; Null, undefined, or other -> empty string
            return '""'
        }
    } catch as err {
        OutputDebug("SimpleJsonEncode error: " err.Message " at line " err.Line)
        throw Error("JSON encoding failed: " err.Message)
    }
}

; Custom JSON decoder - converts JSON string to AutoHotkey objects
; jsonString: The JSON string to parse
; Returns: A Map object containing the parsed data
; TIP: This is a simplified parser. For complex JSON, consider a dedicated library
SimpleJsonDecode(jsonString) {
    ; Create a safer version we can work with
    safeJson := Trim(jsonString)
    
    ; Check if it looks like a JSON object
    if (SubStr(safeJson, 1, 1) != "{" || SubStr(safeJson, -1) != "}") {
        ; Not a JSON object
        return Map()
    }
    
    ; Holds our result object
    result := Map()
    
    ; Extract content between the outer braces
    safeJson := SubStr(safeJson, 2, StrLen(safeJson) - 2)
    
    ; Process object properties
    pos := 1
    len := StrLen(safeJson)
    
    while (pos <= len) {
        ; Skip whitespace
        while (pos <= len && InStr(" `t`r`n", SubStr(safeJson, pos, 1)))
            pos++
        
        ; If at the end, break
        if (pos > len)
            break
            
        ; Check for property separator (comma)
        if (SubStr(safeJson, pos, 1) = ",") {
            pos++
            continue
        }
        
        ; Find property name (should be quoted)
        if (SubStr(safeJson, pos, 1) != Chr(34)) {
            ; Unexpected format
            return Map()
        }
        
        ; Extract property name
        quotePos := InStr(safeJson, Chr(34), false, pos + 1)
        if (!quotePos) {
            ; Malformed JSON
            return Map()
        }
        
        propName := SubStr(safeJson, pos + 1, quotePos - pos - 1)
        pos := quotePos + 1
        
        ; Skip whitespace to the colon
        while (pos <= len && InStr(" `t`r`n", SubStr(safeJson, pos, 1)))
            pos++
            
        ; Check for the colon
        if (pos > len || SubStr(safeJson, pos, 1) != ":") {
            ; Malformed JSON
            return Map()
        }
        
        pos++
        
        ; Skip whitespace after the colon
        while (pos <= len && InStr(" `t`r`n", SubStr(safeJson, pos, 1)))
            pos++
            
        ; Extract property value
        if (pos > len) {
            ; Malformed JSON
            return Map()
        }
        
        ; Determine the type of value
        valueChar := SubStr(safeJson, pos, 1)
        
        if (valueChar = "[") {
            ; Array value
            bracketLevel := 1
            startPos := pos
            pos++
            
            ; Find the matching closing bracket
            while (pos <= len && bracketLevel > 0) {
                ch := SubStr(safeJson, pos, 1)
                if (ch = "[")
                    bracketLevel++
                else if (ch = "]")
                    bracketLevel--
                else if (ch = Chr(34)) {
                    ; Skip quoted sections
                    pos++
                    while (pos <= len && SubStr(safeJson, pos, 1) != Chr(34)) {
                        ; Skip escaped quotes
                        if (SubStr(safeJson, pos, 1) = "\" && pos + 1 <= len)
                            pos++
                        pos++
                    }
                }
                pos++
            }
            
            ; Extract the array JSON
            arrayJson := SubStr(safeJson, startPos, pos - startPos)
            
            ; Process array items
            result[propName] := ParseJsonArray(arrayJson)
        } else if (valueChar = "{") {
            ; Object value - recurse
            braceLevel := 1
            startPos := pos
            pos++
            
            ; Find the matching closing brace
            while (pos <= len && braceLevel > 0) {
                ch := SubStr(safeJson, pos, 1)
                if (ch = "{")
                    braceLevel++
                else if (ch = "}")
                    braceLevel--
                else if (ch = Chr(34)) {
                    ; Skip quoted sections
                    pos++
                    while (pos <= len && SubStr(safeJson, pos, 1) != Chr(34)) {
                        ; Skip escaped quotes
                        if (SubStr(safeJson, pos, 1) = "\" && pos + 1 <= len)
                            pos++
                        pos++
                    }
                }
                pos++
            }
            
            ; Extract the object JSON
            objectJson := SubStr(safeJson, startPos, pos - startPos)
            
            ; Recurse to handle nested objects
            result[propName] := SimpleJsonDecode(objectJson)
        } else if (valueChar = Chr(34)) {
            ; String value
            startPos := pos + 1
            pos++
            
            ; Find the closing quote
            while (pos <= len) {
                if (SubStr(safeJson, pos, 1) = Chr(34) && SubStr(safeJson, pos - 1, 1) != "\")
                    break
                pos++
            }
            
            if (pos > len) {
                ; Malformed JSON
                return Map()
            }
            
            ; Extract the string value
            stringValue := SubStr(safeJson, startPos, pos - startPos)
            
            ; Unescape common escape sequences
            stringValue := StrReplace(stringValue, "\" . Chr(34), Chr(34))  ; Replace \" with "
            stringValue := StrReplace(stringValue, "\\", "\")   ; Replace \\ with \
            stringValue := StrReplace(stringValue, "\n", "`n")  ; Replace \n with newline
            stringValue := StrReplace(stringValue, "\r", "`r")  ; Replace \r with carriage return
            stringValue := StrReplace(stringValue, "\t", "`t")  ; Replace \t with tab
            stringValue := StrReplace(stringValue, "\b", "`b")  ; Replace \b with backspace
            
            ; Normalize paths to use forward slashes if this appears to be a file path
            if (InStr(stringValue, "images") && InStr(stringValue, "\")) {
                if (IsSet(NormalizePath)) {
                    stringValue := NormalizePath(stringValue)
                } else {
                    ; Fallback if NormalizePath is not available
                    stringValue := StrReplace(stringValue, "\", "/")
                }
            }
            
            result[propName] := stringValue
            pos++
        } else if (valueChar = "t" && SubStr(safeJson, pos, 4) = "true") {
            ; Boolean true
            result[propName] := true
            pos += 4
        } else if (valueChar = "f" && SubStr(safeJson, pos, 5) = "false") {
            ; Boolean false
            result[propName] := false
            pos += 5
        } else if (valueChar = "n" && SubStr(safeJson, pos, 4) = "null") {
            ; Null value
            result[propName] := ""
            pos += 4
        } else if (InStr("0123456789-", valueChar)) {
            ; Number value
            startPos := pos
            pos++
            
            ; Find the end of the number
            while (pos <= len && InStr("0123456789.eE+-", SubStr(safeJson, pos, 1)))
                pos++
                
            ; Extract the number
            numberStr := SubStr(safeJson, startPos, pos - startPos)
            
            ; Convert to a number
            result[propName] := numberStr + 0
        } else {
            ; Unknown value type
            pos++
        }
    }
    
    return result
}

; Helper function to parse JSON arrays
; arrayJson: The JSON array string to parse
; Returns: An Array containing the parsed array items
ParseJsonArray(arrayJson) {
    ; Check if it's an array
    if (SubStr(arrayJson, 1, 1) != "[" || SubStr(arrayJson, -1) != "]") {
        ; Not an array
        return []
    }
    
    ; Remove the brackets
    arrayJson := SubStr(arrayJson, 2, StrLen(arrayJson) - 2)
    arrayJson := Trim(arrayJson)
    
    ; Empty array check
    if (arrayJson = "")
        return []
        
    ; Process array items
    result := []
    pos := 1
    len := StrLen(arrayJson)
    
    while (pos <= len) {
        ; Skip whitespace
        while (pos <= len && InStr(" `t`r`n", SubStr(arrayJson, pos, 1)))
            pos++
            
        ; Check for item separator (comma)
        if (SubStr(arrayJson, pos, 1) = ",") {
            pos++
            continue
        }
        
        ; Process the array item
        itemChar := SubStr(arrayJson, pos, 1)
        
        if (itemChar = "{") {
            ; Object item
            braceLevel := 1
            startPos := pos
            pos++
            
            ; Find the matching closing brace
            while (pos <= len && braceLevel > 0) {
                ch := SubStr(arrayJson, pos, 1)
                if (ch = "{")
                    braceLevel++
                else if (ch = "}")
                    braceLevel--
                pos++
            }
            
            ; Extract the object JSON
            objectJson := SubStr(arrayJson, startPos, pos - startPos)
            
            ; Parse the object
            result.Push(SimpleJsonDecode(objectJson))
        } else if (itemChar = "[") {
            ; Nested array
            bracketLevel := 1
            startPos := pos
            pos++
            
            ; Find the matching closing bracket
            while (pos <= len && bracketLevel > 0) {
                ch := SubStr(arrayJson, pos, 1)
                if (ch = "[")
                    bracketLevel++
                else if (ch = "]")
                    bracketLevel--
                pos++
            }
            
            ; Extract the nested array JSON
            nestedArrayJson := SubStr(arrayJson, startPos, pos - startPos)
            
            ; Parse the nested array recursively
            result.Push(ParseJsonArray(nestedArrayJson))
        } else if (itemChar = Chr(34)) {
            ; String item
            startPos := pos + 1
            pos++
            
            ; Find the closing quote
            while (pos <= len) {
                if (SubStr(arrayJson, pos, 1) = Chr(34) && SubStr(arrayJson, pos - 1, 1) != "\")
                    break
                pos++
            }
            
            ; Extract the string value
            stringValue := SubStr(arrayJson, startPos, pos - startPos)
            
            ; Unescape common escape sequences
            stringValue := StrReplace(stringValue, "\" . Chr(34), Chr(34))  ; Replace \" with "
            stringValue := StrReplace(stringValue, "\\", "\")   ; Replace \\ with \
            stringValue := StrReplace(stringValue, "\n", "`n")  ; Replace \n with newline
            stringValue := StrReplace(stringValue, "\r", "`r")  ; Replace \r with carriage return
            stringValue := StrReplace(stringValue, "\t", "`t")  ; Replace \t with tab
            stringValue := StrReplace(stringValue, "\b", "`b")  ; Replace \b with backspace
            
            ; Normalize paths if this appears to be a file path
            if (InStr(stringValue, "images") && InStr(stringValue, "\")) {
                if (IsSet(NormalizePath)) {
                    stringValue := NormalizePath(stringValue)
                } else {
                    ; Fallback if NormalizePath is not available
                    stringValue := StrReplace(stringValue, "\", "/")
                }
            }
            
            result.Push(stringValue)
            pos++
        } else if (itemChar = "t" && SubStr(arrayJson, pos, 4) = "true") {
            ; Boolean true
            result.Push(true)
            pos += 4
        } else if (itemChar = "f" && SubStr(arrayJson, pos, 5) = "false") {
            ; Boolean false
            result.Push(false)
            pos += 5
        } else if (itemChar = "n" && SubStr(arrayJson, pos, 4) = "null") {
            ; Null value
            result.Push("")
            pos += 4
        } else if (InStr("0123456789-", itemChar)) {
            ; Number item
            startPos := pos
            pos++
            
            ; Find the end of the number
            while (pos <= len && InStr("0123456789.eE+-", SubStr(arrayJson, pos, 1)))
                pos++
                
            ; Extract the number
            numberStr := SubStr(arrayJson, startPos, pos - startPos)
            
            ; Convert to a number
            result.Push(numberStr + 0)
        } else {
            ; Unknown item type
            pos++
        }
    }
    
    return result
} 
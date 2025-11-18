-- Test script to find Control Center and Screen Mirroring
tell application "System Events"
    set output to ""
    
    -- Method 1: Try to find Control Center in the main menu bar
    try
        tell application process "ControlCenter"
            -- Try to get windows
            set windowList to windows
            set output to output & "ControlCenter windows: " & (count of windowList) & return
        end tell
    on error e
        set output to output & "Could not access ControlCenter windows: " & e & return
    end try
    
    -- Method 2: Try to find Screen Mirroring in the main menu bar (not ControlCenter process)
    try
        tell application process "SystemUIServer"
            set menuBarItems to menu bar items of menu bar 1
            set output to output & "SystemUIServer menu bar items: " & (count of menuBarItems) & return
            repeat with i from 1 to (count of menuBarItems)
                try
                    set itemName to name of item i of menuBarItems
                    set output to output & "  " & i & ": " & itemName & return
                    if itemName contains "Screen Mirroring" or itemName contains "Mirroring" or itemName contains "Display" then
                        set output to output & "  ✓ Found potential match!" & return
                    end if
                end try
            end repeat
        end tell
    on error e
        set output to output & "Could not access SystemUIServer: " & e & return
    end try
    
    -- Method 3: Try clicking Control Center icon (usually rightmost)
    try
        tell application process "SystemUIServer"
            set menuBarItems to menu bar items of menu bar 1
            set itemCount to count of menuBarItems
            if itemCount > 0 then
                -- Try the last few items (Control Center is usually on the right)
                repeat with i from (itemCount - 2) to itemCount
                    try
                        set itemName to name of item i of menuBarItems
                        set output to output & "Trying menu bar item " & i & ": " & itemName & return
                    end try
                end repeat
            end if
        end tell
    on error e
        set output to output & "Error accessing menu bar: " & e & return
    end try
    
    return output
end tell


-- Test script to manually enable Sidecar
-- Run this to see what works on your system

tell application "System Events"
    -- Try Method 1: Direct Screen Mirroring
    try
        tell process "ControlCenter"
            set screenMirroringItem to menu bar item "Screen Mirroring" of menu bar 1
            click screenMirroringItem
            delay 1.5
            
            set theMenu to menu 1 of screenMirroringItem
            set menuItems to menu items of theMenu
            
            -- List all menu items
            set output to "Found menu items:" & return
            repeat with menuItem in menuItems
                try
                    set itemName to name of menuItem as string
                    set output to output & "  - " & itemName & return
                    if itemName contains "iPad" then
                        click menuItem
                        set output to output & "  ✓ Clicked iPad!" & return
                        return output
                    end if
                end try
            end repeat
            return output
        end tell
    on error errorMessage
        set output to "Method 1 failed: " & errorMessage & return
    end try
    
    -- If that didn't work, list all menu bar items
    try
        tell process "ControlCenter"
            set menuBarItems to menu bar items of menu bar 1
            set output to output & "All menu bar items:" & return
            repeat with menuBarItem in menuBarItems
                try
                    set itemName to name of menuBarItem as string
                    set output to output & "  - " & itemName & return
                end try
            end repeat
        end tell
    on error errorMessage
        set output to output & "Could not list menu bar items: " & errorMessage & return
    end try
    
    return output
end tell


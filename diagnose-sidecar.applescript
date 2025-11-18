-- Diagnostic script to find Control Center structure
tell application "System Events"
    -- List all running processes
    set processList to name of every process
    log "All processes: " & processList
    
    -- Check for Control Center related processes
    try
        tell process "ControlCenter"
            set menuBarItems to menu bar items of menu bar 1
            log "ControlCenter menu bar items found: " & (count of menuBarItems)
            repeat with item in menuBarItems
                try
                    log "Menu bar item: " & (name of item)
                end try
            end repeat
        end tell
    on error e
        log "Error accessing ControlCenter: " & e
    end try
    
    -- Try to find Screen Mirroring
    try
        tell process "ControlCenter"
            set screenMirroring to menu bar item "Screen Mirroring" of menu bar 1
            log "Found Screen Mirroring menu bar item"
            click screenMirroring
            delay 1
            set menuItems to menu items of menu 1 of screenMirroring
            log "Menu items: " & (count of menuItems)
            repeat with item in menuItems
                try
                    log "Menu item: " & (name of item)
                end try
            end repeat
        end tell
    on error e
        log "Error finding Screen Mirroring: " & e
    end try
end tell


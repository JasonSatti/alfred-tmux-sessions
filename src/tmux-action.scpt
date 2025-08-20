(*
    Alfred Tmux Sessions - Action Handler
    
    Handles all tmux session actions triggered from Alfred with production-ready
    reliability, enhanced error handling, and user feedback.
    
    Actions:
    - attach: Opens existing session in new terminal window (default)
    - create: Creates new session and opens it
    - delete: Removes a tmux session
    - detach: Detaches from an active session
    
    Supported Terminals: iTerm2, Ghostty, Terminal.app
    
    Author: Jason Satti
    License: MIT
*)

-- Can be overridden by Alfred workflow environment variable: terminal_app
property defaultTerminal : "auto"

-- GUI timing delays to handle application startup and UI responsiveness
property WINDOW_INIT_DELAY : 0.2
property GHOSTTY_APP_DELAY : 0.5
property GHOSTTY_WINDOW_DELAY : 0.3
property GHOSTTY_COMMAND_DELAY : 0.1
property ALFRED_REOPEN_DELAY : 0.3

property INVALID_SESSION_CHARS : {".", ":", " ", "\n", "\t"}

on isValidSessionName(sessionName)
    if sessionName is "" then return false
    repeat with char in INVALID_SESSION_CHARS
        if sessionName contains char then return false
    end repeat
    return true
end isValidSessionName

on getConfiguredTerminal()
    try
        set terminalApp to (system attribute "terminal_app")
        if terminalApp is not "" then
            return terminalApp
        end if
    on error
    end try
    
    return defaultTerminal
end getConfiguredTerminal

on applicationIsInstalled(appName)
    try
        set result to do shell script "mdfind 'kMDItemKind == \"Application\" && kMDItemFSName == \"" & appName & ".app\"' | head -1"
        return result is not ""
    on error
        return false
    end try
end applicationIsInstalled

on getAvailableTerminal()
    -- Priority: iTerm2 → Ghostty → Terminal.app
    if applicationIsInstalled("iTerm") then
        return "iTerm"
    else if applicationIsInstalled("Ghostty") then
        return "Ghostty"
    else if applicationIsInstalled("Terminal") then
        return "Terminal"
    end if
    
    return missing value
end getAvailableTerminal

on resolveTerminal()
    set configuredTerminal to getConfiguredTerminal()
    
    if configuredTerminal is "auto" then
        set selectedTerminal to getAvailableTerminal()
        if selectedTerminal is missing value then
            error "No supported terminal applications found. Please install iTerm2, Ghostty, or use Terminal.app."
        end if
        return selectedTerminal
    else
        -- Case-insensitive terminal name mapping
        set normalizedTerminal to configuredTerminal
        set appToCheck to configuredTerminal
        if configuredTerminal is "iterm" or configuredTerminal is "iTerm" or configuredTerminal is "ITERM" or configuredTerminal is "iterm2" or configuredTerminal is "iTerm2" or configuredTerminal is "ITERM2" then
            set normalizedTerminal to "iTerm"
            set appToCheck to "iTerm"
        else if configuredTerminal is "ghostty" or configuredTerminal is "Ghostty" or configuredTerminal is "GHOSTTY" then
            set normalizedTerminal to "Ghostty"
            set appToCheck to "Ghostty"
        else if configuredTerminal is "terminal" or configuredTerminal is "Terminal" or configuredTerminal is "TERMINAL" then
            set normalizedTerminal to "Terminal"
            set appToCheck to "Terminal"
        end if
        
        if not applicationIsInstalled(appToCheck) then
            display notification "Configured terminal '" & configuredTerminal & "' not found. Using auto-detection." with title "Tmux Sessions"
            return getAvailableTerminal()
        end if
        return normalizedTerminal
    end if
end resolveTerminal

on run argv
    if (count of argv) is 0 then return
    
    try
        set argData to my parseActionArgument(item 1 of argv)
        set action to action of argData
        set sessionName to sessionName of argData
        
        if sessionName is "" then
            display notification "No session name provided" with title "Tmux Error"
            return
        end if
        
        if not isValidSessionName(sessionName) then
            display notification "Invalid session name '" & sessionName & "'. Names cannot contain spaces, dots, or colons." with title "Tmux Error"
            return
        end if
        
        if action is "delete" then
            my deleteSession(sessionName)
        else if action is "detach" then
            my detachSession(sessionName)
        else if action is "create" then
            my createSession(sessionName)
        else if action is "attach" then
            my attachSession(sessionName)
        else
            display notification "Unknown action: " & action with title "Tmux Error"
        end if
        
    on error errorMessage
        display notification "Unexpected error: " & errorMessage with title "Tmux Error"
    end try
end run

-- Parse "action:session" format, defaults to attach if no colon found
on parseActionArgument(arg)
    set delimiterPosition to offset of ":" in arg
    
    if delimiterPosition is 0 then
        return {action:"attach", sessionName:arg}
    else
        set actionName to text 1 thru (delimiterPosition - 1) of arg
        set sessionName to text (delimiterPosition + 1) thru -1 of arg
        return {action:actionName, sessionName:sessionName}
    end if
end parseActionArgument

on deleteSession(sessionName)
    try
        -- Check existence first for better error messages
        do shell script "tmux has-session -t " & quoted form of sessionName & " 2>/dev/null"
        
        try
            do shell script "tmux kill-session -t " & quoted form of sessionName
            
            my reopenAlfred()
            
        on error errMsg
            display notification "Failed to delete '" & sessionName & "': " & errMsg with title "Tmux Error"
        end try
        
    on error
        display notification "Session '" & sessionName & "' not found" with title "Tmux Error"
    end try
end deleteSession

on detachSession(sessionName)
    try
        do shell script "tmux detach-client -s " & quoted form of sessionName
        
        my reopenAlfred()
        
    on error errorMessage
        -- Parse tmux error messages for specific user feedback
        if errorMessage contains "no clients" then
            display notification "No clients attached to '" & sessionName & "'" with title "Tmux"
        else if errorMessage contains "session not found" then
            display notification "Session '" & sessionName & "' not found" with title "Tmux Error"
        else
            display notification "Could not detach from '" & sessionName & "'" with title "Tmux Error"
        end if
    end try
end detachSession

on createSession(sessionName)
    try
        -- Create detached to avoid terminal race conditions, start in ~
        do shell script "cd ~ && tmux new-session -d -s " & quoted form of sessionName
        my openTerminalSession(sessionName)
        
    on error errorMessage
        if errorMessage contains "duplicate session" then
            display notification "Session '" & sessionName & "' already exists" with title "Tmux Error"
        else
            display notification "Failed to create '" & sessionName & "': " & errorMessage with title "Tmux Error"
        end if
    end try
end createSession

on attachSession(sessionName)
    try
        -- Prevent terminal flash if session doesn't exist
        do shell script "tmux has-session -t " & quoted form of sessionName & " 2>/dev/null"
        my openTerminalSession(sessionName)
    on error
        display notification "Session '" & sessionName & "' not found" with title "Tmux Error"
    end try
end attachSession

on openTerminalSession(sessionName)
    try
        set selectedTerminal to resolveTerminal()
        
        if selectedTerminal is "iTerm" then
            my openInITerm(sessionName)
        else if selectedTerminal is "Ghostty" then
            my openInGhostty(sessionName)
        else if selectedTerminal is "Terminal" then
            my openInTerminal(sessionName)
        else
            error "Unsupported terminal: " & selectedTerminal
        end if
        
    on error errorMessage
        display notification "Failed to open terminal session: " & errorMessage with title "Terminal Error"
    end try
end openTerminalSession

on openInITerm(sessionName)
    try
        tell application "iTerm"
            activate
            
            set newWindow to (create window with default profile)
            
            -- Window needs time to initialize before accepting commands
            delay WINDOW_INIT_DELAY
            
            tell current session of newWindow
                write text "tmux attach-session -t " & quoted form of sessionName
            end tell
        end tell
        
    on error errorMessage
        display notification "Failed to open iTerm: " & errorMessage with title "iTerm Error"
    end try
end openInITerm

-- GUI scripting required due to lack of native AppleScript support
on openInGhostty(sessionName)
    try
        tell application "Ghostty"
            activate
        end tell
        
        delay GHOSTTY_APP_DELAY
        
        tell application "System Events"
            tell process "Ghostty"
                -- Check if we need a new window by counting existing windows
                set windowCount to count of windows
                if windowCount is 0 then
                    keystroke "n" using {command down}
                    delay GHOSTTY_WINDOW_DELAY
                end if
                
                -- Command injection protection via quoted form
                keystroke "tmux attach-session -t " & quoted form of sessionName
                delay GHOSTTY_COMMAND_DELAY
                key code 36
            end tell
        end tell
        
    on error errorMessage
        display notification "Failed to open Ghostty: " & errorMessage with title "Ghostty Error"
    end try
end openInGhostty

on openInTerminal(sessionName)
    try
        tell application "Terminal"
            activate
            do script "tmux attach-session -t " & quoted form of sessionName
        end tell
        
    on error errorMessage
        display notification "Failed to open Terminal: " & errorMessage with title "Terminal Error"
    end try
end openInTerminal

-- UX enhancement: refresh session list after state changes
on reopenAlfred()
    try
        -- Brief delay ensures tmux operation completes before refresh
        delay ALFRED_REOPEN_DELAY
        
        tell application "Alfred"
            search "tmux "
        end tell
    on error errorMessage
        -- Alfred refresh failure shouldn't disrupt main operation
    end try
end reopenAlfred
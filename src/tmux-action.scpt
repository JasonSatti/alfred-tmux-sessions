(*
    Alfred Tmux Sessions - Action Handler

    Handles all tmux session actions triggered from Alfred with production-ready
    reliability, enhanced error handling, and user feedback.

    Actions:
    - attach: Opens existing session in focused terminal window or creates new window (default)
    - create: Creates new session and opens it
    - delete: Removes a tmux session
    - detach: Detaches from an active session

    Supported Terminals: iTerm2, Ghostty, Terminal.app

    Author: Jason Satti
    License: MIT
*)

-- Can be overridden by Alfred workflow environment variable: terminal_app
property defaultTerminal : "auto"
property defaultShell : "auto"

-- GUI timing delays to handle application startup and UI responsiveness
property WINDOW_INIT_DELAY : 0.2
property GHOSTTY_APP_DELAY : 0.5
property GHOSTTY_WINDOW_DELAY : 0.3
property GHOSTTY_COMMAND_DELAY : 0.1
property ALFRED_REOPEN_DELAY : 0.3

property INVALID_SESSION_CHARS : {".", ":", " ", "\n", "\t", "'", "\\"}
property MAX_SESSION_NAME_LENGTH : 100

on isValidSessionName(sessionName)
    if sessionName is "" then return false
    if length of sessionName > MAX_SESSION_NAME_LENGTH then return false
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

on getConfiguredShell()
    try
        set shellPath to (system attribute "default_shell")
        if shellPath is not "" then
            return shellPath
        end if
    on error
    end try

    return defaultShell
end getConfiguredShell

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

on isTerminalRunningAndFrontmost(terminalName)
    try
        tell application "System Events"
            set frontApp to name of first application process whose frontmost is true

            -- Handle app name variations
            if terminalName is "iTerm" then
                return frontApp is "iTerm2" or frontApp is "iTerm"
            else if terminalName is "Terminal" then
                return frontApp is "Terminal"
            else if terminalName is "Ghostty" then
                return frontApp is "Ghostty"
            end if
        end tell
    on error
        return false
    end try

    return false
end isTerminalRunningAndFrontmost

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
            if length of sessionName > MAX_SESSION_NAME_LENGTH then
                display notification "Session name too long (" & (length of sessionName) & " chars). Maximum is " & MAX_SESSION_NAME_LENGTH & "." with title "Tmux Error"
            else
                display notification "Invalid session name '" & sessionName & "'. Names cannot contain spaces, dots, colons, quotes, or backslashes." with title "Tmux Error"
            end if
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
        else if action is "attach-linked" then
            my attachLinkedSession(sessionName)
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
        -- Check if session already exists before opening terminal
        do shell script "tmux has-session -t " & quoted form of sessionName & " 2>/dev/null"
        display notification "Session '" & sessionName & "' already exists" with title "Tmux Error"
    on error
        try
            set cmd to my buildHelperCommand("create " & quoted form of sessionName)
            my openTerminalSession(cmd)
        on error errorMessage
            display notification "Failed to create '" & sessionName & "': " & errorMessage with title "Tmux Error"
        end try
    end try
end createSession

on attachSession(sessionName)
    try
        -- Prevent terminal flash if session doesn't exist
        do shell script "tmux has-session -t " & quoted form of sessionName & " 2>/dev/null"
    on error
        display notification "Session '" & sessionName & "' not found" with title "Tmux Error"
        return
    end try
    try
        set cmd to my buildHelperCommand("attach " & quoted form of sessionName)
        my openTerminalSession(cmd)
    on error errorMessage
        display notification "Failed to attach '" & sessionName & "': " & errorMessage with title "Tmux Error"
    end try
end attachSession

on attachLinkedSession(sessionName)
    try
        -- Check if base session exists
        do shell script "tmux has-session -t " & quoted form of sessionName & " 2>/dev/null"

        -- Find next available number by checking existing linked sessions
        set linkedNumber to 2
        repeat
            set linkedSessionName to sessionName & "@" & linkedNumber
            try
                do shell script "tmux has-session -t " & quoted form of linkedSessionName & " 2>/dev/null"
                -- Session exists, try next number
                set linkedNumber to linkedNumber + 1
            on error
                -- Session doesn't exist, use this name
                exit repeat
            end try
        end repeat

        set cmd to my buildHelperCommand("link " & quoted form of sessionName & " " & quoted form of linkedSessionName)
        my openTerminalSession(cmd)

    on error errorMessage
        if errorMessage contains "session not found" then
            display notification "Base session '" & sessionName & "' not found" with title "Tmux Error"
        else
            display notification "Failed to create linked session: " & errorMessage with title "Tmux Error"
        end if
    end try
end attachLinkedSession

on resolveTmuxPath()
    return do shell script "which tmux"
end resolveTmuxPath

on buildHelperCommand(helperArgs)
    set tmuxPath to my resolveTmuxPath()
    set helperDest to "/tmp/ats"

    -- Write helper with tmux path baked in so the terminal command stays short
    set helperContent to "#!/bin/sh
T='" & tmuxPath & "'; ACTION=\"$1\"; shift
detect_shell() { if [ -n \"$1\" ]; then printf '%s' \"$1\"; else p=$(ps -p \"$PPID\" -o args= 2>/dev/null | awk '{print $1}' | sed 's/^-//'); if [ \"${p#/}\" != \"$p\" ]; then printf '%s' \"$p\"; else r=$(command -v \"$p\" 2>/dev/null); [ -n \"$r\" ] && printf '%s' \"$r\" || printf '%s' /bin/sh; fi; fi; }
case \"$ACTION\" in
create) s=\"$1\"; d=$(detect_shell \"$2\"); \"$T\" new-session -d -s \"$s\" -c \"$HOME\" \"exec \\\"$d\\\" -l\" && \"$T\" set-option -t \"$s\" default-shell \"$d\" && { rm -f \"$0\"; exec \"$T\" attach-session -t \"$s\"; };;
link) b=\"$1\"; l=\"$2\"; d=$(detect_shell \"$3\"); \"$T\" new-session -d -t \"$b\" -s \"$l\" && \"$T\" set-option -t \"$l\" default-shell \"$d\" && { rm -f \"$0\"; exec \"$T\" attach-session -t \"$l\"; };;
attach) rm -f \"$0\"; exec \"$T\" attach-session -t \"$1\";;
esac"
    do shell script "printf '%s' " & quoted form of helperContent & " > " & helperDest & " && chmod +x " & helperDest

    set cmd to helperDest & " " & helperArgs
    set configuredShell to my getConfiguredShell()
    if configuredShell is not "auto" then
        set cmd to cmd & " " & quoted form of configuredShell
    end if
    return cmd
end buildHelperCommand

on openTerminalSession(terminalCommand)
    try
        set selectedTerminal to resolveTerminal()

        if selectedTerminal is "iTerm" then
            my openInITerm(terminalCommand)
        else if selectedTerminal is "Ghostty" then
            my openInGhostty(terminalCommand)
        else if selectedTerminal is "Terminal" then
            my openInTerminal(terminalCommand)
        else
            error "Unsupported terminal: " & selectedTerminal
        end if

    on error errorMessage
        display notification "Failed to open terminal session: " & errorMessage with title "Terminal Error"
    end try
end openTerminalSession

on openInITerm(tmuxCommand)
    try
        -- Detect whether iTerm is already running; activating a cold iTerm
        -- auto-creates a default window, so creating another would yield two.
        tell application "System Events"
            set itermRunning to (exists (processes where name is "iTerm2")) or (exists (processes where name is "iTerm"))
        end tell

        tell application "iTerm"
            activate

            if not itermRunning then
                -- iTerm just launched and auto-created a window; reuse it
                delay WINDOW_INIT_DELAY
                tell current session of current window
                    write text tmuxCommand
                end tell
            else if my isTerminalRunningAndFrontmost("iTerm") and (count of windows) > 0 then
                -- Use current window/session
                tell current session of current window
                    write text tmuxCommand
                end tell
            else
                -- iTerm running but not frontmost or no windows: create one
                set newWindow to (create window with default profile)
                delay WINDOW_INIT_DELAY
                tell current session of newWindow
                    write text tmuxCommand
                end tell
            end if
        end tell

    on error errorMessage
        display notification "Failed to open iTerm: " & errorMessage with title "iTerm Error"
    end try
end openInITerm

-- GUI scripting required due to lack of native AppleScript support
on openInGhostty(tmuxCommand)
    try
        -- Check if Ghostty is already frontmost
        set isFrontmost to my isTerminalRunningAndFrontmost("Ghostty")

        tell application "Ghostty"
            activate
        end tell

        delay GHOSTTY_APP_DELAY

        tell application "System Events"
            tell process "Ghostty"
                set windowCount to count of windows

                -- Create new window only if none exist or Ghostty wasn't frontmost
                if windowCount is 0 or not isFrontmost then
                    keystroke "n" using {command down}
                    delay GHOSTTY_WINDOW_DELAY
                end if

                keystroke tmuxCommand
                delay GHOSTTY_COMMAND_DELAY
                key code 36
            end tell
        end tell

    on error errorMessage
        display notification "Failed to open Ghostty: " & errorMessage with title "Ghostty Error"
    end try
end openInGhostty

on openInTerminal(tmuxCommand)
    try
        tell application "Terminal"
            -- Check if Terminal is already frontmost with a window
            if my isTerminalRunningAndFrontmost("Terminal") and (count of windows) > 0 then
                -- Use current window
                do script tmuxCommand in front window
            else
                -- Create new window
                activate
                do script tmuxCommand
            end if
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

(*
    Alfred Tmux Sessions - Action Handler
    
    Handles all tmux session actions triggered from Alfred with production-ready
    reliability, enhanced error handling, and user feedback.
    
    Actions:
    - attach: Opens existing session in new iTerm window (default)
    - create: Creates new session and opens it
    - delete: Removes a tmux session
    - detach: Detaches from an active session
    
    Author: Jason Satti
    License: MIT
*)

on run argv
    if (count of argv) is 0 then return
    
    try
        -- Parse the action and session name from the argument
        set argData to my parseActionArgument(item 1 of argv)
        set action to action of argData
        set sessionName to sessionName of argData
        
        if sessionName is "" then
            display notification "No session name provided" with title "Tmux Error"
            return
        end if
        
        -- Route to appropriate handler based on action
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

-- Parse "action:session" format into a record
-- Returns {action:"...", sessionName:"..."}
on parseActionArgument(arg)
    set delimiterPosition to offset of ":" in arg
    
    if delimiterPosition is 0 then
        -- No colon found, default to attach action
        return {action:"attach", sessionName:arg}
    else
        -- Extract action and session name
        set actionName to text 1 thru (delimiterPosition - 1) of arg
        set sessionName to text (delimiterPosition + 1) thru -1 of arg
        return {action:actionName, sessionName:sessionName}
    end if
end parseActionArgument

-- Delete a tmux session with precise error handling
on deleteSession(sessionName)
    try
        -- First verify the session exists
        do shell script "tmux has-session -t " & quoted form of sessionName & " 2>/dev/null"
        
        -- Session exists, attempt deletion
        try
            do shell script "tmux kill-session -t " & quoted form of sessionName
            display notification "Session '" & sessionName & "' deleted successfully" with title "Tmux"
            
            -- Reopen Alfred to show updated session list
            my reopenAlfred()
            
        on error errMsg
            display notification "Failed to delete '" & sessionName & "': " & errMsg with title "Tmux Error"
        end try
        
    on error
        -- Session doesn't exist
        display notification "Session '" & sessionName & "' not found" with title "Tmux Error"
    end try
end deleteSession

-- Detach from a tmux session with enhanced feedback
on detachSession(sessionName)
    try
        do shell script "tmux detach-client -s " & quoted form of sessionName
        display notification "Detached from session '" & sessionName & "'" with title "Tmux"
        
        -- Reopen Alfred to show updated session list
        my reopenAlfred()
        
    on error errorMessage
        -- This can fail if session doesn't exist or has no attached clients
        if errorMessage contains "no clients" then
            display notification "No clients attached to '" & sessionName & "'" with title "Tmux"
        else if errorMessage contains "session not found" then
            display notification "Session '" & sessionName & "' not found" with title "Tmux Error"
        else
            display notification "Could not detach from '" & sessionName & "'" with title "Tmux Error"
        end if
    end try
end detachSession

-- Create a new tmux session and open it
on createSession(sessionName)
    try
        -- Create session in detached state first
        do shell script "tmux new-session -d -s " & quoted form of sessionName
        display notification "Session '" & sessionName & "' created" with title "Tmux"
        
        -- Now open it in iTerm
        my openInITerm(sessionName)
        
    on error errorMessage
        if errorMessage contains "duplicate session" then
            display notification "Session '" & sessionName & "' already exists" with title "Tmux Error"
        else
            display notification "Failed to create '" & sessionName & "': " & errorMessage with title "Tmux Error"
        end if
    end try
end createSession

-- Attach to an existing tmux session
on attachSession(sessionName)
    try
        -- Verify session exists before opening iTerm
        do shell script "tmux has-session -t " & quoted form of sessionName & " 2>/dev/null"
        my openInITerm(sessionName)
    on error
        display notification "Session '" & sessionName & "' not found" with title "Tmux Error"
    end try
end attachSession

-- Open a tmux session in a new iTerm window with improved reliability
on openInITerm(sessionName)
    try
        tell application "iTerm"
            activate
            
            -- Create a new window with default profile
            set newWindow to (create window with default profile)
            
            -- Wait briefly for the window to be ready, then execute command
            delay 0.2
            
            tell current session of newWindow
                write text "tmux attach-session -t " & quoted form of sessionName
            end tell
        end tell
        
    on error errorMessage
        display notification "Failed to open iTerm: " & errorMessage with title "iTerm Error"
    end try
end openInITerm

-- Reopen Alfred with the tmux keyword to refresh the session list
on reopenAlfred()
    try
        -- Small delay to ensure the deletion completes
        delay 0.3
        
        tell application "Alfred"
            search "tmux "
        end tell
    on error errorMessage
        -- Silently ignore Alfred reopen errors to avoid disrupting the main action
    end try
end reopenAlfred
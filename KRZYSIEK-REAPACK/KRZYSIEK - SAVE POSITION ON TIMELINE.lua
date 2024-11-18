--[[
@version 1.0
--]]

-- Save current position to an extended state
function SaveTimelinePosition()
    local scriptName = "SaveTimelinePosition"  -- Specify your script name here
    local currentPosition = reaper.GetCursorPosition()
    
    if currentPosition then
        reaper.SetExtState(scriptName, "SavedPosition", tostring(currentPosition), true)

    else

    end
end

-- Run the function
SaveTimelinePosition()


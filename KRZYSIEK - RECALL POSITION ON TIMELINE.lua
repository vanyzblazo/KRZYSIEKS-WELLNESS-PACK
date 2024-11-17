-- Recall saved position from an extended state
function RecallTimelinePosition()
    local scriptName = "SaveTimelinePosition"  -- Specify your script name here
    local savedPosition = reaper.GetExtState(scriptName, "SavedPosition")
    
    if savedPosition ~= "" then
        local savedPositionNum = tonumber(savedPosition)
        if savedPositionNum then
            reaper.SetEditCurPos(savedPositionNum, true, true)

        else

        end
    else

    end
end

-- Run the function
RecallTimelinePosition()


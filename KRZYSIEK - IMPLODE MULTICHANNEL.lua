function implodeToMultichannel()
    -- Get the selected items
    local selectedItems = reaper.CountSelectedMediaItems(0)
    
    if selectedItems < 2 then
        reaper.ShowMessageBox("Please select at least two mono items.", "Error", 0)
        return
    end

    -- Create a new track for the multichannel item
    local newTrackIdx = reaper.CountTracks(0) + 1
    reaper.InsertTrackAtIndex(newTrackIdx, true)

    -- Get the next unoccupied track index
    for i = newTrackIdx, reaper.CountTracks(0) do
        local track = reaper.GetTrack(0, i - 1)
        if reaper.CountTrackMediaItems(track) == 0 then
            newTrackIdx = i
            break
        end
    end

    -- Create a new multichannel item on the new track
    local multichannelItem = reaper.AddMediaItemToTrack(reaper.GetTrack(0, newTrackIdx - 1))
    
    -- Copy each selected item to the new multichannel item
    for i = 1, selectedItems do
        local monoItem = reaper.GetSelectedMediaItem(0, i - 1)
        local monoTake = reaper.GetMediaItemTake(monoItem, 0)
        
        -- Copy source media
        local source = reaper.GetMediaItemTake_Source(monoTake)
        local newTake = reaper.AddTakeToMediaItem(multichannelItem)
        reaper.SetMediaItemTake_Source(newTake, source)
    end

    reaper.UpdateArrange()
end

-- Run the function
reaper.Undo_BeginBlock()
implodeToMultichannel()
reaper.Undo_EndBlock("Implode to Multichannel Item", -1)


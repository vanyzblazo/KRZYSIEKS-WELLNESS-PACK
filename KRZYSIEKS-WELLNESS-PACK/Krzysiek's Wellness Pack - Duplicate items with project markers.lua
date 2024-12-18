--[[
@version 0.1
--]]


function main()
    -- Get count of selected items
    local num_selected = reaper.CountSelectedMediaItems(0)
    if num_selected == 0 then
        reaper.ShowMessageBox("Please select at least one item", "Error", 0)
        return
    end

    -- Store original items' positions and lengths
    local original_items = {}
    for i = 0, num_selected - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        table.insert(original_items, {
            item = item,
            position = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
            length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        })
    end

    -- Begin undo block
    reaper.Undo_BeginBlock()

    -- Duplicate the items
    reaper.Main_OnCommand(41296, 0) -- Duplicate items
    
    -- Get the duplicated items
    local new_items = {}
    for i = 0, num_selected - 1 do
        local new_item = reaper.GetSelectedMediaItem(0, i)
        table.insert(new_items, {
            item = new_item,
            position = reaper.GetMediaItemInfo_Value(new_item, "D_POSITION")
        })
    end

    -- Process each original item and its corresponding duplicate
    for i, orig_data in ipairs(original_items) do
        local orig_pos = orig_data.position
        local orig_end = orig_pos + orig_data.length
        local new_pos = new_items[i].position

        -- Find and duplicate overlapping markers
        local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
        
        for j = 0, num_markers + num_regions - 1 do
            local retval, isrgn, marker_pos, region_end, name, markrgnindexnumber = reaper.EnumProjectMarkers(j)
            
            
            -- Check if it's a marker (not a region) and if it overlaps with the original item
            if retval and not isrgn and marker_pos >= orig_pos and marker_pos <= orig_end then
                -- Calculate relative position and create new marker
                local relative_pos = marker_pos - orig_pos
                local new_marker_pos = new_pos + relative_pos
                
                -- Add new marker at the calculated position
                reaper.AddProjectMarker(0, false, new_marker_pos, 0, name, -1)
            end
        end
    end

    -- End undo block
    reaper.Undo_EndBlock("Duplicate items with markers", -1)
end

reaper.PreventUIRefresh(1)
main()
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()

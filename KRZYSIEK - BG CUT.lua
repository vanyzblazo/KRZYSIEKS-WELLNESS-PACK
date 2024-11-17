local items = {}
local start_time
local end_timeb
local num_selected_items = reaper.CountSelectedMediaItems(0)

for i = 0, num_selected_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    reaper.SetMediaItemInfo_Value(item, "B_LOOPSRC", 0)
    table.insert(items, item)
    
end


for i, item in ipairs(items) do

    local track = reaper.GetMediaItem_Track(item)
    local retval, track_name = reaper.GetTrackName(track)
    local s_track_name = tostring(track_name)
    
    
    if string.find(s_track_name, "SCN_CUT_TRACK") then
    
      start_time = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

      end_time = start_time + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  
    end
end

for i, item in ipairs(items) do

    local track = reaper.GetMediaItem_Track(item)
    local track_name = reaper.GetTrackName(track)
    local s_track_name = tostring(track_name)

    if string.find(s_track_name, "SCN_CUT_TRACK") then
    
    else
        --reaper.ShowConsoleMsg(start_time)
        local fade_time = reaper.GetMediaItemInfo_Value(item, "D_FADEINLEN")
        fade_time = tonumber(0.08)
        

        reaper.SetMediaItemInfo_Value(item, "D_POSITION", start_time - 0.04)
        reaper.SetMediaItemInfo_Value(item, "D_LENGTH", end_time - start_time + 0.08)
        reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", fade_time)
        reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", fade_time)
    end
end

for i, item in ipairs(items) do

    local track = reaper.GetMediaItem_Track(item)
    local retval, track_name = reaper.GetTrackName(track)
    local s_track_name = tostring(track_name)
    
    
    if string.find(s_track_name, "SCN_CUT_TRACK") then
    
        reaper.SetMediaItemInfo_Value(item, "D_POSITION", start_time)
        reaper.SetMediaItemInfo_Value(item, "D_LENGTH", end_time - start_time)
        reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", 0.0)
        reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", 0.0)
  
    end
end


reaper.UpdateArrange()


item = reaper.GetSelectedMediaItem(0, 1)
retval = reaper.TimeMap_curFrameRate(ReaProject)
local d = twoFrame
local d = frameTime
frameTime = 1/retval
twoFrame = 2*frameTime
reaper.Main_OnCommand(41173, 0) -- move cursor to start of items
position = reaper.GetCursorPosition()
reaper.SetEditCurPos(position - frameTime, 1, 0)
reaper.Main_OnCommand(41305, 0) -- trim to left
reaper.Main_OnCommand(41174, 0) -- move edit to end
position = reaper.GetCursorPosition()
reaper.SetEditCurPos(position + frameTime, 1, 0)
reaper.Main_OnCommand(41311, 0) -- trim to right

item_count = reaper.CountSelectedMediaItems(0)
if item_count ~= nil then 
  for i = 1, item_count do
    item = reaper.GetSelectedMediaItem(0, i-1)
   
    if item ~= nil then 
      reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", twoFrame)   
      reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN",twoFrame) 
    end
  end 
end



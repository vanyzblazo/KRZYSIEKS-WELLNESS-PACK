--[[
@version 1.0
--]]
local rate = reaper.Master_GetPlayRate()

reaper.Undo_BeginBlock()

if rate == 1.2
then
  reaper.CSurf_OnPlayRateChange(0.9)
else
  reaper.CSurf_OnPlayRateChange(1.2)
end
reaper.Undo_EndBlock('Toggle master playrate', 2)

-- Created by Krzysiek Chodkiewicz --

reaper.Main_OnCommand(41173, 0) -- move cursor to start of items

time = 5000 -- time (ms)


delta = time/1000
position = reaper.GetCursorPosition()
reaper.SetEditCurPos(position - delta, 1, 0)


reaper.Main_OnCommand(41305, 0) -- trim to left
reaper.Main_OnCommand(41174, 0) -- move edit to end


delta = time/1000
position = reaper.GetCursorPosition()
reaper.SetEditCurPos(position + delta, 1, 0)



reaper.Main_OnCommand(41311, 0) -- trim to right 
reaper.Main_OnCommand(40362, 0) -- glue ignorin time
reaper.Main_OnCommand(40508, 0) -- trim to selected area

reaper.SetEditCurPos(position, 1, 0) -- back to start position



-- Ensure REAPER is running with the required API version
reaper.ClearConsole()

-- Function to solo tracks with selected items
function SoloTracksWithSelectedItems()
    local num_items = reaper.CountSelectedMediaItems(0)
    local tracks = {}
    
    for i = 0, num_items - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local track = reaper.GetMediaItem_Track(item)
        tracks[track] = true
    end
    
    for track, _ in pairs(tracks) do
        reaper.SetMediaTrackInfo_Value(track, "I_SOLO", 1)
    end
end

-- Function to generate a unique render file name
function GenerateUniqueRenderPath()
    local project_path = reaper.GetProjectPath(0, "")
    local project_name_with_ext = reaper.GetProjectName(0, "")
    local project_name = project_name_with_ext:match("(.+)%..+$") or project_name_with_ext
    
    local date_time = os.date("%Y%m%d_%H%M%S")
    local render_name = project_name .. "_render_" .. date_time .. ".wav"
    local render_path = project_path .. "/" .. render_name
    
    return render_path
end

-- Function to set render bounds to time selection
function SetRenderBoundsToTimeSelection()
    local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    reaper.GetSetProjectInfo(0, "RENDER_STARTPOS", start_time, true)
    reaper.GetSetProjectInfo(0, "RENDER_ENDPOS", end_time, true)
end

-- Function to save current render settings
function SaveRenderSettings()
    local settings = {}
    settings.RENDER_FILE = {reaper.GetSetProjectInfo_String(0, "RENDER_FILE", "", false)}
    settings.RENDER_PATTERN = {reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "", false)}
    settings.RENDER_FORMAT = reaper.GetSetProjectInfo(0, "RENDER_FORMAT", 0, false)
    settings.RENDER_SRATE = reaper.GetSetProjectInfo(0, "RENDER_SRATE", 0, false)
    settings.RENDER_CHANNELS = reaper.GetSetProjectInfo(0, "RENDER_CHANNELS", 0, false)
    settings.RENDER_ADDTOPROJ = reaper.GetSetProjectInfo(0, "RENDER_ADDTOPROJ", 0, false)
    settings.RENDER_TAILFLAG = reaper.GetSetProjectInfo(0, "RENDER_TAILFLAG", 0, false)
    settings.RENDER_BOUNDSFLAG = reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 0, false)
    settings.RENDER_DITHER = reaper.GetSetProjectInfo(0, "RENDER_DITHER", 0, false)
    settings.RENDER_FXTAILMS = reaper.GetSetProjectInfo(0, "RENDER_FXTAILMS", 0, false)
    settings.RENDER_PREFX = reaper.GetSetProjectInfo(0, "RENDER_PREFX", 0, false)
    settings.RENDER_STEMS = reaper.GetSetProjectInfo(0, "RENDER_STEMS", 0, false)
    settings.RENDER_SETTINGS = reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", 0, false)
    settings.RENDER_STARTPOS = reaper.GetSetProjectInfo(0, "RENDER_STARTPOS", 0, false)
    settings.RENDER_ENDPOS = reaper.GetSetProjectInfo(0, "RENDER_ENDPOS", 0, false)
    return settings
end

-- Function to restore saved render settings
function RestoreRenderSettings(settings)
    reaper.GetSetProjectInfo_String(0, "RENDER_FILE", settings.RENDER_FILE[2], true)
    reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", settings.RENDER_PATTERN[2], true)
    reaper.GetSetProjectInfo(0, "RENDER_FORMAT", settings.RENDER_FORMAT, true)
    reaper.GetSetProjectInfo(0, "RENDER_SRATE", settings.RENDER_SRATE, true)
    reaper.GetSetProjectInfo(0, "RENDER_CHANNELS", settings.RENDER_CHANNELS, true)
    reaper.GetSetProjectInfo(0, "RENDER_ADDTOPROJ", settings.RENDER_ADDTOPROJ, true)
    reaper.GetSetProjectInfo(0, "RENDER_TAILFLAG", settings.RENDER_TAILFLAG, true)
    reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", settings.RENDER_BOUNDSFLAG, true)
    reaper.GetSetProjectInfo(0, "RENDER_DITHER", settings.RENDER_DITHER, true)
    reaper.GetSetProjectInfo(0, "RENDER_FXTAILMS", settings.RENDER_FXTAILMS, true)
    reaper.GetSetProjectInfo(0, "RENDER_PREFX", settings.RENDER_PREFX, true)
    reaper.GetSetProjectInfo(0, "RENDER_STEMS", settings.RENDER_STEMS, true)
    reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", settings.RENDER_SETTINGS, true)
    reaper.GetSetProjectInfo(0, "RENDER_STARTPOS", settings.RENDER_STARTPOS, true)
    reaper.GetSetProjectInfo(0, "RENDER_ENDPOS", settings.RENDER_ENDPOS, true)
end

-- Function to determine if all selected items are mono and have no panning
function AreAllSelectedItemsMono()
    local num_items = reaper.CountSelectedMediaItems(0)
    for i = 0, num_items - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        if take then
            local src = reaper.GetMediaItemTake_Source(take)
            local num_channels = reaper.GetMediaSourceNumChannels(src)
            local take_channel_mode = reaper.GetMediaItemTakeInfo_Value(take, "I_CHANMODE")
            local take_pan = reaper.GetMediaItemTakeInfo_Value(take, "D_PAN")
            if num_channels ~= 1 and take_channel_mode ~= 3 and take_channel_mode ~= 4 then -- check for mono channel mode (3 and 4 are mono modes)
                return false
            end
            if take_pan ~= 0 then
                return false
            end
        end
        local pan = reaper.GetMediaItemInfo_Value(item, "D_PAN")
        if pan ~= 0 then
            return false
        end
    end
    return true
end

-- Function to get the highest channel count from routed tracks, including folder tracks
function GetHighestChannelCount(tracks)
    local max_channels = 2
    local visited_tracks = {}
    
    local function get_track_channel_count(track)
        if visited_tracks[track] then return end
        visited_tracks[track] = true
        
        local num_channels = reaper.GetMediaTrackInfo_Value(track, "I_NCHAN")

        if num_channels > max_channels then
            max_channels = num_channels
        end
        
        local parent_track = reaper.GetParentTrack(track)
        if parent_track then
            get_track_channel_count(parent_track)
        end
    end
    
    for track, _ in pairs(tracks) do
        get_track_channel_count(track)
    end
    
    return max_channels
end

-- Function to create and configure a virtual bus track
function CreateVirtualBus()
    local num_tracks = reaper.CountTracks(0)
    reaper.InsertTrackAtIndex(num_tracks, false)
    local bus_track = reaper.GetTrack(0, num_tracks)
    reaper.GetSetMediaTrackInfo_String(bus_track, "P_NAME", "Virtual Bus", true)
    return bus_track
end

-- Function to route all group tracks to the virtual bus
function RouteGroupTracksToBus(group_tracks, bus_track)
    for track, _ in pairs(group_tracks) do
        local num_channels = reaper.GetMediaTrackInfo_Value(track, "I_NCHAN")
        local send_id = reaper.CreateTrackSend(track, bus_track)
        reaper.SetTrackSendInfo_Value(track, 0, send_id, "I_SRCCHAN", (num_channels - 1) * 1024) -- Correct channel count
        reaper.SetTrackSendInfo_Value(track, 0, send_id, "I_DSTCHAN", 0) -- Start at channel 0
    end
end

-- Function to render the time selection with the appropriate channel count
function RenderTimeSelection(channel_count)
    local render_path = GenerateUniqueRenderPath()
    local render_directory = render_path:match("(.*/)")
    local render_file = render_path:match(".*/(.*)")
    
    -- Get current project sample rate
    local sample_rate = reaper.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
    
    -- Set render settings explicitly
    reaper.GetSetProjectInfo_String(0, "RENDER_FILE", render_directory, true)
    reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", render_file, true)
    reaper.GetSetProjectInfo(0, "RENDER_FORMAT", 0, true) -- WAV
    reaper.GetSetProjectInfo(0, "RENDER_SRATE", sample_rate, true) -- Project sample rate
    reaper.GetSetProjectInfo(0, "RENDER_CHANNELS", channel_count, true) -- Channel count
    reaper.GetSetProjectInfo(0, "RENDER_ADDTOPROJ", 0, true) -- Do not add to project
    reaper.GetSetProjectInfo(0, "RENDER_TAILFLAG", 0, true) -- No tail
    reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 0, true) -- Custom time bounds
    reaper.GetSetProjectInfo(0, "RENDER_DITHER", 0, true) -- No dither
    reaper.GetSetProjectInfo(0, "RENDER_FXTAILMS", 0, true) -- No tail length
    reaper.GetSetProjectInfo(0, "RENDER_PREFX", 0, true) -- Post-fader (post-FX)
    reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", 3, true) -- Selected tracks (stems)
    
    SetRenderBoundsToTimeSelection()
    
    -- Perform the render using the most recent render settings
    reaper.Main_OnCommand(41824, 0)  -- File: Render project, using the most recent render settings
    
    return render_path
end

-- Function to check if a track is available within the time selection
function IsTrackAvailable(track, start_time, end_time)
    local num_items = reaper.CountTrackMediaItems(track)
    for j = 0, num_items - 1 do
        local item = reaper.GetTrackMediaItem(track, j)
        local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        
        if (item_start < end_time) and (item_end > start_time) then
            return false
        end
    end
    return true
end

-- Function to find the closest available track
function FindClosestAvailableTrack(start_time, end_time, selected_tracks, avoid_last_track)
    local num_tracks = reaper.CountTracks(0)
    local min_distance = math.huge
    local best_track = nil

    for i = 0, num_tracks - 1 do
        local track = reaper.GetTrack(0, i)
        if avoid_last_track and i == num_tracks - 1 then
            goto continue
        end
        if IsTrackAvailable(track, start_time, end_time) then
            local distance = math.huge
            for selected_track, _ in pairs(selected_tracks) do
                local selected_track_index = reaper.GetMediaTrackInfo_Value(selected_track, "IP_TRACKNUMBER") - 1
                local current_distance = math.abs(i - selected_track_index)
                if current_distance < distance then
                    distance = current_distance
                end
            end
            if distance < min_distance then
                min_distance = distance
                best_track = track
            end
        end
        ::continue::
    end

    if best_track == nil then
        reaper.InsertTrackAtIndex(num_tracks, false)
        best_track = reaper.GetTrack(0, num_tracks)
    end

    return best_track
end

-- Function to import the rendered item to the closest available track
function ImportRenderedItem(render_path, selected_tracks, avoid_last_track)
    local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    local track = FindClosestAvailableTrack(start_time, end_time, selected_tracks, avoid_last_track)

    reaper.PreventUIRefresh(1)
    reaper.SetOnlyTrackSelected(track)
    reaper.InsertMedia(render_path, 0) -- Add to the selected track
    local new_item = reaper.GetSelectedMediaItem(0, 0)
    if new_item then
        reaper.SetMediaItemPosition(new_item, start_time, false)
    end
    reaper.PreventUIRefresh(-1)
    reaper.SetTrackSelected(track, true)
end

-- Main execution
reaper.Undo_BeginBlock()

local saved_settings = SaveRenderSettings()

reaper.Main_OnCommand(40290, 0) -- Set time selection to selected items

local selected_tracks = {}
local num_items = reaper.CountSelectedMediaItems(0)
for i = 0, num_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local track = reaper.GetMediaItem_Track(item)
    selected_tracks[track] = true
end

-- Get group tracks for the selected tracks
local group_tracks = {}
for track, _ in pairs(selected_tracks) do
    local parent_track = reaper.GetParentTrack(track)
    if parent_track then
        group_tracks[parent_track] = true
    else
        group_tracks[track] = true
    end
end

local channel_count = 2 -- Default to stereo
if AreAllSelectedItemsMono() then
    channel_count = 1
else
    channel_count = GetHighestChannelCount(group_tracks)
end

SoloTracksWithSelectedItems()

local bus_track = CreateVirtualBus()
RouteGroupTracksToBus(group_tracks, bus_track)
reaper.SetMediaTrackInfo_Value(bus_track, "I_NCHAN", channel_count)

reaper.SetOnlyTrackSelected(bus_track) -- Select the virtual bus track before rendering

local render_path = RenderTimeSelection(channel_count)
ImportRenderedItem(render_path, selected_tracks, true) -- Avoid the last track if necessary

reaper.Main_OnCommand(40340, 0) -- Unsolo all tracks
reaper.DeleteTrack(bus_track)
RestoreRenderSettings(saved_settings)

reaper.Undo_EndBlock("Render and Import Selected Items", -1)

reaper.UpdateArrange()


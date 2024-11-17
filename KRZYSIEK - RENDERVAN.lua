ultraschall_path = reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua"
if reaper.file_exists( ultraschall_path ) then
  dofile( ultraschall_path )
end

if not ultraschall or not ultraschall.GetApiVersion then
  reaper.MB("Please install Ultraschall API, available via Reapack.", "Error", 0)
  return
end

-- Style Manager Definition
local StyleManager = {
    push_count = 0,
    style = {
        vars = {
            [reaper.ImGui_StyleVar_WindowRounding()] = 10,
            [reaper.ImGui_StyleVar_FramePadding()] = {4, 10}
        },
        colors = {
            [reaper.ImGui_Col_WindowBg()] = 0x333333FF,
            [reaper.ImGui_Col_Text()] = 0xEDEDEDFF,
            [reaper.ImGui_Col_FrameBg()] = 0x4C4C4CFF,
            [reaper.ImGui_Col_ChildBg()] = 0x3B3B3BFF,
            [reaper.ImGui_Col_TitleBg()] = 0x3BA195FF,
            [reaper.ImGui_Col_TitleBgActive()] = 0x3BA195FF,
            [reaper.ImGui_Col_TitleBgCollapsed()] = 0x3BA195FF,
            [reaper.ImGui_Col_Button()] = 0x0FA68AFF,
            [reaper.ImGui_Col_ButtonHovered()] = 0x0E9980FF,
            [reaper.ImGui_Col_ButtonActive()] = 0x128C76FF,
            [reaper.ImGui_Col_Header()] = 0x128C76FF,
            [reaper.ImGui_Col_HeaderHovered()] = 0x0E9980FF,
            [reaper.ImGui_Col_HeaderActive()] = 0x128C76FF,
            [reaper.ImGui_Col_FrameBgHovered()] = 0x414342FF,
            [reaper.ImGui_Col_SliderGrab()] = 0x0FA68AFF,
            [reaper.ImGui_Col_SliderGrabActive()] = 0x0FA68AFF,
            [reaper.ImGui_Col_FrameBgActive()] = 0x0D6B66FF,
            [reaper.ImGui_Col_CheckMark()] = 0x0FA68AFF
        },
        dynamic_colors = {
            selected = 0x128C76FF,
            second_pass = 0x800080FF
        }
    }
}

function StyleManager.PushStyle(ctx)
    StyleManager.push_count = StyleManager.push_count + 1
   
    for var, value in pairs(StyleManager.style.vars) do
        if type(value) == 'table' then
            reaper.ImGui_PushStyleVar(ctx, var, table.unpack(value))
        else
            reaper.ImGui_PushStyleVar(ctx, var, value)
        end
    end
   
    for col, value in pairs(StyleManager.style.colors) do
        reaper.ImGui_PushStyleColor(ctx, col, value)
    end
end

function StyleManager.PopStyle(ctx)
    if StyleManager.push_count > 0 then
        StyleManager.push_count = StyleManager.push_count - 1
        reaper.ImGui_PopStyleColor(ctx, #table.keys(StyleManager.style.colors))
        reaper.ImGui_PopStyleVar(ctx, #table.keys(StyleManager.style.vars))
    end
end

function StyleManager.PushDynamicColors(ctx, colors)
    for col, value in pairs(colors) do
        reaper.ImGui_PushStyleColor(ctx, col, value)
    end
    return #colors -- Return number of colors pushed for proper popping
end

function table.keys(t)
    local keys = {}
    for k, _ in pairs(t) do
        table.insert(keys, k)
    end
    return keys
end

-- Initialize ImGui context
local ctx = reaper.ImGui_CreateContext('Region Creator')
if not ctx then
    reaper.ShowMessageBox("Please install ImGUI for REAPER via Reapack.", "Error", 0)
    return
end

local visible = true
local items, types, prefixes = {}, {}, {}
local selectedTypeIndex = 1
local additionalInputs = {}
local filterText = ""
local first_open = true
local soundName = ""
local prefixSelected = false
local folder_items = {} -- Store folder items for batch channel input
local render_queue = {}
local active_render_flags = {} -- Store active render flags as {region_index = {track_guid = flag}}
local last_project_change_count = 0

local selected_items = {}
local is_dragging = false
local drag_start_pos = nil
local drag_end_pos = nil
local drag_started_from_selected = false
local selectedFilteredIndex = 1

local show_channel_input_popup = false
local num_channels = ""
local finalPrefix = "" -- Make sure finalPrefix is defined globally
local region_folder_map = {} -- Data structure to track folder items and regions
local track_folder_map = {} -- Data structure to track folder items and tracks

local secondPassColor = 0x800080FF -- Purple for second pass


-- Render settings variables
local use_additional_render_path = false
local additional_render_path = ""
local render_bitdepths = {"8 bit", "16 bit", "24 bit", "32 bit"}
local selected_bitdepth_index = 2 -- Default to 16
local render_sample_rates = {"32 kHz", "44 kHz", "48 kHz", "88 kHz", "96 kHz", "192 kHz"}
local selected_sample_rate_index = 3 -- Default to 48 kHz

-- Normalization settings variables
local normalize_render = false
local normalization_settings = 0
local normalization_volume = 0.0 -- Default volume for normalization
local normalization_types = {"LUFS-I", "RMS", "Peak", "True Peak", "LUFS-M Max", "LUFS-S Max"}
local normalization_flags = {
    ["LUFS-I"] = 0,
    ["RMS"] = 2,
    ["Peak"] = 4,
    ["True Peak"] = 6,
    ["LUFS-M Max"] = 8,
    ["LUFS-S Max"] = 10
}
local selected_normalization_index = 1 -- Default to LUFS-I

-- Brickwall limiter settings
local use_brickwall_limiter = false
local brickwall_limit_threshold_db = -0.1 -- Default to -0.1 dB
local brickwall_limiter_types = {"Peak", "True Peak"}
local selected_brickwall_limiter_index = 1 -- Default to Peak

local settings_file_path = reaper.GetResourcePath() .. '/Scripts/RenderSettings.csv'

-- Convert dB to amplitude
function dBToAmplitude(dB)
    return 10^(dB / 20)
end


-------------------------------------------------------------------------
------------------------SAVE SETTINGS TO CSV-----------------------------
-------------------------------------------------------------------------

function SaveSettingsToCSV()
    local file = io.open(settings_file_path, 'w')
    if file then
        file:write("use_additional_render_path,", tostring(use_additional_render_path), "\n")
        file:write("additional_render_path,", additional_render_path, "\n")
        file:write("selected_bitdepth_index,", tostring(selected_bitdepth_index), "\n")
        file:write("selected_sample_rate_index,", tostring(selected_sample_rate_index), "\n")
        file:write("normalize_render,", tostring(normalize_render), "\n")
        file:write("normalization_volume,", tostring(normalization_volume), "\n")
        file:write("selected_normalization_index,", tostring(selected_normalization_index), "\n")
        file:write("use_brickwall_limiter,", tostring(use_brickwall_limiter), "\n")
        file:write("brickwall_limit_threshold_db,", tostring(brickwall_limit_threshold_db), "\n")
        file:write("selected_brickwall_limiter_index,", tostring(selected_brickwall_limiter_index), "\n")
        file:close()
    end
end

-------------------------------------------------------------------------
-----------------------LOAD SETTINGS FROM CSV----------------------------
-------------------------------------------------------------------------

function LoadSettingsFromCSV()
    local file = io.open(settings_file_path, 'r')
    if file then
        for line in file:lines() do
            local key, value = line:match("([^,]+),([^,]+)")
            if key and value then
                if key == "use_additional_render_path" then
                    use_additional_render_path = (value == "true")
                elseif key == "additional_render_path" then
                    additional_render_path = value
                elseif key == "selected_bitdepth_index" then
                    selected_bitdepth_index = tonumber(value)
                elseif key == "selected_sample_rate_index" then
                    selected_sample_rate_index = tonumber(value)
                elseif key == "normalize_render" then
                    normalize_render = (value == "true")
                elseif key == "normalization_volume" then
                    normalization_volume = tonumber(value)
                elseif key == "selected_normalization_index" then
                    selected_normalization_index = tonumber(value)
                elseif key == "use_brickwall_limiter" then
                    use_brickwall_limiter = (value == "true")
                elseif key == "brickwall_limit_threshold_db" then
                    brickwall_limit_threshold_db = tonumber(value)
                elseif key == "selected_brickwall_limiter_index" then
                    selected_brickwall_limiter_index = tonumber(value)
                end
            end
        end
        file:close()
    end
end

-------------------------------------------------------------------------
------------------------SAVE AND RESTORE RENDER SETTINGS------------------
-------------------------------------------------------------------------

local original_render_settings = {}

function saveRenderSettings()
    original_render_settings = {
        render_file = {reaper.GetSetProjectInfo_String(0, "RENDER_FILE", "", false)},
        render_pattern = {reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "", false)},
        render_srate = reaper.GetSetProjectInfo(0, "RENDER_SRATE", 0, false),
        render_format = {reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", "", false)},
        render_settings = reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", 0, false),
        render_normalize = reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE", 0, false),
        render_normalize_target = reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE_TARGET", 0, false),
        render_brickwall = reaper.GetSetProjectInfo(0, "RENDER_BRICKWALL", 0, false),
        render_boundsflag = reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 0, false),
        render_tail = reaper.GetSetProjectInfo(0, "RENDER_TAILFLAG", 0, false)
    }
end

function restoreRenderSettings()
    reaper.GetSetProjectInfo_String(0, "RENDER_FILE", original_render_settings.render_file[2], true)
    reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", original_render_settings.render_pattern[2], true)
    reaper.GetSetProjectInfo(0, "RENDER_SRATE", original_render_settings.render_srate, true)
    reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", original_render_settings.render_format[2], true)
    reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", original_render_settings.render_settings, true)
    reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE", original_render_settings.render_normalize, true)
    reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE_TARGET", original_render_settings.render_normalize_target, true)
    reaper.GetSetProjectInfo(0, "RENDER_BRICKWALL", original_render_settings.render_brickwall, true)
    reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", original_render_settings.render_boundsflag, true)
    reaper.GetSetProjectInfo(0, "RENDER_TAILFLAG", original_render_settings.render_tail, true)
   
end

-------------------------------------------------------------------------
------------------------GET TOP MOST FOLDER TRACK------------------------
-------------------------------------------------------------------------

function getTopMostFolderTrack(track)
    local parentTrack = track
    while true do
        local parent = reaper.GetParentTrack(parentTrack)
        if not parent then break end
        parentTrack = parent
    end

    if reaper.GetMediaTrackInfo_Value(parentTrack, "I_FOLDERDEPTH") > 0 then
        return parentTrack
    else
        return nil
    end
end

-------------------------------------------------------------------------
-----------------------------CREATE REGIONS------------------------------
-------------------------------------------------------------------------

function createRegions(base_name)
    local items = {}
    local num_selected_items = reaper.CountSelectedMediaItems(0)
   
    -- Iterate through all selected items
    for i = 0, num_selected_items - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        table.insert(items, item)
    end

    local parent_sets = {}

    -- Split items into sets based on track parentage
    for _, item in ipairs(items) do
        local track = reaper.GetMediaItem_Track(item)
        local parent_track = getTopMostFolderTrack(track)

        if not parent_track then
            reaper.MB("Selected item(s) do not have parent tracks. Please ensure all items belong to a track within a folder.", "Error", 0)
            return
        end

        if not parent_sets[parent_track] then
            parent_sets[parent_track] = {}
        end

        table.insert(parent_sets[parent_track], item)
    end

    -- Iterate through each parent set
    for parent_track, items in pairs(parent_sets) do
        -- Sort items by their position within each parent set
        table.sort(items, function(a, b)
            return reaper.GetMediaItemInfo_Value(a, "D_POSITION") < reaper.GetMediaItemInfo_Value(b, "D_POSITION")
        end)

        local current_stack = {}
        local current_stack_end = 0

        for _, item in ipairs(items) do
            local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

            if item_start >= current_stack_end then
                -- Create region for the previous stack
                if #current_stack > 0 then
                    local stack_start = reaper.GetMediaItemInfo_Value(current_stack[1], "D_POSITION")
                    local stack_end = current_stack_end
                    local variation_suffix = findNextAvailableVariationNumber(base_name)
                    local region_name = base_name .. variation_suffix
                    reaper.AddProjectMarker2(0, true, stack_start, stack_end, region_name, -1, 0)
                    createFolderItem(stack_start, stack_end, region_name, parent_track)
                    current_stack = {}
                    current_stack_end = 0
                end
                table.insert(current_stack, item)
                current_stack_end = item_end
            else
                table.insert(current_stack, item)
                current_stack_end = math.max(current_stack_end, item_end)
            end
        end

        -- Create region for the remaining items in the current stack
        if #current_stack > 0 then
            local stack_start = reaper.GetMediaItemInfo_Value(current_stack[1], "D_POSITION")
            local stack_end = current_stack_end
            local variation_suffix = findNextAvailableVariationNumber(base_name)
            local region_name = base_name .. variation_suffix
            reaper.AddProjectMarker2(0, true, stack_start, stack_end, region_name, -1, 0)
            createFolderItem(stack_start, stack_end, region_name, parent_track)
        end
    end

    -- Detect folder items and regions after creation
    detectFolderItemsAndRegions()
end

-------------------------------------------------------------------------
---------------------------CREATE FOLDER ITEMS---------------------------
-------------------------------------------------------------------------

function createFolderItem(start_pos, end_pos, region_name, parent_track)
    local folder_item = reaper.AddMediaItemToTrack(parent_track)
    reaper.SetMediaItemInfo_Value(folder_item, "D_POSITION", start_pos)
    reaper.SetMediaItemInfo_Value(folder_item, "D_LENGTH", end_pos - start_pos)
    local take = reaper.AddTakeToMediaItem(folder_item)
    reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", region_name, true)
    reaper.ULT_SetMediaItemNote(folder_item, "RENDER ITEM" .. " " .. "CH: " .. tostring(num_channels)) -- Set the number of channels in the item note
end

-------------------------------------------------------------------------
--------------------------UPDATE RENDER QUEUE----------------------------
-------------------------------------------------------------------------

function updateRenderQueue()
    -- Clear the current render queue
    render_queue = {}

    -- Iterate through the selected items and queue them for rendering
    for item, properties in pairs(selected_items) do
        local track = reaper.GetMediaItem_Track(item)
        local folder_track = getTopMostFolderTrack(track)
        if folder_track and folder_track == track then
            local region_name = reaper.GetTakeName(reaper.GetActiveTake(item))
            local note = reaper.ULT_GetMediaItemNote(item)
            local num_channels = tonumber(note:match("CH: (%d+)")) or 2 -- Ensure default to 2 if note is not a number

            -- Check if the region is already in the render queue to avoid duplicates
            local already_in_queue = false
            for _, render_item in ipairs(render_queue) do
                if render_item.region_name == region_name then
                    already_in_queue = true
                    break
                end
            end

            if not already_in_queue then
                selected_items[item].num_channels = num_channels -- Set num_channels in selected_items
                table.insert(render_queue, {
                    region_name = region_name,
                    track = track,
                    num_channels = num_channels,
                    second_pass = properties.second_pass or false
                })
            end
        end
    end
end


-------------------------------------------------------------------------
------------------------RENDER QUEUED REGIONS----------------------------
-------------------------------------------------------------------------

function renderQueuedRegions()
    if not next(selected_items) then
        return -- Return early if there are no selected items
    end

    saveRenderSettings()

    local function setRenderParameters()
        -- Render Tail
        reaper.GetSetProjectInfo(0, "RENDER_TAILFLAG", 0, true)
        -- Sample rate
        reaper.GetSetProjectInfo(0, "RENDER_SRATE", 1000 * tonumber(render_sample_rates[selected_sample_rate_index]:match("%d+")), true)
        -- Bitdepth
        local render_cfg_string = ultraschall.CreateRenderCFG_WAV(selected_bitdepth_index - 1, 1, 0, 0, false)
        reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", render_cfg_string, true)
        -- Normalization
        if normalize_render then
            normalization_settings = normalization_settings | 1  -- Enable normalization
            -- Clear bits 1, 2, and 3
            normalization_settings = normalization_settings & ~14
            -- Set normalization type
            local normalization_type = normalization_types[selected_normalization_index]
            local normalization_flag = normalization_flags[normalization_type]
            normalization_settings = normalization_settings | normalization_flag
           
            -- Apply normalization settings
            reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE", normalization_settings, true)
            -- Convert dB to amplitude for normalization target
            local normalization_target_amplitude = dBToAmplitude(normalization_volume)
            reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE_TARGET", normalization_target_amplitude, true)
        else
            -- Disable normalization
            reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE", 0, true)
        end
       
        -- Limiter
        if use_brickwall_limiter then
            -- Enable brickwall limit
            local normalization_settings = reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE", 0, false)
            normalization_settings = normalization_settings | 64 -- Enable brickwall limit
            if selected_brickwall_limiter_index == 2 then -- True Peak
                normalization_settings = normalization_settings | 128 -- Brickwall limit true peak
            else
                normalization_settings = normalization_settings & ~128 -- Disable brickwall limit true peak
            end
            reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE", normalization_settings, true)
           
            -- Set the brickwall limiter threshold in dB
            local brickwall_limit_threshold_amplitude = dBToAmplitude(brickwall_limit_threshold_db)
            reaper.GetSetProjectInfo(0, "RENDER_BRICKWALL", brickwall_limit_threshold_amplitude, true)
        else
            -- Disable brickwall limit
            local normalization_settings = reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE", 0, false)
            normalization_settings = normalization_settings & ~64 -- Disable brickwall limit
            normalization_settings = normalization_settings & ~128 -- Disable brickwall limit true peak
            reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE", normalization_settings, true)
        end
    end

    local function executeRender(render_path, second_pass)
        reaper.GetSetProjectInfo_String(0, "RENDER_FILE", render_path, true)
        reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "$region", true)
       
        local render_settings = 8 -- Enable render matrix
        if second_pass then
            render_settings = render_settings | 2048 -- Enable second pass render
        end
        reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", render_settings, true)
       
        -- Clear previous active_render_flags array not sure if necessary
        active_render_flags = {}

        -- Set render flags for each item in the render queue
        for _, render_info in ipairs(render_queue) do
            if render_info.second_pass == second_pass then
                local region_idx = findRegionIndexByName(render_info.region_name) -- Function to match region names to indices
                if region_idx then
                    local flag = render_info.num_channels * 2
                   
                    -- Store the flag in our tracking array
                    if not active_render_flags[region_idx] then
                        active_render_flags[region_idx] = {}
                    end
                   
                    active_render_flags[region_idx][render_info.track] = flag
                    reaper.SetRegionRenderMatrix(0, region_idx, render_info.track, flag)
                end
            end
        end

        -- Render the project using current render settings
        reaper.Main_OnCommand(41824, 0) -- Execute render command
       
        clearTrackedRenderFlags()
        -- clearAllRegionRenderFlags() -- Clear flags after rendering
    end

    local project_path = reaper.GetProjectPath()
    local suffix = "Audio Files"
    if project_path:sub(-#suffix) == suffix then
        project_path = project_path:sub(1, -#suffix - 1)
    end
    local render_directory = project_path .. "Render"

    setRenderParameters()
   
    local anySecondPassItems = false
    local anyRegularItems = false
    for _, render_info in ipairs(render_queue) do
        if render_info.second_pass then
            anySecondPassItems = true
        else
            anyRegularItems = true
        end
    end

    if anyRegularItems then
        executeRender(render_directory, false)
    end
   
    if anySecondPassItems then
        executeRender(render_directory, true)
    end
   
    if use_additional_render_path and additional_render_path ~= "" then
        if anyRegularItems then
            executeRender(additional_render_path, false)
        end
        if anySecondPassItems then
            executeRender(additional_render_path, true)
        end
    end
   
    restoreRenderSettings()
end


-------------------------------------------------------------------------
------------------------ clearTrackedRenderFlag -------------------------
-------------------------------------------------------------------------


function clearTrackedRenderFlags()
    for region_idx, track_flags in pairs(active_render_flags) do
        for track, _ in pairs(track_flags) do
            reaper.SetRegionRenderMatrix(0, region_idx, track, -1)
        end
    end
    -- Clear the tracking array after cleaning up
    active_render_flags = {}
end

-------------------------------------------------------------------------
--------------------------FIND REGION BY NAME----------------------------
-------------------------------------------------------------------------

function findRegionIndexByName(regionName)
    local num_markers, num_regions = reaper.CountProjectMarkers(0)
    local total_markers = num_markers + num_regions
    for i = 0, total_markers - 1 do
        local retval, isRegion, pos, rgnEnd, name, markrgnIndexNumber = reaper.EnumProjectMarkers(i)
        if isRegion and name == regionName then
            return markrgnIndexNumber
        end
    end
    return nil -- Return nil if no region with the given name is found
end

-------------------------------------------------------------------------
----------------------------FIND NEXT SUFFIX-----------------------------
-------------------------------------------------------------------------

function findNextAvailableSuffix(base_name)
    local existing_suffixes = {}

    -- Collect all existing region names
    local num_markers, num_regions = reaper.CountProjectMarkers(0)
    for i = 0, num_markers + num_regions - 1 do
        local retval, isRegion, pos, rgnEnd, name, markrgnIndexNumber = reaper.EnumProjectMarkers(i)
        if isRegion and name:find(base_name) then
            local suffix = tonumber(name:match(base_name .. "_(%d+)$"))
            if suffix then
                existing_suffixes[suffix] = true
            end
        end
    end

    -- Find the smallest available suffix
    local suffix = 0
    while existing_suffixes[suffix] do
        suffix = suffix + 1
    end

    return suffix
end

-------------------------------------------------------------------------
----------------------SHOW CHANNEL INPUT WINDOW--------------------------
-------------------------------------------------------------------------

function showChannelInputWindow()
    show_channel_input_popup = true
    local ret, user_inputs = reaper.GetUserInputs("Input Channels", 1, "Number of Channels:", "")
    if ret then
        num_channels = tonumber(user_inputs) or 2 -- Default to stereo if invalid input
        show_channel_input_popup = false
        local base_region_name = finalPrefix .. soundName
        createRegions(base_region_name)
    else
        show_channel_input_popup = false
    end
end

-------------------------------------------------------------------------
---------------------DETECT FOLDER ITEMS AND REGIONS---------------------
-------------------------------------------------------------------------

function detectFolderItemsAndRegions()
    region_folder_map = {}
    track_folder_map = {}
    local num_tracks = reaper.CountTracks(0)
    _, _, num_regions = reaper.CountProjectMarkers(0)
    local folder_tracks = {}
    local added_tracks = {}
   
    for i = 0, num_tracks - 1 do
        local track = reaper.GetTrack(0, i)
        local folder_depth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if folder_depth == 1.0 then
            table.insert(folder_tracks, track)
        end
    end
       
    for _, folder_track in ipairs(folder_tracks) do
        track_folder_map[folder_track] = {}
        local items = reaper.CountTrackMediaItems(folder_track)
        for i = 0, items - 1 do
            local item = reaper.GetTrackMediaItem(folder_track, i)
            local note = reaper.ULT_GetMediaItemNote(item)
            if string.match(note, "RENDER ITEM") then
                table.insert(track_folder_map[folder_track], item)
            end
        end
    end

    -- Sort track_folder_map by track name
    table.sort(folder_tracks, function(a, b)
        local _, nameA = reaper.GetTrackName(a)
        local _, nameB = reaper.GetTrackName(b)
        return nameA < nameB
    end)
end


-------------------------------------------------------------------------
--------------------------UPDATE FOLDER ITEMS----------------------------
-------------------------------------------------------------------------

function adjustFolderItems()
    reaper.Undo_BeginBlock()
    reaper.Main_OnCommand(40297, 0) -- Unselect all tracks
    reaper.Main_OnCommand(40289, 0) -- Unselect all items
    track_count = reaper.CountTracks(0)
    for folder_track, folder_items in pairs(track_folder_map) do
        for _, folder_item in ipairs(folder_items) do
            reaper.Main_OnCommand(40297, 0) -- Unselect all tracks
            reaper.Main_OnCommand(40289, 0) -- Unselect all items
            reaper.SetMediaItemSelected(folder_item, true) -- Select the folder item
           
            -- Get folder item's current position and length
            local folder_start = reaper.GetMediaItemInfo_Value(folder_item, "D_POSITION")
            local folder_end = folder_start + reaper.GetMediaItemInfo_Value(folder_item, "D_LENGTH")
           
            track_number = reaper.GetMediaTrackInfo_Value(folder_track, "IP_TRACKNUMBER")
            isnt_last_child = true
           
            -- Variables to track the actual stack boundaries
            local earliest_start = math.huge
            local latest_end = 0
            local items_found = false
           
            -- Process child tracks to find matching items
            while isnt_last_child do
                track_number = track_number + 1
                next_track = reaper.GetTrack(0, track_number - 1)
                track_item_count = reaper.CountTrackMediaItems(next_track)
             
                for i = 0, track_item_count - 1 do
                    track_media_item = reaper.GetTrackMediaItem(next_track, i)
                    track_item_start_time = reaper.GetMediaItemInfo_Value(track_media_item, "D_POSITION")
                    track_item_length = reaper.GetMediaItemInfo_Value(track_media_item, "D_LENGTH")
                    track_item_end_time = track_item_start_time + track_item_length
                   
                    -- Check if this item overlaps with the folder item's time range
                    if (track_item_start_time <= folder_end and track_item_end_time >= folder_start) then
                        items_found = true
                        earliest_start = math.min(earliest_start, track_item_start_time)
                        latest_end = math.max(latest_end, track_item_end_time)
                        reaper.SetMediaItemSelected(track_media_item, true)
                    end
                end
               
                next_track_depth = reaper.GetMediaTrackInfo_Value(next_track, "I_FOLDERDEPTH")
                if next_track_depth == -1.0 then
                    isnt_last_child = false
                end
            end
           
            if items_found then
                -- Update folder item and region to match the actual stack boundaries
                folder_item_name = reaper.GetTakeName(reaper.GetMediaItemTake(folder_item, 0))
               
                reaper.SetMediaItemInfo_Value(folder_item, "D_POSITION", earliest_start)
                reaper.SetMediaItemInfo_Value(folder_item, "D_LENGTH", latest_end - earliest_start)

                -- Adjust or create region corresponding to folder item
                local region_index = findRegionIndexByName(folder_item_name)
                if region_index then
                    -- Adjust existing region
                    reaper.SetProjectMarker(region_index, true, earliest_start, latest_end, folder_item_name)
                else
                    -- Create new region
                    reaper.AddProjectMarker2(0, true, earliest_start, latest_end, folder_item_name, -1, 0)
                end
            end

            reaper.Main_OnCommand(40289, 0) -- Unselect all items
        end
    end
   
    reaper.Undo_EndBlock("Adjust folder items", 0)
end


-------------------------------------------------------------------------
--------------------------RENAME EXISTING ITEMS--------------------------
-------------------------------------------------------------------------


function nameRename()
    show_channel_input_popup = true
    local ret, user_inputs = reaper.GetUserInputs("Input Channels", 1, "Number of Channels:", "")
    if not ret then
        show_channel_input_popup = false
        return
    end
   
    num_channels = tonumber(user_inputs) or 2 -- Default to stereo if invalid input
    show_channel_input_popup = false
   
    -- Make sure we have a valid base name
    local base_name = finalPrefix .. soundName
    if base_name == "" then
        reaper.MB("Please enter a valid name", "Error", 0)
        return
    end
   
    -- Get time selection
    local time_start, time_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if time_end - time_start == 0 then
        reaper.MB("Please make a time selection", "Error", 0)
        return
    end
   
    -- Find all selected items within time selection
    local items = {}
    local num_selected_items = reaper.CountSelectedMediaItems(0)
    for i = 0, num_selected_items - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
       
        if (item_start < time_end and item_end > time_start) then
            table.insert(items, item)
        end
    end
   
    if #items == 0 then
        -- If no items in time selection, create new regions
        createRegions(base_name)
        return
    end
   
    -- Group items by their stacks (overlapping items)
    local stacks = {}
    local current_stack = {}
    local current_stack_end = 0
   
    table.sort(items, function(a, b)
        return reaper.GetMediaItemInfo_Value(a, "D_POSITION") < reaper.GetMediaItemInfo_Value(b, "D_POSITION")
    end)
   
    for _, item in ipairs(items) do
        local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
       
        if item_start > current_stack_end then
            if #current_stack > 0 then
                table.insert(stacks, current_stack)
                current_stack = {}
            end
            current_stack_end = item_end
        else
            current_stack_end = math.max(current_stack_end, item_end)
        end
        table.insert(current_stack, item)
    end
    if #current_stack > 0 then
        table.insert(stacks, current_stack)
    end
   
    -- Process each stack
    for _, stack in ipairs(stacks) do
        local stack_start = math.huge
        local stack_end = 0
        local parent_track = nil
        local existing_folder_item = nil
       
        -- Find stack boundaries and check for existing folder item
        for _, item in ipairs(stack) do
            local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            stack_start = math.min(stack_start, item_start)
            stack_end = math.max(stack_end, item_end)
           
            local track = reaper.GetMediaItem_Track(item)
            local top_folder = getTopMostFolderTrack(track)
            if top_folder then
                parent_track = top_folder
            end
        end
       
        -- Check for existing folder item
        if parent_track then
            local num_items = reaper.CountTrackMediaItems(parent_track)
            for i = 0, num_items - 1 do
                local item = reaper.GetTrackMediaItem(parent_track, i)
                local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                local note = reaper.ULT_GetMediaItemNote(item)
               
                if string.match(note, "RENDER ITEM") and
                   item_start <= stack_end and item_end >= stack_start then
                    existing_folder_item = item
                    break
                end
            end
        end
       
        if existing_folder_item then
            -- Get the old name first
            local old_take = reaper.GetActiveTake(existing_folder_item)
            local _, old_name = reaper.GetSetMediaItemTakeInfo_String(old_take, "P_NAME", "", false)
           
            -- Generate new name with proper variation number
            local variation_number = findNextAvailableVariationNumber(base_name)
            local new_name = base_name .. variation_number
           
            -- Find the existing region by old name
            local region_index = findRegionIndexByName(old_name)
           
            if region_index then
                -- Update existing region with new name
                reaper.SetProjectMarker(region_index, true, stack_start, stack_end, new_name)
            else
                -- Create new region only if old one wasn't found
                reaper.AddProjectMarker2(0, true, stack_start, stack_end, new_name, -1, 0)
            end
           
            -- Update folder item
            reaper.GetSetMediaItemTakeInfo_String(old_take, "P_NAME", new_name, true)
            reaper.ULT_SetMediaItemNote(existing_folder_item, "RENDER ITEM" .. " " .. "CH: " .. tostring(num_channels))
        else
            -- If no existing folder item was found, create a new one
            if parent_track then
                local variation_number = findNextAvailableVariationNumber(base_name)
                local new_name = base_name .. variation_number
                createFolderItem(stack_start, stack_end, new_name, parent_track)
                reaper.AddProjectMarker2(0, true, stack_start, stack_end, new_name, -1, 0)
            end
        end
    end
   
    detectFolderItemsAndRegions()
end



-------------------------------------------------------------------------
------------------------SHOULD UPDATE DETECTION--------------------------
-------------------------------------------------------------------------


function shouldUpdateDetection()
    local current_change_count = reaper.GetProjectStateChangeCount(0)
    if current_change_count ~= last_project_change_count then
        last_project_change_count = current_change_count
        return true
    end
    return false
end


-------------------------------------------------------------------------
------------------------NEXT AVAILABLE NUMBER----------------------------
-------------------------------------------------------------------------

function findNextAvailableVariationNumber(base_name)
    -- Check if base_name is valid
    if not base_name or base_name == "" then
        return "_00"  -- Return default if base_name is nil or empty
    end
   
    -- First, collect all existing numbers for this base name
    local used_numbers = {}
    local num_markers, num_regions = reaper.CountProjectMarkers(0)
   
    -- Remove _XX from base_name if it exists (with safety check)
    base_name = base_name:gsub("_%d+$", "")
   
    -- Look through all regions
    for i = 0, num_markers + num_regions - 1 do
        local retval, isRegion, pos, rgnEnd, name, markrgnIndexNumber = reaper.EnumProjectMarkers(i)
        if isRegion and name then  -- Add check for name
            -- Check if this region name matches our base pattern
            local this_base, number = name:match("^(" .. base_name .. ")_(%d+)$")
            if this_base then
                local num = tonumber(number)
                if num then  -- Add check for valid number
                    used_numbers[num] = true
                end
            end
        end
    end
   
    -- Find the first available number starting from 0
    local number = 0
    while used_numbers[number] do
        number = number + 1
    end
   
    return string.format("_%02d", number)
end


-------------------------------------------------------------------------
--------------------------LOOOOOOO---OOOOOOOOP---------------------------
-------------------------------------------------------------------------

function loop()
    if shouldUpdateDetection() then
        detectFolderItemsAndRegions()
    end
    if visible then
        reaper.ImGui_SetNextWindowSizeConstraints(ctx, 544, 420, 10000, 10000)
       
        StyleManager.PushStyle(ctx)

        local should_display
        should_display, visible = reaper.ImGui_Begin(ctx, 'NAME / RENDER / BE WELL', visible)
   
        if should_display then
           
           
           
           
           
            reaper.ImGui_BeginChild(ctx, "SETTINGS", 450, 183, 0, reaper.ImGui_WindowFlags_None())
           
           
           
           
            reaper.ImGui_Dummy(ctx,0,0)
            --reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 100)
            changed, selected_bitdepth_index = reaper.ImGui_Combo(ctx, "##bitdepth", selected_bitdepth_index - 1, table.concat(render_bitdepths, "\0") .. "\0")
            selected_bitdepth_index = selected_bitdepth_index + 1
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Dummy(ctx,0,0)
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Text(ctx, ":BIT / SR:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Dummy(ctx,0,0)
           
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 110)
            changed, selected_sample_rate_index = reaper.ImGui_Combo(ctx, "##samplerate", selected_sample_rate_index - 1, table.concat(render_sample_rates, "\0") .. "\0")
            selected_sample_rate_index = selected_sample_rate_index + 1



            reaper.ImGui_Separator(ctx)
            changed, normalize_render = reaper.ImGui_Checkbox(ctx, ":NRMZ?:", normalize_render)
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 100)
            changed, normalization_volume = reaper.ImGui_SliderDouble(ctx, "##norm_vol", normalization_volume, -60, 0, "%.1f dB")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 110)
            changed, selected_normalization_index = reaper.ImGui_Combo(ctx, "##norm_type", selected_normalization_index - 1, table.concat(normalization_types, "\0") .. "\0")
            selected_normalization_index = selected_normalization_index + 1

            reaper.ImGui_Separator(ctx)
            changed, use_brickwall_limiter = reaper.ImGui_Checkbox(ctx, ":LIMT?:", use_brickwall_limiter)
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 100)
            changed, brickwall_limit_threshold_db = reaper.ImGui_SliderDouble(ctx, "##limit_thresh_db", brickwall_limit_threshold_db, -12, 0, "%.2f dB")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 110)
            changed, selected_brickwall_limiter_index = reaper.ImGui_Combo(ctx, "##limiter_type", selected_brickwall_limiter_index - 1, table.concat(brickwall_limiter_types, "\0") .. "\0")
            selected_brickwall_limiter_index = selected_brickwall_limiter_index + 1
           
            reaper.ImGui_Separator(ctx)
            local changed
            changed, use_additional_render_path = reaper.ImGui_Checkbox(ctx, "##Label", use_additional_render_path)

            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Text(ctx, ":Extra Render Path?:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Dummy(ctx, 65, 0)
            reaper.ImGui_SameLine(ctx)
           
            if reaper.ImGui_Button(ctx, "Browse") then
                local retval, path = reaper.JS_Dialog_BrowseForFolder(0, "Select Render Path")
                if retval then
                    additional_render_path = path
                end
            end
            reaper.ImGui_Dummy(ctx, 4, 0)
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Text(ctx, "Path: " .. additional_render_path)
           
           
           
            reaper.ImGui_EndChild(ctx)
           
            reaper.ImGui_Dummy(ctx, 0, 1)
           
   
            if reaper.ImGui_Button(ctx, 'NME!') then
                nameRename()
            end
           
            reaper.ImGui_SameLine(ctx)
       
            if reaper.ImGui_Button(ctx, 'RDR!') then
                renderQueuedRegions()
            end
           
           
            reaper.ImGui_SameLine(ctx)

            if reaper.ImGui_Button(ctx, 'ADJ!') then
                adjustFolderItems()
            end

           
            reaper.ImGui_SameLine(ctx)
           
            reaper.ImGui_Text(ctx, "Name: ")reaper.ImGui_SameLine(ctx)
            reaper.ImGui_BeginChild(ctx, "FINAL ASSET NAME", 268, 33)
            reaper.ImGui_SetNextItemWidth(ctx, 268)
            _, soundName = reaper.ImGui_InputText(ctx, "##", soundName, reaper.ImGui_InputTextFlags_AlwaysOverwrite())
 
            reaper.ImGui_EndChild(ctx)
           

            local sorted_folder_tracks = {}
            local num_tracks = 0
            for folder_track, folder_items in pairs(track_folder_map) do
                if #folder_items > 0 then
                    table.insert(sorted_folder_tracks, folder_track)
                    num_tracks = num_tracks + 1
                end
            end
           
            table.sort(sorted_folder_tracks, function(a, b)
                return reaper.GetMediaTrackInfo_Value(a, "IP_TRACKNUMBER") < reaper.GetMediaTrackInfo_Value(b, "IP_TRACKNUMBER")
            end)

            local num_tracks = #sorted_folder_tracks

            local table_flags = reaper.ImGui_TableFlags_SizingFixedFit() |
                                reaper.ImGui_TableFlags_Resizable() |
                                reaper.ImGui_TableFlags_BordersV()
                               
           
           
            -----------------------------------
            ------------ TABLE ----------------
            -----------------------------------
           
            reaper.ImGui_BeginChild(ctx, "tabela")
           
            if num_tracks ~= 0 and reaper.ImGui_BeginTable(ctx, "regionRenderTable", num_tracks, table_flags) then
                for column_index, folder_track in ipairs(sorted_folder_tracks) do
                    local has_items = #track_folder_map[folder_track] > 0
                    if has_items then
                        local _, track_name = reaper.GetTrackName(folder_track)
                        track_name = string.gsub(track_name, "Track", "T#")
                        local column_width = 80
                        reaper.ImGui_TableSetupColumn(ctx, track_name, reaper.ImGui_TableColumnFlags_None(), column_width)
                    end
                end
                reaper.ImGui_TableHeadersRow(ctx)
   
                local max_items = 0
                for _, items in pairs(track_folder_map) do
                    if #items > max_items then
                        max_items = #items
                    end
                end

                local mouse_clicked = reaper.ImGui_IsMouseClicked(ctx, 0)
                local mouse_released = reaper.ImGui_IsMouseReleased(ctx, 0)
                local mouse_dragging = reaper.ImGui_IsMouseDragging(ctx, 0)
               
                local ctrl_pressed = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl())
                local alt_pressed = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftAlt())
               
                if mouse_clicked then
                    is_dragging = true
                    local mouse_x, mouse_y = reaper.ImGui_GetMousePos(ctx)
                    drag_start_pos = {mouse_x, mouse_y}
                elseif mouse_released then
                    is_dragging = false
                    drag_start_pos = nil
                    updateRenderQueue() -- Update the render queue after dragging
                end
               
                for item_idx = 1, max_items do
                    reaper.ImGui_TableNextRow(ctx)
                    for column_index, folder_track in ipairs(sorted_folder_tracks) do
                        reaper.ImGui_TableSetColumnIndex(ctx, column_index - 1)
                        local items = track_folder_map[folder_track]
                        local item = items[item_idx]
                        if item then
                            local active_take = reaper.GetActiveTake(item)
                            if active_take then
                                local _, item_name = reaper.GetSetMediaItemTakeInfo_String(active_take, "P_NAME", "", false)
                                local note = reaper.ULT_GetMediaItemNote(item)
                                local item_display = string.format("%s", item_name or "Unnamed")
                                local is_selected = selected_items[item] ~= nil
           
                                if is_selected then
                                    local dynamic_colors = {
                                        [reaper.ImGui_Col_Header()] = selected_items[item].second_pass and
                                            StyleManager.style.dynamic_colors.second_pass or
                                            StyleManager.style.dynamic_colors.selected,
                                        [reaper.ImGui_Col_HeaderHovered()] = selected_items[item].second_pass and
                                            StyleManager.style.dynamic_colors.second_pass or
                                            StyleManager.style.dynamic_colors.selected,
                                        [reaper.ImGui_Col_HeaderActive()] = selected_items[item].second_pass and
                                            StyleManager.style.dynamic_colors.second_pass or
                                            StyleManager.style.dynamic_colors.selected
                                    }
                                    local num_colors = StyleManager.PushDynamicColors(ctx, dynamic_colors)
                                end
               
                                if reaper.ImGui_Selectable(ctx, item_display, is_selected) then
                                    if ctrl_pressed then
                                        selected_items[item] = nil
                                    elseif alt_pressed then
                                        if selected_items[item] then
                                            selected_items[item].second_pass = not selected_items[item].second_pass
                                        else
                                            selected_items[item] = { second_pass = true }
                                        end
                                    else
                                        if selected_items[item] then
                                            selected_items[item] = nil
                                        else
                                            selected_items[item] = {}
                                        end
                                    end
                                    updateRenderQueue()
                                end
           
                                if is_selected then
                                    reaper.ImGui_PopStyleColor(ctx, 3)
                                end
                               
                                if reaper.ImGui_IsItemClicked(ctx, 1) then  -- Right mouse button is index 1
                                    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                                    local track_of_item = reaper.GetMediaItem_Track(item)
                                    reaper.Main_OnCommand(40297, 0)
                                    reaper.SetTrackSelected(track_of_item, true)
                                    reaper.SetEditCurPos(item_start, true, false)
                                    reaper.Main_OnCommand(40913,0)
                                    reaper.UpdateArrange()  -- Refresh REAPER's arrange view
                                    break  -- Break the loop once the right item is processed
                                end
                               
                                -- Tooltip for item name
                                if reaper.ImGui_IsItemHovered(ctx) then
                                    reaper.ImGui_BeginTooltip(ctx)
                                    reaper.ImGui_Text(ctx, item_name)
                                    reaper.ImGui_EndTooltip(ctx)
                                end
                             
               
                                if is_dragging and mouse_dragging then
                                    local mouse_x, mouse_y = reaper.ImGui_GetMousePos(ctx)
                                    if drag_start_pos and drag_start_pos[1] and drag_start_pos[2] then
                                        local item_min_x, item_min_y = reaper.ImGui_GetItemRectMin(ctx)
                                        local item_max_x, item_max_y = reaper.ImGui_GetItemRectMax(ctx)
               
                                        local start_x, start_y = drag_start_pos[1], drag_start_pos[2]
                                        local end_x, end_y = mouse_x, mouse_y
               
                                        if start_x > end_x then start_x, end_x = end_x, start_x end
                                        if start_y > end_y then start_y, end_y = end_y, start_y end
               
                                        if item_min_x <= end_x and item_max_x >= start_x and
                                           item_min_y <= end_y and item_max_y >= start_y then
                                            if ctrl_pressed then
                                                selected_items[item] = nil
                                            else
                                                selected_items[item] = {}
                                            end
                                        end
                                    end
                                end
                            end
                        else
                            reaper.ImGui_Text(ctx, "")
                        end
                    end
                end

                reaper.ImGui_EndTable(ctx)
            end
           
            ------ END TABLE ----
       
            reaper.ImGui_EndChild(ctx)
           
   
            reaper.ImGui_End(ctx)
        end
        StyleManager.PopStyle(ctx)
    end

    if visible then
        reaper.defer(loop)
    else
        SaveSettingsToCSV()
    end
end

     
LoadSettingsFromCSV()
loop()

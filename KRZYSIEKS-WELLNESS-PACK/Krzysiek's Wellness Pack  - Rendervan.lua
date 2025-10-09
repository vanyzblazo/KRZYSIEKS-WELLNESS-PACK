--[[
@version 1.83
@provides
  fonts/andalemono_rv.ttf
--]]

ultraschall_path = reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua"
if reaper.file_exists( ultraschall_path ) then
  dofile( ultraschall_path )
end

if not ultraschall or not ultraschall.GetApiVersion then
    reaper.MB("Please install Ultraschall API, available via Reapack.", "Error", 0)
    reaper.ShowConsoleMsg("REAPACK LINK: https://github.com/Ultraschall/ultraschall-lua-api-for-reaper/raw/master/ultraschall_api_index.xml")
    return
end

-- Initialize ImGui context
local ctx = reaper.ImGui_CreateContext('RENDERVAN')
if not ctx then
    reaper.ShowMessageBox("Please install ImGUI for REAPER via Reapack." .. "\n" .. "It is available as a part of ReaTeam Extensions on Reapack. ", "Error", 0)
    reaper.ShowConsoleMsg("REAPACK LINK: https://github.com/ReaTeam/Extensions/raw/master/index.xml")
    return
end
-- Try to load the required version
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local load_success, ImGui = pcall(function()
  return require 'imgui' '0.10.0.0'
end)

if not load_success then
  reaper.MB("ReaImGui version is too old.\n\nThis script requires ReaImGui v0.10.0.0 or newer.\n\nPlease update via ReaPack:\nExtensions > ReaPack > Synchronize packages", "ReaImGui Update Required", 0)
  return
end


-- STYLES --------------------------------------------------------------------------------------------------------------------------
local StyleManager = {
    push_count = 0,
    style = {
        vars = {
            [reaper.ImGui_StyleVar_FramePadding()] = {4, 8},
            [reaper.ImGui_StyleVar_TabBarBorderSize()] = 8,
            [reaper.ImGui_StyleVar_TabBorderSize()] = 10,
            [reaper.ImGui_StyleVar_WindowMinSize()] = {544, 420},
            [reaper.ImGui_StyleVar_WindowPadding()] = {8, 8},
            [reaper.ImGui_StyleVar_GrabRounding()] = 4,
            [reaper.ImGui_StyleVar_TabRounding()] = 4,
            [reaper.ImGui_StyleVar_FrameRounding()] = 4,
            [reaper.ImGui_StyleVar_ChildRounding()] = 4,
            [reaper.ImGui_StyleVar_WindowRounding()] = 4
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
            [reaper.ImGui_Col_SliderGrab()] = 0xB84A62FF,
            [reaper.ImGui_Col_SliderGrabActive()] = 0xC55B73FF,
            [reaper.ImGui_Col_FrameBgActive()] = 0x4A3B3EFF,
            [reaper.ImGui_Col_CheckMark()] = 0x0FA68AFF,
            [reaper.ImGui_Col_Tab()] = 0x333333FF,
            [reaper.ImGui_Col_TabHovered()] = 0x3B3B3BFF,

            [reaper.ImGui_Col_PopupBg()] = 0x4C4C4CFF
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

-- FONTS -----------------------------------------------------------------------------------------------------------------------------------

-- Get your script's directory path
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]

local base_font = reaper.ImGui_CreateFontFromFile(script_path .. 'fonts/andalemono_rv.ttf')

-- Small font
local small_font = reaper.ImGui_CreateFont(custom_font_name)
reaper.ImGui_Attach(ctx, small_font)

-- Normal font
local normal_font = reaper.ImGui_CreateFont(custom_font_name)
reaper.ImGui_Attach(ctx, normal_font)

-- Big font
local big_font = reaper.ImGui_CreateFont(custom_font_name)
reaper.ImGui_Attach(ctx, big_font)

-- INIT VARIABLES --------------------------------------------------------------------------------------------------------------------------

local visible = true
local items, types, prefixes = {}, {}, {}
local first_open = true
local sound_name = ""
local render_queue = {}
local active_render_flags = {} -- Store active render flags as {region_index = {track_guid = flag}}
local last_project_change_count = 0
local preferences_window = false
local pending_imports = {} -- Table to track pending imports: {source_item = {name=, path=}, target_path = "wwise/path"}
local no_suffix_naming = false
local sorted_folder_tracks = {}
local mouse_over_table = false

local selected_items = {}
local is_dragging = false
local drag_start_pos = nil
local pref_variaton_start_number = 0
local selected_items_list = {}  -- List to maintain order

local num_channels = ""
local region_folder_map = {} -- Data structure to track folder items and regions
local track_folder_map = {} -- Data structure to track folder items and tracks
local filter_text = ""
local filtered_items = {}

local adjust_selection = false
local rename_selected_items = false

local drag_start_scroll_y = 0  -- Track scroll position when drag starts
local drag_start_content_y = 0  -- Track content position when drag starts




-- INIT SETTINGS --------------------------------------------------------------------------------------------------------------------------

-- Render settings variables
local use_additional_render_path = false
local additional_render_path = ""
local render_bitdepths = {"8 bit", "16 bit", "24 bit", "32 bit"}
local selected_bitdepth_index = 2 -- Default to 16
local render_sample_rates = {"32 kHz", "44 kHz", "48 kHz", "88 kHz", "96 kHz", "192 kHz"}
local selected_sample_rate_index = 3 -- Default to 48 kHz
local ww_project_only_render = true
local render_via_master = true
local child_tracks_for_adjustment = {}
local ignore_muted_items_when_adj = false
local window_flags = reaper.ImGui_WindowFlags_NoDocking()

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
local brickwall_limit_threshold_db = 0.0 -- Default to -0.1 dB
local brickwall_limiter_types = {"Peak", "True Peak"}
local selected_brickwall_limiter_index = 1 -- Default to Peak

-- Render paths
local pref_inner_render_folder = "Render"
local use_inner_render_path = true
local settings_file_path = reaper.GetResourcePath() .. '/Scripts/RenderSettings.csv'

-- WWise init vairiables --------------------------------------------------------------------------------------------------------------------

local ww_connected = false
local ww_connection_status = false
local ww_proj_name = "No Project"   -- Default value
ww_actor_mixer_hirarchy = {}
local wwise_hierarchy_filter = ""
local wwise_window = false
local ww_window_first_time_open = true
local dragged_items = {}
local filtering_in_progress = false

local wwise_hierarchy_tree = nil
local wwise_hierarchy_filter = ""

local last_filter_time = 0
local filter_delay = 1

local filter_cache = {}
local max_cache_size = 100  
local cache_reset_threshold = 0.8  
local filtering_in_progress = false
local collapse_end_containers = false

local previous_filter = ""
local filtered_hierarchy_tree = nil
local ww_render_to_default = true

local originals_path = ""
local global_path_override = ""
local selected_wwise_object_for_import = nil
local path_history = {} -- Store last 7 paths
local max_path_history = 7

local path_conflicts = {}
local conflict_resolution_window = false
local conflict_decisions = {} -- Store user decisions
local import_operation_pending = nil -- Store the original import operation to continue after conflict resolution

local conflict_resolution_popup_open = false
local pending_conflict_resolution_data = nil

local global_replacement_conflicts = {}
local global_grouped_by_file_path = nil


function handleReplaceFilesInWwise()
    local items_to_replace = collectSelectedItemsInfo()
    if #items_to_replace == 0 then
        reaper.MB("No items selected for replacement", "Error", 0)
        return
    end
    
    -- Connect to Wwise if not already connected
    if not ww_connected then
        ww_connection_status, ww_proj_name = wwiseConnect()
        if not ww_connection_status then
            reaper.MB("Failed to connect to Wwise", "Error", 0)
            return
        end
    end
    
    -- 1. Find all conflicts (no rendering needed - just checking Wwise structure)
    global_replacement_conflicts = findAllReplacementConflicts(items_to_replace)
    
    -- 2. Show conflict resolution if conflicts exist
    if hasReplacementConflicts(global_replacement_conflicts) then
        show_global_replacement_conflicts = true
        reaper.ImGui_OpenPopup(ctx, "File Replacement Conflicts")
    else
        -- 3. No conflicts - render and import directly
        renderAndImportToWwise(items_to_replace, nil, {replace_existing = true})
    end
end


-- Helper function to truncate path from left (reuse your existing one or add this)
function truncatePathLeft(path, max_length)
    if not path or string.len(path) <= max_length then
        return path or ""
    end
    return "..." .. string.sub(path, -(max_length - 3))
end





-------------------------------------------------------------------------------------------------------------------------------
------------------------WWISE FILTER PREPARE ----------------------------
-------------------------------------------------------------------------------------------------------------------------------


function countMatchingSounds(node, filter_words)
    local count = 0
    if node.object.type == "Sound" and doesNodeMatch(node, filter_words) then
        return 1
    end
    if node.children then
        for _, child in ipairs(node.children) do
            count = count + countMatchingSounds(child, filter_words)
        end
    end
    return count
end


-- New separated rendering function
function renderItems(items)
    if #items == 0 then return end
    
    -- Store current selection state
    local previous_selection = {}
    for item, props in pairs(selected_items) do
        previous_selection[item] = props
    end

    -- Set up all items for rendering
    selected_items = {}
    for _, item_info in ipairs(items) do
        if item_info.item then  
            selected_items[item_info.item] = item_info.second_pass and { second_pass = true } or {}
        end
    end
   
    updateRenderQueue()
   
    local previous_additional_path_state = use_additional_render_path
    if ww_project_only_render then
        use_additional_render_path = false
    end
   
    -- Single render call for all items
    renderQueuedRegions()
   
    use_additional_render_path = previous_additional_path_state
    selected_items = previous_selection
    updateRenderQueue()
end

-----------------------------------------------------------------------------------------------------------------
------------------------WWISE GROUP SOUNDS ----------------------------
-----------------------------------------------------------------------------------------------------------------

function wwiseGroupItems(dragged_item_group)
    local ww_grouped_items = {}
       
    for _, item_info in ipairs(dragged_item_group) do
        local item_name = item_info.name
        local base_name = item_name:gsub("_%d+$", "")
           
        if not ww_grouped_items[base_name] then
            ww_grouped_items[base_name] = {}
        end
       
        table.insert(ww_grouped_items[base_name], item_info)
    end

    return ww_grouped_items
end

-----------------------------------------------------------------------------------------------------------------
------------------------DB TO AMPLITUDE-----------------------------
-----------------------------------------------------------------------------------------------------------------

function dBToAmplitude(dB)
    return 10^(dB / 20)
end


-----------------------------------------------------------------------------------------------------------------
------------------------CLEAR SELECTED ITEMS-----------------------------
-----------------------------------------------------------------------------------------------------------------

function clearSelectedItems()
    selected_items = {}
    updateRenderQueue()
end

-----------------------------------------------------------------------------------------------------------------
------------------------SAVE SETTINGS TO CSV-----------------------------
-----------------------------------------------------------------------------------------------------------------

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
        file:write("pref_inner_render_folder,", tostring(pref_inner_render_folder), "\n")
        file:write("use_inner_render_path,", tostring(use_inner_render_path), "\n")
        file:write("ww_project_only_render,", tostring(ww_project_only_render), "\n")
        file:write("ww_render_to_default,", tostring(ww_render_to_default), "\n")
        file:write("render_via_master,", tostring(render_via_master), "\n")
        file:write("pref_variaton_start_number,", tostring(pref_variaton_start_number), "\n")
        file:write("ignore_muted_items_when_adj,", tostring(ignore_muted_items_when_adj), "\n")
        
        -- Add path history - encode as semicolon-separated string
        local path_history_string = table.concat(path_history, ";")
        file:write("path_history,", path_history_string, "\n")
               
        file:close()
    end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------LOAD SETTINGS FROM CSV----------------------------
-----------------------------------------------------------------------------------------------------------------

function LoadSettingsFromCSV() 
    local file = io.open(settings_file_path, 'r')
    if file then
        for line in file:lines() do
            local key, value = line:match("([^,]+),(.*)")
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
                elseif key == "pref_inner_render_folder" then
                    pref_inner_render_folder = value
                elseif key == "use_inner_render_path" then
                    use_inner_render_path = (value == "true")
                elseif key == "ww_project_only_render" then
                    ww_project_only_render = (value == "true")
                elseif key == "ignore_muted_items_when_adj" then
                    ignore_muted_items_when_adj = (value == "true")
                elseif key == "ww_render_to_default" then
                    ww_render_to_default = (value == "true")
                elseif key == "render_via_master" then
                    render_via_master = (value == "true")
                elseif key == "pref_variaton_start_number" then
                    pref_variaton_start_number = tonumber(value)
                elseif key == "path_history" then
                    -- Decode semicolon-separated string back to table
                    path_history = {}
                    if value and value ~= "" then
                        for path in value:gmatch("([^;]+)") do
                            table.insert(path_history, path)
                        end
                    end
                end
            end
        end
        file:close()
    end
end


-----------------------------------------------------------------------------------------------------------------
------------------------SAVE AND RESTORE RENDER SETTINGS-----------------
-----------------------------------------------------------------------------------------------------------------

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

-----------------------------------------------------------------------------------------------------------------
------------------------GET TOP MOST FOLDER TRACK------------------------
-----------------------------------------------------------------------------------------------------------------

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

-----------------------------------------------------------------------------------------------------------------
-----------------------------CREATE REGIONS------------------------------
-----------------------------------------------------------------------------------------------------------------

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

-----------------------------------------------------------------------------------------------------------------
---------------------------CREATE FOLDER ITEMS---------------------------
-----------------------------------------------------------------------------------------------------------------

function createFolderItem(start_pos, end_pos, region_name, parent_track)
    local folder_item = reaper.AddMediaItemToTrack(parent_track)
    reaper.SetMediaItemInfo_Value(folder_item, "D_POSITION", start_pos)
    reaper.SetMediaItemInfo_Value(folder_item, "D_LENGTH", end_pos - start_pos)
    local take = reaper.AddTakeToMediaItem(folder_item)
    reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", region_name, true)
    reaper.ULT_SetMediaItemNote(folder_item, "RENDER ITEM" .. " " .. "CH: " .. tostring(num_channels)) -- Set the number of channels in the item note
end

-----------------------------------------------------------------------------------------------------------------
--------------------------UPDATE RENDER QUEUE----------------------------
-----------------------------------------------------------------------------------------------------------------

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


-----------------------------------------------------------------------------------------------------------------
------------------------RENDER QUEUED REGIONS----------------------------
-----------------------------------------------------------------------------------------------------------------

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
        if render_via_master then
            render_settings = render_settings | 128
        end
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
    local render_directory = project_path .. pref_inner_render_folder

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


-----------------------------------------------------------------------------------------------------------------
------------------------ clearTrackedRenderFlag -------------------------
-----------------------------------------------------------------------------------------------------------------


function clearTrackedRenderFlags()
    for region_idx, track_flags in pairs(active_render_flags) do
        for track, _ in pairs(track_flags) do
            reaper.SetRegionRenderMatrix(0, region_idx, track, -1)
        end
    end
    -- Clear the tracking array after cleaning up
    active_render_flags = {}
end

-----------------------------------------------------------------------------------------------------------------
--------------------------FIND REGION BY NAME----------------------------
-----------------------------------------------------------------------------------------------------------------

function findRegionIndexByName(region_name)
    local num_markers, num_regions = reaper.CountProjectMarkers(0)
    local total_markers = num_markers + num_regions
    for i = 0, total_markers - 1 do
        local retval, is_region, pos, rgn_end, name, markrgn_index_number = reaper.EnumProjectMarkers(i)
        if is_region and name == region_name then
            return markrgn_index_number
        end
    end
    return nil -- Return nil if no region with the given name is found
end

-----------------------------------------------------------------------------------------------------------------
--------------------------DELETE ITEMS----------------------------
-----------------------------------------------------------------------------------------------------------------

function deleteSelectedItems()
    for item, _ in pairs(selected_items) do
        take = reaper.GetActiveTake(item)
        region_name = reaper.GetTakeName(take)
        local region_number = findRegionIndexByName(region_name)
        -- Delete the media item
        reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(item), item)
        reaper.DeleteProjectMarker(0, region_number, true)
    end
    
    detectFolderItemsAndRegions()

    -- Clear the selection
    selected_items = {}
    selected_items_list = {}
    
    -- Refresh UI
    updateRenderQueue()
end

-----------------------------------------------------------------------------------------------------------------
---------------------DETECT FOLDER ITEMS AND REGIONS---------------------
-----------------------------------------------------------------------------------------------------------------

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


-----------------------------------------------------------------------------------------------------------------
--------------------------UPDATE FOLDER ITEMS----------------------------
-----------------------------------------------------------------------------------------------------------------
function getChildTracks(parent_track)
    child_tracks_for_adjustment = {}
    --check if parent track based on depth
    local num_tracks = reaper.GetNumTracks()
    local parent_track_number = reaper.GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER")
    local parent_track_depth = reaper.GetTrackDepth(parent_track)
    for i = parent_track_number, num_tracks - 1 do
        local track = reaper.GetTrack(0, i)
        local track_depth = reaper.GetTrackDepth(track)
        if track_depth <= parent_track_depth then
            break
        end
        table.insert(child_tracks_for_adjustment, track)
    end
    return child_tracks_for_adjustment
end

-----------------------------------------------------------------------------------------------------------------
--------------------------ADJUST FOLDER ITEMS----------------------------
-----------------------------------------------------------------------------------------------------------------

function adjustFolderItems(adjust_selection)
    local is_adjusting_selection = adjust_selection
    reaper.Undo_BeginBlock()
    reaper.Main_OnCommand(40297, 0) -- Unselect all tracks
    reaper.Main_OnCommand(40289, 0) -- Unselect all items
    
    for folder_track, folder_items in pairs(track_folder_map) do
        for _, folder_item in ipairs(folder_items) do
            local is_selected = (is_adjusting_selection and selected_items[folder_item] ~= nil) or not is_adjusting_selection
            
            if is_selected then
                reaper.Main_OnCommand(40297, 0) -- Unselect all tracks
                reaper.Main_OnCommand(40289, 0) -- Unselect all items
                reaper.SetMediaItemSelected(folder_item, true)

                -- Get folder item's current position and length
                local folder_start = reaper.GetMediaItemInfo_Value(folder_item, "D_POSITION")
                local folder_end = folder_start + reaper.GetMediaItemInfo_Value(folder_item, "D_LENGTH")

                -- Variables to track the actual stack boundaries
                local earliest_start = math.huge
                local latest_end = 0
                local items_found = false

                -- Get all valid child tracks (correctly handling subfolders)
                local child_tracks = getChildTracks(folder_track)

                for _, track in ipairs(child_tracks) do
                    local track_item_count = reaper.CountTrackMediaItems(track)
                    
                    for i = 0, track_item_count - 1 do
                        local track_media_item = reaper.GetTrackMediaItem(track, i)
                        local is_muted = reaper.GetMediaItemInfo_Value(track_media_item, "B_MUTE") == 1
                        if not (ignore_muted_items_when_adj and is_muted) then
                            local track_item_start_time = reaper.GetMediaItemInfo_Value(track_media_item, "D_POSITION")
                            local track_item_length = reaper.GetMediaItemInfo_Value(track_media_item, "D_LENGTH")
                            local track_item_end_time = track_item_start_time + track_item_length
                        
    
                            -- Check if this item overlaps with the folder item's time range
                            if track_item_start_time <= folder_end and track_item_end_time >= folder_start then
                                items_found = true
                                earliest_start = math.min(earliest_start, track_item_start_time)
                                latest_end = math.max(latest_end, track_item_end_time)
                                reaper.SetMediaItemSelected(track_media_item, true)
                            end
                        end
                    end
                end

                if items_found then
                    -- Update folder item and region to match the actual stack boundaries
                    local folder_item_name = reaper.GetTakeName(reaper.GetMediaItemTake(folder_item, 0))

                    reaper.SetMediaItemInfo_Value(folder_item, "D_POSITION", earliest_start)
                    reaper.SetMediaItemInfo_Value(folder_item, "D_LENGTH", latest_end - earliest_start)

                    -- Adjust or create region corresponding to folder item
                    local region_index = findRegionIndexByName(folder_item_name)
                    if region_index then
                        reaper.SetProjectMarker(region_index, true, earliest_start, latest_end, folder_item_name)
                    else
                        reaper.AddProjectMarker2(0, true, earliest_start, latest_end, folder_item_name, -1, 0)
                    end
                end

                reaper.Main_OnCommand(40289, 0) -- Unselect all items
            end
        end
    end
    
    reaper.Undo_EndBlock("Adjust folder items", 0)
end



-----------------------------------------------------------------------------------------------------------------
--------------------------RENAME EXISTING ITEMS--------------------------
-----------------------------------------------------------------------------------------------------------------


function nameRename(channels, rename_selected_items)
    local num_channels = tonumber(channels) or 2
    
    -- Make sure we have a valid base name
    local base_name = sound_name
    if base_name == "" then
        reaper.MB("Please enter a valid name", "Error", 0)
        return
    end

    -- Helper function to get new name based on whether suffix is needed
    local function getNewName(old_name, base_name)
        -- Original numbering logic
        local old_base = old_name:gsub("_%d+$", "")
        local original_number = old_name:match("_(%d+)$")
        
        if old_base == base_name and original_number then
            return base_name .. "_" .. original_number
        else
            local variation_number = findNextAvailableVariationNumber(base_name)
            return base_name .. variation_number
        end
    end

    -- Branch 1: Rename items selected in imgui table
    if rename_selected_items then
        -- Get items from selected_items table in order
        local ordered_items = {}
        for item, _ in pairs(selected_items) do
            table.insert(ordered_items, item)
        end
        
        -- Sort them by position
        table.sort(ordered_items, function(a, b)
            return reaper.GetMediaItemInfo_Value(a, "D_POSITION") < reaper.GetMediaItemInfo_Value(b, "D_POSITION")
        end)
        
        -- Process selected items
        for _, item in ipairs(ordered_items) do
            local take = reaper.GetActiveTake(item)
            local _, old_name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            
            local new_name = getNewName(old_name, base_name)
            
            -- Update item name and note
            reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)
            reaper.ULT_SetMediaItemNote(item, "RENDER ITEM" .. " " .. "CH: " .. tostring(num_channels))
            
            -- Update or create region
            local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            
            local region_index = findRegionIndexByName(old_name)
            if region_index then
                reaper.SetProjectMarker(region_index, true, item_start, item_end, new_name)
            else
                reaper.AddProjectMarker2(0, true, item_start, item_end, new_name, -1, 0)
            end
        end
        
        detectFolderItemsAndRegions()
        return
    end

    -- Branch 2: Process timeline items
    if not rename_selected_items then
        reaper.Main_OnCommand(0, 40290) -- make time selection
    end
    
    -- Get time selection
    local time_start, time_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if time_end - time_start == 0 then
        reaper.MB("Please make a time selection", "Error", 0)
        return
    end
    
    -- Find all selected items within time selection
    local all_items = {}
    local num_selected_items = reaper.CountSelectedMediaItems(0)
    for i = 0, num_selected_items - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        
        if (item_start < time_end and item_end > time_start) then
            table.insert(all_items, item)
        end
    end

    if #all_items == 0 then
        -- If no items in time selection, create new regions
        if no_suffix then
            -- Create region without suffix
            reaper.AddProjectMarker2(0, true, time_start, time_end, base_name, -1, 0)
        else
            -- Create regions with original numbering
            createRegions(base_name)
        end
        return
    end

    -- GROUP ITEMS BY TOPMOST FOLDER TRACK FIRST
    local items_by_folder = {}
    for _, item in ipairs(all_items) do
        local track = reaper.GetMediaItem_Track(item)
        local parent_track = getTopMostFolderTrack(track)
        
        if not parent_track then
            reaper.MB("Selected item(s) do not have parent tracks. Please ensure all items belong to a track within a folder.", "Error", 0)
            return
        end
        
        if not items_by_folder[parent_track] then
            items_by_folder[parent_track] = {}
        end
        
        table.insert(items_by_folder[parent_track], item)
    end

    -- NOW PROCESS EACH FOLDER TRACK SEPARATELY
    for parent_track, items in pairs(items_by_folder) do
        -- Sort items by position within this folder track
        table.sort(items, function(a, b)
            return reaper.GetMediaItemInfo_Value(a, "D_POSITION") < reaper.GetMediaItemInfo_Value(b, "D_POSITION")
        end)

        -- Create stacks within this folder track based on temporal overlap
        local stacks = {}
        local current_stack = {}
        local current_stack_end = 0
       
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
       
        -- Process each stack within this folder track
        for _, stack in ipairs(stacks) do
            local stack_start = math.huge
            local stack_end = 0
            local existing_folder_item = nil
           
            -- Find stack boundaries
            for _, item in ipairs(stack) do
                local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                stack_start = math.min(stack_start, item_start)
                stack_end = math.max(stack_end, item_end)
            end
           
            -- Check for existing folder item in this parent track
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
           
            if existing_folder_item then
                -- Get the old name first
                local old_take = reaper.GetActiveTake(existing_folder_item)
                local _, old_name = reaper.GetSetMediaItemTakeInfo_String(old_take, "P_NAME", "", false)
                
                -- Get new name using helper function
                local new_name = getNewName(old_name, base_name)
               
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
                local new_name = no_suffix and base_name or (base_name .. findNextAvailableVariationNumber(base_name))
                createFolderItem(stack_start, stack_end, new_name, parent_track)
                reaper.AddProjectMarker2(0, true, stack_start, stack_end, new_name, -1, 0)
            end
        end
    end
    
    detectFolderItemsAndRegions()
end



-----------------------------------------------------------------------------------------------------------------
------------------------SHOULD UPDATE DETECTION--------------------------
-----------------------------------------------------------------------------------------------------------------


function shouldUpdateDetection()
    local current_change_count = reaper.GetProjectStateChangeCount(0)
    if current_change_count ~= last_project_change_count then
        last_project_change_count = current_change_count
        return true
    end
    return false
end


-----------------------------------------------------------------------------------------------------------------
------------------------NEXT AVAILABLE NUMBER----------------------------
-----------------------------------------------------------------------------------------------------------------

function findNextAvailableVariationNumber(base_name)
    -- Check if base_name is valid
    if not base_name or base_name == "" then
        return "_" .. pref_variaton_start_number  -- Return default if base_name is nil or empty
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
    local number = pref_variaton_start_number
    while used_numbers[number] do
        number = number + 1
    end
   
    return string.format("_%02d", number)
end


-----------------------------------------------------------------------------------------------------------------
------------------------PREFERENCES WINDOW----------------------------
-----------------------------------------------------------------------------------------------------------------


function preferencesWindow()
    if not preferences_window then return end

    StyleManager.PushStyle(ctx)
    reaper.ImGui_PushFont(ctx, base_font, 11)
    local should_display
    should_display, preferences_window = reaper.ImGui_Begin(ctx, 'PREFERENCES', preferences_window, reaper.ImGui_WindowFlags_AlwaysAutoResize())
   
    if should_display then
        reaper.ImGui_Dummy(ctx, 0, 5)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_PushFont(ctx, base_font, 13)
        reaper.ImGui_Text(ctx, "RENDERING")
        reaper.ImGui_PopFont(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Dummy(ctx, 0, 5)
       
        changed, use_inner_render_path = reaper.ImGui_Checkbox(ctx, "##inner_path", use_inner_render_path)
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_Text(ctx, ":Project folder render path?:")
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_SetNextItemWidth(ctx, 85)
        _, pref_inner_render_folder = reaper.ImGui_InputText(ctx, "##project_folder_render_path", pref_inner_render_folder)
       
        changed, use_additional_render_path = reaper.ImGui_Checkbox(ctx, "##additional_path", use_additional_render_path)

        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_Text(ctx, ":Extra outer render path?:")

        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_Dummy(ctx, 12,0)
        reaper.ImGui_SameLine(ctx)
       
        if reaper.ImGui_Button(ctx, "Browse", 85) then
            local retval, path = reaper.JS_Dialog_BrowseForFolder(0, "Select Render Path")
            if retval then
                additional_render_path = path
            end
        end
       
        reaper.ImGui_PushFont(ctx, base_font, 13)
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_Text(ctx, " - Path: " .. additional_render_path)
        reaper.ImGui_PopFont(ctx)
        
        _, render_via_master = reaper.ImGui_Checkbox(ctx, "##render_via_master", render_via_master)
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_Text(ctx, ":Render with Master Track processing")
       
        reaper.ImGui_Dummy(ctx, 0, 5)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_PushFont(ctx, base_font, 13)
        reaper.ImGui_Text(ctx, "NAMING CONVENTION")
        reaper.ImGui_PopFont(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Dummy(ctx, 0, 5)
       
        reaper.ImGui_SetNextItemWidth(ctx, 100)
        _, pref_variaton_start_number = reaper.ImGui_InputInt(ctx, " :Variation start number", pref_variaton_start_number)
        
        reaper.ImGui_Dummy(ctx, 0, 5)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_PushFont(ctx, base_font, 13)
        reaper.ImGui_Text(ctx, "WWISE SETTINGS")
        reaper.ImGui_PopFont(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Dummy(ctx, 0, 5)
        
        changed, ww_project_only_render = reaper.ImGui_Checkbox(ctx, "##ww_project_only_render", ww_project_only_render)
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_Text(ctx, ":Render only to project directory when importing to WWise")
       
        reaper.ImGui_Dummy(ctx, 0, 5)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_PushFont(ctx, base_font, 13)
        reaper.ImGui_Text(ctx, "OTHER")
        reaper.ImGui_PopFont(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Dummy(ctx, 0, 5)
        
        changed, ignore_muted_items_when_adj = reaper.ImGui_Checkbox(ctx, "##ignore_muted_clips_when_adjusting", ignore_muted_items_when_adj)
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_Text(ctx, ":When using ADJ! ignore existence of muted items. Folder items and regions will be adjusted to unmuted items.")
        
        reaper.ImGui_Dummy(ctx, 0, 5)
        
        -- Save button
        if reaper.ImGui_Button(ctx, "Save Settings") then
            SaveSettingsToCSV()
            preferences_window = false
        end
       
        reaper.ImGui_End(ctx)
    end
    StyleManager.PopStyle(ctx)
    reaper.ImGui_PopFont(ctx)
end



-----------------------------------------------------------------------------------------------------------------
------------------------FILTERING STUFF----------------------------
-----------------------------------------------------------------------------------------------------------------

function itemMatchesFilter(item_name, filter)
    -- Return true immediately if filter is empty
    if filter == "" then return true end
    
    -- Convert both to lowercase for case-insensitive comparison
    local lower_name = string.lower(item_name)
    local lower_filter = string.lower(filter)
    
    -- Split filter into individual words
    local words = {}
    for word in lower_filter:gmatch("%S+") do
        table.insert(words, word)
    end
    
    -- Check if all words appear in the item name
    for _, word in ipairs(words) do
        if not lower_name:find(word, 1, true) then
            return false  -- This word wasn't found, so not a match
        end
    end
    
    -- All words were found
    return true
end

-----------------------------------------------------------------------------------------------------------------
------------------------COLLECT SELECTED ITEMS INFO----------------------------
-----------------------------------------------------------------------------------------------------------------

function collectSelectedItemsInfo()
    local items_info = {}
    for selected_item, properties in pairs(selected_items) do
        local active_take = reaper.GetActiveTake(selected_item)
        if active_take then
            local _, item_name = reaper.GetSetMediaItemTakeInfo_String(active_take, "P_NAME", "", false)
            table.insert(items_info, {
                name = item_name,
                item = selected_item,
                type = "render_item",
                second_pass = properties.second_pass,
                path_override = properties.path_override  -- Include path override
            })
        end
    end
    return items_info
end

------------------------------------------------------------------ Copy items name      ------------------------------------------------------------------

function copyItemName(item)
    local take = reaper.GetActiveTake(item)
    if take then
        local _, item_name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        reaper.CF_SetClipboard(item_name)
    end
end

------------------------------------------------------------------ Paste name to item(s) ------------------------------------------------------------------

function pasteNameToItems()
    local clipboard = reaper.CF_GetClipboard()
    if clipboard and clipboard ~= "" then
        for item, _ in pairs(selected_items) do
            local take = reaper.GetActiveTake(item)
            if take then
                reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", clipboard, true)
                
                -- Update region name if it exists
                local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                local old_name = reaper.GetTakeName(take)
                local region_index = findRegionIndexByName(old_name)
                if region_index then
                    reaper.SetProjectMarker(region_index, true, item_start, item_end, clipboard)
                end
            end
        end
    end
end


------------------------------------------------------------------ Change channel count ------------------------------------------------------------------

function changeChannelCount(items, new_channel_count)
    for _, item in ipairs(items) do
        if item then
            reaper.ULT_SetMediaItemNote(item, "RENDER ITEM" .. " " .. "CH: " .. tostring(new_channel_count))
        end
    end
    updateRenderQueue()
end

----------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------
-------------%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%               ITEM CONTEX MENU                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%--------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------

function showItemContextMenu(item)
    if reaper.ImGui_BeginPopup(ctx, "ItemContextMenu") then
    
        if reaper.ImGui_MenuItem(ctx, "Render selected       | RDR!") then
            renderQueuedRegions()
        end
        
        reaper.ImGui_Separator(ctx)
        
        if reaper.ImGui_MenuItem(ctx, "Unselect items        | CLR!") then
            clearSelectedItems()
        end
        if reaper.ImGui_MenuItem(ctx, "Adjust all items      | ADJ!") then
            adjustFolderItems(false)
        end
        if reaper.ImGui_MenuItem(ctx, "Adjust selected items | alt + ADJ!") then
            adjustFolderItems(true)
        end
        
        reaper.ImGui_Separator(ctx)
        
        -- Copy name option (only from right-clicked item)
        if reaper.ImGui_MenuItem(ctx, "Copy name  | ctrl + C | " .. reaper.GetTakeName(reaper.GetActiveTake(item))) then
            copyItemName(item)
        end
        
        -- Paste name option (applies to ALL selected items)
        local clipboard = reaper.CF_GetClipboard()
        if reaper.ImGui_MenuItem(ctx, "Paste name | ctrl + V | selected items only", nil, false, clipboard and clipboard ~= "") then
            pasteNameToItems()
        end
        if reaper.ImGui_MenuItem(ctx, "Rename selected items | alt + NME!") then
            adjustFolderItems(true)
        end
        
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xff73ffFF)
        -- Toggle second pass (applies to ALL selected items)
        local is_second_pass = selected_items[item] and selected_items[item].second_pass
        if reaper.ImGui_MenuItem(ctx, "Toggle second pass    | alt + click/drag", nil, is_second_pass) then
            -- Apply to ALL selected items
            for selected_item, props in pairs(selected_items) do
                if not props then
                    selected_items[selected_item] = {}
                end
                selected_items[selected_item].second_pass = not (props.second_pass or false)
            end
            updateRenderQueue()
        end
        reaper.ImGui_PopStyleColor(ctx)
        
        
        reaper.ImGui_Separator(ctx)
        
        -- Channel count submenu (applies to ALL selected items)
        local note = reaper.ULT_GetMediaItemNote(item)
        local current_channels = note:match("CH: (%d+)") or "2"
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xfffb5dFF)
        if reaper.ImGui_BeginMenu(ctx, "Channel count: " .. current_channels, true) then
            local common_counts = {"1", "2", "3", "4", "6", "8"}
            for _, count in ipairs(common_counts) do
                if reaper.ImGui_MenuItem(ctx, count, nil, count == current_channels) then
                    local items_to_change = {}
                    for selected_item, _ in pairs(selected_items) do
                        table.insert(items_to_change, selected_item)
                    end
                    changeChannelCount(items_to_change, count)
                end
            end
            
            -- Custom channel count option
            if reaper.ImGui_MenuItem(ctx, "Custom...") then
                local ret, user_input = reaper.GetUserInputs("Channel Count", 1, "Number of Channels:", current_channels)
                if ret then
                    local new_count = tonumber(user_input)
                    if new_count and new_count > 0 then
                        local items_to_change = {}
                        for selected_item, _ in pairs(selected_items) do
                            table.insert(items_to_change, selected_item)
                        end
                        changeChannelCount(items_to_change, new_count)
                    end
                end
            end
            
            reaper.ImGui_EndMenu(ctx)
        end
        reaper.ImGui_PopStyleColor(ctx)
        
        reaper.ImGui_Separator(ctx)
        
        -- Jump to item option (only for right-clicked item)
        if reaper.ImGui_MenuItem(ctx, "Jump to item | " .. reaper.GetTakeName(reaper.GetActiveTake(item))) then
            jumpToItemInTimeline(item)
        end
        
        reaper.ImGui_Separator(ctx)
        
        -- Delete option (applies to ALL selected items)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xFF6666FF)
        if reaper.ImGui_MenuItem(ctx, "Delete | hold del 1 sec") then
            deleteSelectedItems()
        end
        reaper.ImGui_PopStyleColor(ctx)
        
        reaper.ImGui_EndPopup(ctx)
    end
end

function jumpToItemInTimeline(item)
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local track_of_item = reaper.GetMediaItem_Track(item)
    reaper.Main_OnCommand(40297, 0)
    reaper.SetTrackSelected(track_of_item, true)
    reaper.SetEditCurPos(item_start, true, false)
    reaper.Main_OnCommand(40913,0)
    reaper.UpdateArrange()  -- Refresh REAPER's arrange view
end

-- Function to handle importing to selected Wwise object
function handleImportToSelectedWwise(browse_for_path)
    -- Check if we have selected items to import
    if not next(selected_items) then
        reaper.MB("No items selected for import", "Error", 0)
        return
    end
    
    if not ww_connection_status then
        ww_connection_status, ww_proj_name = wwiseConnect()
        if not ww_connection_status then
            reaper.MB("Failed to connect to WWise", "Error", 0)
            return false
        end
    end
    
    local selected_wwise_objects = nil
    if ww_connection_status then
        selected_wwise_objects = wwiseGetSelected()
    end
    
    if not selected_wwise_objects or #selected_wwise_objects == 0 then
        reaper.MB("No objects selected in Wwise", "Error", 0)
        return
    end
    
    if #selected_wwise_objects > 1 then
        reaper.MB("Please select only one object in Wwise", "Error", 0)
        return
    end
    
    local selected_object = selected_wwise_objects[1]
    
    -- Check if the selected object is a valid container type
    local valid_types = {
        "ActorMixer", "RandomSequenceContainer", "SwitchContainer", 
        "BlendContainer", "Folder", "WorkUnit"
    }
    
    local is_valid = false
    for _, valid_type in ipairs(valid_types) do
        if selected_object.type == valid_type then
            is_valid = true
            break
        end
    end
    
    if not is_valid then
        reaper.MB("Selected Wwise object (" .. selected_object.type .. ") cannot contain sounds.\nPlease select a container, folder, or work unit.", "Invalid Target", 0)
        return
    end
    
    -- Convert selected items to the format expected by the import function
    local items_to_import = collectSelectedItemsInfo()
    
    -- Handle path browsing if requested
    local custom_path = nil
    if browse_for_path then
        -- Get Wwise originals folder as starting point
        local wwise_originals_path = wwiseGetOriginalsFolder()
        if not wwise_originals_path or wwise_originals_path == "" then
            wwise_originals_path = ""
        end
        
        local retval, selected_path = reaper.JS_Dialog_BrowseForFolder("Select file storage location", wwise_originals_path)
        if retval ~= 1 or selected_path == "" then
            return -- User cancelled
        end
        custom_path = selected_path
        
        -- Add custom path to each item
        for _, item_info in ipairs(items_to_import) do
            item_info.path_override = custom_path
        end
    else
        -- No browsing - get existing sounds with their file paths
        local sound_names = {}
        for _, item_info in ipairs(items_to_import) do
            table.insert(sound_names, item_info.name)
        end
        
        -- Use the existing function to get sounds with paths
        local existing_sounds = wwiseGetExistingSoundsWithPaths(sound_names, selected_object.path)
        
        -- Apply the existing paths to matching items
        for _, item_info in ipairs(items_to_import) do
            if existing_sounds[item_info.name] and #existing_sounds[item_info.name] > 0 then
                local existing_sound = existing_sounds[item_info.name][1]
                if existing_sound.file_path then
                    -- Extract directory from full file path
                    local dir_path = existing_sound.file_path:match("(.+)[\\/][^\\/]+$")
                    if dir_path then
                        item_info.path_override = dir_path
                        --print(string.format("Using existing path for '%s': %s", item_info.name, dir_path))
                    end
                end
            end
        end
    end
    
    -- Show confirmation prompt
    local path_info = custom_path and ("\nFile storage: " .. custom_path) or ""
    local msg = "Import to:\n" .. selected_object.path .. path_info .. "\n\nItems to import: " .. #items_to_import
    local result = reaper.MB(msg, "Confirm Import", 1)
    
    if result ~= 1 then
        return
    end
    
    -- Import based on whether we have custom paths
    if browse_for_path then
        -- Custom path - check conflicts FIRST, then render during import
        importWithConflictCheck(items_to_import, selected_object.path, {
            path_override = custom_path
        })
    else
        -- No custom path - render then import (no conflicts expected)
        local regular_items, second_pass_items = separateItemsBySecondPass(items_to_import)
        
        if #regular_items > 0 then
            renderItems(regular_items)
        end
        if #second_pass_items > 0 then
            renderItems(second_pass_items)
        end
        
        wwiseImportAudio(items_to_import, selected_object.path, {
            skip_conflict_check = true
        })
    end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------
-------------%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%               RENDER ITEM TABLE               %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%--------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------

function renderItemTable(num_tracks)
    local table_flags = reaper.ImGui_TableFlags_SizingFixedFit() |
                        reaper.ImGui_TableFlags_Resizable() |
                        reaper.ImGui_TableFlags_BordersV() |
                        reaper.ImGui_SelectableFlags_SpanAllColumns() |
                        reaper.ImGui_TableFlags_ScrollX()
                        
    if num_tracks ~= 0 and reaper.ImGui_BeginTable(ctx, "regionRenderTable", num_tracks, table_flags) then
        -- Set up columns
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
        
        filtered_items = {} -- Reset filtered items
        
        -- First pass: collect filtered items and find max length
        for folder_track, items in pairs(track_folder_map) do
            filtered_items[folder_track] = {}
            for _, item in ipairs(items) do
                local active_take = reaper.GetActiveTake(item)
                if active_take then
                    local _, item_name = reaper.GetSetMediaItemTakeInfo_String(active_take, "P_NAME", "", false)
                    if itemMatchesFilter(item_name, filter_text) then
                        table.insert(filtered_items[folder_track], item)
                    end
                end
            end
            if #filtered_items[folder_track] > max_items then
                max_items = #filtered_items[folder_track]
            end
        end
        
        -- Get keyboard modifier states
        local ctrl_pressed = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl())
        local shift_pressed = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftShift())
        local alt_pressed = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftAlt())
        
        -- Handle mouse events
        local mouse_clicked = reaper.ImGui_IsMouseClicked(ctx, 0)
        local mouse_released = reaper.ImGui_IsMouseReleased(ctx, 0)
        local mouse_dragging = reaper.ImGui_IsMouseDragging(ctx, 0)
        local mouse_pos_x, mouse_pos_y = reaper.ImGui_GetMousePos(ctx)
        
        -- Get current scroll position
        local current_scroll_y = reaper.ImGui_GetScrollY(ctx)
        
        local clicked_item = nil
        
        -- Drag state management
        local drag_threshold = 3 -- pixels
        
        -- Start potential drag (but not if shift is pressed - that's for Wwise)
        if mouse_clicked and not reaper.ImGui_IsAnyItemActive(ctx) and not shift_pressed then
            -- Check if mouse is within the "tabela" child window
            if reaper.ImGui_IsWindowHovered(ctx, reaper.ImGui_HoveredFlags_ChildWindows()) then
                drag_start_pos = {mouse_pos_x, mouse_pos_y}
                drag_start_scroll_y = current_scroll_y  -- Capture scroll position at drag start
                drag_clicked_item = nil -- Will be set when we find which item was clicked
                drag_selection_snapshot = {} -- Store selection state at drag start
            end
        end
        
        -- Determine if we're actually dragging (moved beyond threshold). Don't consider it dragging if shift is pressed (that's for Wwise drag)
        local currently_dragging = false
        if drag_start_pos and mouse_dragging and not shift_pressed then
            local dx = math.abs(mouse_pos_x - drag_start_pos[1])
            local dy = math.abs(mouse_pos_y - drag_start_pos[2])
            if dx > drag_threshold or dy > drag_threshold then
                if not is_dragging then
                    -- Just started dragging
                    is_dragging = true
                    
                    -- Store original selection state
                    for item, props in pairs(selected_items) do
                        drag_selection_snapshot[item] = {
                            second_pass = props.second_pass or false
                        }
                    end
                end
                currently_dragging = true
            end
        end
        
        -- End drag
        if mouse_released then
            if is_dragging then
                is_dragging = false
                updateRenderQueue()
            end
            drag_start_pos = nil
            drag_clicked_item = nil
            drag_selection_snapshot = {}
            drag_start_scroll_y = 0
        end
        
        -- Calculate current drag rectangle if dragging
        local drag_rect = nil
        if currently_dragging and drag_start_pos then
            -- Calculate scroll offset
            local scroll_offset = current_scroll_y - drag_start_scroll_y
            
            -- Adjust start position for scroll
            local adjusted_start_y = drag_start_pos[2] - scroll_offset
            
            local start_x = drag_start_pos[1]
            drag_rect = {
                min_x = math.min(start_x, mouse_pos_x),
                min_y = math.min(adjusted_start_y, mouse_pos_y),
                max_x = math.max(start_x, mouse_pos_x),
                max_y = math.max(adjusted_start_y, mouse_pos_y)
            }
        end
        
        -- Track which items are currently in drag rectangle
        local items_in_current_drag_rect = {}
        
        -- Render the table rows
        for item_idx = 1, max_items do
            reaper.ImGui_TableNextRow(ctx)
            for column_index, folder_track in ipairs(sorted_folder_tracks) do
                reaper.ImGui_TableSetColumnIndex(ctx, column_index - 1)
                
                local items = filtered_items[folder_track]
                local item = items[item_idx]
                
                if item then
                    local active_take = reaper.GetActiveTake(item)
                    if active_take then
                        local _, item_name = reaper.GetSetMediaItemTakeInfo_String(active_take, "P_NAME", "", false)
                        local note = reaper.ULT_GetMediaItemNote(item)
                        local item_display = string.format("%s", item_name or "Unnamed")
                        local is_selected = selected_items[item] ~= nil
                        
                        -- Apply styling for items
                        local colors_pushed = 0
                        if is_selected then
                            -- Selected item colors
                            local base_color = selected_items[item].second_pass and
                                StyleManager.style.dynamic_colors.second_pass or
                                StyleManager.style.dynamic_colors.selected
                            
                            -- Make hover color brighter for selected items
                            local hover_color = base_color | 0x20202000  -- Add brightness
                            
                            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), base_color)
                            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), hover_color)
                            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), base_color)
                            colors_pushed = 3
                        else
                            -- Unselected item colors - only set hover to be dimmer than selected
                            local dim_hover_color = 0x4A4A4AFF  -- Dimmer than selected items
                            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), dim_hover_color)
                            colors_pushed = 1
                        end
                        
                        -- Render the selectable item
                        local item_clicked = reaper.ImGui_Selectable(ctx, item_display, is_selected)
                        
                        -- Get item rectangle
                        local item_min_x, item_min_y = reaper.ImGui_GetItemRectMin(ctx)
                        local item_max_x, item_max_y = reaper.ImGui_GetItemRectMax(ctx)
                        
                        -- Track if mouse is over table
                        mouse_over_table = false
                        if reaper.ImGui_IsItemHovered(ctx) then
                            mouse_over_table = true
                        end 
                        
                        -- Determine if this item was clicked at drag start (only for selection drag, not Wwise drag)
                        if drag_start_pos and not shift_pressed then
                            -- Adjust for scroll when checking initial click
                            local adjusted_start_y = drag_start_pos[2] - (current_scroll_y - drag_start_scroll_y)
                            local start_x = drag_start_pos[1]
                            if (item_min_x <= start_x and item_max_x >= start_x and 
                                item_min_y <= adjusted_start_y and item_max_y >= adjusted_start_y) then
                                drag_clicked_item = item
                            end
                        end
                        
                        -- Check if item is in current drag rectangle (only for selection drag)
                        if drag_rect then
                            local item_in_rect = (item_min_x <= drag_rect.max_x and item_max_x >= drag_rect.min_x and 
                                                 item_min_y <= drag_rect.max_y and item_max_y >= drag_rect.min_y)
                            if item_in_rect then
                                items_in_current_drag_rect[item] = true
                            end
                        end
                        
                        -- Handle click (only if not dragging)
                        if item_clicked and not currently_dragging then
                            clicked_item = item
                            
                            if shift_pressed and last_selected_item then
                                -- Shift+click: Range selection (Windows style)
                                -- Find all items between last_selected_item and current item
                                local range_items = {}
                                local start_found = false
                                local end_found = false
                                local start_item = last_selected_item
                                local end_item = item
                                
                                -- Search through all filtered items to find the range
                                for _, folder_track in ipairs(sorted_folder_tracks) do
                                    local items = filtered_items[folder_track]
                                    for _, range_item in ipairs(items) do
                                        -- Check if we found either endpoint
                                        if range_item == start_item or range_item == end_item then
                                            if not start_found then
                                                start_found = true
                                                table.insert(range_items, range_item)
                                            elseif not end_found then
                                                end_found = true
                                                table.insert(range_items, range_item)
                                                break
                                            end
                                        elseif start_found and not end_found then
                                            -- We're in the middle of the range
                                            table.insert(range_items, range_item)
                                        end
                                    end
                                    if end_found then break end
                                end
                                
                                -- If we didn't find both endpoints, try reverse order
                                if not end_found then
                                    range_items = {}
                                    start_found = false
                                    end_found = false
                                    start_item = item
                                    end_item = last_selected_item
                                    
                                    for _, folder_track in ipairs(sorted_folder_tracks) do
                                        local items = filtered_items[folder_track]
                                        for _, range_item in ipairs(items) do
                                            if range_item == start_item or range_item == end_item then
                                                if not start_found then
                                                    start_found = true
                                                    table.insert(range_items, range_item)
                                                elseif not end_found then
                                                    end_found = true
                                                    table.insert(range_items, range_item)
                                                    break
                                                end
                                            elseif start_found and not end_found then
                                                table.insert(range_items, range_item)
                                            end
                                        end
                                        if end_found then break end
                                    end
                                end
                                
                                -- Select all items in the range (additive to existing selection)
                                for _, range_item in ipairs(range_items) do
                                    if not selected_items[range_item] then
                                        selected_items[range_item] = {}
                                        table.insert(selected_items_list, range_item)
                                    end
                                    
                                    -- Apply Alt modifier if active
                                    if alt_pressed then
                                        selected_items[range_item].second_pass = not (selected_items[range_item].second_pass or false)
                                    end
                                end
                                
                            elseif ctrl_pressed then
                                -- Ctrl+click: Toggle selection
                                if is_selected then
                                    if alt_pressed then
                                        -- Ctrl+Alt+click on selected: toggle second_pass, keep selected
                                        selected_items[item].second_pass = not (selected_items[item].second_pass or false)
                                    else
                                        -- Ctrl+click on selected: unselect
                                        selected_items[item] = nil
                                        for i, v in ipairs(selected_items_list) do
                                            if v == item then
                                                table.remove(selected_items_list, i)
                                                break
                                            end
                                        end
                                    end
                                else
                                    -- Ctrl+click on unselected: select it
                                    selected_items[item] = {}
                                    table.insert(selected_items_list, item)
                                    if alt_pressed then
                                        selected_items[item].second_pass = true
                                    end
                                end
                            else
                                -- Normal click: different behavior for selected vs unselected
                                if is_selected then
                                    if alt_pressed then
                                        -- Alt+click on selected: toggle second_pass, keep selected
                                        selected_items[item].second_pass = not (selected_items[item].second_pass or false)
                                    else
                                        -- Normal click on selected: unselect it
                                        selected_items[item] = nil
                                        for i, v in ipairs(selected_items_list) do
                                            if v == item then
                                                table.remove(selected_items_list, i)
                                                break
                                            end
                                        end
                                    end
                                else
                                    -- Click on unselected item: select only this item
                                    selected_items = {}
                                    selected_items_list = {}
                                    selected_items[item] = {}
                                    table.insert(selected_items_list, item)
                                    if alt_pressed then
                                        selected_items[item].second_pass = true
                                    end
                                end
                            end
                            
                            -- Update last_selected_item for future shift+clicks
                            last_selected_item = item
                            updateRenderQueue()
                        end
                        
                        -- Handle right-click for context menu
                        if reaper.ImGui_IsItemClicked(ctx, 1) then
                            if not selected_items[item] then
                                selected_items = {}
                                selected_items_list = {}
                                selected_items[item] = {}
                                table.insert(selected_items_list, item)
                                updateRenderQueue()
                            end
                            
                            reaper.ImGui_OpenPopup(ctx, "ItemContextMenu")
                            context_menu_item = item
                        end
                        
                        
                        -- Show tooltip on hover
                        if reaper.ImGui_IsItemHovered(ctx) then
                            reaper.ImGui_BeginTooltip(ctx)
                            local num_channels = note:match("CH: (%d+)") or "2"
                            reaper.ImGui_Text(ctx, "Ch: " .. num_channels)
                            reaper.ImGui_EndTooltip(ctx)
                        end
                        
                        -- Pop styling colors
                        if colors_pushed > 0 then
                            reaper.ImGui_PopStyleColor(ctx, colors_pushed)
                        end
                    end
                else
                    reaper.ImGui_Text(ctx, "")
                end
            end
        end
        
        -- Apply drag selection if currently dragging (selection drag only, not Wwise drag)
        if currently_dragging then
            
            if drag_clicked_item == nil then
                -- CASE 1: Drag started from empty space (table background)
                if ctrl_pressed then
                    -- Ctrl+drag from empty: Additive selection - keep existing selection and add items in rect
                    for item, _ in pairs(items_in_current_drag_rect) do
                        if not selected_items[item] then
                            selected_items[item] = {}
                            table.insert(selected_items_list, item)
                            if alt_pressed then
                                selected_items[item].second_pass = true
                            end
                        end
                    end
                else
                    -- Normal drag from empty: Replace selection - select only items in rect
                    selected_items = {}
                    selected_items_list = {}
                    for item, _ in pairs(items_in_current_drag_rect) do
                        selected_items[item] = {}
                        table.insert(selected_items_list, item)
                        if alt_pressed then
                            selected_items[item].second_pass = true
                        end
                    end
                end
                
            else
                -- CASES 2 & 3: Drag started from an item
                local drag_started_from_selected = (drag_selection_snapshot[drag_clicked_item] ~= nil)
                
                if ctrl_pressed then
                    -- Ctrl+drag from item: Behavior depends on whether item was selected
                    selected_items = {}
                    selected_items_list = {}
                    
                    -- Restore original selection
                    for item, props in pairs(drag_selection_snapshot) do
                        selected_items[item] = {second_pass = props.second_pass}
                        table.insert(selected_items_list, item)
                    end
                    
                    if drag_started_from_selected then
                        -- Ctrl+drag from selected item: Can only UNSELECT items in drag rect
                        for item, _ in pairs(items_in_current_drag_rect) do
                            if selected_items[item] then
                                if alt_pressed then
                                    -- Alt+Ctrl+drag from selected: toggle second_pass on selected items in rect
                                    selected_items[item].second_pass = not (selected_items[item].second_pass or false)
                                else
                                    -- Ctrl+drag from selected: remove from selection
                                    selected_items[item] = nil
                                    for i, v in ipairs(selected_items_list) do
                                        if v == item then
                                            table.remove(selected_items_list, i)
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    else
                        -- Ctrl+drag from unselected item: Can only SELECT items in drag rect
                        for item, _ in pairs(items_in_current_drag_rect) do
                            if not selected_items[item] then
                                selected_items[item] = {}
                                table.insert(selected_items_list, item)
                                if alt_pressed then
                                    selected_items[item].second_pass = true
                                end
                            end
                        end
                    end
                    
                elseif drag_started_from_selected then
                    -- CASE 2: Drag from selected item without Ctrl: Unselect items in drag rect
                    selected_items = {}
                    selected_items_list = {}
                    
                    -- Start with original selection
                    for item, props in pairs(drag_selection_snapshot) do
                        selected_items[item] = {second_pass = props.second_pass}
                        table.insert(selected_items_list, item)
                    end
                    
                    -- Handle items in drag rectangle
                    for item, _ in pairs(items_in_current_drag_rect) do
                        if selected_items[item] then
                            if alt_pressed then
                                -- Alt+drag from selected: toggle second_pass on selected items in rect
                                selected_items[item].second_pass = not (selected_items[item].second_pass or false)
                            else
                                -- Normal drag from selected: unselect items in rect
                                selected_items[item] = nil
                                for i, v in ipairs(selected_items_list) do
                                    if v == item then
                                        table.remove(selected_items_list, i)
                                        break
                                    end
                                end
                            end
                        end
                    end
                    
                else
                    -- CASE 3: Drag from unselected item without Ctrl: Select only items in drag rect
                    selected_items = {}
                    selected_items_list = {}
                    
                    for item, _ in pairs(items_in_current_drag_rect) do
                        selected_items[item] = {}
                        table.insert(selected_items_list, item)
                        if alt_pressed then
                            selected_items[item].second_pass = true
                        end
                    end
                end
            end
        end

        -- Handle keyboard shortcuts
        if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl()) and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_C()) then
            if #selected_items_list > 0 then
                local last_item = selected_items_list[#selected_items_list]
                copyItemName(last_item)
            end
        end
        
        if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl()) and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_V()) then
            if reaper.ImGui_IsWindowHovered(ctx) and not reaper.ImGui_IsAnyItemActive(ctx) then
                pasteNameToItems()
            end
        end
        
        if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_Delete()) then
            local duration = reaper.ImGui_GetKeyDownDuration(ctx, reaper.ImGui_Key_Delete())
            if duration > 1 then
                deleteSelectedItems()
            end
        end

        if context_menu_item then
            showItemContextMenu(context_menu_item)
        end
        
        reaper.ImGui_EndTable(ctx)
        
        -- Draw drag selection rectangle (only for selection drag, not Wwise drag)
        if currently_dragging and drag_rect then
            local draw_list = reaper.ImGui_GetForegroundDrawList(ctx)
            
            -- Get the table's clipping rectangle to constrain the drag rectangle
            local table_min_x, table_min_y = reaper.ImGui_GetItemRectMin(ctx)
            local table_max_x, table_max_y = reaper.ImGui_GetItemRectMax(ctx)
            
            -- Push a clip rect to constrain drawing to the table area
            reaper.ImGui_DrawList_PushClipRect(draw_list, table_min_x, table_min_y, table_max_x, table_max_y, true)
            
            -- Background fill (semi-transparent)
            reaper.ImGui_DrawList_AddRectFilled(draw_list, drag_rect.min_x, drag_rect.min_y, 
                                                drag_rect.max_x, drag_rect.max_y, 0x3030FF30)
            
            -- Border (more opaque)
            reaper.ImGui_DrawList_AddRect(draw_list, drag_rect.min_x, drag_rect.min_y, 
                                          drag_rect.max_x, drag_rect.max_y, 0x6060FFFF, 0, 0, 1.5)
            
            -- Pop the clip rect
            reaper.ImGui_DrawList_PopClipRect(draw_list)
        end
    end
end

-----------------------------------------------------------------------------------------------------------------
--------------------------LOOOOOOO---OOOOOOOOP---------------------------
-----------------------------------------------------------------------------------------------------------------

function loop()
    if shouldUpdateDetection() then
        detectFolderItemsAndRegions()
    end
    
    if visible then
        reaper.ImGui_SetNextWindowSizeConstraints(ctx, 544, 420, 1000, 1000)

        StyleManager.PushStyle(ctx)
        reaper.ImGui_PushFont(ctx, base_font, 11)

        local should_display
 
        should_display, visible = reaper.ImGui_Begin(ctx, 'NAME / RENDER / BE WELL - by Krzysztof Chodkiewicz', visible, window_flags)
       
        if should_display then
        
            -------------------------------------------------------------------------------------------------------------------------------------------
            ---------------------------SETTINGS
            -------------------------------------------------------------------------------------------------------------------------------------------
           
            reaper.ImGui_BeginChild(ctx, "SETTINGS", 350, 138, 0, reaper.ImGui_WindowFlags_None())
            reaper.ImGui_Indent(ctx, 8)
           
            reaper.ImGui_Dummy(ctx,0,4)
           
            reaper.ImGui_SetNextItemWidth(ctx, 100)
            changed, selected_bitdepth_index = reaper.ImGui_Combo(ctx, "##bitdepth", selected_bitdepth_index - 1, table.concat(render_bitdepths, "\0") .. "\0")
            selected_bitdepth_index = selected_bitdepth_index + 1
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Dummy(ctx,5,0)
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Text(ctx, ":BIT  /  SR:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Dummy(ctx,5,0)
           
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 106)
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 8, 8)
            changed, selected_sample_rate_index = reaper.ImGui_Combo(ctx, "##samplerate", selected_sample_rate_index - 1, table.concat(render_sample_rates, "\0") .. "\0")
            selected_sample_rate_index = selected_sample_rate_index + 1
            reaper.ImGui_PopStyleVar(ctx)
            reaper.ImGui_Dummy(ctx, 0, 0)
            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Dummy(ctx, 0, 0)
           
            changed, normalize_render = reaper.ImGui_Checkbox(ctx, "##:NRMZ?:", normalize_render)
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Dummy(ctx, 0, 0)
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Text(ctx, ":NRMZ?:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Dummy(ctx, 0, 0)

           
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 100)
            changed, normalization_volume = reaper.ImGui_SliderDouble(ctx, "##norm_vol", normalization_volume, -60, 0, "%.1f dB")
            -- Right-click for input
            if reaper.ImGui_IsItemClicked(ctx, 1) then
                reaper.ImGui_OpenPopup(ctx, "Edit Normalization Level")
            end
            if reaper.ImGui_BeginPopup(ctx, "Edit Normalization Level") then
                -- Set width and focus for the input
                reaper.ImGui_SetNextItemWidth(ctx, 50)
                if not popup_initialized then
                    reaper.ImGui_SetKeyboardFocusHere(ctx)
                    popup_initialized = true -- Ensure focus is set only once
                end
            
                -- Input for normalization level
                input_changed, normalization_volume = reaper.ImGui_InputDouble(ctx, "##Normalization(dB)", normalization_volume)
               
                if input_changed then
                    normalization_volume = normalization_volume
                end
            
                reaper.ImGui_EndPopup(ctx)
            else
                popup_initialized = false -- Ensure reset when popup is closed
            end
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Dummy(ctx, 0,0)
            reaper.ImGui_SameLine(ctx)
           
           

            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 106)
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 8, 8)
            changed, selected_normalization_index = reaper.ImGui_Combo(ctx, "##norm_type", selected_normalization_index - 1, table.concat(normalization_types, "\0") .. "\0")
            selected_normalization_index = selected_normalization_index + 1
            reaper.ImGui_PopStyleVar(ctx)
           
            reaper.ImGui_Dummy(ctx, 0, 0)
            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Dummy(ctx, 0, 0)
           
            changed, use_brickwall_limiter = reaper.ImGui_Checkbox(ctx, "##:LIMT?:", use_brickwall_limiter)
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Dummy(ctx, 0, 0)
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Text(ctx, ":LIMT?:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Dummy(ctx, 0, 0)
           
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 100)
            changed, brickwall_limit_threshold_db = reaper.ImGui_SliderDouble(ctx, "##limit_thresh_db", brickwall_limit_threshold_db, -12, 0, "%.2f dB")
            -- Right-click for input
            if reaper.ImGui_IsItemClicked(ctx, 1) then
                reaper.ImGui_OpenPopup(ctx, "Edit Limiter Level")
            end
            
            if reaper.ImGui_BeginPopup(ctx, "Edit Limiter Level") then
                -- Set width and focus for the input
                reaper.ImGui_SetNextItemWidth(ctx, 50)
                if not popup_initialized then
                    reaper.ImGui_SetKeyboardFocusHere(ctx)
                    popup_initialized = true -- Ensure focus is set only once
                end
            
                -- Input for normalization level
                input_changed, brickwall_limit_threshold_db = reaper.ImGui_InputDouble(ctx, "##Limiter(dB)", brickwall_limit_threshold_db)
               
                if input_changed then
                    brickwall_limit_threshold_db = brickwall_limit_threshold_db
                end
            
                reaper.ImGui_EndPopup(ctx)
            else
                popup_initialized = false -- Ensure reset when popup is closed
            end
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Dummy(ctx, 0,0)
            reaper.ImGui_SameLine(ctx)
           
           
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 106)
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 8, 8)
            changed, selected_brickwall_limiter_index = reaper.ImGui_Combo(ctx, "##limiter_type", selected_brickwall_limiter_index - 1, table.concat(brickwall_limiter_types, "\0") .. "\0")
            selected_brickwall_limiter_index = selected_brickwall_limiter_index + 1
            reaper.ImGui_PopStyleVar(ctx)
            reaper.ImGui_EndChild(ctx)
            reaper.ImGui_SameLine(ctx)
           
            -------------------------------------------------------------------------------------------------------------------------------------------
            ---------------------------BUTTONS
            -------------------------------------------------------------------------------------------------------------------------------------------
           
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 0, 0)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0xB84A62FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0xC55B73FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0xA13B53FF)
   
            reaper.ImGui_BeginChild(ctx, "BUTTONS", 52, 138, 0, reaper.ImGui_WindowFlags_None())
            reaper.ImGui_Indent(ctx, 8)
           
            reaper.ImGui_Dummy(ctx,4,6)
           
            reaper.ImGui_Dummy(ctx,0,18)
            
            adjust_selection = false
            if reaper.ImGui_Button(ctx, 'ADJ!',34,34) then
                
                if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then
                    adjust_selection = true
                else
                    adjust_selection = false
                end
                adjustFolderItems(adjust_selection)
            end
            
            if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Right()) then
                adjust_selection = true
                adjustFolderItems(adjust_selection)
            end
           
            reaper.ImGui_Dummy(ctx,0,12)
                       
            if reaper.ImGui_Button(ctx, "...", 34, 20) then
                preferences_window = not preferences_window
            end
            reaper.ImGui_Unindent(ctx)
           
            reaper.ImGui_EndChild(ctx)
            reaper.ImGui_PopStyleColor(ctx, 3)
            reaper.ImGui_PopStyleVar(ctx)
           
            
           
            reaper.ImGui_Dummy(ctx,0,0)
           
            -------------------------------------------------------------------------------------------------------------------------------------------
            ---------------------------NAME
            -------------------------------------------------------------------------------------------------------------------------------------------
           

            reaper.ImGui_BeginChild(ctx, "NAME", 460, 50, 0, reaper.ImGui_WindowFlags_None())
           
            reaper.ImGui_Dummy(ctx,0,4)
            reaper.ImGui_Indent(ctx, 8)
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 8, 10)
            reaper.ImGui_AlignTextToFramePadding(ctx)
            reaper.ImGui_Text(ctx, "N:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 254)
           
            if first_open then
                reaper.ImGui_SetKeyboardFocusHere(ctx)
                first_open = false
            end
           
            _, sound_name = reaper.ImGui_InputText(ctx, "##: NAME", sound_name)
            
            local set_focus_to_channels = false
            if reaper.ImGui_IsItemFocused(ctx) then
                if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) then
                    set_focus_to_channels = true
                end
            end
            
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Text(ctx, "CH:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 26)
            
            if set_focus_to_channels then
              reaper.ImGui_SetKeyboardFocusHere(ctx)
              set_focus_to_channels = false
            end
            
            rename_selected_items = false
            
            _, num_channels = reaper.ImGui_InputText(ctx, "##: CHANNELS", num_channels, reaper.ImGui_InputTextFlags_AlwaysOverwrite())
            if reaper.ImGui_IsItemFocused(ctx) then
                if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) then
                    if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then
                        rename_selected_items = true
                        nameRename(num_channels,rename_selected_items)
                    else
                        rename_selected_items = false
                        nameRename(num_channels,rename_selected_items)
                    end
                end
            end
            reaper.ImGui_PopStyleVar(ctx)
            
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Dummy(ctx,0,0)
            reaper.ImGui_SameLine(ctx)
            
            if reaper.ImGui_Button(ctx, 'NME!',34,34) then
                if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then
                    rename_selected_items = true
                else
                    rename_selected_items = false
                end
                nameRename(num_channels,rename_selected_items)
            end
            
            if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Right()) then
                rename_selected_items = true
                nameRename(num_channels,rename_selected_items)
            end
            
            rename_selected_items = false
            
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Dummy(ctx,0,0)
            reaper.ImGui_SameLine(ctx)
            
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0xB84A62FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0xC55B73FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0xA13B53FF)
            if reaper.ImGui_Button(ctx, 'RDR!',34,34) then
                renderQueuedRegions()
            end
            reaper.ImGui_PopStyleColor(ctx,3)
            
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Unindent(ctx)  
           
            reaper.ImGui_EndChild(ctx)
           

            reaper.ImGui_Dummy(ctx,0,0)
           
           -------------------------------------------------------------------------------------------------------------------------------------------
           ---------------------------TABLE HEADER
           -------------------------------------------------------------------------------------------------------------------------------------------          
           
            reaper.ImGui_BeginChild(ctx, "TABLE HEADER", 460, 50, reaper.ImGui_WindowFlags_None())
            reaper.ImGui_Dummy(ctx,0,4)

            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 8, 10)
            
            reaper.ImGui_AlignTextToFramePadding(ctx)
            reaper.ImGui_Indent(ctx, 8)
            reaper.ImGui_Text(ctx, "F:")
            reaper.ImGui_Unindent(ctx)
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 254)
            _, filter_text = reaper.ImGui_InputText(ctx, "##FLTR", filter_text)
           
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Dummy(ctx, 6, 0)
            reaper.ImGui_SameLine(ctx)
            
            if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
                clearSelectedItems()
            end
            if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
                clearSelectedItems()
            end
            reaper.ImGui_PopStyleVar(ctx)
            
            -- Determine button label and action based on selection state
            local has_selection = next(selected_items) ~= nil
            local button_label = has_selection and "CLR!" or "ALL!"
            
            if reaper.ImGui_Button(ctx, button_label, 34, 34) then
                if has_selection then
                    -- Clear selection
                    clearSelectedItems()
                else
                    -- Select all filtered items
                    selected_items = {}
                    selected_items_list = {}
                    for folder_track, items in pairs(filtered_items) do
                        for _, item in ipairs(items) do
                            selected_items[item] = {}
                            table.insert(selected_items_list, item)
                        end
                    end
                    updateRenderQueue()
                end
            end
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Dummy(ctx, 0, 0)
            reaper.ImGui_SameLine(ctx)
            
            reaper.ImGui_BeginChild(ctx, "Selection Summary", 102)
            
            local selected_info = {}
            
            -- Build list of selected items with names
            for item, props in pairs(selected_items) do
                local take = reaper.GetActiveTake(item)
                if take then
                    local _, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                    table.insert(selected_info, { name = name, second_pass = props.second_pass })
                end
            end
            
            -- Group them using your existing logic
            local grouped = wwiseGroupItems(selected_info)
            local total_selected = #selected_info
            
            -- Display summary label
            reaper.ImGui_AlignTextToFramePadding(ctx)

            reaper.ImGui_Text(ctx, string.format(" SELECTED: %d", total_selected))
            
            reaper.ImGui_EndChild(ctx)
            
            -- Tooltip appears when hovering the entire child region
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_BeginTooltip(ctx)
                if total_selected == 0 then
                    reaper.ImGui_Text(ctx, "No items selected.")
                else
                    for group_name, items in pairs(grouped) do
                        reaper.ImGui_Text(ctx, string.format("%s (%d)", group_name, #items))
                    end
                end
                reaper.ImGui_EndTooltip(ctx)
            end

            reaper.ImGui_EndChild(ctx)
            
            sorted_folder_tracks = {}  -- Use the global variable
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
            
            reaper.ImGui_Dummy(ctx, 0, 0)

            reaper.ImGui_BeginChild(ctx, "tabela")
            renderItemTable(num_tracks)
            reaper.ImGui_EndChild(ctx)
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_SetConfigVar(ctx, reaper.ImGui_ConfigVar_WindowsMoveFromTitleBarOnly(), 1)
            else
                reaper.ImGui_SetConfigVar(ctx, reaper.ImGui_ConfigVar_WindowsMoveFromTitleBarOnly(), 0)
            end
            reaper.ImGui_End(ctx)
            
        end
        StyleManager.PopStyle(ctx)
        reaper.ImGui_PopFont(ctx)
    end
    if visible then
        preferencesWindow()
        reaper.defer(loop)
    else
        SaveSettingsToCSV()
    end
end

LoadSettingsFromCSV()
loop()

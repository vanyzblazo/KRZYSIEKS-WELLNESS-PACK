--[[
@version 1.1
@provides
  fonts/andalemono.ttf
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

local reawwise_open_cmd = reaper.NamedCommandLookup("_AK_REAWWISE_OPEN")
if reawwise_open_cmd == 0 then
    reaper.MB("ReaWwise extension is not installed.", "Missing Dependency", 0)
    reaper.ShowConsoleMsg("REAPACK LINK: https://github.com/Audiokinetic/Reaper-Tools/raw/main/index.xml")
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

local base_font = reaper.ImGui_CreateFontFromFile(script_path .. 'fonts/andalemono.ttf')

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


function executeGlobalReplacement(conflicts)
    -- Ensure we're connected to Wwise
    if not ww_connected then
        ww_connection_status, ww_proj_name = wwiseConnect()
        if not ww_connection_status then
            reaper.MB("Failed to connect to Wwise for replacement", "Error", 0)
            return false
        end
    end
    
    -- Collect all the sound names that need to be replaced
    local sounds_to_replace = {}
    local selected_hierarchy_paths = {}
    
    for sound_name, instances in pairs(conflicts.sound_conflicts) do
        for _, instance in ipairs(instances) do
            if instance.selected then
                if not sounds_to_replace[sound_name] then
                    sounds_to_replace[sound_name] = {
                        name = sound_name,
                        item = nil,
                        type = "render_item",
                        second_pass = false
                    }
                end
                
                if not selected_hierarchy_paths[sound_name] then
                    selected_hierarchy_paths[sound_name] = {}
                end
                table.insert(selected_hierarchy_paths[sound_name], instance.hierarchy_path)
            end
        end
    end
    
    -- Find the corresponding items from selected_items
    local items_to_replace = {}
    for sound_name, sound_info in pairs(sounds_to_replace) do
        local found_item = nil
        local found_properties = nil
        
        for selected_item, properties in pairs(selected_items) do
            local active_take = reaper.GetActiveTake(selected_item)
            if active_take then
                local _, item_name = reaper.GetSetMediaItemTakeInfo_String(active_take, "P_NAME", "", false)
                if item_name == sound_name then
                    found_item = selected_item
                    found_properties = properties
                    break
                end
            end
        end
        
        if found_item then
            table.insert(items_to_replace, {
                name = sound_name,
                item = found_item,
                type = "render_item",
                second_pass = found_properties.second_pass or false,
                hierarchy_paths = selected_hierarchy_paths[sound_name]
            })
        end
    end
    
    if #items_to_replace == 0 then
        reaper.MB("No matching items found in selection for replacement", "Error", 0)
        return false
    end
    
    -- NOW render the items (right before import)
    local regular_items, second_pass_items = separateItemsBySecondPass(items_to_replace)
    if #regular_items > 0 then
        renderItems(regular_items)
    end
    if #second_pass_items > 0 then
        renderItems(second_pass_items)
    end
    
    -- Perform targeted replacement for each sound
    for _, item_info in ipairs(items_to_replace) do
        for _, hierarchy_path in ipairs(item_info.hierarchy_paths) do
            local success = wwiseReplaceSpecificSound(item_info, hierarchy_path)
            if not success then
                -- Log failure but continue
            end
        end
    end
    
    return true
end


function wwiseReplaceSpecificSound(item_info, hierarchy_path)
    if not ww_connected then
        return false
    end
    
    -- Get project path and construct file path
    local project_path = reaper.GetProjectPath()
    local suffix = "Audio Files"
    if project_path:sub(-#suffix) == suffix then
        project_path = project_path:sub(1, -#suffix - 1)
    end
    local render_directory = project_path .. pref_inner_render_folder
    local audioFilePath = render_directory .. "/" .. item_info.name .. ".wav"
    
    -- Get the existing file path for this specific sound instance
    local existing_originals_subfolder = ""
    
    -- Query Wwise to get the current file path for this specific hierarchy path
    local args = reaper.AK_AkJson_Map()
    local waql = string.format('$ "%s"', hierarchy_path)
    reaper.AK_AkJson_Map_Set(args, "waql", reaper.AK_AkVariant_String(waql))
    
    local fields = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("originalFilePath"))
    
    local options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(options, "return", fields)
    
    local result = reaper.AK_Waapi_Call("ak.wwise.core.object.get", args, options)
    local status = reaper.AK_AkJson_GetStatus(result)
    
    if status then
        local return_objects = reaper.AK_AkJson_Map_Get(result, "return")
        local count = reaper.AK_AkJson_Array_Size(return_objects)
        if count > 0 then
            local obj = reaper.AK_AkJson_Array_Get(return_objects, 0)
            local file_path_variant = reaper.AK_AkJson_Map_Get(obj, "originalFilePath")
            if file_path_variant then
                local full_file_path = reaper.AK_AkVariant_GetString(file_path_variant)
                --reaper.ShowConsoleMsg(string.format("Found existing file path: %s\n", full_file_path))
                
                -- Extract the originals subfolder from the existing file path
                -- Path format: C:\...\Originals\SFX\[subfolder]\filename.wav
                local wwise_originals = wwiseGetOriginalsFolder()
                if wwise_originals and full_file_path:find(wwise_originals, 1, true) == 1 then
                    -- Remove the originals base path
                    local relative_path = full_file_path:sub(#wwise_originals + 1)
                    -- Remove the filename to get just the subfolder
                    local subfolder_path = relative_path:match("(.+)[\\/][^\\/]+$")
                    if subfolder_path then
                        existing_originals_subfolder = subfolder_path:gsub("\\", "/")
                        --reaper.ShowConsoleMsg(string.format("Extracted originals subfolder: '%s'\n", existing_originals_subfolder))
                    end
                end
            end
        end
    end
    
    reaper.AK_AkJson_ClearAll()
    
    -- Set up Wwise import for this specific sound
    local importCommand = "ak.wwise.core.audio.import"
    local importOperation = reaper.AK_AkVariant_String("useExisting")
    
    local default = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(default, "importLanguage", reaper.AK_AkVariant_String("SFX"))
    
    local imports = reaper.AK_AkJson_Array()
    
    -- Create import item targeting the specific hierarchy path
    local importItem = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(importItem, "audioFile", reaper.AK_AkVariant_String(audioFilePath))
    reaper.AK_AkJson_Map_Set(importItem, "objectPath", reaper.AK_AkVariant_String(hierarchy_path))
    reaper.AK_AkJson_Map_Set(importItem, "objectType", reaper.AK_AkVariant_String("Sound"))
    reaper.AK_AkJson_Map_Set(importItem, "importLanguage", reaper.AK_AkVariant_String("SFX"))
    
    -- CRITICAL: Set the originalsSubFolder to match the existing file location
    reaper.AK_AkJson_Map_Set(importItem, "originalsSubFolder", reaper.AK_AkVariant_String(existing_originals_subfolder))
    
    reaper.AK_AkJson_Array_Add(imports, importItem)
    
    -- Execute the import
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "importOperation", importOperation)
    reaper.AK_AkJson_Map_Set(arguments, "default", default)
    reaper.AK_AkJson_Map_Set(arguments, "imports", imports)
    reaper.AK_AkJson_Map_Set(arguments, "autoAddToSourceControl", reaper.AK_AkVariant_Bool(true))
    
    local result = reaper.AK_Waapi_Call(importCommand, arguments, reaper.AK_AkJson_Map())
    local status = reaper.AK_AkJson_GetStatus(result)
    
    if status then
        --reaper.ShowConsoleMsg(string.format("Successfully replaced '%s' at %s\n", item_info.name, hierarchy_path))
        return true
    else
        local errorMessage = reaper.AK_AkJson_Map_Get(result, "message")
        if errorMessage then
            local errorMessageStr = reaper.AK_AkVariant_GetString(errorMessage)
            --reaper.ShowConsoleMsg(string.format("Wwise import failed for '%s' at %s: %s\n", item_info.name, hierarchy_path, errorMessageStr))
        end
        return false
    end
end


function wwiseGetAllReplacementConflicts(sound_names)
    if not ww_connected then
        reaper.ShowMessageBox("Not connected to Wwise\n", "Warning!", 0)
        return {sound_conflicts = {}}
    end
    
    local global_conflicts = {
        sound_conflicts = {}
    }
    
    --reaper.ShowConsoleMsg("=== Searching for replacement conflicts globally ===\n")
    --reaper.ShowConsoleMsg(string.format("Searching for %d sound names: %s\n", #sound_names, table.concat(sound_names, ", ")))
    
    for _, sound_name in ipairs(sound_names) do
        --reaper.ShowConsoleMsg(string.format("\n--- Searching for: '%s' ---\n", sound_name))
        
        local args = reaper.AK_AkJson_Map()
        local search_query = string.format('$ from type Sound where name = "%s"', sound_name)
        --reaper.ShowConsoleMsg(string.format("WAQL Query: %s\n", search_query))
        reaper.AK_AkJson_Map_Set(args, "waql", reaper.AK_AkVariant_String(search_query))

        local fields = reaper.AK_AkJson_Array()
        reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("name"))
        reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("path"))
        reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("originalFilePath"))
        reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("parent"))

        local options = reaper.AK_AkJson_Map()
        reaper.AK_AkJson_Map_Set(options, "return", fields)
        
        local result = reaper.AK_Waapi_Call("ak.wwise.core.object.get", args, options)
        local status = reaper.AK_AkJson_GetStatus(result)

        if status then
            local return_objects = reaper.AK_AkJson_Map_Get(result, "return")
            local num_objects = reaper.AK_AkJson_Array_Size(return_objects)
            
            --reaper.ShowConsoleMsg(string.format("WAAPI call successful - found %d instances\n", num_objects))
            
            -- ✅ NEW: Collect all unique file paths for this sound
            local unique_file_paths = {}
            local instances_by_path = {}
            
            for i = 0, num_objects - 1 do
                local obj = reaper.AK_AkJson_Array_Get(return_objects, i)
                
                local name = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(obj, "name"))
                local hierarchy_path = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(obj, "path"))
                
                local file_path_variant = reaper.AK_AkJson_Map_Get(obj, "originalFilePath")
                local file_path = file_path_variant and reaper.AK_AkVariant_GetString(file_path_variant) or "No file assigned"
                
                local parent_variant = reaper.AK_AkJson_Map_Get(obj, "parent")
                local parent_path = parent_variant and reaper.AK_AkVariant_GetString(parent_variant) or "Unknown parent"
                local container_info = extractContainerName(parent_path)
                
                --reaper.ShowConsoleMsg(string.format("  Instance %d:\n", i+1))
                --reaper.ShowConsoleMsg(string.format("    Hierarchy: %s\n", hierarchy_path))
                --reaper.ShowConsoleMsg(string.format("    File: %s\n", file_path))
                --reaper.ShowConsoleMsg(string.format("    Container: %s\n", container_info))
                
                -- ✅ Group by file path
                if not instances_by_path[file_path] then
                    instances_by_path[file_path] = {}
                    table.insert(unique_file_paths, file_path)
                end
                
                table.insert(instances_by_path[file_path], {
                    hierarchy_path = hierarchy_path,
                    file_path = file_path,
                    container_info = container_info,
                    decision = "skip",
                    selected = false
                })
            end
            
            -- ✅ NEW: Only flag as conflict if there are MULTIPLE file paths OR multiple instances
            if #unique_file_paths > 1 then
                -- Multiple different file paths - definite conflict!
                --reaper.ShowConsoleMsg(string.format("CONFLICT DETECTED: '%s' exists at %d different file paths\n", sound_name, #unique_file_paths))
                global_conflicts.sound_conflicts[sound_name] = {}
                
                for file_path, instances in pairs(instances_by_path) do
                    for _, instance in ipairs(instances) do
                        table.insert(global_conflicts.sound_conflicts[sound_name], instance)
                    end
                end
            elseif num_objects > 1 and #unique_file_paths == 1 then
                -- Multiple instances but all point to SAME file - also a conflict
                -- (user might want different files for different containers)
                --reaper.ShowConsoleMsg(string.format("CONFLICT DETECTED: %d instances of '%s' all using same file: %s\n", num_objects, sound_name, unique_file_paths[1]))
                global_conflicts.sound_conflicts[sound_name] = {}
                
                for file_path, instances in pairs(instances_by_path) do
                    for _, instance in ipairs(instances) do
                        table.insert(global_conflicts.sound_conflicts[sound_name], instance)
                    end
                end
            elseif num_objects == 1 then
                --reaper.ShowConsoleMsg("Only one instance found - no conflict\n")
            else
                --reaper.ShowConsoleMsg("No instances found in Wwise\n")
            end
        else
            --reaper.ShowConsoleMsg(string.format("WAAPI call FAILED for sound: %s\n", sound_name))
        end
        
        reaper.AK_AkJson_ClearAll()
    end
    
    local total_conflicts = 0
    for sound_name, instances in pairs(global_conflicts.sound_conflicts) do
        total_conflicts = total_conflicts + 1
    end
    
    --reaper.ShowConsoleMsg(string.format("=== FINAL RESULT: %d sounds with conflicts ===\n", total_conflicts))
    
    return global_conflicts
end


-- Helper function to extract container name from full path
function extractContainerName(full_path)
    if not full_path or full_path == "" then return "Unknown" end
    
    -- Remove the Actor-Mixer Hierarchy prefix and get the parent container
    local clean_path = full_path:gsub("\\Actor%-Mixer Hierarchy\\", "")
    local parts = {}
    for part in clean_path:gmatch("[^\\]+") do
        table.insert(parts, part)
    end
    
    if #parts > 0 then
        return "In: " .. parts[#parts] -- Return the last part (immediate parent)
    else
        return "Unknown container"
    end
end

-- Helper function to check if there are any conflicts
function hasReplacementConflicts(conflicts)
    return next(conflicts.sound_conflicts) ~= nil
end

-- Integration function for your existing workflow
function findAllReplacementConflicts(items_to_replace)
    local sound_names = {}
    for _, item_info in ipairs(items_to_replace) do
        table.insert(sound_names, item_info.name)
    end
    
    return wwiseGetAllReplacementConflicts(sound_names)
end



function conflictResolutionPopup(ctx)
    if not conflict_resolution_popup_open or not pending_conflict_resolution_data then return end
    reaper.ImGui_SetNextWindowSizeConstraints(ctx, 500, 400, 1000, 500)
    local popup_open = reaper.ImGui_Begin(ctx, "Resolve Import Conflicts", true, reaper.ImGui_WindowFlags_NoDocking())
    if not popup_open then
        conflict_resolution_popup_open = false
        pending_conflict_resolution_data = nil
        return
    end

    local conflicts = pending_conflict_resolution_data.conflicts
    local operation = pending_conflict_resolution_data.operation
    
    -- Show different titles based on conflict type
    if operation.type == "container_resolution_only" then
        reaper.ImGui_Text(ctx, "Step 1: Resolve Container Conflicts")
    elseif operation.type == "sound_resolution_only" then
        reaper.ImGui_Text(ctx, "Step 2: Resolve Sound Path Conflicts")
    end
    reaper.ImGui_Separator(ctx)
    
    -- CONTAINER CONFLICTS SECTION (Show only for container resolution)
    if conflicts.container_conflicts and #conflicts.container_conflicts > 0 then
        reaper.ImGui_SeparatorText(ctx, "Container Name Conflicts")
        reaper.ImGui_TextWrapped(ctx, "The following containers already exist in Wwise:")
        reaper.ImGui_Dummy(ctx, 0, 5)
        
        -- Container conflicts table
        local table_flags = reaper.ImGui_TableFlags_Borders() | reaper.ImGui_TableFlags_RowBg()
        if reaper.ImGui_BeginTable(ctx, "ContainerConflictTable", 4, table_flags) then
            reaper.ImGui_TableSetupColumn(ctx, "Container Name", reaper.ImGui_TableColumnFlags_WidthFixed(), 150)
            reaper.ImGui_TableSetupColumn(ctx, "Existing Location", reaper.ImGui_TableColumnFlags_WidthFixed(), 250)
            reaper.ImGui_TableSetupColumn(ctx, "Action", reaper.ImGui_TableColumnFlags_WidthFixed(), 120)
            reaper.ImGui_TableSetupColumn(ctx, "New Name", reaper.ImGui_TableColumnFlags_WidthFixed(), 150)
            reaper.ImGui_TableHeadersRow(ctx)
            
            for i, container in ipairs(conflicts.container_conflicts) do
                reaper.ImGui_TableNextRow(ctx)
                
                -- Container Name
                reaper.ImGui_TableSetColumnIndex(ctx, 0)
                reaper.ImGui_Text(ctx, container.container_name)
                
                -- Existing Location
                reaper.ImGui_TableSetColumnIndex(ctx, 1)
                local display_path = string.gsub(container.full_path, "\\Actor%-Mixer Hierarchy", "")
                reaper.ImGui_Text(ctx, display_path)
                
                -- Action Selection
                reaper.ImGui_TableSetColumnIndex(ctx, 2)
                local conflict_id = "container_" .. i
                
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 2, 2)
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 4, 2)
                
                local reuse = reaper.ImGui_RadioButton(ctx, "Use Existing##" .. conflict_id, container.decision == "reuse")
                if reuse then container.decision = "reuse" end
                
                local rename = reaper.ImGui_RadioButton(ctx, "Rename##" .. conflict_id, container.decision == "rename")
                if rename then container.decision = "rename" end
                
                reaper.ImGui_PopStyleVar(ctx, 2)
                
                -- New Name Input (only show if rename is selected)
                reaper.ImGui_TableSetColumnIndex(ctx, 3)
                if container.decision == "rename" then
                    reaper.ImGui_SetNextItemWidth(ctx, 140)
                    local rv, new_name = reaper.ImGui_InputText(ctx, "##rename_input" .. i, 
                        container.rename_to or container.suggested_new_name or (container.container_name .. "_1"))
                    if rv then 
                        container.rename_to = new_name 
                    end
                else
                    reaper.ImGui_Text(ctx, "-")
                end
            end
            
            reaper.ImGui_EndTable(ctx)
        end
        
        reaper.ImGui_Dummy(ctx, 0, 10)
    end

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Dummy(ctx, 0, 5)
    
    -- Action buttons
    if reaper.ImGui_Button(ctx, "Apply Decisions", 120, 30) then
        applyConflictResolutionDecisions()
        conflict_resolution_popup_open = false
        pending_conflict_resolution_data = nil
    end
    
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Cancel", 120, 30) then
        conflict_resolution_popup_open = false
        pending_conflict_resolution_data = nil
    end

    reaper.ImGui_End(ctx)
end

-----------------------------------------------------------------------------------------------------------------
------------------------ENHANCED APPLY DECISIONS FUNCTION-----------------------------
-----------------------------------------------------------------------------------------------------------------

function applyConflictResolutionDecisions()
    local data = pending_conflict_resolution_data
    local operation = data.operation
    
    if operation.type == "container_resolution_only" then
        -- Apply container decisions
        if data.conflicts.container_conflicts then
            for _, container_conflict in ipairs(data.conflicts.container_conflicts) do
                local import_to_modify = operation.imports[container_conflict.import_index]
                
                if container_conflict.decision == "rename" and container_conflict.rename_to then
                    import_to_modify.container_name = container_conflict.rename_to
                elseif container_conflict.decision == "reuse" then
                    import_to_modify.container_type = nil
                    import_to_modify.container_name = nil
                    import_to_modify.target_path = container_conflict.full_path
                end
            end
        end
        
        conflict_resolution_popup_open = false
        pending_conflict_resolution_data = nil
        
        -- ✅ Pass the stored items for rendering later
        proceedWithSoundConflictCheck(
            operation.imports, 
            operation.all_regular_items, 
            operation.all_second_pass_items
        )
        
    elseif operation.type == "sound_resolution_only" then

        -- STEP 3: Apply sound conflict decisions and execute imports
        local sound_conflict_decisions = {}
        if data.conflicts.sound_path_conflicts then
            for _, sound_conflict in ipairs(data.conflicts.sound_path_conflicts) do
                local name_key = sound_conflict.item_name
                sound_conflict_decisions[name_key] = sound_conflict_decisions[name_key] or {}
                table.insert(sound_conflict_decisions[name_key], {
                    decision = sound_conflict.decision,
                    existing_path = sound_conflict.existing_path,
                    sound_hierarchy_path = sound_conflict.existing_sound_path
                })
            end
        end
        
        -- Execute all imports with resolved sound conflicts
        for _, import in ipairs(operation.imports) do
            local items_to_import = {}
            
            for _, item_info in ipairs(import.items) do
                local item_decisions = sound_conflict_decisions[item_info.name]
                local should_skip = false
                
                if item_decisions then
                    for _, decision in ipairs(item_decisions) do
                        if decision.decision == "skip" then
                            should_skip = true
                            break
                        elseif decision.decision == "use_original" then
                            local dir_path = decision.existing_path and 
                                decision.existing_path:match("(.+)[\\/][^\\/]+$") or nil
                            if dir_path then
                                item_info.path_override = dir_path
                            end
                        end
                    end
                end
                
                if not should_skip then
                    table.insert(items_to_import, item_info)
                end
            end
            
            local container_info = nil
            if import.container_type and import.container_name then
                container_info = {
                    type = import.container_type,
                    name = import.container_name
                }
            end
            
            if #items_to_import > 0 then
                wwiseImportAudio(items_to_import, import.target_path, {
                    container_info = container_info,
                    skip_conflict_check = true
                })
            end
        end
        
        -- Clear pending imports after successful import
        pending_imports = {}
        conflict_resolution_popup_open = false
        pending_conflict_resolution_data = nil
        
    else
        -- Handle single import operation (existing logic for backward compatibility)
        executeImportWithConflictDecisions(operation, sound_conflict_decisions)
    end
end

function executeImportWithConflictDecisions(import_operation, decisions)
    if not import_operation then 
        --print("ERROR: import_operation is nil")
        return 
    end
    
    --print("=== executeImportWithConflictDecisions called ===")
    --print("Operation type: " .. (import_operation.type or "unknown"))
    --print("Decisions provided: " .. (decisions and "YES" or "NO"))
    
    if import_operation.type == "batch_import" then
        -- Handle batch imports from TRS!
        for _, import in ipairs(import_operation.imports) do
            local items_to_import = {}
            
            for _, item_info in ipairs(import.items) do
                local item_decisions = decisions and decisions[item_info.name] or nil
                local should_skip = false
                local use_original_path = false
                
                if item_decisions then
                    for _, decision in ipairs(item_decisions) do
                        if decision.decision == "skip" then
                            should_skip = true
                            break
                        elseif decision.decision == "use_original" then
                            use_original_path = true
                            item_info.path_override = decision.existing_path and 
                                decision.existing_path:match("(.+)[\\/][^\\/]+$") or nil
                        end
                    end
                end
                
                if not should_skip then
                    table.insert(items_to_import, item_info)
                end
            end
            
            -- Execute imports for this group
            local container_info = nil
            if import.container_type and import.container_name then
                container_info = {
                    type = import.container_type,
                    name = import.container_name
                }
            end
            
            if #items_to_import > 0 then
                wwiseImportAudio(items_to_import, import.target_path, {
                    container_info = container_info,
                    skip_conflict_check = true
                })
            end
        end
        
        pending_imports = {}
        
    elseif import_operation.type == "batch_import_after_container_resolution" then
        -- Render items BEFORE importing (after conflict resolution)
        --print("=== Rendering items after conflict resolution ===")
        
        if import_operation.all_regular_items and #import_operation.all_regular_items > 0 then
            --print(string.format("Rendering %d regular items", #import_operation.all_regular_items))
            renderItems(import_operation.all_regular_items)
        end
        
        if import_operation.all_second_pass_items and #import_operation.all_second_pass_items > 0 then
            --print(string.format("Rendering %d second pass items", #import_operation.all_second_pass_items))
            renderItems(import_operation.all_second_pass_items)
        end
        
        -- Handle batch imports after container conflicts were resolved
        --print("=== Executing batch import after container resolution ===")
        
        for _, import in ipairs(import_operation.imports) do
            local items_to_import = {}
            
            for _, item_info in ipairs(import.items) do
                local item_decisions = decisions and decisions[item_info.name] or nil
                local should_skip = false
                
                if item_decisions then
                    for _, decision in ipairs(item_decisions) do
                        if decision.decision == "skip" then
                            should_skip = true
                            break
                        elseif decision.decision == "use_original" then
                            local dir_path = decision.existing_path and 
                                decision.existing_path:match("(.+)[\\/][^\\/]+$") or nil
                            if dir_path then
                                item_info.path_override = dir_path
                            end
                        end
                    end
                else
                    -- No decisions provided - this is OK for "batch_import_after_container_resolution"
                    --print("No specific decisions for item: " .. item_info.name .. " - proceeding with import")
                end
                
                if not should_skip then
                    table.insert(items_to_import, item_info)
                end
            end
            
            local container_info = nil
            if import.container_type and import.container_name then
                container_info = {
                    type = import.container_type,
                    name = import.container_name
                }
            end
            
            --print(string.format("Importing %d items to: %s", #items_to_import, import.target_path))
            
            if #items_to_import > 0 then
                wwiseImportAudio(import.items, import.target_path, {
                    container_info = container_info,
                    skip_conflict_check = true
                })
            end
        end
        
        -- Clear pending imports after successful batch import
        pending_imports = {}
        
    else
        -- Handle single import operation (original logic)
        -- ✅ First, render the items
        local regular_items, second_pass_items = separateItemsBySecondPass(import_operation.items)
        
        if #regular_items > 0 then
            renderItems(regular_items)
        end
        if #second_pass_items > 0 then
            renderItems(second_pass_items)
        end
        
        -- Then process decisions and import
        local items_to_import = {}
        
        for _, item_info in ipairs(import_operation.items) do
            local item_decisions = decisions and decisions[item_info.name] or nil
            local should_skip = false
            
            if item_decisions then
                for _, decision in ipairs(item_decisions) do
                    if decision.decision == "skip" then
                        should_skip = true
                        break
                    elseif decision.decision == "use_original" then
                        local dir_path = decision.existing_path and 
                            decision.existing_path:match("(.+)[\\/][^\\/]+$") or nil
                        if dir_path then
                            item_info.path_override = dir_path
                        end
                    end
                end
            end
            
            if not should_skip then
                table.insert(items_to_import, item_info)
            end
        end
        
        if #items_to_import > 0 then
            wwiseImportAudio(items_to_import, import_operation.target_path, {
                container_info = import_operation.container_info,
                skip_conflict_check = true
            })
        end
    end
end

function importWithConflictCheck(items, target_path, options)
    options = options or {}
    
    -- Skip conflict check if explicitly told to
    if options.skip_conflict_check then
        return wwiseImportAudio(items, target_path, options)
    end
    
    -- Prepare container info if provided
    local container_info = nil
    if options.container_type and options.container_name then
        container_info = {
            name = options.container_name,
            type = options.container_type
        }
    end
    
    -- ✅ Check for conflicts FIRST (no rendering yet!)
    local can_proceed, conflicts, special_conflict = checkPathConflicts(
        items,
        target_path,
        options.path_override or global_path_override,
        container_info
    )
    
    -- Handle container conflicts
    if special_conflict and special_conflict.type == "container_exists" then
        local msg = string.format("A container named '%s' already exists at:\n\n%s\n\nPlease choose a different name or cancel.",
                                  special_conflict.container_name, special_conflict.path)
        
        local ret = reaper.MB(msg .. "\n\nClick OK to enter a new name, or Cancel to abort.", "Container Name Conflict", 1)
        if ret == 1 then  -- OK
            local retval, new_name = reaper.GetUserInputs("New Container Name", 1, "Container Name:", special_conflict.container_name .. "_new")
            if retval then
                options.container_name = new_name
                -- Retry with new name
                return importWithConflictCheck(items, target_path, options)
            end
        end
        return false  -- Cancelled
    end
    
    -- Handle path conflicts
    if not can_proceed and #conflicts > 0 then
        -- Store conflict information for resolution window
        path_conflicts = {}
        for _, conflict in ipairs(conflicts) do
            table.insert(path_conflicts, {
                sound_name = conflict.item_name,
                item_name = conflict.item_name,
                intended_path = conflict.import_path,
                existing_path = conflict.existing_path,
                existing_sound_path = conflict.existing_sound_path,
                sound_hierarchy_path = conflict.existing_sound_path,
                decision = "use_original"
            })
        end
        
        -- Store the import operation to continue after resolution
        import_operation_pending = {
            items = items,
            target_path = target_path,
            container_info = options.container_info,
            options = options
        }
        
        -- Open conflict resolution window
        conflict_resolution_window = true
        return false  -- Import will continue after user resolves conflicts
    end
        
    -- ✅ No conflicts - NOW render and proceed with import
    local regular_items, second_pass_items = separateItemsBySecondPass(items)
    
    if #regular_items > 0 then
        renderItems(regular_items)
    end
    if #second_pass_items > 0 then
        renderItems(second_pass_items)
    end
    
    return wwiseImportAudio(items, target_path, options)
end


-----------------------------------------------------------------------------------------------------------------
------------------------GET EXISTING SOUNDS WITH FILE PATHS IN HIERARCHY-----------------------------
-----------------------------------------------------------------------------------------------------------------

function wwiseGetExistingSoundsWithPaths(sound_names, target_hierarchy_path)
    if not ww_connected then
        --reaper.ShowConsoleMsg("Not connected to Wwise\n")
        reaper.ShowMessageBox("Not connected to Wwise\n", "Warning!", 0)
        return {}
    end
    
    --reaper.ShowConsoleMsg(string.format("Searching for existing sounds in hierarchy: %s\n", target_hierarchy_path or "GLOBAL"))
    --reaper.ShowConsoleMsg(string.format("Sound names to search: %s\n", table.concat(sound_names, ", ")))
    
    local existing_sounds = {}
    
    for _, sound_name in ipairs(sound_names) do
        existing_sounds[sound_name] = {}
        
        local args = reaper.AK_AkJson_Map()
        local search_query
        
        if target_hierarchy_path and target_hierarchy_path ~= "" then
            search_query = string.format('$ "%s" select children where type = "Sound" and name = "%s"', 
                target_hierarchy_path, sound_name)
        else
            search_query = string.format('$ from type Sound where name = "%s"', sound_name)
        end
        
        --reaper.ShowConsoleMsg(string.format("WAQL Query: %s\n", search_query))
        reaper.AK_AkJson_Map_Set(args, "waql", reaper.AK_AkVariant_String(search_query))

        local fields = reaper.AK_AkJson_Array()
        reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("name"))
        reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("path"))
        reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("originalFilePath"))

        local options = reaper.AK_AkJson_Map()
        reaper.AK_AkJson_Map_Set(options, "return", fields)
        
        local result = reaper.AK_Waapi_Call("ak.wwise.core.object.get", args, options)
        local status = reaper.AK_AkJson_GetStatus(result)

        if status then
            local return_objects = reaper.AK_AkJson_Map_Get(result, "return")
            local num_objects = reaper.AK_AkJson_Array_Size(return_objects)

            for i = 0, num_objects - 1 do
                local obj = reaper.AK_AkJson_Array_Get(return_objects, i)
                
                local name = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(obj, "name"))
                local path = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(obj, "path"))
                local file_path_variant = reaper.AK_AkJson_Map_Get(obj, "originalFilePath")
                
                local file_path = nil
                if file_path_variant then
                    file_path = reaper.AK_AkVariant_GetString(file_path_variant)
                end
                
                --reaper.ShowConsoleMsg(string.format("Found existing sound '%s' at hierarchy path: %s\n", name, path))
                --reaper.ShowConsoleMsg(string.format("Existing sound '%s' uses file: %s\n", name, file_path or "NO FILE"))
                
                table.insert(existing_sounds[sound_name], {
                    sound_path = path,
                    file_path = file_path
                })
            end
        end
    end
    
    reaper.AK_AkJson_ClearAll()
    return existing_sounds
end

-----------------------------------------------------------------------------------------------------------------
------------------------CALCULATE SFX RELATIVE PATH FOR IMPORT-----------------------------
-----------------------------------------------------------------------------------------------------------------

function calculateSFXRelativePathForImport(item_info, custom_path, wwise_originals_path)
    --reaper.ShowConsoleMsg(string.format("Calculating import path for '%s'\n", item_info.name))
    --reaper.ShowConsoleMsg(string.format("  Custom path: %s\n", custom_path or "NONE"))
    --reaper.ShowConsoleMsg(string.format("  Item path override: %s\n", item_info.path_override or "NONE"))
    --reaper.ShowConsoleMsg(string.format("  Wwise originals path: %s\n", wwise_originals_path or "NONE"))
    
    local originals_sub_folder = ""
    
    -- Determine which custom path to use
    local final_custom_path = nil
    if item_info.path_override and item_info.path_override ~= "" then
        final_custom_path = item_info.path_override
        --reaper.ShowConsoleMsg(string.format("  Using item path override: %s\n", final_custom_path))
    elseif custom_path and custom_path ~= "" then
        final_custom_path = custom_path
        --reaper.ShowConsoleMsg(string.format("  Using custom path: %s\n", final_custom_path))
    else
        --reaper.ShowConsoleMsg("  No custom path specified - using default\n")
    end
    
    -- Calculate relative path if custom path is provided
    if final_custom_path and wwise_originals_path ~= "" then
        -- Check if custom path is within Wwise Originals folder
        local originals_lower = string.lower(wwise_originals_path)
        local custom_lower = string.lower(final_custom_path)
        
        if string.find(custom_lower, originals_lower, 1, true) == 1 then
            -- Custom path is within Originals folder, calculate relative path
            local relative_start = #wwise_originals_path + 1
            -- Skip path separator if it exists
            if final_custom_path:sub(relative_start, relative_start) == "\\" or final_custom_path:sub(relative_start, relative_start) == "/" then
                relative_start = relative_start + 1
            end
            local full_relative_path = final_custom_path:sub(relative_start)
            
            -- Convert backslashes to forward slashes for Wwise
            full_relative_path = string.gsub(full_relative_path, "\\", "/")
            
            -- Remove SFX/ prefix if it exists (since Wwise automatically adds Originals/SFX/)
            if string.lower(full_relative_path):sub(1, 4) == "sfx/" then
                originals_sub_folder = full_relative_path:sub(5)
                --reaper.ShowConsoleMsg(string.format("  Removed SFX/ prefix: %s\n", originals_sub_folder))
            else
                originals_sub_folder = full_relative_path
                --reaper.ShowConsoleMsg(string.format("  Full relative path: %s\n", originals_sub_folder))
            end
        else
            --reaper.ShowConsoleMsg("  Custom path is outside Wwise Originals folder\n")
        end
    end
    
    -- Construct the final relative file path
    -- Wwise will place this in Originals/SFX/originals_sub_folder/filename.wav
    local final_path = originals_sub_folder
    if final_path ~= "" and not final_path:match("/$") then
        final_path = final_path .. "/"
    end
    final_path = final_path .. item_info.name .. ".wav"
    
    --reaper.ShowConsoleMsg(string.format("  Final calculated path: %s\n", final_path))
    
    return final_path
end

-----------------------------------------------------------------------------------------------------------------
------------------------MAIN CONFLICT CHECK AND RESOLUTION-----------------------------
-----------------------------------------------------------------------------------------------------------------

function checkPathConflicts(items_to_import, target_hierarchy_path, custom_import_path, container_info)
    local sound_names = {}
    for _, item in ipairs(items_to_import) do
        table.insert(sound_names, item.name)
    end
    
    local conflicts = {}
    local conflict_found = false
    
    --print("Found existing sounds for " .. #sound_names .. " names - checking for path conflicts")
    
    -- Check for container conflicts FIRST - before processing sound conflicts
    if container_info and container_info.name then
        local full_container_path = target_hierarchy_path .. "\\" .. container_info.name
    
        -- Run WAQL to check if that object path already exists
        local args = reaper.AK_AkJson_Map()
        local waql = string.format('$ "%s"', full_container_path)
        reaper.AK_AkJson_Map_Set(args, "waql", reaper.AK_AkVariant_String(waql))
    
        local fields = reaper.AK_AkJson_Array()
        reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("name"))
        reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("path"))
        reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("type"))
    
        local options = reaper.AK_AkJson_Map()
        reaper.AK_AkJson_Map_Set(options, "return", fields)
    
        local result = reaper.AK_Waapi_Call("ak.wwise.core.object.get", args, options)
        local status = reaper.AK_AkJson_GetStatus(result)
    
        if status then
            local return_objects = reaper.AK_AkJson_Map_Get(result, "return")
            local count = reaper.AK_AkJson_Array_Size(return_objects)
            if count > 0 then
                -- Container conflict found - return immediately with special conflict info
                reaper.AK_AkJson_ClearAll()
                --print("CONTAINER CONFLICT: A container with the same name already exists at: " .. full_container_path)
                return false, {}, { type = "container_exists", path = full_container_path, container_name = container_info.name }
            else
                -- NEW CONTAINER - NO CONFLICT CHECK NEEDED
                -- Container doesn't exist yet, so there can't be any sound conflicts at the future path
                reaper.AK_AkJson_ClearAll()
                --print("=== NEW CONTAINER: No sound conflicts possible at future path ===")
                return true, {}, nil
            end
        end
        
        -- Clean up JSON objects after container check
        reaper.AK_AkJson_ClearAll()
    end
    
    -- ONLY reach here if NO container is being created (importing to existing structure)
    -- Get existing sounds with their actual file paths
    local existing_sounds = wwiseGetExistingSoundsWithPaths(sound_names, target_hierarchy_path)
    
    -- Now check each item for sound file path conflicts
    for _, item in ipairs(items_to_import) do
        local item_name = item.name
        
        -- Calculate where this item would be imported
        local calculated_path = calculateSFXRelativePathForImport(item, custom_import_path, wwiseGetOriginalsFolder())
        --print(string.format("Calculating import path for '%s'", item_name))
        --print(string.format("  Custom path: %s", custom_import_path or ""))
        --print(string.format("  Item path override: %s", item.path_override or "NONE"))
        
        local wwise_originals = wwiseGetOriginalsFolder()
        --print(string.format("  Wwise originals path: %s", wwise_originals or "UNKNOWN"))
        
        if not custom_import_path or custom_import_path == "" then
            --print("  No custom path specified - using default")
        end
        
        --print(string.format("  Final calculated path: %s", calculated_path))
        
        -- Check for conflicts with existing sounds
        if existing_sounds[item_name] and #existing_sounds[item_name] > 0 then
            for _, existing_info in ipairs(existing_sounds[item_name]) do
                local existing_file_path = existing_info.file_path
                local existing_sound_path = existing_info.sound_path
                
                if existing_file_path then
                    -- Calculate full absolute import path
                    local full_import_path = wwise_originals .. calculated_path
                    -- Normalize path separators to backslashes for Windows
                    full_import_path = string.gsub(full_import_path, "/", "\\")
                    
                    --print(string.format("Comparing paths for '%s':", item_name))
                    --print(string.format("  Import path: '%s'", full_import_path))
                    --print(string.format("  Existing file: '%s'", existing_file_path))
                    
                    if full_import_path == existing_file_path then
                        --print(string.format("EXACT MATCH: '%s' - same file path, will replace", item_name))
                    else
                        --print(string.format("PATH CONFLICT: '%s' - different paths!", item_name))
                        --print(string.format("  Would import to: %s", full_import_path))
                        --print(string.format("  Already exists at: %s", existing_file_path))
                        
                        conflict_found = true
                        table.insert(conflicts, {
                            item_name = item_name,
                            import_path = full_import_path,
                            existing_path = existing_file_path,
                            existing_sound_path = existing_sound_path
                        })
                    end
                else
                    --print(string.format("WARNING: '%s' - existing sound has no file path", item_name))
                end
            end
        else
            --print(string.format("NO EXISTING SOUND: '%s' - no conflicts", item_name))
        end
    end
    
    if conflict_found then
        --print("=== RESULT: Path conflicts detected! ===")
        return false, conflicts, nil
    else
        --print("=== RESULT: No path conflicts detected - proceeding with replacement ===")
        return true, {}, nil
    end
end

-----------------------------------------------------------------------------------------------------------------
------------------------PATH CONFLICT RESOLUTION WINDOW-----------------------------
-----------------------------------------------------------------------------------------------------------------

function pathConflictResolutionWindow()
    -- Handle global replacement conflicts
    if show_global_replacement_conflicts then
        StyleManager.PushStyle(ctx)
        reaper.ImGui_PushFont(ctx, base_font, 11)
        reaper.ImGui_SetNextWindowSizeConstraints(ctx, 400, 400, 1000, 1000)
        local should_display
        should_display, show_global_replacement_conflicts = reaper.ImGui_Begin(ctx, 'FILE REPLACEMENT CONFLICTS', show_global_replacement_conflicts, reaper.ImGui_WindowFlags_NoDocking())
       
        if should_display then
            reaper.ImGui_Text(ctx, "Multiple file paths found for some audio files:")
            reaper.ImGui_Text(ctx, "Select which file paths to replace with your new audio:")
            
            -- Group instances by file path for cleaner display (maintain state globally)
            if not global_grouped_by_file_path then
                global_grouped_by_file_path = {}
                for sound_name, instances in pairs(global_replacement_conflicts.sound_conflicts) do
                    global_grouped_by_file_path[sound_name] = {}
                    
                    for _, instance in ipairs(instances) do
                        local file_path = instance.file_path
                        if not global_grouped_by_file_path[sound_name][file_path] then
                            global_grouped_by_file_path[sound_name][file_path] = {
                                file_path = file_path,
                                hierarchies = {},
                                selected = false,
                                decision = "skip"
                            }
                        end
                        table.insert(global_grouped_by_file_path[sound_name][file_path].hierarchies, instance.hierarchy_path)
                    end
                end
            end
            
            local grouped_by_file_path = global_grouped_by_file_path
            
            -- Scrollable table with grouped conflicts
            reaper.ImGui_BeginChild(ctx, "ConflictsList", 950, 400)
            local table_flags = reaper.ImGui_TableFlags_Borders() | reaper.ImGui_TableFlags_RowBg() | 
                               reaper.ImGui_TableFlags_ScrollY()
                               
            if reaper.ImGui_BeginTable(ctx, "ConflictTable", 4, table_flags) then
                reaper.ImGui_TableSetupColumn(ctx, "Sound Name", reaper.ImGui_TableColumnFlags_WidthFixed(), 120)
                reaper.ImGui_TableSetupColumn(ctx, "File Path", reaper.ImGui_TableColumnFlags_WidthFixed(), 350)
                reaper.ImGui_TableSetupColumn(ctx, "Used In Hierarchies", reaper.ImGui_TableColumnFlags_WidthFixed(), 400)
                reaper.ImGui_TableSetupColumn(ctx, "Replace?", reaper.ImGui_TableColumnFlags_WidthFixed(), 80)
                reaper.ImGui_TableHeadersRow(ctx)
                
                for sound_name, file_paths in pairs(global_grouped_by_file_path) do
                    local file_path_count = 0
                    for _ in pairs(file_paths) do file_path_count = file_path_count + 1 end
                    
                    local row_index = 0
                    for file_path, group_data in pairs(file_paths) do
                        row_index = row_index + 1
                        reaper.ImGui_TableNextRow(ctx)
                        
                        -- Sound Name (only show on first row for this sound)
                        reaper.ImGui_TableSetColumnIndex(ctx, 0)
                        if row_index == 1 then
                            reaper.ImGui_Text(ctx, sound_name)
                            if reaper.ImGui_IsItemHovered(ctx) then
                                reaper.ImGui_SetTooltip(ctx, sound_name or "Unknown")
                            end
                            
                        end
                        
                        -- File Path
                        reaper.ImGui_TableSetColumnIndex(ctx, 1)
                        local truncated_path = truncatePathLeft(file_path, 45)
                        reaper.ImGui_Text(ctx, truncated_path)
                        if reaper.ImGui_IsItemHovered(ctx) then
                            reaper.ImGui_SetTooltip(ctx, file_path)
                        end
                        
                        -- Hierarchy Locations
                        reaper.ImGui_TableSetColumnIndex(ctx, 2)
                        local hierarchy_text = ""
                        for i, hierarchy_path in ipairs(group_data.hierarchies) do
                            local clean_hierarchy = hierarchy_path:gsub("\\Actor%-Mixer Hierarchy\\", "")
                            if i > 1 then
                                hierarchy_text = hierarchy_text .. "\n"
                            end
                            hierarchy_text = hierarchy_text .. clean_hierarchy
                        end
                        
                        -- If there are many hierarchies, show count instead
                        if #group_data.hierarchies > 4 then
                            local first_few = {}
                            for i = 1, 3 do
                                local clean_hierarchy = group_data.hierarchies[i]:gsub("\\Actor%-Mixer Hierarchy\\", "")
                                table.insert(first_few, clean_hierarchy)
                            end
                            hierarchy_text = table.concat(first_few, "\n") .. 
                                           string.format("\n... and %d more locations", #group_data.hierarchies - 3)
                        end
                        
                        reaper.ImGui_Text(ctx, hierarchy_text)
                        if reaper.ImGui_IsItemHovered(ctx) then
                            reaper.ImGui_SetTooltip(ctx, hierarchy_text or "Unknown")
                        end
                        
                        -- Show full hierarchy list in tooltip if there are many
                        if reaper.ImGui_IsItemHovered(ctx) and #group_data.hierarchies > 4 then
                            reaper.ImGui_BeginTooltip(ctx)
                            reaper.ImGui_Text(ctx, "All hierarchy locations:")
                            for _, hierarchy_path in ipairs(group_data.hierarchies) do
                                local clean_hierarchy = hierarchy_path:gsub("\\Actor%-Mixer Hierarchy\\", "")
                                reaper.ImGui_Text(ctx, "• " .. clean_hierarchy)
                            end
                            reaper.ImGui_EndTooltip(ctx)
                        end
                        
                        -- Replace Checkbox
                        reaper.ImGui_TableSetColumnIndex(ctx, 3)
                        local checkbox_id = sound_name .. "_" .. file_path
                        local changed, new_selected = reaper.ImGui_Checkbox(ctx, "##" .. checkbox_id, group_data.selected)
                        if changed then
                            group_data.selected = new_selected
                            group_data.decision = new_selected and "replace" or "skip"
                        end
                    end
                    
                    -- Add visual separator between different sound names if there are multiple file paths
                    if file_path_count > 1 and next(grouped_by_file_path, sound_name) then
                        reaper.ImGui_TableNextRow(ctx)
                        reaper.ImGui_TableSetColumnIndex(ctx, 0)
                        reaper.ImGui_Dummy(ctx, 0, 5)
                    end
                end
                
                reaper.ImGui_EndTable(ctx)
            end
            reaper.ImGui_EndChild(ctx)
            

            reaper.ImGui_Dummy(ctx,0,0)
            
            if reaper.ImGui_Button(ctx, "Select All", 120, 30) then
                for sound_name, file_paths in pairs(global_grouped_by_file_path) do
                    for file_path, group_data in pairs(file_paths) do
                        group_data.selected = true
                        group_data.decision = "replace"
                    end
                end
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Select None", 120, 30) then
                for sound_name, file_paths in pairs(global_grouped_by_file_path) do
                    for file_path, group_data in pairs(file_paths) do
                        group_data.selected = false
                        group_data.decision = "skip"
                    end
                end
            end
            reaper.ImGui_Dummy(ctx,0,5)
            
            -- Summary info
            local total_file_paths = 0
            local selected_file_paths = 0
            for sound_name, file_paths in pairs(global_grouped_by_file_path) do
                for file_path, group_data in pairs(file_paths) do
                    total_file_paths = total_file_paths + 1
                    if group_data.selected then
                        selected_file_paths = selected_file_paths + 1
                    end
                end
            end
            
            reaper.ImGui_Text(ctx, string.format("Total file paths: %d | Selected for replacement: %d", 
                total_file_paths, selected_file_paths))
            
            reaper.ImGui_Dummy(ctx, 0, 5)
            
            -- Action buttons
            if reaper.ImGui_Button(ctx, "Replace Selected", 120, 30) then
                -- Convert grouped data back to original format for execution
                for sound_name, file_paths in pairs(global_grouped_by_file_path) do
                    if global_replacement_conflicts.sound_conflicts[sound_name] then
                        for _, instance in ipairs(global_replacement_conflicts.sound_conflicts[sound_name]) do
                            local group_data = file_paths[instance.file_path]
                            if group_data then
                                instance.selected = group_data.selected
                                instance.decision = group_data.decision
                            end
                        end
                    end
                end
                
                executeGlobalReplacement(global_replacement_conflicts)
                show_global_replacement_conflicts = false
                global_grouped_by_file_path = nil  -- Reset the grouped data
            end
            
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Cancel", 120, 30) then
                show_global_replacement_conflicts = false
                global_grouped_by_file_path = nil  -- Reset the grouped data
            end
            
            reaper.ImGui_End(ctx)
        end
        StyleManager.PopStyle(ctx)
        reaper.ImGui_PopFont(ctx)
        return  -- Exit early so we don't show the path conflict window at the same time
    end

    -- Original path conflict resolution logic (unchanged)
    if not conflict_resolution_window or #path_conflicts == 0 then 
        return 
    end

    StyleManager.PushStyle(ctx)
    reaper.ImGui_PushFont(ctx, base_font, 11)
    reaper.ImGui_SetNextWindowSizeConstraints(ctx, 400, 400, 1000, 1000)
    local should_display
    should_display, conflict_resolution_window = reaper.ImGui_Begin(ctx, 'PATH CONFLICTS DETECTED', conflict_resolution_window, reaper.ImGui_WindowFlags_NoDocking())
   
    if should_display then
        reaper.ImGui_Text(ctx, "Path conflicts detected during replacement operation:")
        reaper.ImGui_Dummy(ctx, 0, 10)
        
        reaper.ImGui_TextWrapped(ctx, "The files you're trying to import have different storage paths than the existing audio sources in Wwise. What would you like to do?")
        reaper.ImGui_Dummy(ctx, 0, 10)
        
        -- Helper function to truncate path from the left
        local function truncatePathLeft(path, max_length)
            if string.len(path) <= max_length then
                return path
            end
            return "..." .. string.sub(path, -(max_length - 3))
        end
        
        -- Display conflicts in a table
        local table_flags = reaper.ImGui_TableFlags_Borders() | reaper.ImGui_TableFlags_RowBg() | reaper.ImGui_TableFlags_SizingFixedFit()
        if reaper.ImGui_BeginTable(ctx, "ConflictTable", 4, table_flags) then
            reaper.ImGui_TableSetupColumn(ctx, "Sound Name", reaper.ImGui_TableColumnFlags_WidthFixed(), 120)
            reaper.ImGui_TableSetupColumn(ctx, "Paths", reaper.ImGui_TableColumnFlags_WidthFixed(), 400)
            reaper.ImGui_TableSetupColumn(ctx, "Hierarchy Location", reaper.ImGui_TableColumnFlags_WidthFixed(), 250)
            reaper.ImGui_TableSetupColumn(ctx, "Action", reaper.ImGui_TableColumnFlags_WidthFixed(), 120)
            reaper.ImGui_TableHeadersRow(ctx)
            
            for i, conflict in ipairs(path_conflicts) do
                reaper.ImGui_TableNextRow(ctx)
                
                -- Sound Name
                reaper.ImGui_TableSetColumnIndex(ctx, 0)
                reaper.ImGui_Text(ctx, conflict.sound_name or conflict.item_name or "Unknown")
                if reaper.ImGui_IsItemHovered(ctx) then
                    reaper.ImGui_SetTooltip(ctx, conflict.sound_name or conflict.item_name or "Unknown")
                end
                
                -- Paths (combined column)
                reaper.ImGui_TableSetColumnIndex(ctx, 1)
                
                -- Current Path
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xAAFFAAFF) -- Light green
                local current_display = truncatePathLeft(conflict.existing_path or "Unknown", 50)
                reaper.ImGui_Text(ctx, current_display)
                if reaper.ImGui_IsItemHovered(ctx) then
                    reaper.ImGui_SetTooltip(ctx, conflict.existing_path or "Unknown")
                end
                reaper.ImGui_PopStyleColor(ctx)
                
                -- Intended Path
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xFFAAAAFF) -- Light red
                local intended_display = truncatePathLeft(conflict.intended_path or "Unknown", 50)
                reaper.ImGui_Text(ctx, intended_display)
                if reaper.ImGui_IsItemHovered(ctx) then
                    reaper.ImGui_SetTooltip(ctx, conflict.intended_path or "Unknown")
                end
                reaper.ImGui_PopStyleColor(ctx)
                
                -- Hierarchy Location
                reaper.ImGui_TableSetColumnIndex(ctx, 2)
                local display_path = string.gsub(conflict.sound_hierarchy_path or "", "\\Actor%-Mixer Hierarchy", "")
                reaper.ImGui_Text(ctx, display_path)
                if reaper.ImGui_IsItemHovered(ctx) then
                    reaper.ImGui_SetTooltip(ctx, display_path or "Unknown")
                end
                
                -- Action Selection
                reaper.ImGui_TableSetColumnIndex(ctx, 3)
                local conflict_id = "conflict_" .. i
                
                -- Initialize decision if not set
                if not conflict.decision then
                    conflict.decision = "use_original"
                end
                
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 2, 2)
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 4, 2)
                
                if reaper.ImGui_RadioButton(ctx, "Use Original##" .. conflict_id, conflict.decision == "use_original") then
                    conflict.decision = "use_original"
                end
                
                if reaper.ImGui_RadioButton(ctx, "Skip##" .. conflict_id, conflict.decision == "skip") then
                    conflict.decision = "skip"
                end
                
                reaper.ImGui_PopStyleVar(ctx, 2)
            end
            
            reaper.ImGui_EndTable(ctx)
        end
        
        reaper.ImGui_Dummy(ctx, 0, 10)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Dummy(ctx, 0, 5)
        
        -- Explanation text
        reaper.ImGui_TextWrapped(ctx, "• Use Original: Replace audio content but keep the existing file storage path")
        reaper.ImGui_TextWrapped(ctx, "• Skip: Don't import this item")
        reaper.ImGui_Dummy(ctx, 0, 5)
        
        -- Quick action buttons
        if reaper.ImGui_Button(ctx, "Use Original for All") then
            for _, conflict in ipairs(path_conflicts) do
                conflict.decision = "use_original"
            end
        end
        
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Skip All") then
            for _, conflict in ipairs(path_conflicts) do
                conflict.decision = "skip"
            end
        end
        
        reaper.ImGui_Dummy(ctx, 0, 10)
        
        -- Action buttons
        if reaper.ImGui_Button(ctx, "Apply Decisions", 120, 30) then
            -- Store decisions and close window
            conflict_decisions = {}
            for _, conflict in ipairs(path_conflicts) do
                local name_key = conflict.item_name or conflict.sound_name or "unknown"
                conflict_decisions[name_key] = conflict_decisions[name_key] or {}
                table.insert(conflict_decisions[name_key], {
                    decision = conflict.decision,
                    existing_path = conflict.existing_path,
                    sound_hierarchy_path = conflict.existing_sound_path,
                    item_info = conflict.item_info
                })
            end
            
            conflict_resolution_window = false
            path_conflicts = {}
            
            -- Execute the import with decisions
            if import_operation_pending then
                executeImportWithConflictDecisions(import_operation_pending, conflict_decisions)
                import_operation_pending = nil
            end
            
            conflict_decisions = {}
        end
        
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Cancel", 120, 30) then
            conflict_resolution_window = false
            path_conflicts = {}
            conflict_decisions = {}
            import_operation_pending = nil
        end
        
        reaper.ImGui_End(ctx)
    end
    StyleManager.PopStyle(ctx)
    reaper.ImGui_PopFont(ctx)
end

-------------------------------------------------------------------------------------------------------------------------------
------------------------WWISE NODE MATCHING ----------------------------
-------------------------------------------------------------------------------------------------------------------------------

-- Core matching logic used by all filtering operations
local function doesNodeMatch(node, filter_words)
    if not node or not node.object or not node.object.name then 
        return false 
    end
    
    -- Empty filter always matches
    if #filter_words == 0 then 
        return true 
    end
    
    -- Convert name to lowercase once
    local name_lower = string.lower(node.object.name)
    
    -- Check if all filter words are present
    for _, word in ipairs(filter_words) do
        if not name_lower:find(word, 1, true) then
            return false
        end
    end
    
    return true
end

-------------------------------------------------------------------------------------------------------------------------------
------------------------WWISE FILTER PREPARE ----------------------------
-------------------------------------------------------------------------------------------------------------------------------

-- Convert filter string to normalized word array and validate minimum length
local function validateAndPrepareFilterWords(filter)
    -- If filter is empty, return empty array
    if not filter or filter == "" then
        return {}
    end

    -- Normalize filter string
    filter = filter:lower():gsub("^%s+", ""):gsub("%s+$", "")
    
    -- Split into words and check lengths
    local words = {}
    local has_three_char_word = false
    
    for word in filter:gmatch("%S+") do
        local normalized_word = word:lower()
        if #normalized_word >= 3 then
            has_three_char_word = true
        end
        table.insert(words, normalized_word)
    end
    
    -- Only return the words if at least one meets the length requirement
    if has_three_char_word then
        return words
    else
        return {}
    end
end

-------------------------------------------------------------------------------------------------------------------------------
------------------------WWISE MATCHING COUNT ----------------------------
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

-------------------------------------------------------------------------------------------------------------------------------
------------------------WWISE MATCHING ----------------------------
-------------------------------------------------------------------------------------------------------------------------------

-- Check if a node or any of its descendants match
function wwiseNodeOrDescendantsMatch(node, filter_words)
    -- Check current node
    if doesNodeMatch(node, filter_words) then 
        return true 
    end
    
    -- Check children recursively
    if node.children then
        for _, child in ipairs(node.children) do
            if wwiseNodeOrDescendantsMatch(child, filter_words) then
                return true
            end
        end
    end
    
    return false
end

-------------------------------------------------------------------------------------------------------------------------------
------------------------WWISE ILTER HIERARCHY ----------------------------
-------------------------------------------------------------------------------------------------------------------------------

-- Create filtered hierarchy
function wwiseCreateFilteredHierarchy(full_hierarchy, filter)
    if filtering_in_progress then 
        return {} 
    end
    
    filtering_in_progress = true
    
    -- Handle empty input
    if not full_hierarchy or #full_hierarchy == 0 then 
        filtering_in_progress = false
        return {} 
    end
    
    -- Reset cache if too large
    if #filter_cache >= max_cache_size * cache_reset_threshold then
        filter_cache = {}
    end
    
    -- Prepare filter
    local filter_words = validateAndPrepareFilterWords(filter)
    
    -- Check cache
    for i, cached_result in ipairs(filter_cache) do
        if cached_result.filter == filter then
            -- Move to end (most recently used)
            table.remove(filter_cache, i)
            table.insert(filter_cache, cached_result)
            filtering_in_progress = false
            return cached_result.tree
        end
    end
    
    -- Recursive filtering function
    local function filterNode(node)
        local filtered_node = {
            object = node.object,
            children = {}
        }
        
        local node_matches = doesNodeMatch(node, filter_words)
        local has_matching_children = false
        
        -- Process children
        if node.children then
            for _, child in ipairs(node.children) do
                local filtered_child = filterNode(child)
                if filtered_child then
                    table.insert(filtered_node.children, filtered_child)
                    has_matching_children = true
                end
            end
        end
        
        -- Keep node if it matches or has matching children
        if node_matches or has_matching_children then
            return filtered_node
        end
        
        return nil
    end
    
    -- Filter the tree
    local filtered_tree = {}
    for _, node in ipairs(full_hierarchy) do
        local filtered_node = filterNode(node)
        if filtered_node then
            table.insert(filtered_tree, filtered_node)
        end
    end
    
    -- Cache result
    if #filter_cache >= max_cache_size then
        table.remove(filter_cache, 1)  -- Remove oldest
    end
    table.insert(filter_cache, {
        filter = filter,
        tree = filtered_tree
    })
    
    filtering_in_progress = false
    return filtered_tree
end


-----------------------------------------------------------------------------------------------------------------
------------------------WWISE CONNECT-----------------------------
-----------------------------------------------------------------------------------------------------------------

-- Modified connect function
function wwiseConnect()
    if reaper.AK_Waapi_Connect("127.0.0.1", 8080) then
        ww_connected = true
       
        -- Create empty arguments and options
        local args = reaper.AK_AkJson_Map()
        local options = reaper.AK_AkJson_Map()
       
        -- Make the call to get project info
        local result = reaper.AK_Waapi_Call("ak.wwise.core.getProjectInfo", args, options)
        local status = reaper.AK_AkJson_GetStatus(result)
       
        if status then
            -- Get the project name
            local name = reaper.AK_AkJson_Map_Get(result, "name")
            local projectName = reaper.AK_AkVariant_GetString(name)
            reaper.AK_AkJson_ClearAll()
            return true, projectName
        end
        reaper.AK_AkJson_ClearAll()
        return true, "Unknown Project"
    end
   
    --reaper.ShowConsoleMsg("Failed to connect to Wwise\n")
    reaper.ShowMessageBox("Failed to connect to Wwise\n", "Warning!", 0)
    return false, "Not Connected"
end

-----------------------------------------------------------------------------------------------------------------
------------------------WWISE DISCONNECT-----------------------------
-----------------------------------------------------------------------------------------------------------------

function wwiseDisconnect()
    reaper.AK_AkJson_ClearAll()
    reaper.AK_Waapi_Disconnect()
    ww_connected = false
    return ww_connected
end
-----------------------------------------------------------------------------------------------------------------
------------------------GET SELECTED FROM WWISE-----------------------------
-----------------------------------------------------------------------------------------------------------------

function wwiseGetSelected()
    if not ww_connected then
        --reaper.ShowConsoleMsg("Not connected to Wwise\n")
        reaper.ShowMessageBox("Failed to connect to Wwise\n", "Warning!", 0)
        return nil
    end

    local selected_objects = {}
   
    local ww_fields_to_return = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(ww_fields_to_return, reaper.AK_AkVariant_String("path"))
    reaper.AK_AkJson_Array_Add(ww_fields_to_return, reaper.AK_AkVariant_String("name"))
    reaper.AK_AkJson_Array_Add(ww_fields_to_return, reaper.AK_AkVariant_String("type"))
   
    local ww_options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(ww_options, "return", ww_fields_to_return)
   
    local ww_result = reaper.AK_Waapi_Call("ak.wwise.ui.getSelectedObjects", reaper.AK_AkJson_Map(), ww_options)
   
    local ww_status = reaper.AK_AkJson_GetStatus(ww_result)
   
    if ww_status then
        local ww_objects = reaper.AK_AkJson_Map_Get(ww_result, "objects")
        local ww_num_objects = reaper.AK_AkJson_Array_Size(ww_objects)
       
        for i = 0, ww_num_objects - 1 do
            local ww_item = reaper.AK_AkJson_Array_Get(ww_objects, i)
           
            local ww_path = reaper.AK_AkJson_Map_Get(ww_item, "path")
            local ww_name = reaper.AK_AkJson_Map_Get(ww_item, "name")
            local ww_type = reaper.AK_AkJson_Map_Get(ww_item, "type")
           
            -- Store each object's data
            table.insert(selected_objects, {
                path = reaper.AK_AkVariant_GetString(ww_path),
                name = reaper.AK_AkVariant_GetString(ww_name),
                type = reaper.AK_AkVariant_GetString(ww_type)
            })
        end
    end
   
    reaper.AK_AkJson_ClearAll()
    return selected_objects
end

-------------------------------------------------------------------------------------------------------------------------------------
------------------------GET ACTOR MIXER HIERARCHY FROM WWISE-----------------------------
-------------------------------------------------------------------------------------------------------------------------------------

function wwiseGetActorMixerHierarchy()
    if not ww_connected then
        return nil
    end
    local hierarchy = {}

    local args = reaper.AK_AkJson_Map()
    -- Modified query to get all descendants
    reaper.AK_AkJson_Map_Set(args, "waql", reaper.AK_AkVariant_String("$ \"Actor-Mixer Hierarchy\" select descendants where type != \"AudioFileSource\""))

    local fields = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("name"))
    reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("type"))
    reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("path"))
    reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("@RandomOrSequence"))

    local options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(options, "return", fields)

    local result = reaper.AK_Waapi_Call("ak.wwise.core.object.get", args, options)
   
    local status = reaper.AK_AkJson_GetStatus(result)

    if status then
        local return_objects = reaper.AK_AkJson_Map_Get(result, "return")
        local num_objects = reaper.AK_AkJson_Array_Size(return_objects)
       
        for i = 0, num_objects - 1 do
            local obj = reaper.AK_AkJson_Array_Get(return_objects, i)
           
            local name = reaper.AK_AkJson_Map_Get(obj, "name")
            local type = reaper.AK_AkJson_Map_Get(obj, "type")
            local path = reaper.AK_AkJson_Map_Get(obj, "path")
            local play_type = reaper.AK_AkJson_Map_Get(obj, "@RandomOrSequence")
           
           
            local name_str = reaper.AK_AkVariant_GetString(name)
            local type_str = reaper.AK_AkVariant_GetString(type)
            local path_str = reaper.AK_AkVariant_GetString(path)
            local play_type_value = reaper.AK_AkVariant_GetInt(play_type)
 
            table.insert(hierarchy, {
                name = name_str,
                type = type_str,
                path = path_str,
                level = select(2, string.gsub(path_str, "\\", "\\")) - 1,
                play_type = play_type_value
            })
        end
    end

    reaper.AK_AkJson_ClearAll()
    return hierarchy
end


----------------------------------------------------------------------------------------------------------------------------------
------------------------WWISE IMPORT-----------------------------
----------------------------------------------------------------------------------------------------------------------------------

-- Helper function to render items before Wwise import (for replace operations)
function renderAndImportToWwise(items, target_path, options)
    if #items == 0 then return end
    
    -- Separate items by second_pass status
    local regular_items, second_pass_items = separateItemsBySecondPass(items)
    
    -- Render both batches (right before import)
    if #regular_items > 0 then
        renderItems(regular_items)
    end
    if #second_pass_items > 0 then
        renderItems(second_pass_items)
    end
    
    -- Import all items to Wwise
    wwiseImportAudio(items, target_path, options)
end

-- Helper function to separate items by second_pass status
function separateItemsBySecondPass(items)
    local regular_items = {}
    local second_pass_items = {}
    
    for _, item_info in ipairs(items) do
        if item_info.second_pass then
            table.insert(second_pass_items, item_info)
        else
            table.insert(regular_items, item_info)
        end
    end
    
    return regular_items, second_pass_items
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

function wwiseImportAudio(items, target_path, options)
    options = options or {}
    local container_info = options.container_info
    local replace_existing = options.replace_existing or false
    local selected_wwise_object = options.selected_wwise_object
    
    if not ww_connected then
        if replace_existing then
            ww_connection_status, ww_proj_name = wwiseConnect()
            if not ww_connection_status then
                reaper.MB("Failed to connect to WWise", "Error", 0)
                return false
            end
        else
            --reaper.ShowConsoleMsg("Not connected to Wwise\n")
            reaper.ShowMessageBox("Failed to connect to Wwise\n", "Warning!", 0)
            return false
        end
    end

    -- Get Wwise originals folder path
    local wwise_originals_path = wwiseGetOriginalsFolder()
    if not wwise_originals_path then
        --reaper.ShowConsoleMsg("Warning: Could not get Wwise Originals folder path\n")
        reaper.ShowMessageBox("Could not get Wwise Originals folder path\n", "Warning!", 0)
        wwise_originals_path = ""
    end

    -- Find existing sounds if replacing
    local found_sounds = {}
    if replace_existing then
        for _, item_info in ipairs(items) do
            local search_args = reaper.AK_AkJson_Map()
            local search_query = string.format('$ from type Sound where name = "%s"', item_info.name)
            reaper.AK_AkJson_Map_Set(search_args, "waql", reaper.AK_AkVariant_String(search_query))

            local fields = reaper.AK_AkJson_Array()
            reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("name"))
            reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("path"))
            reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("type"))
            reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("id"))

            local options_search = reaper.AK_AkJson_Map()
            reaper.AK_AkJson_Map_Set(options_search, "return", fields)
            
            local result = reaper.AK_Waapi_Call("ak.wwise.core.object.get", search_args, options_search)
            local status = reaper.AK_AkJson_GetStatus(result)

            if status then
                local return_objects = reaper.AK_AkJson_Map_Get(result, "return")
                local num_objects = reaper.AK_AkJson_Array_Size(return_objects)

                for i = 0, num_objects - 1 do
                    local obj = reaper.AK_AkJson_Array_Get(return_objects, i)
                    local name = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(obj, "name"))
                    local path = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(obj, "path"))
                    found_sounds[name] = path
                end
            end
        end
    end

    -- Create container if specified and not replacing
    local container_path = target_path
    
    -- Use selected Wwise object if provided (from context menu)
    if selected_wwise_object then
        container_path = selected_wwise_object.path
        --reaper.ShowConsoleMsg("Importing to selected Wwise object: " .. container_path .. "\n")
    end
    
    if container_info and container_info.type and container_info.name and not replace_existing then
        local containerCommand = "ak.wwise.core.object.set"
        local objects = reaper.AK_AkJson_Array()
        local containerObj = reaper.AK_AkJson_Map()
       
        reaper.AK_AkJson_Map_Set(containerObj, "object", reaper.AK_AkVariant_String(target_path))
       
        local children = reaper.AK_AkJson_Array()
        local child = reaper.AK_AkJson_Map()
       
        reaper.AK_AkJson_Map_Set(child, "name", reaper.AK_AkVariant_String(container_info.name))
        reaper.AK_AkJson_Map_Set(child, "type", reaper.AK_AkVariant_String(container_info.type.type))
       
        if container_info.type.type == "RandomSequenceContainer" and container_info.type.play_type ~= nil then
            reaper.AK_AkJson_Map_Set(child, "@RandomOrSequence", reaper.AK_AkVariant_Int(container_info.type.play_type))
        end
       
        reaper.AK_AkJson_Array_Add(children, child)
        reaper.AK_AkJson_Map_Set(containerObj, "children", children)
        reaper.AK_AkJson_Array_Add(objects, containerObj)
       
        local args = reaper.AK_AkJson_Map()
        reaper.AK_AkJson_Map_Set(args, "objects", objects)
       
        local containerResult = reaper.AK_Waapi_Call(containerCommand, args, reaper.AK_AkJson_Map())
        local containerStatus = reaper.AK_AkJson_GetStatus(containerResult)
       
        if not containerStatus then
            local errorMessage = reaper.AK_AkJson_Map_Get(containerResult, "message")
            local errorMessageStr = reaper.AK_AkVariant_GetString(errorMessage)
            --reaper.ShowConsoleMsg("Container creation failed: " .. errorMessageStr .. "\n")
            return false
        end
       
        container_path = target_path .. "\\" .. container_info.name
    end

    -- Set up Wwise import
    local importCommand = "ak.wwise.core.audio.import"
    -- Use "useExisting" instead of "replaceExisting" to preserve references and settings
    local importOperation = reaper.AK_AkVariant_String("useExisting")
   
    local default = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(default, "importLanguage", reaper.AK_AkVariant_String("SFX"))
   
    local imports = reaper.AK_AkJson_Array()
   
    -- Get project path and render directory
    local project_path = reaper.GetProjectPath()
    local suffix = "Audio Files"
    if project_path:sub(-#suffix) == suffix then
        project_path = project_path:sub(1, -#suffix - 1)
    end
    local render_directory = project_path .. pref_inner_render_folder
   
    -- Track items that weren't found (for replace mode)
    local not_found_items = {}
    local outside_originals_items = {}
    
    -- Build import array
    for _, item_info in ipairs(items) do
        local importItem = reaper.AK_AkJson_Map()
        local audioFilePath = render_directory .. "/" .. item_info.name .. ".wav"
        reaper.AK_AkJson_Map_Set(importItem, "audioFile", reaper.AK_AkVariant_String(audioFilePath))
       
        -- Calculate originals_sub_folder based on custom paths
        local originals_sub_folder = ""
        
        -- Determine which custom path to use (individual override takes precedence)
        local custom_path = nil
        if item_info.path_override and item_info.path_override ~= "" then
            custom_path = item_info.path_override
        elseif global_path_override and global_path_override ~= "" then
            custom_path = global_path_override
        end
        
        -- Calculate relative path if custom path is provided
        if custom_path and wwise_originals_path ~= "" then
            -- Check if custom path is within Wwise Originals folder
            local originals_lower = string.lower(wwise_originals_path)
            local custom_lower = string.lower(custom_path)
            
            -- Remove trailing slashes for consistent comparison
            originals_lower = originals_lower:gsub("[\\/]+$", "")
            custom_lower = custom_lower:gsub("[\\/]+$", "")
            
            if string.find(custom_lower, originals_lower, 1, true) == 1 then
                -- Custom path is within Originals folder, calculate relative path
                local relative_start = #wwise_originals_path + 1
                -- Skip path separator if it exists
                if custom_path:sub(relative_start, relative_start) == "\\" or custom_path:sub(relative_start, relative_start) == "/" then
                    relative_start = relative_start + 1
                end
                local full_relative_path = custom_path:sub(relative_start)
                
                -- Convert backslashes to forward slashes for Wwise
                full_relative_path = string.gsub(full_relative_path, "\\", "/")
                
                -- IMPORTANT: Remove the automatic category folder that Wwise adds
                -- Since we're importing with importLanguage: "SFX", Wwise automatically 
                -- creates Originals/SFX/, so we need to remove "SFX/" from the beginning
                -- of our path to avoid duplication
                if string.lower(full_relative_path):sub(1, 4) == "sfx/" then
                    originals_sub_folder = full_relative_path:sub(5) -- Remove "SFX/" prefix
                elseif string.lower(full_relative_path):sub(1, 6) == "music/" then
                    originals_sub_folder = full_relative_path:sub(7) -- Remove "Music/" prefix  
                elseif string.lower(full_relative_path):sub(1, 7) == "voices/" then
                    originals_sub_folder = full_relative_path:sub(8) -- Remove "Voices/" prefix
                else
                    -- If it doesn't start with a known category, use the full path
                    originals_sub_folder = full_relative_path
                end
            else
                -- Custom path is outside Originals folder
                table.insert(outside_originals_items, item_info.name)
                originals_sub_folder = "" -- Fall back to default
            end
        end
       
        -- Set object path based on mode
        local objectPath
        if replace_existing then
            local sound_path = found_sounds[item_info.name]
            if sound_path then
                objectPath = sound_path
            else
                table.insert(not_found_items, item_info.name)
                objectPath = nil -- Skip this item
            end
        else
            objectPath = container_path .. "\\<Sound SFX>" .. item_info.name
        end
        
        if objectPath then
            reaper.AK_AkJson_Map_Set(importItem, "objectPath", reaper.AK_AkVariant_String(objectPath))
            reaper.AK_AkJson_Map_Set(importItem, "originalsSubFolder", reaper.AK_AkVariant_String(originals_sub_folder))
            if replace_existing then
                reaper.AK_AkJson_Map_Set(importItem, "objectType", reaper.AK_AkVariant_String("Sound"))
                reaper.AK_AkJson_Map_Set(importItem, "importLanguage", reaper.AK_AkVariant_String("SFX"))
            end
            reaper.AK_AkJson_Array_Add(imports, importItem)
        end
    end
   
    -- Show warnings for items with issues
    if replace_existing and #not_found_items > 0 then
        local msg = "The following items were not found in WWise:\n" .. table.concat(not_found_items, "\n")
        reaper.MB(msg, "Not Found", 0)
    end
    
    if #outside_originals_items > 0 then
        local msg = "The following items have custom paths outside Wwise Originals folder.\nUsing default location instead:\n" .. table.concat(outside_originals_items, "\n")
        reaper.MB(msg, "Path Warning", 0)
    end
   
    -- Execute import
    local numFilesToImport = reaper.AK_AkJson_Array_Size(imports)
   
    if numFilesToImport > 0 then
        local arguments = reaper.AK_AkJson_Map()
        reaper.AK_AkJson_Map_Set(arguments, "importOperation", importOperation)
        reaper.AK_AkJson_Map_Set(arguments, "default", default)
        reaper.AK_AkJson_Map_Set(arguments, "imports", imports)
        reaper.AK_AkJson_Map_Set(arguments, "autoAddToSourceControl", reaper.AK_AkVariant_Bool(true))
        
        local result = reaper.AK_Waapi_Call(importCommand, arguments, reaper.AK_AkJson_Map())
        local status = reaper.AK_AkJson_GetStatus(result)
       
        if status then
            return true
        else
            local errorMessage = reaper.AK_AkJson_Map_Get(result, "message")
            local errorMessageStr = reaper.AK_AkVariant_GetString(errorMessage)
            local error_msg = replace_existing and "WWise import failed: " or "Wwise import failed: "
            if replace_existing then
                reaper.MB(error_msg .. errorMessageStr, "Error", 0)
            else
                --reaper.ShowConsoleMsg(error_msg .. errorMessageStr .. "\n")
            end
            return false
        end
    end
    
    return false
end

function handleTRSButton()
    if #pending_imports == 0 then return end
    
    -- Collect all items (but DON'T render yet!)
    local all_regular_items = {}
    local all_second_pass_items = {}
    local all_imports_info = {}
    
    for _, import in ipairs(pending_imports) do
        local regular_items, second_pass_items = separateItemsBySecondPass(import.items)
        
        for _, item in ipairs(regular_items) do
            table.insert(all_regular_items, item)
        end
        for _, item in ipairs(second_pass_items) do
            table.insert(all_second_pass_items, item)
        end
        
        table.insert(all_imports_info, import)
    end
    
    -- STEP 1: Check for container conflicts ONLY
    local container_conflicts = {}
    
    for import_index, import in ipairs(all_imports_info) do
        if import.container_type and import.container_name then
            local container_info = {
                type = import.container_type,
                name = import.container_name
            }
            
            local can_proceed, sound_conflicts, special_conflict = checkPathConflicts(
                {},
                import.target_path,
                import.path_override or global_path_override,
                container_info
            )
            
            if special_conflict and special_conflict.type == "container_exists" then
                table.insert(container_conflicts, {
                    import_index = import_index,
                    container_name = special_conflict.container_name,
                    full_path = special_conflict.path,
                    target_path = import.target_path,
                    suggested_new_name = special_conflict.container_name .. "_1",
                    decision = "rename",
                    rename_to = special_conflict.container_name .. "_1"
                })
            end
        end
    end
    
    -- STEP 2: If container conflicts exist, resolve them first
    if #container_conflicts > 0 then
        pending_conflict_resolution_data = {
            conflicts = {
                container_conflicts = container_conflicts
            },
            operation = {
                type = "container_resolution_only",
                imports = all_imports_info,
                -- ✅ NEW: Store items for later rendering
                all_regular_items = all_regular_items,
                all_second_pass_items = all_second_pass_items
            }
        }
        
        conflict_resolution_popup_open = true
        return
    end
    
    -- STEP 3: No container conflicts, proceed with sound conflict check
    proceedWithSoundConflictCheck(all_imports_info, all_regular_items, all_second_pass_items)
end




function proceedWithSoundConflictCheck(all_imports_info, all_regular_items, all_second_pass_items)
    --print("=== Starting sound conflict check with updated paths ===")
    local all_sound_conflicts = {}
    
    -- Check for sound conflicts with final target paths
    for import_index, import in ipairs(all_imports_info) do
        local effective_target_path = import.target_path
        local container_info = nil
        
        if import.container_type and import.container_name then
            effective_target_path = import.target_path .. "\\" .. import.container_name
            container_info = {
                type = import.container_type,
                name = import.container_name
            }
        end
        
        local sound_names = {}
        for _, item in ipairs(import.items) do
            table.insert(sound_names, item.name)
        end
        
        local existing_sounds = wwiseGetExistingSoundsWithPaths(sound_names, effective_target_path)
        
        for _, item in ipairs(import.items) do
            local item_name = item.name
            local calculated_path = calculateSFXRelativePathForImport(item, import.path_override or global_path_override, wwiseGetOriginalsFolder())
            local wwise_originals = wwiseGetOriginalsFolder()
            
            if existing_sounds[item_name] and #existing_sounds[item_name] > 0 then
                for _, existing_info in ipairs(existing_sounds[item_name]) do
                    local existing_file_path = existing_info.file_path
                    local existing_sound_path = existing_info.sound_path
                    
                    if existing_file_path then
                        local full_import_path = wwise_originals .. calculated_path
                        full_import_path = string.gsub(full_import_path, "/", "\\")
                        
                        if full_import_path ~= existing_file_path then
                            table.insert(all_sound_conflicts, {
                                item_name = item_name,
                                import_path = full_import_path,
                                existing_path = existing_file_path,
                                existing_sound_path = existing_sound_path,
                                import_index = import_index
                            })
                        end
                    end
                end
            end
        end
    end
    
    -- If sound conflicts exist, show resolution
    if #all_sound_conflicts > 0 then
        path_conflicts = {}
        for _, conflict in ipairs(all_sound_conflicts) do
            table.insert(path_conflicts, {
                item_name = conflict.item_name,
                intended_path = conflict.import_path,
                existing_path = conflict.existing_path,
                existing_sound_path = conflict.existing_sound_path,
                sound_hierarchy_path = conflict.existing_sound_path,
                decision = "use_original"
            })
        end
        
        import_operation_pending = {
            type = "batch_import_after_container_resolution",
            imports = all_imports_info,
            -- ✅ NEW: Store items for later rendering
            all_regular_items = all_regular_items,
            all_second_pass_items = all_second_pass_items
        }
        
        conflict_resolution_window = true
        return
    end
    
    -- ✅ No conflicts - NOW render and proceed
    if #all_regular_items > 0 then
        renderItems(all_regular_items)
    end
    if #all_second_pass_items > 0 then
        renderItems(all_second_pass_items)
    end
    
    for _, import in ipairs(all_imports_info) do
        local container_info = nil
        if import.container_type and import.container_name then
            container_info = {
                type = import.container_type,
                name = import.container_name
            }
        end
        
        local custom_path = import.path_override or global_path_override
        if custom_path and custom_path ~= "" then
            for _, item_info in ipairs(import.items) do
                if not item_info.path_override or item_info.path_override == "" then
                    item_info.path_override = custom_path
                end
            end
        end
        
        wwiseImportAudio(import.items, import.target_path, {
            container_info = container_info,
            skip_conflict_check = true
        })
    end
    
    pending_imports = {}
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
------------------------GET WWISE ORIGINALS FOLDER-----------------------------
-----------------------------------------------------------------------------------------------------------------

function wwiseGetOriginalsFolder()
    if not ww_connected then
        return nil
    end
    -- Create empty arguments and options
    local args = reaper.AK_AkJson_Map()
    local options = reaper.AK_AkJson_Map()
   
    -- Make the call to get project info
    local result = reaper.AK_Waapi_Call("ak.wwise.core.getProjectInfo", args, options)
    local status = reaper.AK_AkJson_GetStatus(result)
   
    if status then
        -- Get the directories object
        local directories = reaper.AK_AkJson_Map_Get(result, "directories")
        if directories then
            -- Get the originals path
            local originals = reaper.AK_AkJson_Map_Get(directories, "originals")
            if originals then
                local originals_path = reaper.AK_AkVariant_GetString(originals)
                reaper.AK_AkJson_ClearAll()
                -- Add \SFX to the path
                return originals_path .. "SFX\\"
            end
        end
    end
   
    reaper.AK_AkJson_ClearAll()
    return nil
end

-----------------------------------------------------------------------------------------------------------------
------------------------WWISE HIERARCHY AND DISPLAY----------------------------
-----------------------------------------------------------------------------------------------------------------

local function wwiseBuildHierarchy(array)
    local tree = {}
    local parentStack = {}
   
    for i, object in ipairs(array) do
        while #parentStack > 0 and object.level <= parentStack[#parentStack].object.level do
            table.remove(parentStack)
        end
       
        local node = {
            object = object,  -- Contains the original object with all its properties
            children = {}
        }
       
        if #parentStack > 0 then
            table.insert(parentStack[#parentStack].children, node)
        else
            table.insert(tree, node)
        end
       
        table.insert(parentStack, node)
    end
   
    return tree
end

-------------------------------------------------------------------------------------------------------------------------------
------------------------WWISE RENDER TREEEEEE ----------------------------
-------------------------------------------------------------------------------------------------------------------------------

function wwiseRenderTree(tree, parent_level, result_count)
    result_count = result_count or {count = 0, max = 50}  
    parent_level = parent_level or 1
    local has_visible_children = false
    
    -- Get filter words from the already prepared global filter
    local filter_words = validateAndPrepareFilterWords(wwise_hierarchy_filter or "")

    for _, node in ipairs(tree) do
        local object = node.object
        local should_show = true
        
        if object.type == "Sound" and collapse_end_containers then
            goto continue  -- Skip to next iteration
        end
        
        -- Check if this node is a direct match (not just a parent of matches)
        local is_direct_match = wwise_hierarchy_filter ~= "" and doesNodeMatch(node, filter_words)
        
        if should_show then
            -- Only count and check limit for direct matches
            if is_direct_match then
                if result_count.count >= result_count.max then
                    return has_visible_children
                end
                result_count.count = result_count.count + 1
            end
            
            has_visible_children = true
            
            -- Type indicator styling
            local font_color = 0x111111FF
            local color = 0xB84A62FF
            local abbr = "XXX"

            -- Type-specific styling
            if object.type == "RandomSequenceContainer" then
                abbr = (object.play_type == 0) and "SEQ" or "RND"
                color = (object.play_type == 0) and 0xE25473FF or 0x5190C7FF
            elseif object.type == "Folder" then
                abbr = "FLD"
                color = 0x545863FF
                font_color = 0xE1DABDFF
            elseif object.type == "WorkUnit" then
                abbr = "WUT"
                color = 0xE1DABDFF
            elseif object.type == "SwitchContainer" then
                abbr = "SWC"
                color = 0xF05D5EFF
            elseif object.type == "BlendContainer" then
                abbr = "BLC"
                color = 0x23CEAFFF
            elseif object.type == "ActorMixer" then
                abbr = "AMX"
                color = 0xFFC145FF
            elseif object.type == "Sound" then
                abbr = "SND"
                color = 0x031926FF
                font_color = 0xE1DABDFF
            end

            -- Draw type indicator
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), font_color)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), color)
            reaper.ImGui_Button(ctx, abbr .. "##" .. object.path)  -- Add unique ID using path
            reaper.ImGui_PopStyleColor(ctx, 2)
            reaper.ImGui_SameLine(ctx)
            
            local node_flags = reaper.ImGui_TreeNodeFlags_SpanAvailWidth() | reaper.ImGui_TreeNodeFlags_OpenOnArrow()
            
            -- Check if this is a container with only Sound children
            local has_only_sound_children = false
            local matching_sounds_count = 0
            if node.children and #node.children > 0 then
                has_only_sound_children = true
                for _, child in ipairs(node.children) do
                    if child.object.type ~= "Sound" then
                        has_only_sound_children = false
                        break
                    end
                end
                if has_only_sound_children then
                    matching_sounds_count = countMatchingSounds(node, filter_words)
                end
            end
            
            -- Apply node flags based on type and settings
            if object.type == "Sound" then
                node_flags = node_flags | reaper.ImGui_TreeNodeFlags_Leaf() | reaper.ImGui_TreeNodeFlags_NoTreePushOnOpen()
            elseif wwise_hierarchy_filter ~= "" and wwiseNodeOrDescendantsMatch(node, filter_words) then
                node_flags = node_flags | reaper.ImGui_TreeNodeFlags_DefaultOpen()
            end
            
            -- Add visual feedback for selected import target (BEFORE TreeNode creation)
            local colors_pushed = 0
            if selected_wwise_object_for_import and selected_wwise_object_for_import.path == object.path then
                -- Use exact same colors as render table selected items
                local base_color = StyleManager.style.dynamic_colors.selected
                local hover_color = base_color | 0x20202000  -- Add brightness (same as render table)
                
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), base_color)
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), hover_color)
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), base_color)
                colors_pushed = 3
                
                -- Add the Selected flag to make it visually selected
                node_flags = node_flags | reaper.ImGui_TreeNodeFlags_Selected()
            end
            
            -- Create the tree node
            local node_label = object.name
            if has_only_sound_children and matching_sounds_count > 0 then
                node_label = node_label .. string.format(" (%d)", matching_sounds_count)
            end
            local node_open = reaper.ImGui_TreeNode(ctx, node_label, node_flags)
            
            if colors_pushed > 0 then
                reaper.ImGui_PopStyleColor(ctx, colors_pushed)
            end
            
            -- Add selection tracking for import target (only if NOT clicking on arrow)
            if reaper.ImGui_IsItemClicked(ctx, 0) and not currently_dragging then
                -- Check if click was on the arrow part vs the label part
                local item_min_x, item_min_y = reaper.ImGui_GetItemRectMin(ctx)
                local mouse_x, mouse_y = reaper.ImGui_GetMousePos(ctx)
                local indent = reaper.ImGui_GetTreeNodeToLabelSpacing(ctx)
                
                -- Only select if click was on the label part (past the arrow)
                if mouse_x > item_min_x + indent then
                    -- Check if this is a valid container type for import
                    local valid_types = {
                        "ActorMixer", "RandomSequenceContainer", "SwitchContainer", 
                        "BlendContainer", "Folder", "WorkUnit"
                    }
                    
                    local is_valid_target = false
                    for _, valid_type in ipairs(valid_types) do
                        if object.type == valid_type then
                            is_valid_target = true
                            break
                        end
                    end
                    
                    if is_valid_target then
                        selected_wwise_object_for_import = {
                            path = object.path,
                            name = object.name,
                            type = object.type
                        }
                    else
                        selected_wwise_object_for_import = nil
                    end
                end
            end
            
            -- Handle drag and drop
            if reaper.ImGui_BeginDragDropTarget(ctx) then
                local payload = reaper.ImGui_AcceptDragDropPayload(ctx, "RENDER_ITEMS")
                if payload and dragged_items then
                    -- Set target path for drag operation
                    selected_wwise_object_for_import = {
                        path = object.path,
                        name = object.name,
                        type = object.type
                    }
                    addToPendingImports(true)
                end
                reaper.ImGui_EndDragDropTarget(ctx)
            end
            
            -- Handle children recursively
            if node_open and object.type ~= "Sound" then
                if node.children and #node.children > 0 and 
                   not (collapse_end_containers and has_only_sound_children) then
                    wwiseRenderTree(node.children, parent_level + 1, result_count)
                end
                reaper.ImGui_TreePop(ctx)
            end
        end
        
        ::continue::
    end

    return has_visible_children
end

-------------------------------------------------------------------------------------------------------------------------------
------------------------WWISE WINDOW ----------------------------
-------------------------------------------------------------------------------------------------------------------------------


function wwiseWindow()
    if not wwise_window then return end
   
    if ww_window_first_time_open then
        ww_connection_status, ww_proj_name = wwiseConnect()
        originals_path = wwiseGetOriginalsFolder()
        
        if ww_connection_status then
            ww_actor_mixer_hierarchy = wwiseGetActorMixerHierarchy()
            wwise_hierarchy_tree = wwiseBuildHierarchy(ww_actor_mixer_hierarchy or {})
            filtered_hierarchy_tree = wwiseCreateFilteredHierarchy(wwise_hierarchy_tree, "")
        else
            -- Set safe defaults when connection fails
            ww_actor_mixer_hierarchy = {}
            wwise_hierarchy_tree = {}
            filtered_hierarchy_tree = {}
        end
        
        previous_filter = ""
        ww_window_first_time_open = false  -- Always reset the flag
    end
   
    local current_time = reaper.time_precise()
    --if wwise_hierarchy_filter ~= previous_filter and current_time - last_filter_time > filter_delay then
        last_filter_time = current_time
        filtered_hierarchy_tree = wwiseCreateFilteredHierarchy(wwise_hierarchy_tree, wwise_hierarchy_filter)
        previous_filter = wwise_hierarchy_filter
    --end

    StyleManager.PushStyle(ctx)
    reaper.ImGui_PushFont(ctx, base_font, 11)
    local should_display
    reaper.ImGui_SetNextWindowSizeConstraints(ctx, 816, 300, 816, 1000)
    should_display, wwise_window = reaper.ImGui_Begin(ctx, 'WWISE', wwise_window, reaper.ImGui_WindowFlags_NoDocking() | reaper.ImGui_WindowFlags_NoScrollWithMouse() | reaper.ImGui_WindowFlags_NoScrollbar())
   
    if should_display then
        
        reaper.ImGui_BeginChild(ctx, "WWise Stuff", 800, 0)
        reaper.ImGui_Dummy(ctx,0,4)
        reaper.ImGui_Indent(ctx, 8)
       
        if reaper.ImGui_Button(ctx, "CNT!", 36, 36) then
            ww_connection_status, ww_proj_name = wwiseConnect()
            originals_path = wwiseGetOriginalsFolder()
        end
       
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0xB84A62FF)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0xC55B73FF)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0xA13B53FF)
       
        if reaper.ImGui_Button(ctx, "DCN!", 36, 36) then
            ww_connection_status = wwiseDisconnect()
        end
       
        reaper.ImGui_PopStyleColor(ctx, 3)
       
        reaper.ImGui_SameLine(ctx)
       
        if reaper.ImGui_Button(ctx, "GET!", 36, 36) then
            -- ✅ Check connection first
            if not ww_connected then
                ww_connection_status, ww_proj_name = wwiseConnect()
                if not ww_connection_status then
                    reaper.MB("Not connected to Wwise. Please connect first using CNT! button.", "Connection Required", 0)
                    -- Set safe defaults
                    ww_actor_mixer_hierarchy = {}
                    wwise_hierarchy_tree = {}
                    filtered_hierarchy_tree = {}
                    filter_cache = {}
                    return  -- Early return to prevent error
                end
            end
            
            -- Only proceed if connected
            ww_actor_mixer_hierarchy = wwiseGetActorMixerHierarchy()
            wwise_hierarchy_tree = wwiseBuildHierarchy(ww_actor_mixer_hierarchy or {})  -- ✅ Still add safety check
            filter_cache = {}
        end
        reaper.ImGui_SameLine(ctx)
        
        reaper.ImGui_BeginChild(ctx, "WWise project status", 160, 42)
        reaper.ImGui_Dummy(ctx, 0,0)
        --reaper.ImGui_AlignTextToFramePadding(ctx)
        if ww_connection_status then
            reaper.ImGui_Text(ctx, "CONNECTED" .. "\n" ..ww_proj_name)
        else
            reaper.ImGui_Text(ctx, "NOT CONNECTED")
        end
       
        if ww_connection_status then
            --reaper.ImGui_Text(ctx, ww_proj_name)
        else
            reaper.ImGui_Text(ctx, "...")
        end
       
        reaper.ImGui_EndChild(ctx)
        
        reaper.ImGui_SameLine(ctx)
        
        reaper.ImGui_Dummy(ctx, 5,5)
        
        reaper.ImGui_SameLine(ctx)
        
        reaper.ImGui_BeginChild(ctx, "WWise path global override", 470, 42)
        if ww_connection_status then
 
           -- Determine what to show in the combo preview
           local combo_preview = ""
           if global_path_override and global_path_override ~= "" then
               combo_preview = global_path_override
           else
               combo_preview = originals_path or "Default Originals"
           end
           
           -- Truncate from left if too long (show right side)
           local max_chars = 60  -- Adjust this number based on your combo width
           if string.len(combo_preview) > max_chars then
               combo_preview = "..." .. string.sub(combo_preview, -(max_chars - 3))
           end
           
           reaper.ImGui_SetNextItemWidth(ctx, 470)
           reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 10, 12)
           if reaper.ImGui_BeginCombo(ctx, "##PathOverride", combo_preview) then
               -- First option: Default originals path
               if reaper.ImGui_Selectable(ctx, originals_path or "Default Originals", global_path_override == "") then
                   global_path_override = ""
               end
               
               -- Add separator if we have history
               if #path_history > 0 then
                   reaper.ImGui_Separator(ctx)
                   -- Recent paths
                   for i, hist_path in ipairs(path_history) do
                       local display_name = hist_path
                       -- Truncate long paths for display
                       if string.len(display_name) > 50 then
                           display_name = "..." .. string.sub(display_name, -47)
                       end
                       
                       if reaper.ImGui_Selectable(ctx, display_name, global_path_override == hist_path) then
                           global_path_override = hist_path
                       end
                       
                       -- Show full path in tooltip
                       if reaper.ImGui_IsItemHovered(ctx) then
                           reaper.ImGui_SetTooltip(ctx, hist_path)
                       end
                   end
                   reaper.ImGui_Separator(ctx)
               end
               
               -- Second option: Browse for new path
               if reaper.ImGui_Selectable(ctx, "Browse...") then
                   local start_path = originals_path or ""
                   local retval, selected_path = reaper.JS_Dialog_BrowseForFolder("Select Import Path", originals_path)
                   if retval then
                       global_path_override = selected_path
                       addToPathHistory(selected_path) -- Add to history
                   end
               end
               
               reaper.ImGui_EndCombo(ctx)
           end
           reaper.ImGui_PopStyleVar(ctx)
           
        end
        
        reaper.ImGui_EndChild(ctx)

        -----------------------------------------------------------------------------------------------------------------------------------
        -------------------------------------- Pppppending imports TABLE rendering section ------------------------------------------------
        -----------------------------------------------------------------------------------------------------------------------------------
        
        reaper.ImGui_Dummy(ctx, 0, 5)
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_CellPadding(), 4, 4) -- 4px horizontal, 6px vertical
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 0, 0)
        local table_flags = reaper.ImGui_TableFlags_Borders()
        if reaper.ImGui_BeginTable(ctx, "pending_imports", 5, table_flags, 784) then
            reaper.ImGui_TableSetupColumn(ctx, "Source Items", reaper.ImGui_TableColumnFlags_WidthFixed(), 180) 
            reaper.ImGui_TableSetupColumn(ctx, "Target", reaper.ImGui_TableColumnFlags_WidthFixed(), 160)
            reaper.ImGui_TableSetupColumn(ctx, "Container", reaper.ImGui_TableColumnFlags_WidthFixed(), 330)
            reaper.ImGui_TableSetupColumn(ctx, "Path", reaper.ImGui_TableColumnFlags_WidthFixed(), 45)
            reaper.ImGui_TableSetupColumn(ctx, "Del", reaper.ImGui_TableColumnFlags_WidthFixed(), 25)
            reaper.ImGui_TableHeadersRow(ctx)
           
            if #pending_imports == 0 then
                reaper.ImGui_TableNextRow(ctx)
                reaper.ImGui_TableSetColumnIndex(ctx, 0)
                reaper.ImGui_Text(ctx, "No pending imports...")
            end
           
            for idx, import in ipairs(pending_imports) do
                reaper.ImGui_TableNextRow(ctx)
                reaper.ImGui_TableSetColumnIndex(ctx, 0)
               
                -- Show group name if available, otherwise fall back to item names
                local preview_text = import.group_name or
                    (import.items[1].name .. (#import.items > 1 and string.format(" (+%d more)", #import.items - 1) or ""))

                local variations = {}
                for _, item in ipairs(import.items) do
                    local var = item.name:match("_(%d+)$")
                    if var then table.insert(variations, tonumber(var)) end
                end
               
                local variation_range = #variations > 1
                    and string.format("[%02d-%02d]", math.min(table.unpack(variations)), math.max(table.unpack(variations)))
                    or ""
             
                reaper.ImGui_Text(ctx, preview_text .. " " .. variation_range)
               
                reaper.ImGui_TableSetColumnIndex(ctx, 1)
                local display_path = string.gsub(import.target_path, "\\Actor%-Mixer Hierarchy", "")
                reaper.ImGui_Text(ctx, display_path)
                
                -- Right-click context menu for changing target
                if reaper.ImGui_IsItemClicked(ctx, 1) then
                    reaper.ImGui_OpenPopup(ctx, "ChangeTarget##" .. idx)
                end
                
                if reaper.ImGui_BeginPopup(ctx, "ChangeTarget##" .. idx) then
                    if reaper.ImGui_MenuItem(ctx, "Change target to selected") then
                        if selected_wwise_object_for_import then
                            import.target_path = selected_wwise_object_for_import.path
                        else
                            reaper.MB("No Wwise object selected.\nPlease click on an object in the Wwise hierarchy first.", "No Target Selected", 0)
                        end
                    end
                    reaper.ImGui_EndPopup(ctx)
                end
               
                -- Container type selection
                reaper.ImGui_TableSetColumnIndex(ctx, 2)
               
                -- Container type buttons with predefined colors
                local container_types = {
                    { name = "SEQ", type = "RandomSequenceContainer", color = 0xE25473FF, play_type = 0 },
                    { name = "RND", type = "RandomSequenceContainer", color = 0x5190C7FF, play_type = 1 },
                    { name = "SWC", type = "SwitchContainer", color = 0xF05D5EFF },
                    { name = "BLC", type = "BlendContainer", color = 0x23CEAFFF },
                    { name = "AMX", type = "ActorMixer", color = 0xFFC145FF },
                    { name = "FLD", type = "Folder", color = 0x545863FF }
                }
               
                -- Ensure import has a container type
                if not import.container_type then
                    import.container_type = nil  -- No container by default
                end
               
                for _, container in ipairs(container_types) do
                    local is_selected = import.container_type and
                                        import.container_type.type == container.type and
                                        (container.play_type == nil or import.container_type.play_type == container.play_type)
                   
                    if is_selected then
                        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xE1DABDFF)
                        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x00000FF)
                        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000FF)
                        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0x00000FF)
                    else
                        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x111111FF)
                        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), container.color)
                        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), container.color)
                        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), container.color)
                    end
                   
                    if reaper.ImGui_Button(ctx, container.name .. "##" .. idx) then
                        -- Unselect all other buttons for this import
                        if is_selected then
                            import.container_type = nil  -- Deselect if already selected
                            import.container_name = nil
                        else
                            import.container_type = {
                                type = container.type,
                                play_type = container.play_type
                            }
                            -- Only set container name if it hasn't been manually entered
                            if not import.container_name then
                                import.container_name = import.group_name and
                                    import.group_name:gsub("%s*%[%d+-%d+%]$", "") or
                                    import.items[1].name:gsub("_%d+$", "")
                            end
                        end
                    end
                   
                    reaper.ImGui_PopStyleColor(ctx, 4)
                   
                    if _ < #container_types then
                        reaper.ImGui_SameLine(ctx)
                    end
                end
               
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_SetNextItemWidth(ctx, 145)
                _, import.container_name = reaper.ImGui_InputText(ctx, "##ContainerName" .. idx,
                    import.container_name or
                    (import.group_name and import.group_name:gsub("%s*%[%d+-%d+%]$", "") or
                     import.items[1].name:gsub("_%d+$", "")))
               
                reaper.ImGui_TableSetColumnIndex(ctx, 3)
                
                -- Determine if this import has a path override
                local has_override = import.path_override and import.path_override ~= ""
                local actual_path = has_override and import.path_override or (originals_path or "Default Originals")
                
                -- Set button color based on override status
                if has_override then
                   reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0xFFD700FF)        -- Yellow
                   reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0xFFE135FF) -- Lighter yellow
                   reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0xE6C200FF)  -- Darker yellow
                else
                   reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x808080FF)        -- Gray
                   reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x909090FF) -- Lighter gray
                   reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0x707070FF)  -- Darker gray
                end
                
                reaper.ImGui_SetNextItemWidth(ctx, 30)
                if reaper.ImGui_BeginCombo(ctx, "##PathOverride" .. idx, "") then
                    -- First option: Default originals path
                    if reaper.ImGui_Selectable(ctx, originals_path or "Default Originals", not has_override) then
                        import.path_override = ""
                    end
                    
                    -- Add recent paths if we have any
                    if #path_history > 0 then
                        reaper.ImGui_Separator(ctx)
                        for i, hist_path in ipairs(path_history) do
                            local display_name = hist_path
                            if string.len(display_name) > 40 then
                                display_name = "..." .. string.sub(display_name, -37)
                            end
                            
                            if reaper.ImGui_Selectable(ctx, display_name, import.path_override == hist_path) then
                                import.path_override = hist_path
                            end
                            
                            if reaper.ImGui_IsItemHovered(ctx) then
                                reaper.ImGui_SetTooltip(ctx, hist_path)
                            end
                        end
                        reaper.ImGui_Separator(ctx)
                    end
                    
                    -- Browse option
                    if reaper.ImGui_Selectable(ctx, "Browse...") then
                        local start_path = originals_path or ""
                        local retval, selected_path = reaper.JS_Dialog_BrowseForFolder("Select Import Path for " .. (import.group_name or import.items[1].name), originals_path)
                        if retval then
                            import.path_override = selected_path
                            addToPathHistory(selected_path) -- Add to history
                        end
                    end
                    
                    reaper.ImGui_EndCombo(ctx)
                end
                
                -- Add tooltip on hover
                if reaper.ImGui_IsItemHovered(ctx) then
                   reaper.ImGui_SetTooltip(ctx, actual_path)
                end
                
                reaper.ImGui_PopStyleColor(ctx, 3)
                
                
                reaper.ImGui_TableSetColumnIndex(ctx, 4)
                if reaper.ImGui_Button(ctx, "DEL##" .. idx) then
                    table.remove(pending_imports, idx)
                end
            end
           
            reaper.ImGui_EndTable(ctx)
        
        end
        
        reaper.ImGui_PopStyleVar(ctx, 2)
        
        reaper.ImGui_Dummy(ctx, 0, 5)

        -----------------------------------------------------------------------------------------------------------------------------------
        -------------------------------------------------------- FILTER ----------------------------------------------------------
        -----------------------------------------------------------------------------------------------------------------------------------
        
        reaper.ImGui_BeginChild(ctx, "FilterWWise", 604, 42)
        reaper.ImGui_SetNextItemWidth(ctx, 280)
        
        -- Get new filter text
        local retval, new_filter = reaper.ImGui_InputText(ctx, "Filter WWise Hierarchy", wwise_hierarchy_filter)
        
        -- Add collapse checkbox
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_Dummy(ctx, 28, 0)
        reaper.ImGui_SameLine(ctx)
        _, collapse_end_containers = reaper.ImGui_Checkbox(ctx, "Compact View", collapse_end_containers)
        
        -- Only update the actual filter if it contains a word of at least 3 characters
        local temp_words = validateAndPrepareFilterWords(new_filter)
        if #temp_words > 0 or new_filter == "" then
            wwise_hierarchy_filter = new_filter
        end
        
        reaper.ImGui_EndChild(ctx)
        
        if #pending_imports > 0 then
            
            reaper.ImGui_SameLine(ctx)

            reaper.ImGui_Dummy(ctx, 22, 0)
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x3C39D6FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x4846E7FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0x3734D5FF)
            if reaper.ImGui_Button(ctx, "TRS!", 136, 36) then
                handleTRSButton()
            end
            reaper.ImGui_PopStyleColor(ctx,3)
        end
       
        -----------------------------------------------------------------------------------------------------------------------------------
        -------------------------------------------------------- WWise hierarchy ----------------------------------------------------------
        -----------------------------------------------------------------------------------------------------------------------------------
       
        -- Add a scrollable child window for the hierarchy
        reaper.ImGui_BeginChild(ctx, "WWiseHierarchy", 782)  
        if filtered_hierarchy_tree and #filtered_hierarchy_tree > 0 then
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 0, 0)
            wwiseRenderTree(filtered_hierarchy_tree, 1)  -- Use the filtered tree
            reaper.ImGui_PopStyleVar(ctx, 1)
        end
        reaper.ImGui_EndChild(ctx)
        reaper.ImGui_Unindent(ctx)
        reaper.ImGui_EndChild(ctx)
        
        conflictResolutionPopup(ctx)

       
        reaper.ImGui_End(ctx)
    end
    StyleManager.PopStyle(ctx)
    reaper.ImGui_PopFont(ctx)
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
------------------------HELPER TO ADD TO PATH HISTORY-----------------
-----------------------------------------------------------------------------------------------------------------

function addToPathHistory(new_path)
    if not new_path or new_path == "" then return end
    
    -- Remove path if it already exists (to move it to front)
    for i, existing_path in ipairs(path_history) do
        if existing_path == new_path then
            table.remove(path_history, i)
            break
        end
    end
    
    -- Add to front
    table.insert(path_history, 1, new_path)
    
    -- Keep only last 7 paths
    while #path_history > max_path_history do
        table.remove(path_history, #path_history)
    end
    
    -- Save immediately
    SaveSettingsToCSV()
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
        
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x00ffd3FF)
        
        if reaper.ImGui_MenuItem(ctx, "Replace files in WWise           | alt + WWISE!") then
            handleReplaceFilesInWwise()  -- ← Use the same function!
        end
        
        if reaper.ImGui_MenuItem(ctx, "Import to selected in WWise      | shift + WWISE!") then
            handleImportToSelectedWwise(false)
        end
        
        if reaper.ImGui_MenuItem(ctx, "Import to selected with browsing | shift + alt + WWISE!") then
            handleImportToSelectedWwise(true)
        end
        
        if wwise_window then
            if reaper.ImGui_MenuItem(ctx, "Add to pending imports           | ctrl + WWISE!") then
                addToPendingImports(false)
            end
        end
        
        reaper.ImGui_PopStyleColor(ctx, 1)
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

function addToPendingImports(is_from_drag)
    local items_to_import = {}
    local target_path = nil
    
    if is_from_drag then
        -- Use existing drag logic
        if not dragged_items or #dragged_items == 0 then
            return false
        end
        items_to_import = dragged_items
        -- target_path will be set by the drop target in the calling context
    else
        -- Use selected items from main table and pre-selected Wwise target
        if not selected_wwise_object_for_import then
            reaper.MB("No Wwise object selected for import.\nPlease click on an object in the Wwise hierarchy first.", "No Target Selected", 0)
            return false
        end
        
        if not next(selected_items) then
            reaper.MB("No items selected for import", "Error", 0)
            return false
        end
        
        items_to_import = collectSelectedItemsInfo()
        target_path = selected_wwise_object_for_import.path
    end
    
    if #items_to_import == 0 then
        return false
    end
    
    -- Group items (same logic as existing drag-and-drop)
    local ww_grouped_items = wwiseGroupItems(items_to_import)
    
    -- Add each group to pending imports
    for group_name, group_items in pairs(ww_grouped_items) do
        table.insert(pending_imports, {
            items = group_items,
            target_path = target_path or selected_wwise_object_for_import.path,
            group_name = group_name
        })
    end
    
    return true
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
                        
                        -- Handle Shift+drag for Wwise (this is the key fix!)
                        -- This should happen regardless of currently_dragging state
                        if shift_pressed and reaper.ImGui_IsItemActive(ctx) then
                            if reaper.ImGui_BeginDragDropSource(ctx, reaper.ImGui_DragDropFlags_None()) then
                                dragged_items = collectSelectedItemsInfo()
                                reaper.ImGui_SetDragDropPayload(ctx, "RENDER_ITEMS", "items")
                                
                                reaper.ImGui_Text(ctx, string.format("������ Dragging %d items", #dragged_items))
                                for i = 1, math.min(3, #dragged_items) do
                                    reaper.ImGui_Text(ctx, "  " .. dragged_items[i].name)
                                end
                                if #dragged_items > 3 then
                                    reaper.ImGui_Text(ctx, "  ...")
                                end
                                reaper.ImGui_EndDragDropSource(ctx)
                            end
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
           
            reaper.ImGui_SameLine(ctx)
           
            reaper.ImGui_BeginChild(ctx, "WWISE", 42, 138, 0, reaper.ImGui_WindowFlags_None())
            
            reaper.ImGui_Indent(ctx, 8)
           
            reaper.ImGui_Dummy(ctx,4,22)
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 0,0)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x3C39D6FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x4846E7FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0x3734D5FF)

            if reaper.ImGui_Button(ctx, "W" .. "\n" .. "W" .. "\n" .. "I" .. "\n" .. "S" .. "\n" .. "E", 24, 86) then
                if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) and not reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift()) then
                    handleReplaceFilesInWwise()
                elseif reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift())and not reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then
                    handleImportToSelectedWwise(false)
                elseif reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift()) and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then
                    handleImportToSelectedWwise(true)
                elseif reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and not reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift()) and not reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then
                    addToPendingImports(false)
                else
                    wwise_window = not wwise_window
                end
            end
            
            reaper.ImGui_SameLine(ctx)
            
            -- Updated right-click handler
            if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Right()) then
                reaper.ImGui_OpenPopup(ctx, "WWise Context Menu")  -- Open the popup
            end

            if reaper.ImGui_BeginPopup(ctx, "WWise Context Menu") then
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x00ffd3FF)
                if reaper.ImGui_MenuItem(ctx, "Replace files in WWise           | alt + WWISE!") then
                    local items_to_replace = collectSelectedItemsInfo()
                    renderAndImportToWwise(items_to_replace, nil, {replace_existing = true})
                end
                
                if reaper.ImGui_MenuItem(ctx, "Import to selected in WWise      | shift + WWISE!") then
                    handleImportToSelectedWwise(false)
                end
                
                if reaper.ImGui_MenuItem(ctx, "Import to selected with browsing | shift + alt + WWISE!") then
                    handleImportToSelectedWwise(true)
                end
                
                if wwise_window then
                    if reaper.ImGui_MenuItem(ctx, "Add to pending imports           | ctrl + WWISE!") then
                        addToPendingImports(false)
                    end
                end
                reaper.ImGui_PopStyleColor(ctx)
                reaper.ImGui_EndPopup(ctx)
            end
            
            -- Updated drag and drop target behavior
            if reaper.ImGui_BeginDragDropTarget(ctx) then
                local payload = reaper.ImGui_AcceptDragDropPayload(ctx, "RENDER_ITEMS")
                if payload and dragged_items then
                    renderAndImportToWwise(dragged_items, nil, {replace_existing = true})
                    dragged_items = {}  -- Clear dragged items after processing
                end
                reaper.ImGui_EndDragDropTarget(ctx)
            end
           
            reaper.ImGui_PopStyleVar(ctx, 1)
            reaper.ImGui_PopStyleColor(ctx, 3)
            reaper.ImGui_Unindent(ctx)
           
            reaper.ImGui_EndChild(ctx)
           
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
        wwiseWindow()
        pathConflictResolutionWindow()
        reaper.defer(loop)
    else
        SaveSettingsToCSV()
    end
end

LoadSettingsFromCSV()
loop()

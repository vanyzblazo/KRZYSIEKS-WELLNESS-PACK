--[[
@version 1.05
--]]

ultraschall_path = reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua"
if reaper.file_exists( ultraschall_path ) then
  dofile( ultraschall_path )
end

if not ultraschall or not ultraschall.GetApiVersion then
    reaper.ShowConsoleMsg("Please install both Ultrashall API and ReaTeam js_ReaScript API" .. "\n" .. "REAPACK LINK: https://github.com/Ultraschall/ultraschall-lua-api-for-reaper/raw/master/ultraschall_api_index.xml" .. "\n" .. "REAPACK LINK: https://github.com/ReaTeam/Extensions/raw/master/index.xml")
    reaper.MB("Please install Ultraschall API and ReaTeam js_ReaScript API , available via Reapack.", "Error", 0)
    return
  end

-- STYLES --------------------------------------------------------------------------------------------------------------------------
local StyleManager = {
    push_count = 0,
    style = {
        vars = {
            [reaper.ImGui_StyleVar_FramePadding()] = {4, 10},
            [reaper.ImGui_StyleVar_TabBarBorderSize()] = 10,
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

-- Initialize ImGui context
local ctx = reaper.ImGui_CreateContext('RENDERVAN')
if not ctx then
    reaper.ShowConsoleMsg("REAPACK LINK: https://github.com/ReaTeam/Extensions/raw/master/index.xml")
    reaper.ShowMessageBox("Please install ImGUI for REAPER via Reapack." .. "\n" .. "It is available as a part of ReaTeam Extensions on Reapack. ", "Error", 0)
    return
end

-- FONTS -----------------------------------------------------------------------------------------------------------------------------------

local font_name = "ProggyClean"
-- Small font
local small_font = reaper.ImGui_CreateFont(font_name, 12)
reaper.ImGui_Attach(ctx, small_font)

-- Normal font
local normal_font = reaper.ImGui_CreateFont(font_name, 14)
reaper.ImGui_Attach(ctx, normal_font)

-- Big font
local big_font = reaper.ImGui_CreateFont(font_name, 16)
reaper.ImGui_Attach(ctx, big_font)

-- INIT VARIABLES --------------------------------------------------------------------------------------------------------------------------

local visible = true
local items, types, prefixes = {}, {}, {}
local first_open = true
local sound_name = ""
local folder_items = {} -- Store folder items for batch channel input
local render_queue = {}
local active_render_flags = {} -- Store active render flags as {region_index = {track_guid = flag}}
local last_project_change_count = 0
local renaming_to_same_name = false
local preferences_window = false
local pending_imports = {} -- Table to track pending imports: {source_item = {name=, path=}, target_path = "wwise/path"}
local drop_target_path = nil

local selected_items = {}
local is_dragging = false
local drag_start_pos = nil
local drag_end_pos = nil
local drag_started_from_selected = false
local selectedFilteredIndex = 1
local pref_variaton_start_number = 0

local show_channel_input_popup = false
local num_channels = ""
local finalPrefix = ""
local region_folder_map = {} -- Data structure to track folder items and regions
local track_folder_map = {} -- Data structure to track folder items and tracks

local filter_text = ""
local filtered_items = {}

-- INIT SETTINGS --------------------------------------------------------------------------------------------------------------------------

-- Render settings variables
local use_additional_render_path = false
local additional_render_path = ""
local render_bitdepths = {"8 bit", "16 bit", "24 bit", "32 bit"}
local selected_bitdepth_index = 2 -- Default to 16
local render_sample_rates = {"32 kHz", "44 kHz", "48 kHz", "88 kHz", "96 kHz", "192 kHz"}
local selected_sample_rate_index = 3 -- Default to 48 kHz
local ww_project_only_render = true

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
   
    reaper.ShowConsoleMsg("Failed to connect to Wwise\n")
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
        reaper.ShowConsoleMsg("Not connected to Wwise\n")
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

-----------------------------------------------------------------------------------------------------------------
------------------------GET ACTOR MIXER HIERARCHY FROM WWISE-----------------------------
-----------------------------------------------------------------------------------------------------------------

function wwiseGetActorMixerHierarchy()
    if not ww_connected then
        --reaper.ShowConsoleMsg("Not connected to Wwise\n")
        return nil
    end
    --reaper.ShowConsoleMsg("Starting hierarchy fetch...\n")

    local hierarchy = {}

    local args = reaper.AK_AkJson_Map()
    -- Modified query to get all descendants
    reaper.AK_AkJson_Map_Set(args, "waql", reaper.AK_AkVariant_String("$ \"Actor-Mixer Hierarchy\" select descendants where type != \"AudioFileSource\""))

    --reaper.ShowConsoleMsg("Args set\fields = reaper.AK_AkJson_Array()
    local fields = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("name"))
    reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("type"))
    reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("path"))
    reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("@RandomOrSequence"))
    --reaper.ShowConsoleMsg("Fields added\n")

    local options = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(options, "return", fields)
    --reaper.ShowConsoleMsg("Options set\n")

    local result = reaper.AK_Waapi_Call("ak.wwise.core.object.get", args, options)
    --reaper.ShowConsoleMsg("WAAPI call made\n")
   
    local status = reaper.AK_AkJson_GetStatus(result)
    --reaper.ShowConsoleMsg("Status: " .. tostring(status) .. "\n")
   
    if status then
        local return_objects = reaper.AK_AkJson_Map_Get(result, "return")
        local num_objects = reaper.AK_AkJson_Array_Size(return_objects)
        --reaper.ShowConsoleMsg("Number of objects: " .. tostring(num_objects) .. "\n")
       
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
           
            --reaper.ShowConsoleMsg("Processing object: " .. name_str .. " (" .. type_str .. " PTV:" .. play_type_value .. ")\n")

           
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

-----------------------------------------------------------------------------------------------------------------
------------------------WWISE IMPORT-----------------------------
-----------------------------------------------------------------------------------------------------------------

function wwiseImport(items, target_path, container_info)  -- Added container_info parameter
    if not ww_connected then
        reaper.ShowConsoleMsg("Not connected to Wwise\n")
        return false
    end

    -- Store current selection state and handle render queue
    local previous_selection = {}
    for item, props in pairs(selected_items) do
        previous_selection[item] = props
    end

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
   
    renderQueuedRegions()
   
    use_additional_render_path = previous_additional_path_state
    selected_items = previous_selection
    updateRenderQueue()

    -- Create container if specified
    local container_path = target_path
    --reaper.ShowConsoleMsg("Initial target_path: " .. target_path .. "\n")
    --reaper.ShowConsoleMsg("Container type: " .. tostring(container_info and container_info.type and container_info.type.type) .. "\n")
    --reaper.ShowConsoleMsg("Container name: " .. tostring(container_info and container_info.name) .. "\n")
   
    if container_info and container_info.type and container_info.name then
        local containerCommand = "ak.wwise.core.object.set"
        local objects = reaper.AK_AkJson_Array()
        local containerObj = reaper.AK_AkJson_Map()
       
        -- Set container object
        reaper.AK_AkJson_Map_Set(containerObj, "object", reaper.AK_AkVariant_String(target_path))
       
        -- Create children array for the new container
        local children = reaper.AK_AkJson_Array()
        local child = reaper.AK_AkJson_Map()
       
        -- Set up container properties
        reaper.AK_AkJson_Map_Set(child, "name", reaper.AK_AkVariant_String(container_info.name))
        reaper.AK_AkJson_Map_Set(child, "type", reaper.AK_AkVariant_String(container_info.type.type))
       
        -- Set play type for sequence/random containers
        if container_info.type.type == "RandomSequenceContainer" and container_info.type.play_type ~= nil then
            reaper.AK_AkJson_Map_Set(child, "@RandomOrSequence", reaper.AK_AkVariant_Int(container_info.type.play_type))
        end
       
        -- Add child to children array
        reaper.AK_AkJson_Array_Add(children, child)
       
        -- Add children array to container object
        reaper.AK_AkJson_Map_Set(containerObj, "children", children)
       
        -- Add container object to objects array
        reaper.AK_AkJson_Array_Add(objects, containerObj)
       
        -- Set up arguments
        local args = reaper.AK_AkJson_Map()
        reaper.AK_AkJson_Map_Set(args, "objects", objects)
       
        -- Create container and handle response
        local containerResult = reaper.AK_Waapi_Call(containerCommand, args, reaper.AK_AkJson_Map())
        local containerStatus = reaper.AK_AkJson_GetStatus(containerResult)
       
        if not containerStatus then
            local errorMessage = reaper.AK_AkJson_Map_Get(containerResult, "message")
            local errorMessageStr = reaper.AK_AkVariant_GetString(errorMessage)
            reaper.ShowConsoleMsg("Container creation failed: " .. errorMessageStr .. "\n")
            return false
        end
       
        -- Update container path for audio import
        container_path = target_path .. "\\" .. container_info.name
    end

    -- Set up Wwise import command
    local importCommand = "ak.wwise.core.audio.import"
    local importOperation = reaper.AK_AkVariant_String("replaceExisting")
   
    -- Set up default import settings
    local default = reaper.AK_AkJson_Map()
    local importLanguage = reaper.AK_AkVariant_String("SFX")
    reaper.AK_AkJson_Map_Set(default, "importLanguage", importLanguage)
   
    -- Create imports array
    local imports = reaper.AK_AkJson_Array()
   
    -- Get project path and render directory
    local project_path = reaper.GetProjectPath()
    local suffix = "Audio Files"
    if project_path:sub(-#suffix) == suffix then
        project_path = project_path:sub(1, -#suffix - 1)
    end
    local render_directory = project_path .. pref_inner_render_folder
   
    -- Build import array for each item
    for _, item_info in ipairs(items) do
        local importItem = reaper.AK_AkJson_Map()
       
        -- Set audio file path
        local audioFilePath = render_directory .. "/" .. item_info.name .. ".wav"
        reaper.AK_AkJson_Map_Set(importItem, "audioFile",
            reaper.AK_AkVariant_String(audioFilePath))
       
        -- Set object path (target path in Wwise)
        local objectPath = container_path .. "\\<Sound SFX>" .. item_info.name
        reaper.AK_AkJson_Map_Set(importItem, "objectPath",
            reaper.AK_AkVariant_String(objectPath))
       
        -- Set originals subfolder
        reaper.AK_AkJson_Map_Set(importItem, "originalsSubFolder",
            reaper.AK_AkVariant_String(""))
       
        -- Add to imports array
        reaper.AK_AkJson_Array_Add(imports, importItem)
    end
   
    -- Set up main arguments
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "importOperation", importOperation)
    reaper.AK_AkJson_Map_Set(arguments, "default", default)
    reaper.AK_AkJson_Map_Set(arguments, "imports", imports)
    reaper.AK_AkJson_Map_Set(arguments, "autoAddToSourceControl",
        reaper.AK_AkVariant_Bool(true))
   
    -- Execute import if there are files to import
    local numFilesToImport = reaper.AK_AkJson_Array_Size(imports)
   
    if numFilesToImport > 0 then
        local result = reaper.AK_Waapi_Call(importCommand, arguments, reaper.AK_AkJson_Map())
        local status = reaper.AK_AkJson_GetStatus(result)
       
        if status then
            return true
        else
            local errorMessage = reaper.AK_AkJson_Map_Get(result, "message")
            local errorMessageStr = reaper.AK_AkVariant_GetString(errorMessage)
            reaper.ShowConsoleMsg("Wwise import failed: " .. errorMessageStr .. "\n")
            return false
        end
    else
        return false
    end
end

function wwiseReplaceAudio(items)
    if not ww_connected then
        ww_connection_status, ww_proj_name = wwiseConnect()
        if not ww_connection_status then
            reaper.MB("Failed to connect to WWise", "Error", 0)
            return false
        end
    end

    -- First, try to find each sound
    local found_sounds = {}
    for _, item_info in ipairs(items) do
        local search_args = reaper.AK_AkJson_Map()
        -- Specific search for Sound objects with exact name match
        local search_query = string.format('$ from type Sound where name = "%s"', item_info.name)
        reaper.AK_AkJson_Map_Set(search_args, "waql", reaper.AK_AkVariant_String(search_query))

        local fields = reaper.AK_AkJson_Array()
        reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("name"))
        reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("path"))
        reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("type"))
        reaper.AK_AkJson_Array_Add(fields, reaper.AK_AkVariant_String("id"))

        local options = reaper.AK_AkJson_Map()
        reaper.AK_AkJson_Map_Set(options, "return", fields)

        --reaper.ShowConsoleMsg("\nSearching with query: " .. search_query .. "\n")
        
        local result = reaper.AK_Waapi_Call("ak.wwise.core.object.get", search_args, options)
        local status = reaper.AK_AkJson_GetStatus(result)
        

        if status then
            local return_objects = reaper.AK_AkJson_Map_Get(result, "return")
            local num_objects = reaper.AK_AkJson_Array_Size(return_objects)

            --reaper.ShowConsoleMsg("Found " .. num_objects .. " objects\n")

            for i = 0, num_objects - 1 do
                local obj = reaper.AK_AkJson_Array_Get(return_objects, i)
                local name = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(obj, "name"))
                local path = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(obj, "path"))
                local type = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(obj, "type"))
                local id = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(obj, "id"))

                --reaper.ShowConsoleMsg(string.format("Found: %s (%s) at %s [ID: %s]\n", name, type, path, id))
                
                -- Store sound path
                found_sounds[name] = path
                --reaper.ShowConsoleMsg("*** Matched sound! ***\n")
            end
        end
    end

    -- Store current selection state and handle render queue
    local previous_selection = {}
    for item, props in pairs(selected_items) do
        previous_selection[item] = props
    end

    -- Set up items for rendering
    selected_items = {}
    for _, item_info in ipairs(items) do
        if item_info.item then
            selected_items[item_info.item] = item_info.second_pass and { second_pass = true } or {}
        end
    end
   
    -- Render the files
    updateRenderQueue()
    
    local previous_additional_path_state = use_additional_render_path
    if ww_project_only_render then
        use_additional_render_path = false
    end
   
    renderQueuedRegions()
    
    use_additional_render_path = previous_additional_path_state
    selected_items = previous_selection
    updateRenderQueue()

    -- Set up Wwise import command for replacement
    local importCommand = "ak.wwise.core.audio.import"
    local importOperation = reaper.AK_AkVariant_String("useExisting")
   
    -- Set up default import settings
    local default = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(default, "importLanguage", reaper.AK_AkVariant_String("SFX"))
   
    -- Create imports array
    local imports = reaper.AK_AkJson_Array()
   
    -- Get project path and render directory
    local project_path = reaper.GetProjectPath()
    local suffix = "Audio Files"
    if project_path:sub(-#suffix) == suffix then
        project_path = project_path:sub(1, -#suffix - 1)
    end
    local render_directory = project_path .. pref_inner_render_folder
   
    -- Track items that weren't found in WWise
    local not_found_items = {}
    
    --reaper.ShowConsoleMsg("\nBuilding import list:\n")
    
    -- Build import array for each item
    for _, item_info in ipairs(items) do
        local sound_path = found_sounds[item_info.name]
        
        if sound_path then
            --reaper.ShowConsoleMsg(string.format("Item: %s\n", item_info.name))
            --reaper.ShowConsoleMsg(string.format("Original path: %s\n", sound_path))
            
            local importItem = reaper.AK_AkJson_Map()
            local audioFilePath = render_directory .. "/" .. item_info.name .. ".wav"
            reaper.AK_AkJson_Map_Set(importItem, "audioFile", reaper.AK_AkVariant_String(audioFilePath))
            reaper.AK_AkJson_Map_Set(importItem, "objectPath", reaper.AK_AkVariant_String(sound_path))
            reaper.AK_AkJson_Map_Set(importItem, "objectType", reaper.AK_AkVariant_String("Sound"))
            reaper.AK_AkJson_Map_Set(importItem, "importLanguage", reaper.AK_AkVariant_String("SFX"))
            reaper.AK_AkJson_Array_Add(imports, importItem)
            
            --reaper.ShowConsoleMsg(string.format("Import path set to: %s\n\n", sound_path))
        else
            --reaper.ShowConsoleMsg("No match found for: " .. item_info.name .. "\n")
            table.insert(not_found_items, item_info.name)
        end
    end
   
    -- Set up main arguments
    local arguments = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(arguments, "importOperation", importOperation)
    reaper.AK_AkJson_Map_Set(arguments, "default", default)
    reaper.AK_AkJson_Map_Set(arguments, "imports", imports)
    reaper.AK_AkJson_Map_Set(arguments, "autoAddToSourceControl", reaper.AK_AkVariant_Bool(true))
   
    -- Execute import
    local numFilesToImport = reaper.AK_AkJson_Array_Size(imports)
    
    if #not_found_items > 0 then
        local msg = "The following items were not found in WWise:\n" .. table.concat(not_found_items, "\n")
        reaper.MB(msg, "Not Found", 0)
    end
   
    if numFilesToImport > 0 then
        --reaper.ShowConsoleMsg("\nSending import command with " .. numFilesToImport .. " files\n")
        
        local result = reaper.AK_Waapi_Call(importCommand, arguments, reaper.AK_AkJson_Map())
        local status = reaper.AK_AkJson_GetStatus(result)
       
        if status then
            -- Get more details from the result
            local resultObj = reaper.AK_AkJson_Map_Get(result, "objects")
            local numImported = reaper.AK_AkJson_Array_Size(resultObj)
            --reaper.ShowConsoleMsg(string.format("Import completed. %d objects imported.\n", numImported))

            -- Check for logs
            local logs = reaper.AK_AkJson_Map_Get(result, "log")
            local numLogs = reaper.AK_AkJson_Array_Size(logs)
            
            --reaper.ShowConsoleMsg("\nImport logs:\n")
            for i = 0, numLogs - 1 do
                local logEntry = reaper.AK_AkJson_Array_Get(logs, i)
                local severity = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(logEntry, "severity"))
                local message = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(logEntry, "message"))
                --reaper.ShowConsoleMsg(string.format("[%s] %s\n", severity, message))
            end
            
            return true
        else
            local errorMessage = reaper.AK_AkJson_Map_Get(result, "message")
            local errorMessageStr = reaper.AK_AkVariant_GetString(errorMessage)
            --reaper.ShowConsoleMsg("Import failed: " .. errorMessageStr .. "\n")
            reaper.MB("WWise import failed: " .. errorMessageStr, "Error", 0)
            return false
        end
    end
    
    return false
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

function wwiseRenderTree(tree, parent_level, result_count)
    result_count = result_count or {count = 0, max = 50}  
    parent_level = parent_level or 1
    local has_visible_children = false
    
    -- Get filter words from the already prepared global filter
    local filter_words = validateAndPrepareFilterWords(wwise_hierarchy_filter or "")

    for _, node in ipairs(tree) do
        local object = node.object
        local should_show = true
        
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
            reaper.ImGui_Button(ctx, abbr)
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
            if object.type == "Sound" and collapse_end_containers then
                return has_visible_children -- Skip rendering individual sounds when collapsing
            elseif object.type == "Sound" then
                node_flags = node_flags | reaper.ImGui_TreeNodeFlags_Leaf() | reaper.ImGui_TreeNodeFlags_NoTreePushOnOpen()
            elseif wwise_hierarchy_filter ~= "" and wwiseNodeOrDescendantsMatch(node, filter_words) then
                node_flags = node_flags | reaper.ImGui_TreeNodeFlags_DefaultOpen()
            end
            
            -- Create the tree node
            local node_label = object.name
            if has_only_sound_children and matching_sounds_count > 0 then
                node_label = node_label .. string.format(" (%d)", matching_sounds_count)
            end
            local node_open = reaper.ImGui_TreeNode(ctx, node_label, node_flags)
            
            -- Handle drag and drop
            if reaper.ImGui_BeginDragDropTarget(ctx) then
                local payload = reaper.ImGui_AcceptDragDropPayload(ctx, "RENDER_ITEMS")
                if payload and dragged_items then
                    local ww_grouped_items = wwiseGroupItems(dragged_items)
                    for group_name, group_items in pairs(ww_grouped_items) do
                        table.insert(pending_imports, {
                            items = group_items,
                            target_path = object.path,
                            group_name = group_name
                        })
                    end
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
    end

    return has_visible_children
end

-----------------------------------------------------------------------------------------------------------------
------------------------WWISE WINDOW ----------------------------
-----------------------------------------------------------------------------------------------------------------


  function wwiseWindow()
    if not wwise_window then return end
   
    if ww_window_first_time_open then
        ww_connection_status, ww_proj_name = wwiseConnect()
        ww_actor_mixer_hierarchy = wwiseGetActorMixerHierarchy()
        wwise_hierarchy_tree = wwiseBuildHierarchy(ww_actor_mixer_hierarchy)
        filtered_hierarchy_tree = wwiseCreateFilteredHierarchy(wwise_hierarchy_tree, "")
        previous_filter = ""
        ww_window_first_time_open = false
    end
   
    local current_time = reaper.time_precise()
    if wwise_hierarchy_filter ~= previous_filter and current_time - last_filter_time > filter_delay then
        last_filter_time = current_time
        filtered_hierarchy_tree = wwiseCreateFilteredHierarchy(wwise_hierarchy_tree, wwise_hierarchy_filter)
        previous_filter = wwise_hierarchy_filter
    end

    StyleManager.PushStyle(ctx)
    local should_display
    should_display, wwise_window = reaper.ImGui_Begin(ctx, 'WWISE', wwise_window, reaper.ImGui_WindowFlags_NoDocking())
   
    if should_display then
        reaper.ImGui_BeginChild(ctx, "WWise Stuff", 800, 800)
        reaper.ImGui_Dummy(ctx,0,4)
        reaper.ImGui_Indent(ctx, 8)
       
        if reaper.ImGui_Button(ctx, "CNT!", 36, 36) then
            ww_connection_status, ww_proj_name = wwiseConnect()
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
            ww_actor_mixer_hierarchy = wwiseGetActorMixerHierarchy()
            wwise_hierarchy_tree = wwiseBuildHierarchy(ww_actor_mixer_hierarchy)
            filtered_hierarchy_tree = wwiseCreateFilteredHierarchy(wwise_hierarchy_tree, "")
            previous_filter = ""
        end
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_BeginChild(ctx, "WWise project status", 120, 42)
        reaper.ImGui_Dummy(ctx, 0,0)
        if ww_connection_status then
            reaper.ImGui_Text(ctx, "CONNECTED")
        else
            reaper.ImGui_Text(ctx, "NOT CONNECTED")
        end
       
        if ww_connection_status then
            reaper.ImGui_Text(ctx, ww_proj_name)
        else
            reaper.ImGui_Text(ctx, "...")
        end
       
        reaper.ImGui_EndChild(ctx)

        if #pending_imports > 0 then
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x3C39D6FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x4846E7FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0x3734D5FF)
            if reaper.ImGui_Button(ctx, "TRS!", 72, 36) then
                        for _, import in ipairs(pending_imports) do
                            local container_info = nil
                            if import.container_type and import.container_name then
                                container_info = {
                                    type = import.container_type,
                                    name = import.container_name
                                }
                            end
                            wwiseImport(import.items, import.target_path, container_info)
                        end
                        pending_imports = {}
            end
            reaper.ImGui_PopStyleColor(ctx,3)
        end
       

        -----------------------------------------------------------------------------------------------------------------------------------
        -------------------------------------- Pppppending imports table rendering section ------------------------------------------------
        -----------------------------------------------------------------------------------------------------------------------------------
       
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 0, 0)
       
        reaper.ImGui_Dummy(ctx, 0, 5)
        if reaper.ImGui_BeginTable(ctx, "pending_imports", 4, reaper.ImGui_TableFlags_Borders() | reaper.ImGui_TableFlags_Resizable()) then
            reaper.ImGui_TableSetupColumn(ctx, "Source Items")
           
            reaper.ImGui_TableSetupColumn(ctx, "Target Path")
            reaper.ImGui_TableSetupColumn(ctx, "Container")
            reaper.ImGui_TableSetupColumn(ctx, "Del")
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
                reaper.ImGui_SetNextItemWidth(ctx, 120)
                _, import.container_name = reaper.ImGui_InputText(ctx, "##ContainerName" .. idx,
                    import.container_name or
                    (import.group_name and import.group_name:gsub("%s*%[%d+-%d+%]$", "") or
                     import.items[1].name:gsub("_%d+$", "")))
               
               
                reaper.ImGui_TableSetColumnIndex(ctx, 3)
                if reaper.ImGui_Button(ctx, "DEL##" .. idx) then
                    table.remove(pending_imports, idx)
                end
            end
           
            reaper.ImGui_EndTable(ctx)
        end
       
        reaper.ImGui_Dummy(ctx, 0, 5)
       
        reaper.ImGui_PopStyleVar(ctx, 1)
 
        -----------------------------------------------------------------------------------------------------------------------------------
        -------------------------------------------------------- FILTER ----------------------------------------------------------
        -----------------------------------------------------------------------------------------------------------------------------------
        
        reaper.ImGui_BeginChild(ctx, "FilterWWise", 560, 42)
        reaper.ImGui_SetNextItemWidth(ctx, 200)
        
        -- Get new filter text
        local retval, new_filter = reaper.ImGui_InputText(ctx, "Filter WWise Hierarchy", wwise_hierarchy_filter)
        
        -- Add collapse checkbox
        reaper.ImGui_SameLine(ctx)
        _, collapse_end_containers = reaper.ImGui_Checkbox(ctx, "Compact View", collapse_end_containers)
        
        -- Only update the actual filter if it contains a word of at least 3 characters
        local temp_words = validateAndPrepareFilterWords(new_filter)
        if #temp_words > 0 or new_filter == "" then
            wwise_hierarchy_filter = new_filter
        end
        
        reaper.ImGui_EndChild(ctx)
       
        -----------------------------------------------------------------------------------------------------------------------------------
        -------------------------------------------------------- WWise hierarchy ----------------------------------------------------------
        -----------------------------------------------------------------------------------------------------------------------------------
       
        -- Add a scrollable child window for the hierarchy
        reaper.ImGui_BeginChild(ctx, "WWiseHierarchy")  
        if filtered_hierarchy_tree and #filtered_hierarchy_tree > 0 then
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 0, 0)
            wwiseRenderTree(filtered_hierarchy_tree, 1)  -- Use the filtered tree
            reaper.ImGui_PopStyleVar(ctx, 1)
        end
        reaper.ImGui_EndChild(ctx)
        reaper.ImGui_Unindent(ctx)
        reaper.ImGui_EndChild(ctx)

       
        reaper.ImGui_End(ctx)
    end
    StyleManager.PopStyle(ctx)
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
        file:write("pref_variaton_start_number,", tostring(pref_variaton_start_number), "\n")
               
        file:close()
    end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------LOAD SETTINGS FROM CSV----------------------------
-----------------------------------------------------------------------------------------------------------------

function LoadSettingsFromCSV()
    local pref_variaton_start_number = 0
    local use_inner_render_path = true
    local ww_project_only_render = true
   
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
                elseif key == "pref_variaton_start_number" then
                    pref_variaton_start_number = tonumber(value)
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


-----------------------------------------------------------------------------------------------------------------
----------------------SHOW CHANNEL INPUT WINDOW--------------------------
-----------------------------------------------------------------------------------------------------------------

function showChannelInputWindow()
    show_channel_input_popup = true
    local ret, user_inputs = reaper.GetUserInputs("Input Channels", 1, "Number of Channels:", "")
    if ret then
        num_channels = tonumber(user_inputs) or 2 -- Default to stereo if invalid input
        show_channel_input_popup = false
        local base_region_name = finalPrefix .. sound_name
        createRegions(base_region_name)
    else
        show_channel_input_popup = false
    end
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


-----------------------------------------------------------------------------------------------------------------
--------------------------RENAME EXISTING ITEMS--------------------------
-----------------------------------------------------------------------------------------------------------------


function nameRename(channels)
    local num_channels = tonumber(channels) or 2
 
    -- Make sure we have a valid base name
    local base_name = finalPrefix .. sound_name
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
           
            -- Get base names without numbers and the original number
            local old_base = old_name:gsub("_%d+$", "")
            local original_number = old_name:match("_(%d+)$")
            local new_name
           
            if old_base == base_name and original_number then
                -- If renaming to same base name and we found the original number, keep it
                new_name = base_name .. "_" .. original_number
            else
                -- If renaming to different base name, get next available number
                local variation_number = findNextAvailableVariationNumber(base_name)
                new_name = base_name .. variation_number
            end
           
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
   
    if renaming_to_same_name == true then
        number = number - 1
    end
   
    return string.format("_%02d", number)
end


-----------------------------------------------------------------------------------------------------------------
------------------------PREFERENCES WINDOW----------------------------
-----------------------------------------------------------------------------------------------------------------


function preferencesWindow()
    if not preferences_window then return end

    StyleManager.PushStyle(ctx)
    local should_display
    should_display, preferences_window = reaper.ImGui_Begin(ctx, 'PREFERENCES', preferences_window, reaper.ImGui_WindowFlags_AlwaysAutoResize())
   
    if should_display then
        reaper.ImGui_Dummy(ctx, 0, 5)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_PushFont(ctx, big_font)
        reaper.ImGui_Text(ctx, "RENDER PATHS")
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
       
        reaper.ImGui_PushFont(ctx, small_font)
        reaper.ImGui_Text(ctx, "Path: " .. additional_render_path)
        reaper.ImGui_PopFont(ctx)
       
        reaper.ImGui_Dummy(ctx, 0, 5)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_PushFont(ctx, big_font)
        reaper.ImGui_Text(ctx, "NAMING CONVENTION")
        reaper.ImGui_PopFont(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Dummy(ctx, 0, 5)
       
        reaper.ImGui_SetNextItemWidth(ctx, 100)
        _, pref_variaton_start_number = reaper.ImGui_InputInt(ctx, " :Variation start number", pref_variaton_start_number)
       
        reaper.ImGui_Dummy(ctx, 0, 5)
        reaper.ImGui_Separator(ctx)
       
        changed, ww_project_only_render = reaper.ImGui_Checkbox(ctx, "##ww_project_only_render", ww_project_only_render)
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_Text(ctx, ":Render only to project directory when importing to WWise")
       
        reaper.ImGui_Dummy(ctx, 0, 5)
        reaper.ImGui_Separator(ctx)
       
       
        reaper.ImGui_Dummy(ctx, 0, 5)
       
        -- Save button
        if reaper.ImGui_Button(ctx, "Save Settings") then
            SaveSettingsToCSV()
            preferences_window = false
        end
       
        reaper.ImGui_End(ctx)
    end
    StyleManager.PopStyle(ctx)
end



-----------------------------------------------------------------------------------------------------------------
------------------------FILTERING STUFF----------------------------
-----------------------------------------------------------------------------------------------------------------

function itemMatchesFilter(item_name, filter)
    if filter == "" then return true end
   
    -- Convert both strings to lowercase for case-insensitive comparison
    local lower_name = string.lower(item_name)
    local lower_filter = string.lower(filter)
   
    -- Check if the filter is a continuous substring
    if string.find(lower_name, lower_filter, 1, true) then
        return true
    end
   
    -- Split filter into characters and check if they appear in sequence
    local filter_len = string.len(lower_filter)
    local name_len = string.len(lower_name)
    local j = 1 -- Position in name
    local i = 1 -- Position in filter
   
    while i <= filter_len and j <= name_len do
        if string.sub(lower_filter, i, i) == string.sub(lower_name, j, j) then
            i = i + 1
        end
        j = j + 1
    end
   
    return i > filter_len -- All filter characters were found in sequence
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
                second_pass = properties.second_pass
            })
        end
    end
    return items_info
end

-----------------------------------------------------------------------------------------------------------------
--------------------------LOOOOOOO---OOOOOOOOP---------------------------
-----------------------------------------------------------------------------------------------------------------

function loop()
    if shouldUpdateDetection() then
        detectFolderItemsAndRegions()
    end
    if visible then
        reaper.ImGui_SetNextWindowSizeConstraints(ctx, 544, 420, 10000, 10000)
       
        StyleManager.PushStyle(ctx)

        local should_display
 
        should_display, visible = reaper.ImGui_Begin(ctx, 'NAME / RENDER / BE WELL', visible, reaper.ImGui_WindowFlags_NoDocking())

        --reaper.ImGui_PushFont(ctx, normal_font)
       
        if should_display then
           
       
            -------------------------------------------------------------------------------------------------------------------------------------------
            ---------------------------SETTINGS
            -------------------------------------------------------------------------------------------------------------------------------------------
           
            reaper.ImGui_BeginChild(ctx, "SETTINGS", 350, 148, 0, reaper.ImGui_WindowFlags_None())
            reaper.ImGui_Indent(ctx, 8)
           
            reaper.ImGui_Dummy(ctx,0,4)
           
            reaper.ImGui_SetNextItemWidth(ctx, 100)
            changed, selected_bitdepth_index = reaper.ImGui_Combo(ctx, "##bitdepth", selected_bitdepth_index - 1, table.concat(render_bitdepths, "\0") .. "\0")
            selected_bitdepth_index = selected_bitdepth_index + 1
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Dummy(ctx,10,0)
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Text(ctx, ":BIT / SR:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Dummy(ctx,10,0)
           
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 110)
            changed, selected_sample_rate_index = reaper.ImGui_Combo(ctx, "##samplerate", selected_sample_rate_index - 1, table.concat(render_sample_rates, "\0") .. "\0")
            selected_sample_rate_index = selected_sample_rate_index + 1
           
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
           
                -- Detect Enter key
                if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) then
                    reaper.ImGui_CloseCurrentPopup(ctx)
                    popup_initialized = false -- Reset for the next popup
                end
           
                reaper.ImGui_SameLine(ctx)
           
                -- OK button
                if reaper.ImGui_Button(ctx, "OK") then
                    reaper.ImGui_CloseCurrentPopup(ctx)
                    popup_initialized = false -- Reset for the next popup
                end
           
                reaper.ImGui_EndPopup(ctx)
            else
                popup_initialized = false -- Ensure reset when popup is closed
            end

            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 110)
            changed, selected_normalization_index = reaper.ImGui_Combo(ctx, "##norm_type", selected_normalization_index - 1, table.concat(normalization_types, "\0") .. "\0")
            selected_normalization_index = selected_normalization_index + 1
           
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
           
                -- Detect Enter key
                if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) then
                    reaper.ImGui_CloseCurrentPopup(ctx)
                    popup_initialized = false -- Reset for the next popup
                end
           
                reaper.ImGui_SameLine(ctx)
           
                -- OK button
                if reaper.ImGui_Button(ctx, "OK") then
                    reaper.ImGui_CloseCurrentPopup(ctx)
                    popup_initialized = false -- Reset for the next popup
                end
           
                reaper.ImGui_EndPopup(ctx)
            else
                popup_initialized = false -- Ensure reset when popup is closed
            end
           
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 110)
            changed, selected_brickwall_limiter_index = reaper.ImGui_Combo(ctx, "##limiter_type", selected_brickwall_limiter_index - 1, table.concat(brickwall_limiter_types, "\0") .. "\0")
            selected_brickwall_limiter_index = selected_brickwall_limiter_index + 1
           
            reaper.ImGui_EndChild(ctx)
            reaper.ImGui_SameLine(ctx)
           
            -------------------------------------------------------------------------------------------------------------------------------------------
            ---------------------------BUTTONS
            -------------------------------------------------------------------------------------------------------------------------------------------
           
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 0, 0)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0xB84A62FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0xC55B73FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0xA13B53FF)
   
            reaper.ImGui_BeginChild(ctx, "BUTTONS", 52, 148, 0, reaper.ImGui_WindowFlags_None())
            reaper.ImGui_Indent(ctx, 8)
           
            reaper.ImGui_Dummy(ctx,4,6)
           
            reaper.ImGui_Dummy(ctx,0,18)
           
            if reaper.ImGui_Button(ctx, 'ADJ!',36,36) then
                adjustFolderItems()
            end
           
            reaper.ImGui_Dummy(ctx,0,12)
                       
            if reaper.ImGui_Button(ctx, "...", 36, 20) then
                preferences_window = not preferences_window
            end
            reaper.ImGui_Unindent(ctx)
           
            reaper.ImGui_EndChild(ctx)
            reaper.ImGui_PopStyleColor(ctx, 3)
            reaper.ImGui_PopStyleVar(ctx)
           
            reaper.ImGui_SameLine(ctx)
           
           
            reaper.ImGui_BeginChild(ctx, "WWISE", 42, 148, 0, reaper.ImGui_WindowFlags_None())
            reaper.ImGui_Indent(ctx, 8)
           
            reaper.ImGui_Dummy(ctx,4,22)
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 0,0)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x3C39D6FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x4846E7FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0x3734D5FF)
            if reaper.ImGui_Button(ctx, "W" .. "\n" .. "W" .. "\n" .. "I" .. "\n" .. "S" .. "\n" .. "E", 24, 86) then
                wwise_window = not wwise_window
            end
            
            
            -- drag and drop target behavior
            if reaper.ImGui_BeginDragDropTarget(ctx) then
                local payload = reaper.ImGui_AcceptDragDropPayload(ctx, "RENDER_ITEMS")
                if payload and dragged_items then
                    wwiseReplaceAudio(dragged_items)
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
           
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0xB84A62FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0xC55B73FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0xA13B53FF)
            reaper.ImGui_BeginChild(ctx, "NAME", 410, 50, 0, reaper.ImGui_WindowFlags_None())
           
            reaper.ImGui_Dummy(ctx,0,4)
            reaper.ImGui_Indent(ctx, 8)
            reaper.ImGui_AlignTextToFramePadding(ctx)
            reaper.ImGui_Text(ctx, "N:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 260)
           
            if first_open then
                reaper.ImGui_SetKeyboardFocusHere(ctx)
                first_open = false
            end
           
            _, sound_name = reaper.ImGui_InputText(ctx, "##: NAME", sound_name)
           
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Text(ctx, "CH:")
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 22)
            _, num_channels = reaper.ImGui_InputText(ctx, "##: CHANNELS", num_channels, reaper.ImGui_InputTextFlags_AlwaysOverwrite())
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Dummy(ctx,0,0)
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, 'NME!') then
                nameRename(num_channels)
            end
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Unindent(ctx)
           
            reaper.ImGui_EndChild(ctx)
           
            reaper.ImGui_PopStyleColor(ctx, 3)
            reaper.ImGui_Dummy(ctx,0,0)
           
           -------------------------------------------------------------------------------------------------------------------------------------------
           ---------------------------TABLE HEADER
           -------------------------------------------------------------------------------------------------------------------------------------------          
           
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(), 0x333333FF)
           
            reaper.ImGui_BeginChild(ctx, "TABLE HEADER", 410, 42, 0, reaper.ImGui_WindowFlags_None())
            reaper.ImGui_SetNextItemWidth(ctx, 244)
            _, filter_text = reaper.ImGui_InputText(ctx, " : FLTR", filter_text)
           
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Dummy(ctx, 0, 0)
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "CLR!", 36,36) then
                clearSelectedItems()
            end
           
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Dummy(ctx, 0,0)
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0xB84A62FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0xC55B73FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0xA13B53FF)
            if reaper.ImGui_Button(ctx, 'RDR!',36,36) then
                renderQueuedRegions()
            end
            reaper.ImGui_PopStyleColor(ctx,3)
            reaper.ImGui_EndChild(ctx)
            reaper.ImGui_PopStyleColor(ctx)

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
                               
            -------------------------------------------------------------------------------------------------------------------------------
            ------------ TABLE ----------------
            -------------------------------------------------------------------------------------------------------------------------------
           
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
               
                for _, items in pairs(track_folder_map) do
                    if #items > max_items then
                        max_items = #items
                    end
                end

                local mouse_clicked = reaper.ImGui_IsMouseClicked(ctx, 0)
                local mouse_released = reaper.ImGui_IsMouseReleased(ctx, 0)
                local mouse_dragging = reaper.ImGui_IsMouseDragging(ctx, 0)
               
                local ctrl_pressed = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl())
                local shift_pressed = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftShift())
                local alt_pressed = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftAlt())
               
                if mouse_clicked and not reaper.ImGui_IsAnyItemActive(ctx) and not shift_pressed then
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
                       
                        local items = filtered_items[folder_track]
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
                               
                                if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftShift()) then
                                    if reaper.ImGui_BeginDragDropSource(ctx, reaper.ImGui_DragDropFlags_None()) then
                                        -- Collect all selected items
                                        dragged_items = collectSelectedItemsInfo()
                                       
                                        -- Set drag preview
                                        reaper.ImGui_SetDragDropPayload(ctx, "RENDER_ITEMS", "items")
                                       
                                        -- Show preview of dragged items
                                        reaper.ImGui_Text(ctx, string.format("������ Dragging %d items", #dragged_items))
                                        -- Show first few items as preview
                                        for i = 1, math.min(3, #dragged_items) do
                                            reaper.ImGui_Text(ctx, "  " .. dragged_items[i].name)
                                        end
                                        if #dragged_items > 3 then
                                            reaper.ImGui_Text(ctx, "  ...")
                                        end
                                       
                                        reaper.ImGui_EndDragDropSource(ctx)
                                    end
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
        preferencesWindow()
        wwiseWindow()
        reaper.defer(loop)
    else
        SaveSettingsToCSV()
    end
end

LoadSettingsFromCSV()

loop()

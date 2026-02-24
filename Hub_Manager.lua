script_name = "Hub Myanmar"
script_description = "Dynamic script loader with Space-in-Path support."
script_author = "KomeNome"
script_version = "2.6"

-- [[ DYNAMIC PATH RESOLVER ]]
local script_path = debug.getinfo(1).source:match("@?(.*[\\/])")
local modules_path = script_path .. "modules\\" -- Windows အတွက် backslash သုံးတာ ပိုစိတ်ချရတယ်

-- Folder Scan Function
local function get_modules()
    local modules = {}
    
    -- BRUTAL FIX: Path မှာ space ပါရင် dir command က quote လိုအပ်ပါတယ်
    -- /b က filename ပဲယူတာ၊ /a-d က folder တွေကို ဖယ်ထုတ်တာ
    local cmd = 'dir "' .. modules_path .. '*.lua" /b /a-d'
    local p = io.popen(cmd)
    
    if p then
        for filename in p:lines() do
            if filename:match("%.lua$") then
                local display_name = filename:gsub("%.lua$", ""):gsub("_", " "):upper()
                table.insert(modules, { name = display_name, file = filename })
            end
        end
        p:close()
    end
    return modules
end

-- Custom Loader (No-Cache)
local function execute_module(filename, subs, sel)
    local full_path = modules_path .. filename
    local f = io.open(full_path, "r")
    if not f then return nil, "File not found: " .. full_path end
    
    local content = f:read("*all")
    f:close()
    
    local chunk, err = loadstring(content)
    if not chunk then return nil, "Syntax Error: " .. tostring(err) end
    
    local success, ScriptModule = pcall(chunk)
    if success and type(ScriptModule) == "table" and ScriptModule.run then
        ScriptModule.run(subs, sel)
    else
        return nil, "Runtime Error: Module must return a table with a 'run' function."
    end
    return true
end

function main_hub(subs, sel)
    local module_list = get_modules()
    
    if #module_list == 0 then
        -- Debugging အတွက် Path ကိုပါ ပြခိုင်းမယ်
        aegisub.debug.out(2, "No .lua files found!\nChecked Path: " .. modules_path .. "\n\nPlease ensure your scripts are inside the 'modules' folder.")
        return
    end

    local items = {}
    for _, mod in ipairs(module_list) do table.insert(items, mod.name) end

    local dialog = {
        { class = "label", label = "Select Tool:", x = 0, y = 0, width = 1, height = 1 },
        { class = "dropdown", name = "tool", items = items, value = items[1], x = 0, y = 1, width = 1, height = 1 }
    }

    local btn, result = aegisub.dialog.display(dialog, { "Run", "Cancel" }, { ok = "Run", cancel = "Cancel" })

    if btn == "Run" then
        local target_file = nil
        for _, mod in ipairs(module_list) do
            if mod.name == result.tool then target_file = mod.file break end
        end

        if target_file then
            local success, err = execute_module(target_file, subs, sel)
            if not success then
                aegisub.debug.out(2, "Error loading " .. target_file .. ":\n" .. tostring(err))
            end
        end
    end
end

aegisub.register_macro(script_name, script_description, main_hub)
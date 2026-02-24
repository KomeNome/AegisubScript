local ScriptModule = {}
-- Karaskel library ကို ခေါ်သုံးရပါမယ်
local karaskel = require "karaskel"
if type(karaskel) == "boolean" then
    karaskel = _G.karaskel
end

-- [[ SHAKE/DURA LOGIC ]]
local function get_dura_tags(duration, timelength, frzange)
    local result = ""
    local count = math.ceil(duration / timelength)
    for i = 1, count do
        local angle = frzange[((i + 1) % 2) + 1]
        result = result .. string.format("\\t(%d,%d,\\frz%.1f)", (i-1)*timelength, i*timelength, angle)
    end
    return result
end

function ScriptModule.run(subs, sel)
    -- 1. GUI Configuration Box
    local config = {
        { class = "label", label = "Apply Mode:", x = 0, y = 0 },
        { class = "dropdown", name = "mode", items = {"Selected Lines", "By Style Name"}, value = "Selected Lines", x = 1, y = 0 },
        { class = "label", label = "Style Name:", x = 0, y = 1 },
        { class = "edit", name = "target_style", value = "Default", x = 1, y = 1 },
        { class = "label", label = "Slice Count (Y-Axis):", x = 0, y = 2 },
        { class = "intedit", name = "ycount", value = 15, x = 1, y = 2 },
        { class = "label", label = "Shake Intensity:", x = 0, y = 3 },
        { class = "floatedit", name = "shake_val", value = 0.3, x = 1, y = 3 },
        { class = "label", label = "Pre-line Duration (ms):", x = 0, y = 4 },
        { class = "intedit", name = "preline_ms", value = 300, x = 1, y = 4 },
        { class = "label", label = "Primary Color:", x = 0, y = 5 },
        { class = "color", name = "p_color", x = 1, y = 5 },
        { class = "label", label = "Outline Color:", x = 0, y = 6 },
        { class = "color", name = "s_color", x = 1, y = 6 },
        { class = "label", label = "Blur Intensity:", x = 0, y = 7 },
        { class = "intedit", name = "blur_val", value = 5, x = 1, y = 7 }
    }

    local btn, res = aegisub.dialog.display(config, {"Apply Effect", "Cancel"})
    if btn ~= "Apply Effect" then return end

    -- Karaskel အတွက် Meta data စုဆောင်းမယ်
    local meta, styles = karaskel.collect_head(subs)
    local frzange = {-res.shake_val, res.shake_val}
    local ycount = res.ycount

    -- 2. Processing Loop (Reverse to prevent index shifting)
    for i = #subs, 1, -1 do
        local line = subs[i]
        
        if line.class == "dialogue" then
            local is_target = false
            if res.mode == "Selected Lines" then
                for _, s in ipairs(sel) do
                    if i == s then
                        is_target = true
                        break
                    end
                end
            elseif line.style == res.target_style then
                is_target = true
            end

            if is_target then
                -- [[ BRUTAL FIX: Karaskel နဲ့ Line Position တွေ တွက်မယ် ]]
                karaskel.preproc_line(subs, meta, styles, line)
                
                local lh = line.height / ycount
                local base_line = table.copy(line)
                
                -- Insert Slices (Loop 1 to ycount)
                for j = 1, ycount do
                    local nl = table.copy(base_line)
                    
                    -- Use the preline_ms value from GUI
                    nl.start_time = line.start_time - res.preline_ms
                    nl.end_time = line.start_time
                    
                    -- Karaskel ကပေးတဲ့ top, center, middle တွေကို သုံးမယ်
                    local top = line.top + (lh * (j-1))
                    local bottom = line.top + (lh * j)
                    local shift = (j % 2 == 1) and 15 or -15
                    
                    -- Left-to-Right Reveal: Animated clip from 0 to full width
                    local reveal_clip = string.format("\\clip(%d,%d,%d,%d)\\t(0,400,\\clip(%d,%d,%d,%d))", 
                                        0, top, 0, bottom, 0, top, meta.res_x, bottom)
                    
                    -- Color Override: Fix color formatting for Aegisub ABGR format
                    local p_clr = res.p_color:gsub("#", "&H") .. "&"
                    local s_clr = res.s_color:gsub("#", "&H") .. "&"

                    local color_tags = string.format("\\1c%s\\3c%s\\blur%d", p_clr, s_clr, res.blur_val)
                    
                    local duration = nl.end_time - nl.start_time
                    local shake_tags = get_dura_tags(duration, 50, frzange)
                    
                    -- Use static position instead of move animation
                    local tags = string.format("{\\an5\\pos(%.1f,%.1f)%s%s%s\\fad(200,0)}", 
                                 line.center, line.middle, 
                                 reveal_clip, color_tags, shake_tags)

                    nl.text = tags .. base_line.text_stripped
                    subs.insert(i + j, nl)
                end
            end
        end
    end
end

return ScriptModule
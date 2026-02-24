local ScriptModule = {}

script_name = "Myanmar Syllable Splitter"
script_description = "Inserts a custom marker between Myanmar syllable clusters"
script_author = "Cline Agent Manager"
script_version = "3.0"

local function get_codepoint(s)
    if not s then return nil end
    local b = s:byte(1)
    if not b then return nil end
    if b < 128 then return b end
    local res, w
    if b < 224 then res = b - 192 w = 2
    elseif b < 240 then res = b - 224 w = 3
    else res = b - 240 w = 4 end
    for i = 2, w do res = res * 64 + s:byte(i) - 128 end
    return res
end

local function is_myanmar_consonant(cp)
    return (cp >= 0x1000 and cp <= 0x1021) or (cp >= 0x1023 and cp <= 0x102A) or (cp == 0x103F)
end

local function is_modifier(cp)
    return (cp >= 0x102B and cp <= 0x103E) or (cp >= 0x105A and cp <= 0x109D)
end

local function split_myanmar_syllables(text, marker)
    local result = ""
    local chars = {}
    for c in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do table.insert(chars, c) end

    local pos = 1
    while pos <= #chars do
        local current_char = chars[pos]
        if pos > 1 then result = result .. marker end
        result = result .. current_char
        pos = pos + 1

        while pos <= #chars do
            local next_char = chars[pos]
            local next_cp = get_codepoint(next_char)
            if not next_cp then break end

            if next_cp == 0x1039 then
                result = result .. next_char
                pos = pos + 1
                if chars[pos] then
                    result = result .. chars[pos]
                    pos = pos + 1
                end
            elseif is_modifier(next_cp) then
                result = result .. next_char
                pos = pos + 1
            elseif is_myanmar_consonant(next_cp) then
                local lookahead = pos + 1
                local found_asat = false
                while lookahead <= #chars do
                    local la_cp = get_codepoint(chars[lookahead])
                    if la_cp == 0x103A then found_asat = true break end
                    if is_modifier(la_cp) then lookahead = lookahead + 1
                    else break end
                end
                if found_asat then
                    for k = pos, lookahead do result = result .. chars[k] end
                    pos = lookahead + 1
                else
                    break
                end
            else
                break
            end
        end
    end

    local escaped = marker:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
    result = result:gsub("(" .. escaped .. ")+", marker)
    result = result:gsub("^" .. escaped, ""):gsub(escaped .. "$", "")
    return result
end

function ScriptModule.run(subs, sel)
    -- GUI Dialog — single step, no separate confirm needed
    local dialog = {
        { class = "label",
          label = "Marker to insert between syllables:",
          x = 0, y = 0, width = 2, height = 1 },
        { class = "edit",
          name  = "marker",
          value = "{split}",
          x = 0, y = 1, width = 2, height = 1 },
        { class = "label",
          label = "Exactly what you type will be inserted.",
          x = 0, y = 2, width = 2, height = 1 },
    }

    local btn, result = aegisub.dialog.display(dialog, { "Apply", "Cancel" }, { ok = "Apply", cancel = "Cancel" })

    if btn ~= "Apply" then
        aegisub.cancel()
        return
    end

    -- Use exactly what the user typed; fall back to {split} if blank
    local marker = result.marker
    if not marker or marker:match("^%s*$") then
        marker = "{split}"
    end

    for _, i in ipairs(sel) do
        local line = subs[i]
        local new_text = ""
        local last_pos = 1

        for tag_start, tag_content, tag_end in line.text:gmatch("()({[^}]*})()") do
            local text_before = line.text:sub(last_pos, tag_start - 1)
            if text_before ~= "" then
                new_text = new_text .. split_myanmar_syllables(text_before, marker)
            end
            new_text = new_text .. tag_content
            last_pos = tag_end
        end

        local text_after = line.text:sub(last_pos)
        if text_after ~= "" then
            new_text = new_text .. split_myanmar_syllables(text_after, marker)
        end

        local escaped = marker:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
        new_text = new_text:gsub(escaped .. "({[^}]*})", "%1")
                           :gsub("({[^}]*})" .. escaped, "%1")

        line.text = new_text:gsub("^" .. escaped, ""):gsub(escaped .. "$", "")
        subs[i] = line
    end

    aegisub.set_undo_point(script_name)
end

-- aegisub.register_macro("Myanmar/Syllable Splitter", script_description, process_lines)

return ScriptModule
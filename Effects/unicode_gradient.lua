local ScriptModule = {}

local karaskel = require "karaskel"
local unicode  = require "unicode"
if type(karaskel) == "boolean" then karaskel = _G.karaskel end
if type(unicode)  == "boolean" then unicode  = _G.unicode  end

-- ─────────────────────────────────────────────────────────────────────────────
-- Unicode helpers
-- ─────────────────────────────────────────────────────────────────────────────
local function get_codepoint(s)
    if not s then return nil end
    local b = s:byte(1)
    if not b then return nil end
    if b < 128 then return b end
    local res, w
    if b < 224 then res = b - 192; w = 2
    elseif b < 240 then res = b - 224; w = 3
    else res = b - 240; w = 4 end
    for i = 2, w do res = res * 64 + s:byte(i) - 128 end
    return res
end

-- Only these codepoints may OPEN a new syllable cluster
local function is_myanmar_consonant(cp)
    return (cp >= 0x1000 and cp <= 0x1021)
        or (cp >= 0x1023 and cp <= 0x102A)
        or  cp == 0x103F
end

-- These codepoints EXTEND an already-open syllable (vowel signs,
-- tone marks, medial marks, Asat, killer, anusvara, visarga …)
local function is_modifier(cp)
    return (cp >= 0x102B and cp <= 0x103E)
        or (cp >= 0x105A and cp <= 0x109D)
end

-- Medial consonant marks only (ya U+103B, ra U+103C, wa U+103D, ha U+103E).
-- These are the ONLY modifiers safe to cross when lookaheading for an Asat
-- that makes a following consonant a syllable-final cluster member.
-- Vowel signs (U+102B–U+1035, U+1038 visarga) prove we are inside a rhyme
-- and must stop the lookahead immediately.
local function is_medial_mark(cp)
    return cp >= 0x103B and cp <= 0x103E
end

-- ─────────────────────────────────────────────────────────────────────────────
-- tokenise(text)
--
-- Returns { {kind, text}, … } where kind is "syllable" or "space".
-- Only is_myanmar_consonant() codepoints may start a syllable; everything
-- else (spaces, \N, punctuation, digits, bare Asat, vowels appearing at the
-- start of a token, non-Myanmar chars) becomes a verbatim "space" token.
-- ─────────────────────────────────────────────────────────────────────────────
local function tokenise(text)
    local tokens = {}

    -- Split into raw UTF-8 codepoint strings
    local chars = {}
    for c in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        chars[#chars + 1] = c
    end

    -- Merge  \  N  (and  \  n)  into single "\N"/"\n" atoms
    local merged = {}
    local ci = 1
    while ci <= #chars do
        local c = chars[ci]
        if c == "\\" and (chars[ci + 1] == "N" or chars[ci + 1] == "n") then
            merged[#merged + 1] = { raw = "\\" .. chars[ci + 1], newline = true }
            ci = ci + 2
        else
            merged[#merged + 1] = { raw = c, cp = get_codepoint(c), newline = false }
            ci = ci + 1
        end
    end

    local pos = 1
    while pos <= #merged do
        local m = merged[pos]

        -- ── Hard line-break ──────────────────────────────────────────────
        if m.newline then
            tokens[#tokens + 1] = { kind = "space", text = m.raw }
            pos = pos + 1

        -- ── Myanmar syllable: ONLY a consonant may open it ───────────────
        elseif m.cp and is_myanmar_consonant(m.cp) then
            local syllable = m.raw
            pos = pos + 1

            while pos <= #merged do
                local nm = merged[pos]
                if nm.newline or not nm.cp then break end
                local cp = nm.cp

                if cp == 0x1039 then
                    -- Explicit stacked-consonant marker (killer): consume it
                    -- plus the consonant it stacks onto.
                    syllable = syllable .. nm.raw
                    pos = pos + 1
                    if pos <= #merged and not merged[pos].newline then
                        syllable = syllable .. merged[pos].raw
                        pos = pos + 1
                    end

                elseif is_modifier(cp) then
                    -- Vowel sign, tone mark, medial mark, Asat, etc.
                    syllable = syllable .. nm.raw
                    pos = pos + 1

                elseif is_myanmar_consonant(cp) then
                    -- A bare consonant may belong to this syllable ONLY as a
                    -- syllable-final cluster (e.g. သ် in နှင့်သော).
                    -- Rule: scan forward past MEDIAL MARKS ONLY (U+103B–103E).
                    -- If the very next non-medial char is Asat (U+103A) → attach.
                    -- Any vowel sign, tone mark, or other modifier encountered
                    -- first means the consonant opens a NEW syllable → stop.
                    local lookahead  = pos + 1
                    local found_asat = false
                    while lookahead <= #merged do
                        local la = merged[lookahead]
                        if la.newline or not la.cp then break end
                        if la.cp == 0x103A then
                            found_asat = true
                            break
                        end
                        -- Only cross medial marks; vowels/tone marks stop us
                        if is_medial_mark(la.cp) then
                            lookahead = lookahead + 1
                        else
                            break
                        end
                    end

                    if found_asat then
                        -- Include the consonant, any intervening medial marks,
                        -- and the Asat itself.
                        for k = pos, lookahead do
                            syllable = syllable .. merged[k].raw
                        end
                        pos = lookahead + 1
                    else
                        break   -- consonant starts a fresh syllable
                    end

                else
                    -- Non-Myanmar, digit, punctuation, space → end this syllable
                    break
                end
            end

            tokens[#tokens + 1] = { kind = "syllable", text = syllable }

        -- ── Everything else: one verbatim space token ─────────────────────
        else
            tokens[#tokens + 1] = { kind = "space", text = m.raw }
            pos = pos + 1
        end
    end

    return tokens
end

-- ─────────────────────────────────────────────────────────────────────────────
-- build_tag – ASS \t() override block for one syllable
-- ─────────────────────────────────────────────────────────────────────────────
local function build_tag(idx, total, dur, t1, t2, t3)
    local hue        = (360 / total) * idx
    local r, g, b   = _G.HSV_to_RGB(hue, 1, 1)
    local color_code = _G.ass_color(r, g, b)
    local fl         = math.floor

    return string.format(
        "{\\alpha&HFF&\\t(%d,%d,\\alpha&H80&\\c%s)\\t(%d,%d,\\c&HFFFFFF&)" ..
        "\\t(%d,%d,\\alpha&H00&\\c%s)\\t(%d,%d,\\alpha&H80&)}",
        fl((t1 / total) * (idx - 1)),   fl((t1 / total) * idx),   color_code,
        fl((t2 / total) * (idx - 1)),   fl((t2 / total) * idx),
        fl((t3 / total) * (idx - 1)),   fl((t3 / total) * idx),   color_code,
        fl(((500 / total) * (idx - 1)) + (dur - 500)),
        fl(((500 / total) * idx)       + (dur - 500)))
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ScriptModule.run
-- ─────────────────────────────────────────────────────────────────────────────
function ScriptModule.run(subs, sel)
    local meta, styles = karaskel.collect_head(subs)

    for i = #subs, 1, -1 do
        local line = subs[i]
        local is_selected = false
        for _, s in ipairs(sel) do
            if i == s then is_selected = true; break end
        end

        if is_selected and line.class == "dialogue" then
            karaskel.preproc_line(subs, meta, styles, line)

            local clean_text = line.text_stripped:gsub("{.-}", "")
            local tokens     = tokenise(clean_text)

            local total_syllables = 0
            for _, tok in ipairs(tokens) do
                if tok.kind == "syllable" then
                    total_syllables = total_syllables + 1
                end
            end
            if total_syllables == 0 then total_syllables = 1 end

            local dur = line.end_time - line.start_time
            local t1  = dur * 0.4
            local t2  = dur * 0.45
            local t3  = dur * 0.5

            local result  = ""
            local syl_idx = 0

            for _, tok in ipairs(tokens) do
                if tok.kind == "syllable" then
                    syl_idx = syl_idx + 1
                    result  = result
                           .. build_tag(syl_idx, total_syllables, dur, t1, t2, t3)
                           .. tok.text
                else
                    result = result .. tok.text
                end
            end

            local base_tags = string.format(
                "{\\an5\\pos(%.1f,%.1f)\\yshad5}", line.center, line.middle)
            line.text = base_tags .. result
            subs[i]   = line
        end
    end
end

return ScriptModule
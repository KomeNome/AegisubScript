local ScriptModule = {}

-- Vector Alpha Timing - TEST VERSION
-- Only 2-3 hardcoded \t blocks to verify invisible/visible logic
-- Check: is the gap between \t blocks truly invisible?

script_name = "Vector Alpha Test"
script_description = "Test alpha timing with 2-3 hardcoded transforms"
script_author = "KomeNome"
script_version = "1.0"

function ScriptModule.run(subs, sel)

    -- -------------------------------------------------------
    -- HARDCODED TEST DATA
    -- Simulating 3 text lines:
    --
    -- Line 1: start=0,    end=2000  (duration=2000)
    -- gap: 4000ms  (2000 -> 6000)
    -- Line 2: start=6000, end=9000  (duration=3000)
    -- gap: 2000ms  (9000 -> 11000)
    -- Line 3: start=11000,end=14000 (duration=3000)
    --
    -- Expected tag chain:
    -- {\alpha&HFF&}
    -- {\t(0,2000,0,\alpha&H00&)\alpha&HFF&}      <- visible 0-2000,    invisible 2000-6000
    -- {\t(6000,9000,0,\alpha&H00&)\alpha&HFF&}    <- visible 6000-9000, invisible 9000-11000
    -- {\t(11000,14000,0,\alpha&H00&)\alpha&HFF&}  <- visible 11000-14000
    -- -------------------------------------------------------

    local test_lines = {
        { start_time = 0,     end_time = 2000  },
        { start_time = 6000,  end_time = 9000  },
        { start_time = 11000, end_time = 14000 },
    }

    -- Build tag chain using same logic as full macro
    local tag_chain = "{\\alpha&HFF&}"
    local offset = 0

    for i, line in ipairs(test_lines) do
        local duration = line.end_time - line.start_time
        local t_start  = offset
        local t_end    = offset + duration

        tag_chain = tag_chain .. string.format(
            "{\\t(%d,%d,0,\\alpha&H00&)\\alpha&HFF&}",
            t_start, t_end
        )

        aegisub.debug.out(string.format(
            "Line %d | duration=%d | t=[%d, %d] | gap after=%d\n",
            i, duration, t_start, t_end,
            i < #test_lines and (test_lines[i+1].start_time - line.end_time) or 0
        ))

        if i < #test_lines then
            local gap = test_lines[i + 1].start_time - line.end_time
            offset = t_end + gap
        end
    end

    aegisub.debug.out("\nResult:\n" .. tag_chain .. "\n")

    -- Strip the leading {\alpha&HFF&} from chain
    -- because we inject \alpha&HFF& directly inside the \pos block instead
    local t_chain = tag_chain:gsub("^{\\alpha&HFF&}", "")

    -- Apply to selected line
    for _, si in ipairs(sel) do
        local line = subs[si]
        line.start_time = 0
        line.end_time   = 14000

        -- Find the {} block containing \pos(...) and inject \alpha&HFF& before its closing }
        -- Then append the \t chain right after that block
        local new_text, count = line.text:gsub(
            "(\\pos%([^%)]+%)([^}]*)})",
            "%1%2\\alpha&HFF&}" .. t_chain,
            1
        )

        if count == 0 then
            aegisub.debug.out("WARNING: \\pos not found in line " .. si .. " - skipping\n")
        else
            line.text = new_text
            aegisub.debug.out("Applied to line " .. si .. "\n")
            aegisub.debug.out("Text: " .. line.text .. "\n")
        end

        subs[si] = line
    end

    aegisub.set_undo_point("Vector Alpha Test Applied")
end

-- aegisub.register_macro(
--     script_name,
--     script_description,
--     test_vector_alpha
-- )

return ScriptModule
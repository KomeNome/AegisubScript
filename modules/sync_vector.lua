local ScriptModule = {}

script_name = "Sync Vector to Dialogue"
script_description = "Generates relative \t tags for Vector lines based on Default lines"
script_author = "Gemini"
script_version = "1.0"

function ScriptModule.run(subs, sel)
    local dialogue_times = {}
    
    -- အဆင့် ၁: "Default" Style ရှိတဲ့ စာသားလိုင်းတွေရဲ့ အချိန်တွေကို အရင်စုဆောင်းမယ်
    for i = 1, #subs do
        local line = subs[i]
        if line.class == "dialogue" and line.style == "Default" then
            table.insert(dialogue_times, {s = line.start_time, e = line.end_time})
        end
    end
    
    -- Default လိုင်း တစ်ကြောင်းမှ မရှိရင် Error ပြပြီး ရပ်မယ်
    if #dialogue_times == 0 then
        aegisub.debug.out("Brutal Error: No lines with 'Default' style found!\nMake sure your text lines are set to 'Default' style.")
        aegisub.cancel()
    end

    -- အဆင့် ၂: ခင်ဗျားရဲ့ (i.start - 1st.start) Logic အတိုင်း \t Tag အရှည်ကြီးကို တည်ဆောက်မယ်
    local first_s = dialogue_times[1].s
    local last_e = dialogue_times[#dialogue_times].e
    
    -- ပထမဆုံး စပေါ်ပေါ်ချင်းမှာ ပျောက်နေအောင် \alpha&HFF& ကို အရင်ထည့်မယ်
    local tags = "\\alpha&HFF&" 
    
    for i = 1, #dialogue_times do
        local t1 = math.floor(dialogue_times[i].s - first_s)
        local t2 = math.floor(dialogue_times[i].e - first_s)
        
        -- လင်းမယ့်အချိန် (\alpha&H00&) နဲ့ ပြန်ပျောက်မယ့်အချိန် (\alpha&HFF&)
        tags = tags .. string.format("\\t(%d,%d,\\alpha&H00&)\\t(%d,%d,\\alpha&HFF&)", t1, t1, t2, t2)
    end

    -- အဆင့် ၃: "Vector" Style ရှိတဲ့ လိုင်းတွေကိုရှာပြီး Tag တွေ သွားထည့်မယ်
    local vector_found = false
    for i = 1, #subs do
        local line = subs[i]
        if line.class == "dialogue" and line.style == "Vector" then
            vector_found = true
            -- Vector လိုင်းရဲ့ အချိန်ကို စာသားတွေရဲ့ အစနဲ့အဆုံး အတိုင်း ဆွဲဆန့်လိုက်မယ်
            line.start_time = first_s
            line.end_time = last_e
            
            -- \p1 ရဲ့ အနောက်မှာ ကျွန်တော်တို့ တည်ဆောက်ထားတဲ့ tags တွေ အစားထိုးထည့်မယ် (1 ကြိမ်ပဲ အလုပ်လုပ်မယ်)
            line.text = string.gsub(line.text, "\\p1", "\\p1" .. tags, 1)
            
            subs[i] = line
        end
    end
    
    if not vector_found then
        aegisub.debug.out("Brutal Error: No lines with 'Vector' style found!\nMake sure your drawing line is set to 'Vector' style.")
        aegisub.cancel()
    end

    aegisub.set_undo_point(script_name)
end

-- aegisub.register_macro(script_name, script_description, sync_vectors)

return ScriptModule
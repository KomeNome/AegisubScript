# Aegisub Modular Script Instruction (Hub Myanmar)

## (မြန်မာဘာသာ - ညွှန်ကြားချက်)

ဤ Hub System အတွက် Lua Script အသစ်များ ရေးသားရာတွင် အောက်ပါ Structure အတိုင်း တိကျစွာ လိုက်နာရန် လိုအပ်ပါသည်။ သာမန် Aegisub script ပုံစံအတိုင်း `register_macro` ကို အသုံးမပြုရပါ။

### လိုက်နာရမည့် အချက်များ:
1. ဖိုင်၏ အပေါ်ဆုံးတွင် `local ScriptModule = {}` ကို အမြဲထည့်ရပါမည်။
2. Script ၏ ပင်မလုပ်ဆောင်ချက် (Main Function) ကို `function ScriptModule.run(subs, sel)` ဟု အမည်ပေးရပါမည်။
3. ဖိုင်၏ အောက်ဆုံးတွင် `return ScriptModule` ကို မဖြစ်မနေ ထည့်ရပါမည်။
4. `aegisub.register_macro` ကို လုံးဝ အသုံးမပြုရပါ။

### Code Template:
```lua
local ScriptModule = {}

-- Main Function
function ScriptModule.run(subs, sel)
    -- Your core logic here
    aegisub.debug.out("Script is running...")
end

-- Return the table to the Manager
return ScriptModule
ChnModOutTranslation = not ChnModOutTranslation
local msg = ""
if ChnModOutTranslation then
   log("Translation Enabled!")
   msg = "传出翻译已激活"
else
   log("Translation Disabled!")
   msg = "传出翻译已关闭"
end

if managers.chat then
   managers.chat:_receive_message(1, "玩家对话翻译", msg,  tweak_data.system_chat_color)
end

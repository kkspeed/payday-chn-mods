local translationData = {}
local confFile = io.open(ModPath .. "chnmodex_save_data.txt")
if confFile then
   translationData = json.decode(confFile:read("*all"))
   confFile:close()
end

translateFrom = "en"
translateTo = translateTo or translationData.chnmodex_default_lang or "zh-CHS"

local Net = _G.LuaNetworking

function escape (s)
   s = string.gsub(s, "([&=+%c])", function (c)
                      return string.format("%%%02X", string.byte(c))
   end)
   s = string.gsub(s, " ", "+")
   return s
end

function decodeUTF16(msg)
   local num = tonumber(msg, 16)
   local first = math.floor(num/4096)
   num = num - 4096 * first
   return string.char(first+224, math.floor(num/64)+128, num%64+128)
end

function displayMessage(channel_id, name, msg, color, icon)
   local receivers = managers.chat._receivers[channel_id]
   if not receivers then
      return
   end
   for i, receiver in ipairs(receivers) do
      receiver:receive_message(name, msg, color, icon)
   end
end

function lookupTranslation(channel_id, name, msg, color, icon)
   dohttpreq( "https://api.microsofttranslator.com/v2/ajax.svc/TranslateArray2?" ..
              "appId=%22TqlJ42aMMFnjskGGBSvpb-jcl4EMQF13g3szntA6FB58*%22&texts=%5B%22" ..
              escape(msg) ..
              "%22%5D&from=%22%22&to=%22" ..
              translateTo .. "%22",
              function(data, id)
                 local trans = json.decode(string.match(data, "%[.*%]"))
                 local chn_msg = trans[1].TranslatedText
                 if trans[1].From ~= translateTo then
                    translateFrom = trans[1].From
                 end
                 log("Set reply translation to: " .. translateFrom)
                 displayMessage(channel_id, name, chn_msg, color, icon)
                 log("Translation Received: " .. trans.trans_result[1].dst)
              end
   )
end

Hooks:Add("ChatManagerOnReceiveMessage", "ChatManagerReceiveMessageTrans",
          function(channel_id, name, message, color, icon)
             log("Translate lang is: " .. translateTo)
             -- Single player mode - you do not need translation
             if not Net:IsMultiplayer() then
                log("Single player mode .. translation disabled")
                return
             end
             local player_name = managers.network:session():local_peer():name()
             -- Do not translate my own message
             if player_name == name then
                log("Message from my self .. translation disabled")
                return
             end
             -- Do not send system message to translation
             if color == tweak_data.system_chat_color then
                log("Message from system .. translation disabled")
                return
             end

             log("Calling on hook received msg: " .. message)
             if string.find(message, "%[AutoTranslate%] ") then
                return
             end
             if ChnModTranslation then
                lookupTranslation(channel_id, name, message, color, icon)
             end
          end
)

CloneClass(ChatManager)
function ChatManager.send_message(this, channel_id, sender, message)
   if Net:IsMultiplayer() and sender == managers.network:session():local_peer():name() then
      if ChnModOutTranslation then
         local msg = message
         dohttpreq(
            "https://api.microsofttranslator.com/v2/ajax.svc/TranslateArray2?" ..
            "appId=%22TqlJ42aMMFnjskGGBSvpb-jcl4EMQF13g3szntA6FB58*%22&texts=%5B%22" ..
            escape(msg) ..
            "%22%5D&from=%22%22&to=%22" ..
            translateFrom .. "%22",
            function(data, id)
               local real_data = string.match(data, "%[.*%]")
               log("Send received data.. " .. real_data)
               local trans = json.decode(real_data)
               local chn_msg = trans[1].TranslatedText
               log("Got sending translation: " .. chn_msg)
               log("Sending Translation.. " .. chn_msg)
               this.orig.send_message(this, channel_id, sender, "[AutoTranslate] "
                                         .. chn_msg)
               log("Translation Received: " .. trans.trans_result[1].dst)
            end
         )
      end
   end
   return this.orig.send_message(this, channel_id, sender, message)
end

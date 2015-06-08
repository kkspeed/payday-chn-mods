local API_KEY = ""
-- _G.ChnModTranslation = _G.ChnModTranslation or false

-- json = require("json")


translateFrom = "auto"
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
   dohttpreq( "http://openapi.baidu.com/public/2.0/bmt/"..
              "translate?client_id=" .. API_KEY .. "&from="..
              "auto&to=zh&q=" .. escape(msg),
              function(data, id)
                 log("Lookup received data.. " .. data)
                 local trans = json.decode(data)
                 local chn_msg = trans.trans_result[1].dst
                 translateFrom = trans.from
                 log("Set reply translation to: " .. translateFrom)
                 chn_msg = string.gsub(chn_msg, "u(....)", decodeUTF16)
                 displayMessage(channel_id, name, chn_msg, color, icon)
                 log("Translation Received: " .. trans.trans_result[1].dst)
              end
   )
end

Hooks:Add("ChatManagerOnReceiveMessage", "ChatManagerReceiveMessageTrans",
          function(channel_id, name, message, color, icon)
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
         dohttpreq( "http://openapi.baidu.com/public/2.0/bmt/"..
                    "translate?client_id=" .. API_KEY .. "&from="..
                    "auto&" ..
                    "to=" .. translateFrom ..
                    "&q=" .. escape(msg),
                    function(data, id)
                       log("Send received data.. " .. data)
                       local trans = json.decode(data)
                       chn_msg = trans.trans_result[1].dst
                       log("Got sending translation: " .. chn_msg)
                       if translateFrom ~= "en" then
                          chn_msg = string.gsub(chn_msg, "u(....)", decodeUTF16)
                       end
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

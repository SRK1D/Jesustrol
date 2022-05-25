local Players = game:GetService("Players")
-- Modules

local Optipost = require(script.Optipost)

-- Config

local DefaultConfig = {
    -- Target URL
    URL = "http://127.0.0.1:4545/rocontrol"
}

-- Code

local ut = {}

ut.ChatService = require(
    game:GetService("ServerScriptService")
        :WaitForChild("ChatServiceRunner")
        :WaitForChild("ChatService")
)

ut.Speaker = ut.ChatService:AddSpeaker("RoControl")
ut.Speaker:JoinChannel("All")

-- ut commands

ut.commands = {
    commands = {},
    Session = nil
}

function ut.commands:addCommand(id,commandAliases,desc,args_amt,action)
    if not self.Session then error("Cannot addCommand when Session is nil.") end

    ut.commands.commands[id] = action

    self.Session:Send({
        type = "RegisterCommand",
        names = commandAliases,
        id = id,
        args_amt = args_amt,
        desc=desc
    })
end

-- ut.discord

ut.discord = {
    Session = nil
}

function ut.discord:Say(str)
    if not self.Session then error("Cannot say when Session is nil.") end
    self.Session:Send({
        type = "Say",
        data=str
    })
end

-- ut.chat

function ut._initChat(session,player:Player)
    local c = player.Chatted:Connect(function(msg)
        session:Send({
            type = "Chat",
            data = msg,
            userid = tostring(player.UserId),
            username = player.Name,
            displayname = player.DisplayName
        })
    end)
    
    session.onclose:Connect(function()
        c:Disconnect()
    end)
end

function ut.chat(session)
    print("Chat logging ready.")

    for x,v in pairs(game:GetService("Players"):GetPlayers()) do
        ut._initChat(session,v)
    end

    local c = game:GetService("Players").PlayerAdded:Connect(function(p)
        ut._initChat(session,p)
    end)

    session.onclose:Connect(function()
        c:Disconnect()
    end)
end

-- ut init

function ut.init(session)
    local x = table.clone(ut)
    x.commands.Session = session
    x.discord.Session = session
end

local Actions = {
    Ready = function(session,data)
        session:Send({
            type = "GetGameInfo",
            data = game.JobId,
            gameid = tonumber(game.PlaceId)
        })
    end,
    Chat = function(session,data)
        ut.Speaker:SayMessage(data.data,"All",{Tags={
            {
                TagText = "as "..data.tag,
                TagColor = Color3.fromHex(data.tagColor or "#FFFFFF")
            }
        },NameColor=Color3.new(1,0,0)})
    end,
    ExecuteCommand = function(session,data)
        if (session.api.commands[data.commandId]) then
            session.api.commands[data.commandId](data.args)
        end
    end
}

function StartSession(config)
    local Config = config or DefaultConfig

    local OptipostSession = Optipost.new(Config.URL)

    OptipostSession.onmessage:Connect(function(data) 
        if (Actions[data.type or ""]) then
            Actions[data.type or ""](OptipostSession,data)
        end
    end)

    OptipostSession.onopen:Connect(function(data)
        print("Connected to RoControl. Waiting for server to send back Ready...")
    end)

    OptipostSession:Open()

    ut.chat(OptipostSession)

    return OptipostSession
end

return StartSession
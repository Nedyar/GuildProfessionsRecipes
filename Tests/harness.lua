-- Test harness for Guild Professions & Recipes: a fake world with a virtual clock, a guild
-- roster and a server that delivers addon messages between clients. Each
-- client loads the real addon files into its own environment.
local H = {}

H.ADDON = assert(ADDON_PATH, "set ADDON_PATH")
H.FILES = {
    "Locales/Locales.lua", "Locales/deDE.lua", "Locales/esES.lua", "Locales/esMX.lua", "Locales/frFR.lua",
    "Locales/itIT.lua", "Locales/koKR.lua", "Locales/ptBR.lua", "Locales/ruRU.lua", "Locales/zhCN.lua", "Locales/zhTW.lua",
    "Core.lua", "Pack.lua", "Data.lua", "Comm.lua", "Roster.lua", "Scanner.lua",
    "Sync.lua", "RosterColumn.lua", "Viewer.lua", "Probe.lua",
}

-- Assertions ------------------------------------------------------------------

H.passes, H.failures = 0, 0

function H.check(condition, message)
    if condition then
        H.passes = H.passes + 1
    else
        H.failures = H.failures + 1
        print("  FAIL: " .. message)
    end
    return condition
end

function H.eq(actual, expected, message)
    return H.check(actual == expected, ("%s (got %s, expected %s)"):format(message, tostring(actual), tostring(expected)))
end

function H.section(name)
    print("== " .. name)
end

function H.DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for k, v in pairs(value) do
        copy[H.DeepCopy(k)] = H.DeepCopy(v)
    end
    return copy
end

function H.SameList(a, b)
    if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

-- Independent Base64 (to cross-check the addon's own) -----------------------------

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function Enc64(s)
    local out = {}
    for i = 1, #s, 3 do
        local chunk = s:sub(i, i + 2)
        local bits = ""
        for j = 1, #chunk do
            local b = chunk:byte(j)
            for k = 7, 0, -1 do
                bits = bits .. (math.floor(b / 2 ^ k) % 2)
            end
        end
        while #bits % 6 ~= 0 do
            bits = bits .. "0"
        end
        for j = 1, #bits, 6 do
            out[#out + 1] = B64:sub(tonumber(bits:sub(j, j + 5), 2) + 1, tonumber(bits:sub(j, j + 5), 2) + 1)
        end
        out[#out + 1] = ("="):rep(3 - #chunk)
    end
    return table.concat(out)
end
local function Dec64(s)
    s = s:gsub("=", "")
    local bits = ""
    for i = 1, #s do
        local v = B64:find(s:sub(i, i), 1, true) - 1
        for k = 5, 0, -1 do
            bits = bits .. (math.floor(v / 2 ^ k) % 2)
        end
    end
    local out = {}
    for i = 1, #bits - 7, 8 do
        out[#out + 1] = string.char(tonumber(bits:sub(i, i + 7), 2))
    end
    return table.concat(out)
end
H.Enc64, H.Dec64 = Enc64, Dec64

-- World -------------------------------------------------------------------------

local World = {}
World.__index = World

function H.NewWorld(options)
    options = options or {}
    math.randomseed(options.seed or 1)
    local world = setmetatable({
        now = 0,
        base = 1760000000,
        timers = {},
        seq = 0,
        clients = {},
        roster = {},
        guildName = "Test Guild",
        realm = "TestRealm",
        errors = {},
        dict = {},
        lastDelivery = {},
        jitter = options.jitter or 0.15,
        senderFormat = options.senderFormat or "full",
        -- WoW Forever's roster gives names without a realm; "full" adds it.
        rosterNames = options.rosterNames or "short",
        guildRealm = options.guildRealm or "TestRealm",
        realmIDs = { TestRealm = 1 },
        encoding = options.encoding or "native", -- "native" or "none"
        compress = options.compress ~= false,
        whisperLimit = options.whisperLimit,
        communities = options.communities,
        strictWhispers = options.strictWhispers,
        systemShown = {},
        recipeSkill = {},
        log = {},
        stats = { sent = 0, guild = 0, whisper = 0, throttled = 0, types = {} },
    }, World)
    return world
end

function World:Schedule(delay, fn, owner)
    self.seq = self.seq + 1
    local timer = { at = self.now + math.max(delay or 0, 0), seq = self.seq, fn = fn, owner = owner }
    self.timers[#self.timers + 1] = timer
    return timer
end

function World:Protect(label, fn, ...)
    local args, n = { ... }, select("#", ...)
    local ok, err = xpcall(function()
        return fn(unpack(args, 1, n))
    end, debug.traceback)
    if not ok then
        self.errors[#self.errors + 1] = label .. ": " .. tostring(err)
    end
end

function World:Step(dt)
    self.now = self.now + dt
    local due, keep = {}, {}
    for _, timer in ipairs(self.timers) do
        if not timer.cancelled then
            if timer.at <= self.now + 1e-9 then
                due[#due + 1] = timer
            else
                keep[#keep + 1] = timer
            end
        end
    end
    self.timers = keep
    table.sort(due, function(a, b)
        if a.at ~= b.at then
            return a.at < b.at
        end
        return a.seq < b.seq
    end)
    for _, timer in ipairs(due) do
        if not timer.cancelled then
            self:Protect("timer", timer.fn)
        end
    end
    for _, client in ipairs(self.clients) do
        if client.loggedIn then
            for frame in pairs(client.updateFrames) do
                if frame._shown and frame._scripts.OnUpdate then
                    self:Protect(client.name .. " OnUpdate", frame._scripts.OnUpdate, frame, dt)
                end
            end
        end
    end
end

function World:RunFor(seconds, dt)
    dt = dt or 0.05
    local stop = self.now + seconds
    while self.now < stop - 1e-9 do
        self:Step(dt)
    end
end

-- Runs until done() is true (checked every second) or the time runs out.
function World:RunUntil(done, maxSeconds)
    local stop = self.now + maxSeconds
    while self.now < stop do
        self:RunFor(1)
        if done() then
            return true
        end
    end
    return false
end

-- Fake frames ---------------------------------------------------------------------

local function NewObject(client, objectType)
    local object = { _scripts = {}, _shown = true, _type = objectType, _client = client, _points = {} }
    return setmetatable(object, {
        __index = function(self, key)
            local method = H.FrameMethods[key]
            if method then
                return method
            end
            -- Other widget methods do nothing; like a real frame, any other
            -- key is nil.
            if H.NoOpMethods[key] then
                return H.NoOp
            end
            return nil
        end,
    })
end

H.NewObject = NewObject

H.NoOp = function()
    return nil
end
H.NoOpMethods = {}
for name in ([[AddLine ClearAllPoints EnableMouse HighlightText RegisterForClicks RegisterForDrag SetAllPoints
    SetAlpha SetAutoFocus SetClampedToScreen SetColorTexture SetDesaturated SetElementExtent SetEnabled SetFocus
    SetFontObject SetFrameStrata SetHeight SetHighlightTexture SetID SetItemByID SetJustifyH SetMinMaxValues
    SetMotionScriptsWhileDisabled SetMovable SetMultiLine SetOwner SetPoint SetPortraitToAsset SetScrollChild
    SetSize SetSpacing SetSpellByID SetStatusBarColor SetStatusBarTexture SetTexCoord SetTexture SetTitle
    SetToplevel SetValue SetWidth SetWordWrap StartMoving StopMovingOrSizing SetMaxLetters SetMaxBytes
    SetDataProvider SetElementInitializer]]):gmatch("%a+") do
    H.NoOpMethods[name] = true
end

H.FrameMethods = {
    RegisterEvent = function(self, event)
        local client = self._client
        client.eventFrames[event] = client.eventFrames[event] or {}
        client.eventFrames[event][self] = true
    end,
    UnregisterEvent = function(self, event)
        local frames = self._client.eventFrames[event]
        if frames then
            frames[self] = nil
        end
    end,
    SetScript = function(self, name, fn)
        self._scripts[name] = fn
        if name == "OnUpdate" then
            self._client.updateFrames[self] = true
        end
    end,
    HookScript = function(self, name, fn)
        local old = self._scripts[name]
        self._scripts[name] = function(...)
            if old then
                old(...)
            end
            fn(...)
        end
    end,
    GetScript = function(self, name)
        return self._scripts[name]
    end,
    Show = function(self)
        self._shown = true
    end,
    Hide = function(self)
        self._shown = false
    end,
    SetShown = function(self, shown)
        self._shown = shown and true or false
    end,
    IsShown = function(self)
        return self._shown
    end,
    IsVisible = function(self)
        return self._shown
    end,
    CreateTexture = function(self)
        return NewObject(self._client, "Texture")
    end,
    CreateFontString = function(self)
        return NewObject(self._client, "FontString")
    end,
    GetName = function(self)
        return self._name
    end,
    GetText = function(self)
        return self._text
    end,
    SetText = function(self, text)
        self._text = text
    end,
    -- About 6 pixels per character.
    GetTextWidth = function(self)
        return 6 * #(self._text or "")
    end,
}

-- Clients -------------------------------------------------------------------------

-- professions: list in GetProfessions order of
--   { sl = skillLine, r = rank, m = max, spell = spellID, hasRecipes = bool }
function World:RealmID(realm)
    if not self.realmIDs[realm] then
        local count = 0
        for _ in pairs(self.realmIDs) do
            count = count + 1
        end
        self.realmIDs[realm] = count + 1
    end
    return self.realmIDs[realm]
end

-- options.realm: the character's realm (members of a guild can be on several).
function World:NewClient(name, options)
    options = options or {}
    local realm = options.realm or self.realm
    local client = {
        world = self,
        name = name,
        realm = realm,
        key = name .. "-" .. realm,
        guid = ("Player-%d-%08X"):format(self:RealmID(realm), #self.roster + 1),
        professions = options.professions or {},
        locale = options.locale or "enUS",
        eventFrames = {},
        updateFrames = {},
        printed = {},
        filters = {},
        bucket = { tokens = 10, last = 0 },
        inGuild = true,
        lockdown = false,
        saved = options.saved, -- the account's saved variables file
    }
    self.clients[#self.clients + 1] = client
    self.roster[#self.roster + 1] = { key = client.key, short = name, class = "MAGE", guid = client.guid, client = client }
    return client
end

-- A guild member who never logs in with the addon.
function World:AddMember(name, realm)
    realm = realm or self.realm
    local key = name .. "-" .. realm
    local guid = ("Player-%d-%08X"):format(self:RealmID(realm), #self.roster + 1)
    self.roster[#self.roster + 1] = { key = key, short = name, class = "WARRIOR", guid = guid }
    return key, guid
end

function World:RemoveMember(key)
    for i, member in ipairs(self.roster) do
        if member.key == key then
            table.remove(self.roster, i)
            return
        end
    end
end

function World:FindClient(target)
    for _, client in ipairs(self.clients) do
        if client.key == target or client.name == target then
            return client
        end
    end
end

function World:FireEvent(client, event, ...)
    local frames = client.eventFrames[event]
    if not frames then
        return
    end
    local list = {}
    for frame in pairs(frames) do
        list[#list + 1] = frame
    end
    for _, frame in ipairs(list) do
        if frame._scripts.OnEvent then
            self:Protect(client.name .. " " .. event, frame._scripts.OnEvent, frame, event, ...)
        end
    end
end

function World:RosterChanged(except)
    for _, other in ipairs(self.clients) do
        if other.loggedIn and other ~= except then
            self:Schedule(0.3, function()
                self:FireEvent(other, "GUILD_ROSTER_UPDATE", true)
            end, other)
        end
    end
end

function World:OnlineCount()
    local count = 0
    for _, member in ipairs(self.roster) do
        if member.client and member.client.loggedIn then
            count = count + 1
        end
    end
    return count
end

function World:LoadFile(client, path)
    local chunk, err = loadfile(H.ADDON .. "/" .. path)
    if not chunk then
        -- Like the game: an error for this file, and loading goes on.
        self.errors[#self.errors + 1] = client.name .. ": error loading " .. path .. ": " .. tostring(err)
        return
    end
    setfenv(chunk, client.env)
    self:Protect(client.name .. " load " .. path, chunk, "GuildProfessionsRecipes", client.ns)
end

-- The client's saved file (client.saved) loads after the addon's files,
-- unless options.brokenSavedVariables is set (the data was lost).
function World:Login(client, options)
    options = options or {}
    client.env = self:MakeEnv(client)
    client.ns = {}
    client.eventFrames, client.updateFrames, client.printed = {}, {}, {}
    for _, path in ipairs(H.FILES) do
        self:LoadFile(client, path)
    end
    if client.saved and not options.brokenSavedVariables then
        client.env.GuildProfessionsRecipesDB = H.DeepCopy(client.saved)
    end
    client.loggedIn = true
    self:FireEvent(client, "ADDON_LOADED", "GuildProfessionsRecipes")
    self:FireEvent(client, "PLAYER_LOGIN")
    self:RosterChanged(client)
end

function World:Logout(client)
    self:FireEvent(client, "PLAYER_LOGOUT")
    client.saved = H.DeepCopy(client.env.GuildProfessionsRecipesDB)
    client.loggedIn = false
    for _, timer in ipairs(self.timers) do
        if timer.owner == client then
            timer.cancelled = true
        end
    end
    self:RosterChanged(client)
end

-- Opens a profession window on the client: all = every recipe of the
-- profession, learned = the ones the character knows.
function World:OpenProfession(client, skillLine, all, learned, linked)
    local set = {}
    for _, id in ipairs(learned) do
        set[id] = true
        self.recipeSkill[id] = skillLine
    end
    for _, id in ipairs(all) do
        self.recipeSkill[id] = skillLine
    end
    client.session = { sl = skillLine, all = all, learned = set, linked = linked }
    self:FireEvent(client, "TRADE_SKILL_SHOW")
    self:FireEvent(client, "TRADE_SKILL_LIST_UPDATE")
end

function World:CloseProfession(client)
    client.session = nil
    self:FireEvent(client, "TRADE_SKILL_CLOSE")
end

-- The server -------------------------------------------------------------------------

function World:Send(client, prefix, text, channel, target)
    if type(text) ~= "string" or #text > 255 or text:find("\0", 1, true) then
        self.errors[#self.errors + 1] = client.name .. ": invalid addon message (" .. tostring(text and #text) .. " bytes)"
        return 2
    end
    if client.lockdown then
        return 11
    end
    if channel == "GUILD" and not client.inGuild then
        return 10
    end
    local bucket = client.bucket
    bucket.tokens = math.min(10, bucket.tokens + (self.now - bucket.last))
    bucket.last = self.now
    if channel == "GUILD" then
        if bucket.tokens < 1 then
            self.stats.throttled = self.stats.throttled + 1
            return 3
        end
        bucket.tokens = bucket.tokens - 1
    end
    -- Optionally whispers are throttled too (cap messages, rate per second).
    local limit = self.whisperLimit
    if channel == "WHISPER" and limit then
        local whisper = client.whisperBucket or { tokens = limit.cap, last = self.now }
        client.whisperBucket = whisper
        whisper.tokens = math.min(limit.cap, whisper.tokens + (self.now - whisper.last) * limit.rate)
        whisper.last = self.now
        if whisper.tokens < 1 then
            self.stats.throttled = self.stats.throttled + 1
            return 3
        end
        whisper.tokens = whisper.tokens - 1
    end
    local recipients = {}
    if channel == "GUILD" then
        for _, other in ipairs(self.clients) do
            if other.loggedIn and other.inGuild then
                recipients[#recipients + 1] = other
            end
        end
        self.stats.guild = self.stats.guild + 1
    elseif channel == "WHISPER" then
        local other = self:FindClient(target)
        if self.strictWhispers and other and target ~= other.name then
            -- Like WoW Forever: only "Name Surname" reaches a player; the send
            -- still "succeeds" and the server answers with a system line.
            self:Schedule(0.1, function()
                self:SystemMessage(client, ("No player named '%s' is currently playing."):format(target))
            end, client)
            return 0
        end
        if not other or not other.loggedIn then
            return 12
        end
        recipients[1] = other
        self.stats.whisper = self.stats.whisper + 1
    else
        return 4
    end
    self.stats.sent = self.stats.sent + 1
    self.log[#self.log + 1] = { time = self.now, from = client.name, channel = channel, target = target, text = text }
    local sender = self.senderFormat == "full" and client.key or client.name
    for _, other in ipairs(recipients) do
        local pair = client.name .. ">" .. other.name
        local at = math.max(self.now + 0.05 + math.random() * self.jitter, (self.lastDelivery[pair] or 0) + 0.001)
        self.lastDelivery[pair] = at
        self:Schedule(at - self.now, function()
            if other.loggedIn then
                self:FireEvent(other, "CHAT_MSG_ADDON", prefix, text, channel, sender, other.name)
            end
        end, other)
    end
    return 0
end

-- A system line in the chat, unless one of the client's chat filters hides it.
function World:SystemMessage(client, text)
    local filter = client.filters.CHAT_MSG_SYSTEM
    if filter and filter(nil, "CHAT_MSG_SYSTEM", text) then
        return
    end
    self.systemShown[#self.systemShown + 1] = client.name .. ": " .. text
end

-- Decodes a logged chunk's message type when it is a single-part message.
function World:CountTypes(since)
    local counts = {}
    for _, entry in ipairs(self.log) do
        if entry.time >= (since or 0) then
            counts[entry.channel] = (counts[entry.channel] or 0) + 1
        end
    end
    return counts
end

-- API stubs ------------------------------------------------------------------------

function World:MakeEnv(client)
    local world = self
    local api = {}
    local env = setmetatable({}, {
        __index = function(_, key)
            local value = api[key]
            if value ~= nil then
                return value
            end
            return _G[key]
        end,
    })

    api.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring((select(i, ...)))
        end
        client.printed[#client.printed + 1] = table.concat(parts, " ")
    end
    api.date = os.date
    api.geterrorhandler = function()
        return function(err)
            world.errors[#world.errors + 1] = client.name .. ": " .. tostring(err) .. "\n" .. debug.traceback()
        end
    end
    api.wipe = function(t)
        for k in pairs(t) do
            t[k] = nil
        end
        return t
    end
    api.tContains = function(t, value)
        for _, v in pairs(t) do
            if v == value then
                return true
            end
        end
        return false
    end
    api.tinsert = table.insert
    api.strtrim = function(s)
        return (s:match("^%s*(.-)%s*$"))
    end
    api.hooksecurefunc = function() end
    api.GetTime = function()
        return world.now
    end
    api.GetServerTime = function()
        return math.floor(world.base + world.now)
    end
    api.C_Timer = {
        After = function(delay, fn)
            world:Schedule(delay, fn, client)
        end,
        NewTimer = function(delay, fn)
            local handle = {}
            handle.timer = world:Schedule(delay, function()
                fn(handle)
            end, client)
            handle.Cancel = function(self)
                self.timer.cancelled = true
            end
            return handle
        end,
        NewTicker = function(delay, fn, iterations)
            local handle = { count = 0 }
            local function Tick()
                if handle.cancelled then
                    return
                end
                handle.count = handle.count + 1
                fn(handle)
                if not handle.cancelled and (not iterations or handle.count < iterations) then
                    handle.timer = world:Schedule(delay, Tick, client)
                end
            end
            handle.timer = world:Schedule(delay, Tick, client)
            handle.Cancel = function(self)
                self.cancelled = true
                self.timer.cancelled = true
            end
            return handle
        end,
    }
    api.CreateFrame = function(objectType, name, parent)
        local frame = NewObject(client, objectType)
        frame._name = name
        frame._parent = parent
        client.created = client.created or {}
        client.created[#client.created + 1] = frame
        if name then
            env[name] = frame
        end
        return frame
    end
    api.C_AddOns = {
        GetAddOnMetadata = function()
            return "0.1.0"
        end,
    }
    api.GetLocale = function()
        return client.locale
    end
    api.Enum = {
        SendAddonMessageResult = { Success = 0, InvalidMessage = 2, AddonMessageThrottle = 3, ChannelThrottle = 8, NotInGuild = 10, AddOnMessageLockdown = 11, TargetOffline = 12 },
        CompressionMethod = { Deflate = 0, Zlib = 1, Gzip = 2 },
        SpellBookSpellBank = { Player = 0, Pet = 1 },
        ClubType = { BattleNet = 0, Character = 1, Guild = 2, Other = 3 },
        CraftingReagentType = { Modifying = 0, Basic = 1 },
    }
    api.C_ChatInfo = {
        RegisterAddonMessagePrefix = function()
            return 0
        end,
        IsAddonMessagePrefixRegistered = function()
            return true
        end,
        InChatMessagingLockdown = function()
            return client.lockdown
        end,
        AreOutgoingAddonChatMessagesRestricted = function()
            return false
        end,
        SendAddonMessage = function(prefix, text, channel, target)
            return world:Send(client, prefix, text, channel, target)
        end,
    }
    if world.encoding == "native" then
        api.C_EncodingUtil = {
            EncodeBase64 = Enc64,
            DecodeBase64 = Dec64,
        }
        if world.compress then
            -- An invertible stand-in: a short token for each distinct input.
            api.C_EncodingUtil.CompressString = function(text)
                local token = world.dict[text]
                if not token then
                    world.dictCount = (world.dictCount or 0) + 1
                    token = "Z" .. world.dictCount .. "\0"
                    world.dict[text] = token
                    world.dict[token] = text
                end
                return token
            end
            api.C_EncodingUtil.DecompressString = function(token)
                return assert(world.dict[token], "unknown compressed data")
            end
        end
    end
    -- Like WoW Forever: a two-part name comes back in two values.
    api.UnitName = function()
        local first, last = client.name:match("^(%S+)%s+(.+)$")
        if first then
            return first, last
        end
        return client.name
    end
    api.UnitGUID = function()
        return client.guid
    end
    api.GetRealmName = function()
        return "Test Realm"
    end
    api.GetNormalizedRealmName = function()
        return client.realm
    end
    api.IsInGuild = function()
        return client.inGuild
    end
    api.GetGuildInfo = function()
        if client.inGuild then
            return world.guildName, "Member", 1, world.guildRealm ~= client.realm and world.guildRealm or nil
        end
    end
    api.GetNumGuildMembers = function()
        local online = world:OnlineCount()
        return #world.roster, online, online
    end
    api.GetGuildRosterInfo = function(index)
        local member = world.roster[index]
        if not member then
            return nil
        end
        local online = member.client and member.client.loggedIn or false
        local name = world.rosterNames == "full" and member.key or member.short
        return name, "Member", 1, 60, "Mage", "Zone", "", "", online, 0, member.class, 0, 0, false, false, 0, member.guid
    end
    api.C_GuildInfo = {
        GuildRoster = function()
            world:Schedule(0.2, function()
                world:FireEvent(client, "GUILD_ROSTER_UPDATE", false)
            end, client)
        end,
    }
    api.GetProfessions = function()
        local result = {}
        for i = 1, 7 do
            result[i] = client.professions[i] and i or nil
        end
        return unpack(result, 1, 7)
    end
    api.GetProfessionInfo = function(index)
        local prof = client.professions[index]
        return "Prof" .. prof.sl, 1000 + index, prof.r, prof.m, 2, index * 10, prof.sl, 0, 0, 0, "Prof" .. prof.sl
    end
    api.IsPlayerSpell = function(spellID)
        return client.knownSpells ~= nil and client.knownSpells[spellID] == true
    end
    api.C_SpellBook = {
        GetSpellBookItemInfo = function(slot)
            for index = 1, 7 do
                local prof = client.professions[index]
                if prof and index * 10 + 1 == slot then
                    return { spellID = prof.spell, actionID = prof.spell }
                end
            end
            return {}
        end,
    }
    local function SessionFlag()
        return client.session ~= nil and client.session.linked == true
    end
    api.C_TradeSkillUI = {
        CanTradeSkillShowCraftingUI = function(spellID)
            for index = 1, 7 do
                local prof = client.professions[index]
                if prof and prof.spell == spellID then
                    return prof.hasRecipes
                end
            end
            return false
        end,
        IsTradeSkillReady = function()
            return client.session ~= nil
        end,
        IsDataSourceChanging = function()
            return false
        end,
        IsTradeSkillLinked = SessionFlag,
        IsTradeSkillGuild = function()
            return false
        end,
        IsTradeSkillGuildMember = function()
            return false
        end,
        IsNPCCrafting = function()
            return false
        end,
        GetChildProfessionInfo = function()
            return { professionID = client.session and client.session.sl or 0 }
        end,
        GetBaseProfessionInfo = function()
            return { professionID = client.session and client.session.sl or 0 }
        end,
        GetAllRecipeIDs = function()
            if client.noAllRecipeIDs then
                return nil
            end
            return client.session and client.session.all or {}
        end,
        GetFilteredRecipeIDs = function()
            return client.session and (client.session.filtered or client.session.all) or {}
        end,
        GetRecipeInfo = function(id)
            return { name = "Recipe " .. id, learned = client.session ~= nil and client.session.learned[id] == true, categoryID = 5, isDummyRecipe = false }
        end,
        GetCategoryInfo = function()
            return { name = "Category", uiOrder = 1 }
        end,
        GetProfessionInfoByRecipeID = function(id)
            return { professionID = world.recipeSkill[id] or 0 }
        end,
        GetTradeSkillLineForRecipe = function(id)
            return world.recipeSkill[id]
        end,
        GetTradeSkillDisplayName = function(skillLine)
            return "Skill" .. skillLine
        end,
        GetTradeSkillTexture = function()
            return 1
        end,
        IsGuildTradeSkillsEnabled = function()
            return false
        end,
    }
    api.C_Spell = {
        GetSpellName = function(id)
            return "Spell" .. id
        end,
        GetSpellTexture = function()
            return 2
        end,
        GetSpellLink = function()
            return nil
        end,
        RequestLoadSpellData = function() end,
    }
    api.C_Item = {
        GetItemIconByID = function()
            return 3
        end,
        GetItemQualityByID = function()
            return 1
        end,
        RequestLoadItemDataByID = function() end,
    }
    api.Ambiguate = function(name)
        return (name:gsub("%-[^%-]+$", ""))
    end
    -- Blizzard's SecondsToTime (Blizzard_SharedXML\TimeUtil.lua) with
    -- English unit names. Limited to one term, it only uses a unit from 1.5
    -- of it.
    api.SecondsToTime = function(seconds, noSeconds, notAbbreviated, maxCount, roundUp)
        seconds = roundUp and math.ceil(seconds) or math.floor(seconds)
        maxCount = maxCount or 2
        local threshold = maxCount > 1 and 1.0 or 1.5
        local parts = {}
        for _, unit in ipairs({ { 86400, " Days" }, { 3600, " Hours" }, { 60, " Minutes" } }) do
            local size, name = unit[1], unit[2]
            if #parts < maxCount and seconds >= size * threshold then
                local last = #parts + 1 == maxCount
                parts[#parts + 1] = (last and roundUp and math.ceil(seconds / size) or math.floor(seconds / size)) .. name
                seconds = seconds % size
            end
        end
        if #parts < maxCount and seconds > 0 and not noSeconds then
            parts[#parts + 1] = seconds .. " Seconds"
        end
        return table.concat(parts, " ")
    end
    api.InCombatLockdown = function()
        return false
    end
    api.IsInInstance = function()
        return false
    end
    api.EventUtil = {
        ContinueOnAddOnLoaded = function() end,
    }
    api.ChatFrameUtil = {
        AddMessageEventFilter = function(event, fn)
            client.filters[event] = fn
        end,
        InsertLink = function() end,
    }
    -- UI stubs, enough to drive the viewer and the roster column.
    api.hooksecurefunc = function(a, b, c)
        local target, name, hook
        if type(a) == "table" then
            target, name, hook = a, b, c
        else
            target, name, hook = env, a, b
        end
        local original = target[name]
        rawset(target, name, function(...)
            local results = { original(...) }
            hook(...)
            return unpack(results)
        end)
    end
    api.CreateDataProvider = function(elements)
        return { elements = elements }
    end
    api.CreateScrollBoxListLinearView = function()
        local view = NewObject(client, "View")
        rawset(view, "SetElementInitializer", function(self, template, init)
            self.init = init
        end)
        return view
    end
    api.ScrollUtil = {
        InitScrollBoxListWithScrollBar = function(scrollBox, _, view)
            rawset(scrollBox, "_view", view)
            rawset(scrollBox, "SetDataProvider", function(self, provider)
                self._provider = provider
            end)
        end,
        AddAcquiredFrameCallback = function(scrollBox, callback, owner)
            rawset(scrollBox, "_acquired", function(frame)
                callback(owner, frame)
            end)
        end,
    }
    api.ScrollBoxConstants = { RetainScrollPosition = true }
    api.PanelTemplates_SetNumTabs = function() end
    api.PanelTemplates_UpdateTabs = function() end
    api.PanelTemplates_TabResize = function() end
    api.Item = {
        CreateFromItemID = function()
            return { ContinueOnItemLoad = function(_, callback) callback() end }
        end,
    }
    api.IsModifiedClick = function()
        return client.shiftDown == true
    end
    api.PlaySound = function() end
    api.SOUNDKIT = {}
    api.GameTooltip = NewObject(client, "GameTooltip")
    api.GameTooltip_Hide = function() end
    api.RETRIEVING_ITEM_INFO = "Retrieving item information"
    api.NORMAL_FONT_COLOR = { GetRGB = function() return 1, 0.82, 0 end }
    api.GREEN_FONT_COLOR = { GetRGB = function() return 0, 1, 0 end }
    api.C_Item.GetItemInfoInstant = function(itemID)
        return itemID, "Trade Goods", "Elixir", "", 1, 7, 2
    end
    api.C_Item.GetItemQualityColor = function()
        return 1, 1, 1, "ffffffff"
    end
    api.C_Item.GetItemNameByID = function(itemID)
        return "Item" .. itemID
    end
    api.C_Item.GetItemInfo = function(itemID)
        return "Item" .. itemID, "|cffffffff|Hitem:" .. itemID .. "|h[Item]|h|r"
    end
    api.C_TradeSkillUI.GetRecipeSchematic = function(recipeID)
        return {
            name = "Recipe " .. recipeID, icon = 4, outputItemID = recipeID + 100000, quantityMin = 1, quantityMax = recipeID % 2 + 1,
            reagentSlotSchematics = { { reagents = { { itemID = 2447 } }, quantityRequired = 2, reagentType = 1 } },
        }
    end
    api.ChatFrameUtil.InsertLink = function(link)
        client.linked = link
    end
    if world.communities then
        api.CommunitiesFrame = world.communities(client)
        api.EventUtil.ContinueOnAddOnLoaded = function(_, callback)
            callback()
        end
    end
    api.ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
    api.YES, api.NO, api.NONE = "Yes", "No", "None"
    api.UISpecialFrames = {}
    api.SlashCmdList = {}
    api.UIParent = NewObject(client, "Frame")
    return env
end

return H

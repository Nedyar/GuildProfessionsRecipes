-- Guild Professions & Recipes: shows the professions and recipes of every guild member.
--
-- The addon messages, the guild roster, the saved database and the sync
-- are LibGuildSync's (a separate addon this one depends on), attached
-- below. Core.lua holds the startup, how our own changes are announced,
-- and the slash commands.
local ADDON_NAME, ns = ...
local L = ns.L
local Lib = LibGuildSync

ns.ADDON_NAME = ADDON_NAME

-- While a version with a new protocol is tried in game before its release,
-- set trial = true: it then talks on trialPrefix (see LibGuildSync's
-- Core.lua). Turn it off for the release.
Lib.Attach(ns, {
    title = "Guild Professions & Recipes",
    tag = "GR",
    prefix = "GuildProfRecipes",
    trialPrefix = "GuildProfRecTest",
    trial = false,
    -- 4: orders without expiry, deliveries counted (version 0.9). Still
    -- read: 2, members known by GUID (0.2 to 0.7); 3, records with crafting
    -- orders (0.8). The protocol is also the record format (Pack.FORMAT).
    protocol = "4",
    legacy = { ["2"] = true, ["3"] = true },
    -- The test messages of /grecipes probe.
    probe = "0",
    savedVariable = "GuildProfessionsRecipesDB",
})

-- While a version that keeps the protocol is tried in game before its
-- release, it tells the guild it runs the last release (ANNOUNCE_AS): it
-- keeps sharing with the members on it, who are not told to update to a
-- version they cannot get yet. Set it to nil for the release.
local ANNOUNCE_AS = nil
if ANNOUNCE_AS then
    ns.VERSION_NUM = Lib.VersionNumber(ANNOUNCE_AS)
end

-- Announcing our changes ---------------------------------------------------------
--
-- Besides its whole record (U), a member announces a change of skill levels
-- alone with a short S message, and changes to crafting orders go out
-- within seconds. Members on 0.2 to 0.8 still hear and send both U and S.
local Sync = ns.Sync
local T_LEVELS = string.byte("S")
Sync.QUICK_KINDS.O = true
Sync.LEGACY_TYPES[T_LEVELS] = true

-- Our professions have been read, so what we announce is current.
function Sync.OwnReady()
    return ns.Scanner.ready
end

local function OnlyLevels(pending)
    for kind in pairs(pending) do
        if kind ~= "S" then
            return false
        end
    end
    return pending.S == true
end

-- Skill levels alone, on top of the version of our record last announced.
function Sync.WriteOwnChange(record, state, pending)
    if not OnlyLevels(pending) or state.sentGuild ~= ns.Roster.guildKey or not state.sentT or state.sentT >= record.t then
        return nil
    end
    local writer = Sync.Begin(T_LEVELS)
    writer:UInt(state.sentT)
    writer:UInt(record.t)
    local professions = ns.Data.SortedProfessions(record)
    writer:UInt(#professions)
    for _, prof in ipairs(professions) do
        writer:UInt(prof.sl)
        writer:UInt(prof.r)
        writer:UInt(prof.m)
    end
    return writer
end

Sync.handlers[T_LEVELS] = function(reader, sender, guildKey)
    local Data, Pack = ns.Data, ns.Pack
    local previous, t = reader:UInt(), reader:UInt()
    local count = reader:UInt()
    if count > Pack.LIMITS.professions then
        return
    end
    local levels = {}
    for i = 1, count do
        levels[i] = { reader:UInt(), reader:UInt(), reader:UInt() }
    end
    local guild = Data.GetGuild(guildKey)
    local owner = ns.Roster.GUIDOfSender(sender)
    local record = guild and owner and guild.members[owner]
    -- Only applies on top of the version it follows; otherwise the next sync
    -- brings the whole record.
    if not record or record.t ~= previous or t <= previous or t > ns.Now() + 300 then
        return
    end
    for _, level in ipairs(levels) do
        local prof = record.p[level[1]]
        if prof and level[2] <= Pack.LIMITS.rank and level[3] <= Pack.LIMITS.rank then
            prof.r, prof.m = level[2], level[3]
        end
    end
    record.t, record.fh, record.seen = t, true, ns.Now()
    Data.Changed(guild)
end

-- Professions ----------------------------------------------------------------

-- The usual icon of each profession, for when the client has no better one.
local PROFESSION_ICONS = {
    [129] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", -- First Aid
    [164] = "Interface\\Icons\\Trade_BlackSmithing",
    [165] = "Interface\\Icons\\Trade_LeatherWorking",
    [171] = "Interface\\Icons\\Trade_Alchemy",
    [182] = "Interface\\Icons\\Trade_Herbalism",
    [185] = "Interface\\Icons\\INV_Misc_Food_15",           -- Cooking
    [186] = "Interface\\Icons\\Trade_Mining",
    [197] = "Interface\\Icons\\Trade_Tailoring",
    [202] = "Interface\\Icons\\Trade_Engineering",
    [333] = "Interface\\Icons\\Trade_Engraving",            -- Enchanting
    [356] = "Interface\\Icons\\Trade_Fishing",
    [393] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",      -- Skinning
    [40] = "Interface\\Icons\\Trade_BrewPoison",            -- Poisons
}

-- Name and icon of a skill line, in the client's language. spellID (the
-- profession's own spell) is the fallback when the client cannot name it.
function ns.ProfessionName(skillLine, spellID)
    local name = ns.Try(C_TradeSkillUI.GetTradeSkillDisplayName, skillLine)
    if not name or name == "" then
        local info = ns.Try(C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLine)
        name = type(info) == "table" and info.professionName or nil
    end
    if (not name or name == "") and spellID then
        name = C_Spell.GetSpellName(spellID)
    end
    return (name and name ~= "") and name or ("#" .. skillLine)
end

function ns.ProfessionIcon(skillLine, spellID)
    local icon = ns.Try(C_TradeSkillUI.GetTradeSkillTexture, skillLine)
    if not icon and spellID then
        icon = C_Spell.GetSpellTexture(spellID)
    end
    return icon or PROFESSION_ICONS[skillLine] or 134400 -- question mark
end

-- Startup ------------------------------------------------------------------

local events = CreateFrame("Frame")
ns.RegisterEvents(events, "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT")
events:SetScript("OnEvent", function(self, event, name)
    if event == "PLAYER_LOGOUT" then
        ns.Data.PackForSave(ns.db)
    elseif event == "ADDON_LOADED" and name == ADDON_NAME then
        self:UnregisterEvent("ADDON_LOADED")
        ns.Data.Load()
        if ns.db.settings.locale then
            ns.SetLocale(ns.db.settings.locale)
        end
    elseif event == "PLAYER_LOGIN" then
        -- The library first: our name, the roster, the messages and the sync.
        Lib.Start(ns)
        -- Each part starts on its own, so a failure in one (reported as a normal
        -- Lua error) does not stop the others.
        for _, init in ipairs({ ns.Scanner.Init, ns.Orders.Init, ns.OrderList.Init, ns.Deliveries.Init, ns.RosterColumn.Init,
                ns.GuildTab.Init, ns.Viewer.Init, ns.Prepare.Init, ns.BagLocks.Init }) do
            xpcall(init, geterrorhandler())
        end
    end
end)

-- Slash commands -------------------------------------------------------------

local function PrintHelp()
    ns.Print(L["/grecipes - your own professions"])
    ns.Print(L["/grecipes <name> - the professions of a guild member"])
    ns.Print(L["/grecipes status - what the addon knows and is doing"])
    ns.Print(L["/grecipes sync - ask the guild for missing data now"])
    ns.Print(L["/grecipes probe - test report for the addon's author"])
    ns.Print(L["/grecipes language [code|auto] - language of the addon's texts"])
    ns.Print(L["/grecipes debug - show the sync log in the chat"])
    ns.Print(L["/grecipes reset - forget the data of your current guild"])
end

local function PrintStatus()
    ns.Print(L["version %s. Saved data loaded by the client: %s."], ns.VERSION, ns.loadInfo.native and YES or NO)

    local guildKey = ns.Roster.guildKey
    if not guildKey then
        ns.Print(L["you are not in a guild (or the guild has not loaded yet)."])
        return
    end
    local guild = ns.Data.GetGuild(guildKey)
    local members, withRecipes = 0, 0
    for _, record in pairs(guild and guild.members or {}) do
        members = members + 1
        if ns.Data.Stats(record) > 0 then
            withRecipes = withRecipes + 1
        end
    end
    ns.Print(L["guild %s: data on %d |4member:members;, %d of them with recipes."], guildKey, members, withRecipes)

    local own = ns.Data.GetOwnRecord(false)
    for _, prof in ipairs(ns.Data.SortedProfessions(own)) do
        local state
        if prof.k == false then
            state = L["no recipes"]
        elseif prof.k == nil then
            state = L["recipes not read yet: open the profession once"]
        else
            state = L["%d |4recipe:recipes;"]:format(#prof.k)
        end
        ns.Print("  %s (%d/%d): %s", ns.ProfessionName(prof.sl, prof.lk), prof.r, prof.m, state)
    end
    ns.Print(L["sync: %s"], ns.Sync.Describe())
end

SLASH_GUILDPROFESSIONSRECIPES1 = "/grecipes"
SLASH_GUILDPROFESSIONSRECIPES2 = "/gprecipes"
SlashCmdList.GUILDPROFESSIONSRECIPES = function(message)
    message = strtrim(message or "")
    local command, rest = message:match("^(%S*)%s*(.-)$")
    local lower = command:lower()
    if lower == "" then
        ns.Viewer.Open(nil)
    elseif lower == "status" then
        PrintStatus()
    elseif lower == "sync" then
        ns.Sync.SendHello(true)
    elseif lower == "probe" then
        if rest:lower() == "ui" then
            ns.Probe.Layout()
        else
            ns.Probe.Run(rest:lower() == "burst")
        end
    elseif lower == "debug" then
        ns.debugEnabled = not ns.debugEnabled
        ns.Print(ns.debugEnabled and L["sync log on."] or L["sync log off."])
    elseif lower == "language" or lower == "lang" then
        -- A language code in any case ("dede" is deDE), or auto.
        local code
        for _, known in ipairs(ns.LOCALES) do
            if known:lower() == rest:lower() then
                code = known
            end
        end
        if not code and rest:lower() ~= "auto" then
            ns.Print(L["languages: %s, or auto for the client's."], table.concat(ns.LOCALES, ", "))
            return
        end
        ns.db.settings.locale = code
        ns.SetLocale(code)
        ns.Print(L["language set to %s. Type /reload to update every window."], ns.LOCALE)
    elseif lower == "reset" then
        if rest:lower() ~= "confirm" then
            ns.Print(L["this forgets what you know about your current guild. Type /grecipes reset confirm to do it."])
        else
            ns.Data.ResetGuild(ns.Roster.guildKey)
            ns.Print(L["data of your current guild forgotten."])
        end
    elseif lower == "help" or lower == "?" then
        PrintHelp()
    else
        -- Anything else is a member's name (WoW Forever names have spaces).
        ns.Viewer.Open(message)
    end
end

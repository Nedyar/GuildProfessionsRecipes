-- Probe.lua: /grecipes probe, a test report on the parts of the WoW Forever
-- API this addon relies on without documentation. The report opens in a
-- window to copy from; it is meant for the addon's author, so it is not
-- translated.
local _, ns = ...
local L = ns.L

local Probe = {}
ns.Probe = Probe

-- Fixed recipes to look up (vanilla IDs): Minor Healing Potion, Charred
-- Wolf Meat, Linen Bandage, Copper Bracers, Enchant Bracer - Minor Health,
-- Smelt Copper.
local SAMPLE_RECIPES = { 2330, 2538, 3275, 2663, 7418, 2657 }
local WATCHED_EVENTS = {
    "NEW_RECIPE_LEARNED", "SKILL_LINES_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "TRADE_SKILL_CLOSE",
    "GUILD_ROSTER_UPDATE", "GUILD_TRADESKILL_UPDATE", "SPELL_DATA_LOAD_RESULT",
}

local TradeSkill = C_TradeSkillUI or {}
local seenEvents = {}  -- [event] = { count, last arguments }
local pings = {}

local eventFrame = CreateFrame("Frame")
ns.RegisterEvents(eventFrame, unpack(WATCHED_EVENTS))
eventFrame:SetScript("OnEvent", function(_, event, ...)
    local entry = seenEvents[event] or { count = 0 }
    entry.count = entry.count + 1
    local args = {}
    for i = 1, math.min(select("#", ...), 4) do
        local value = ns.Plain((select(i, ...)))
        args[i] = tostring(value)
    end
    entry.args = table.concat(args, ", ")
    seenEvents[event] = entry
end)

function Probe.OnPing(text, channel, sender)
    if #pings < 50 then
        pings[#pings + 1] = ("%s via %s from %s"):format(tostring(text), tostring(channel), tostring(sender))
    end
end

-- Report building -------------------------------------------------------------

local lines

local function Add(text, ...)
    if select("#", ...) > 0 then
        local values = {}
        for i = 1, select("#", ...) do
            local value = select(i, ...)
            values[i] = type(value) == "string" and value or tostring(value)
        end
        local ok, formatted = pcall(string.format, text, unpack(values, 1, select("#", ...)))
        text = ok and formatted or (text .. " " .. table.concat(values, " "))
    end
    -- Raw links and color codes are shown as text, not rendered.
    lines[#lines + 1] = text:gsub("|", "||")
end

local function Section(title)
    lines[#lines + 1] = ""
    lines[#lines + 1] = "== " .. title
end

local function Values(...)
    local parts = {}
    for i = 1, select("#", ...) do
        local value = ns.Plain((select(i, ...)))
        parts[i] = type(value) == "table" and "{table}" or tostring(value)
    end
    return table.concat(parts, ", ")
end

local function Fields(tbl, ...)
    if type(tbl) ~= "table" then
        return tostring(tbl)
    end
    local parts = {}
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        local value = ns.Plain(tbl[key])
        parts[#parts + 1] = key .. "=" .. (type(value) == "table" and "{table}" or tostring(value))
    end
    return table.concat(parts, " ")
end

local function Has(fn)
    return type(fn) == "function" and "yes" or "MISSING"
end

local function ClientSection()
    Section("Client")
    Add("build: %s", Values(GetBuildInfo()))
    Add("locale: %s, addon %s, addon language %s", GetLocale(), ns.VERSION, ns.LOCALE)
    Add("in instance: %s, in combat: %s", Values(IsInInstance()), tostring(InCombatLockdown()))
end

local function SavedDataSection()
    Section("Saved data")
    Add("loaded by the client: %s", tostring(ns.loadInfo.native))
    local guilds, members = 0, 0
    for _, guild in pairs(ns.db.guilds) do
        guilds = guilds + 1
        for _ in pairs(guild.members) do
            members = members + 1
        end
    end
    Add("guilds: %d, member records: %d", guilds, members)
end

local function GuildSection()
    Section("Guild")
    Add("IsInGuild: %s; GetGuildInfo: %s", tostring(IsInGuild()), Values(GetGuildInfo("player")))
    Add("guild key: %s; roster ready: %s; GetNumGuildMembers: %s", tostring(ns.Roster.guildKey), tostring(ns.Roster.ready), Values(GetNumGuildMembers()))
    local read, online = 0, 0
    for _, member in pairs(ns.Roster.members) do
        read = read + 1
        if member.online then
            online = online + 1
        end
    end
    Add("roster entries read: %d, online (not mobile): %d", read, online)
    Add("we are: name=%s, messages signed %s, GUID %s; the roster matches us: %s", tostring(ns.playerName) .. " (UnitName: " .. Values(UnitName("player")) .. ")", tostring(ns.playerKey),
        tostring(ns.playerGUID), tostring(ns.Roster.GUIDOfSender(ns.playerKey) == ns.playerGUID))
    for i = 1, math.min(3, ns.Plain((GetNumGuildMembers())) or 0) do
        local name, _, _, _, _, _, _, _, isOnline, _, class, _, _, isMobile, _, _, guid = GetGuildRosterInfo(i)
        Add("  entry %d: name=%s online=%s mobile=%s class=%s guid=%s", i, Values(name), Values(isOnline), Values(isMobile), Values(class), Values(guid))
    end
end

local function ProfessionsSection()
    Section("Own professions")
    Add("GetProfessions (%d values): %s", select("#", GetProfessions()), Values(GetProfessions()))
    local indices = { GetProfessions() }
    for order = 1, select("#", GetProfessions()) do
        local index = indices[order]
        if index then
            Add("slot %d: GetProfessionInfo = %s", order, Values(GetProfessionInfo(index)))
            local _, _, _, _, _, spellOffset, skillLine = GetProfessionInfo(index)
            local info = C_SpellBook and ns.Try(C_SpellBook.GetSpellBookItemInfo, (spellOffset or 0) + 1, Enum.SpellBookSpellBank.Player)
            local spellID = type(info) == "table" and info.spellID
            Add("  spell book item: %s", Fields(info, "spellID", "actionID", "name", "itemType"))
            if spellID then
                Add("  CanTradeSkillShowCraftingUI: %s", Values(ns.Try(TradeSkill.CanTradeSkillShowCraftingUI, spellID)))
                Add("  C_Spell.GetSpellTradeSkillLink: %s", Values(ns.Try(C_Spell.GetSpellTradeSkillLink, spellID)))
            end
            Add("  GetSpellBookItemTradeSkillLink: %s", Values(C_SpellBook and ns.Try(C_SpellBook.GetSpellBookItemTradeSkillLink, (spellOffset or 0) + 1, Enum.SpellBookSpellBank.Player)))
            if skillLine then
                Add("  GetTradeSkillDisplayName: %s; GetTradeSkillTexture: %s", Values(ns.Try(TradeSkill.GetTradeSkillDisplayName, skillLine)), Values(ns.Try(TradeSkill.GetTradeSkillTexture, skillLine)))
                Add("  C_SkillInfo.GetSkillLineInfoByID: %s", Fields(ns.Try(C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID, skillLine), "skillID", "name", "rank", "maxRank", "modifier"))
            end
        end
    end
    local record = ns.Data.GetOwnRecord(false)
    for _, prof in ipairs(ns.Data.SortedProfessions(record)) do
        local state = prof.k == false and "no recipes" or prof.k == nil and "not read" or (#prof.k .. " recipes")
        local catalog = ns.Data.Catalog(prof.sl)
        Add("stored: skill line %d, %d/%d, spell %s, %s; catalog %s", prof.sl, prof.r, prof.m, tostring(prof.lk), state,
            catalog and (#catalog .. " recipes") or "none")
    end
end

local function SessionSection()
    Section("Open profession window")
    if ns.Try(TradeSkill.IsTradeSkillReady) ~= true then
        Add("(none open: open a profession window and run /grecipes probe again)")
        return
    end
    Add("ready=%s changing=%s linked=%s guild=%s guildMember=%s npc=%s",
        Values(ns.Try(TradeSkill.IsTradeSkillReady)), Values(ns.Try(TradeSkill.IsDataSourceChanging)),
        Values(ns.Try(TradeSkill.IsTradeSkillLinked)), Values(ns.Try(TradeSkill.IsTradeSkillGuild)),
        Values(ns.Try(TradeSkill.IsTradeSkillGuildMember)), Values(ns.Try(TradeSkill.IsNPCCrafting)))
    local fields = { "professionID", "parentProfessionID", "professionName", "parentProfessionName", "skillLevel", "maxSkillLevel", "profession" }
    Add("child profession: %s", Fields(ns.Try(TradeSkill.GetChildProfessionInfo), unpack(fields)))
    Add("base profession: %s", Fields(ns.Try(TradeSkill.GetBaseProfessionInfo), unpack(fields)))
    local all = ns.Try(TradeSkill.GetAllRecipeIDs)
    local filtered = ns.Try(TradeSkill.GetFilteredRecipeIDs)
    Add("GetAllRecipeIDs: %s (%s); GetFilteredRecipeIDs: %s (%s)", Has(TradeSkill.GetAllRecipeIDs), type(all) == "table" and #all or tostring(all),
        Has(TradeSkill.GetFilteredRecipeIDs), type(filtered) == "table" and #filtered or tostring(filtered))
    local learned, shown, firstCategory = 0, 0, nil
    for _, recipeID in ipairs(type(all) == "table" and all or filtered or {}) do
        local info = ns.Try(TradeSkill.GetRecipeInfo, recipeID)
        if type(info) == "table" and info.learned then
            learned = learned + 1
            if shown < 3 then
                shown = shown + 1
                Add("  recipe %d: %s", recipeID, Fields(info, "name", "learned", "categoryID", "icon", "isDummyRecipe"))
            end
            firstCategory = firstCategory or info.categoryID
        end
    end
    Add("learned: %d", learned)
    -- Spells we know that the window does not count as learned recipes.
    local phantoms = {}
    for _, recipeID in ipairs(type(all) == "table" and all or filtered or {}) do
        local info = ns.Try(TradeSkill.GetRecipeInfo, recipeID)
        if type(info) == "table" and not info.learned and ns.Try(IsPlayerSpell, recipeID) == true then
            phantoms[#phantoms + 1] = ("%d %s%s"):format(recipeID, tostring(info.name), info.isDummyRecipe and " (dummy)" or "")
        end
    end
    Add("known spells not learned in the window: %d %s", #phantoms, table.concat(phantoms, "; ", 1, math.min(#phantoms, 5)))
    if firstCategory then
        Add("GetCategoryInfo(%d): %s", firstCategory, Fields(ns.Try(TradeSkill.GetCategoryInfo, firstCategory), "categoryID", "name", "parentCategoryID", "uiOrder", "type"))
    end
    Add("GetTradeSkillListLink: %s", Values(ns.Try(TradeSkill.GetTradeSkillListLink)))
end

local function LookupSection()
    Section("Recipe lookups (any time)")
    local ids = {}
    local record = ns.Data.GetOwnRecord(false)
    for _, prof in ipairs(ns.Data.SortedProfessions(record)) do
        if type(prof.k) == "table" and prof.k[1] then
            ids[#ids + 1] = prof.k[1]
            break
        end
    end
    for _, id in ipairs(SAMPLE_RECIPES) do
        ids[#ids + 1] = id
    end
    for _, recipeID in ipairs(ids) do
        Add("recipe %d:", recipeID)
        Add("  GetRecipeInfo: %s", Fields(ns.Try(TradeSkill.GetRecipeInfo, recipeID), "name", "learned", "categoryID", "icon"))
        local schematic = ns.Try(TradeSkill.GetRecipeSchematic, recipeID, false)
        local firstReagent = type(schematic) == "table" and type(schematic.reagentSlotSchematics) == "table" and schematic.reagentSlotSchematics[1]
        Add("  GetRecipeSchematic: %s slots=%s firstReagent=%s", Fields(schematic, "name", "outputItemID", "quantityMin", "quantityMax"),
            type(schematic) == "table" and type(schematic.reagentSlotSchematics) == "table" and #schematic.reagentSlotSchematics or "-",
            firstReagent and Fields(firstReagent.reagents and firstReagent.reagents[1], "itemID") .. " x" .. tostring(firstReagent.quantityRequired) .. " type " .. tostring(firstReagent.reagentType) or "-")
        Add("  GetRecipeOutputItemData: %s", Fields(ns.Try(TradeSkill.GetRecipeOutputItemData, recipeID), "itemID", "hyperlink"))
        Add("  GetProfessionInfoByRecipeID: %s", Fields(ns.Try(TradeSkill.GetProfessionInfoByRecipeID, recipeID), "professionID", "parentProfessionID", "professionName"))
        Add("  GetTradeSkillLineForRecipe: %s", Values(ns.Try(TradeSkill.GetTradeSkillLineForRecipe, recipeID)))
        Add("  IsSpellKnown: %s; IsPlayerSpell: %s; spell name: %s", Values(ns.Try(C_SpellBook and C_SpellBook.IsSpellKnown, recipeID)), Values(ns.Try(IsPlayerSpell, recipeID)), Values(C_Spell.GetSpellName(recipeID)))
        Add("  GetRecipeLink: %s; GetSpellLink: %s", Values(ns.Try(TradeSkill.GetRecipeLink, recipeID)), Values(C_Spell.GetSpellLink(recipeID)))
    end
end

local function CommsSection(burst)
    Section("Encoding and addon messages")
    local encoding = C_EncodingUtil or {}
    Add("C_EncodingUtil: compress %s, base64 %s; CompressionMethod.Zlib = %s", Has(encoding.CompressString), Has(encoding.EncodeBase64),
        tostring(Enum.CompressionMethod and Enum.CompressionMethod.Zlib))
    local bytes = {}
    for i = 0, 255 do
        bytes[#bytes + 1] = string.char(i)
    end
    local sample = table.concat(bytes):rep(8)
    local compressed = ns.Comm.Compress(sample)
    local roundTrip = ns.Comm.Decompress(compressed)
    Add("compression: %d -> %d bytes, round trip %s", #sample, #compressed, tostring(roundTrip == sample))
    local encoded = ns.Comm.ToBase64(sample)
    Add("base64: round trip %s, same as the fallback %s", tostring(ns.Comm.FromBase64(encoded) == sample), tostring(encoded == ns.Pack.ToBase64(sample)))
    Add("prefix registered: %s; InChatMessagingLockdown: %s; AreOutgoingAddonChatMessagesRestricted: %s",
        Values(ns.Try(C_ChatInfo.IsAddonMessagePrefixRegistered, ns.PREFIX)), Values(ns.Try(C_ChatInfo.InChatMessagingLockdown)),
        Values(ns.Try(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted)))
    Add("queue: %s", ns.Sync.Describe())
    wipe(pings)
    -- Which form of our name a whisper reaches: "Name Surname" or with the realm.
    Add("ping WHISPER to %s: result %s", ns.playerName, ns.Comm.SendProbe("whisper-name", "WHISPER", ns.playerName))
    Add("ping WHISPER to %s: result %s", ns.playerKey, ns.Comm.SendProbe("whisper-name-realm", "WHISPER", ns.playerKey))
    if IsInGuild() then
        Add("ping GUILD: result %s", ns.Comm.SendProbe("guild", "GUILD"))
        if burst then
            local results = {}
            for i = 1, 12 do
                results[i] = ns.Comm.SendProbe("burst" .. i, "GUILD")
            end
            Add("burst of 12 GUILD pings: %s", table.concat(results, " "))
        end
    end
end

local function NativeGuildSection()
    Section("The game's own guild professions")
    Add("IsGuildTradeSkillsEnabled: %s", Values(ns.Try(TradeSkill.IsGuildTradeSkillsEnabled)))
    local clubID = C_Club and ns.Try(C_Club.GetGuildClubId)
    Add("guild club: %s", tostring(clubID))
    if clubID then
        local info = ns.Try(C_Club.GetMemberInfoForSelf, clubID)
        Add("own member info: %s", Fields(info, "name", "guid", "profession1ID", "profession1Rank", "profession1Name", "profession2ID", "profession2Rank", "profession2Name"))
    end
    local list = CommunitiesFrame and CommunitiesFrame.MemberList
    Add("roster frame: %s; column headers pool: %s; extra column: %s", tostring(list ~= nil),
        tostring(list and list.ColumnDisplay and list.ColumnDisplay.columnHeaders ~= nil), list and Values(ns.Try(list.GetGuildColumnIndex, list)) or "-")
end

local function EventsSection()
    Section("Events since login")
    for _, event in ipairs(WATCHED_EVENTS) do
        local entry = seenEvents[event]
        Add("%s: %s", event, entry and (entry.count .. " (last: " .. entry.args .. ")") or "0")
    end
end

local function FinishReport()
    Section("Pings received")
    if #pings == 0 then
        Add("(none)")
    end
    for _, ping in ipairs(pings) do
        Add(ping)
    end
    Section("Debug log (last 40 lines)")
    local log = ns.debugLog
    for i = math.max(1, #log - 39), #log do
        Add(log[i])
    end
end

-- Window ----------------------------------------------------------------------

local window

local function ShowReport(text)
    if not window then
        window = CreateFrame("Frame", "GuildProfessionsRecipesProbe", UIParent, "PortraitFrameTemplate")
        window:SetSize(680, 500)
        window:SetPoint("CENTER")
        window:SetFrameStrata("DIALOG")
        window:SetMovable(true)
        window:EnableMouse(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", window.StartMoving)
        window:SetScript("OnDragStop", window.StopMovingOrSizing)
        window:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Gear_01")
        window:SetTitle("Guild Professions & Recipes - probe")
        tinsert(UISpecialFrames, window:GetName())

        local hint = window:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        hint:SetPoint("TOPLEFT", 70, -36)
        hint:SetPoint("RIGHT", -20, 0)
        hint:SetJustifyH("LEFT")
        hint:SetText(L["Press Ctrl+A, then Ctrl+C, and paste the text to the addon's author."])

        local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -66)
        scroll:SetPoint("BOTTOMRIGHT", -34, 16)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(620)
        pcall(edit.SetMaxLetters, edit, 0)
        pcall(edit.SetMaxBytes, edit, 0)
        edit:SetScript("OnEscapePressed", function()
            window:Hide()
        end)
        scroll:SetScrollChild(edit)
        window.Edit = edit
    end
    window.Edit:SetText(text)
    window:Show()
    window.Edit:SetFocus()
    window.Edit:HighlightText()
end

function Probe.Run(burst)
    lines = {}
    Add("Guild Professions & Recipes probe, %s", date("%Y-%m-%d %H:%M:%S"))
    for _, section in ipairs({ ClientSection, SavedDataSection, GuildSection, ProfessionsSection, SessionSection, LookupSection, NativeGuildSection, EventsSection }) do
        local ok, err = pcall(section)
        if not ok then
            Add("!! section failed: %s", tostring(err))
        end
    end
    local ok, err = pcall(CommsSection, burst)
    if not ok then
        Add("!! section failed: %s", tostring(err))
    end
    ns.Print(L["running the probe; the report opens in a few seconds."])
    -- Pings take a moment to come back.
    C_Timer.After(3, function()
        pcall(FinishReport)
        ShowReport(table.concat(lines, "\n"))
    end)
end

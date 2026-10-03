-- RosterColumn.lua: a "Professions" column in the guild's Roster tab, with
-- one icon per profession of each member.
--
-- Blizzard's roster (CommunitiesFrame.MemberList) keeps its column layout in
-- local tables, so the column is added from the outside: after Blizzard
-- lays out the headers and each row, the Note column is made narrower and
-- the icons fill the space it gave up (or, while Blizzard shows an extra
-- column, the icons replace the Note column). Everything here only hooks
-- (hooksecurefunc) and reads Blizzard's frames, so the roster's own
-- actions (invite, promote, remove...) are left untouched.
local _, ns = ...
local L = ns.L

local RosterColumn = {}
ns.RosterColumn = RosterColumn

local ICON_SIZE = 14
local ICON_GAP = 1
local MAX_ICONS = 7
local HOLDER_WIDTH = MAX_ICONS * (ICON_SIZE + ICON_GAP) - ICON_GAP
local RIGHT_PADDING = 4
local FACTION_PADDING = 24  -- room for the faction icon of cross-faction members

local memberList
local header
local holders = setmetatable({}, { __mode = "k" })  -- row -> our icon holder
local hooked = setmetatable({}, { __mode = "k" })

local function IsGuildClub(list)
    local clubInfo = list.GetSelectedClubInfo and list:GetSelectedClubInfo()
    return ns.CanRead(clubInfo) and ns.Plain(clubInfo.clubType) == Enum.ClubType.Guild
end

-- What to show for a row's member: { sl, r, m, lk, k, native }, plus the
-- member's GUID and record. Members without the addon get what the guild
-- roster itself knows: their two main professions.
local function MemberProfessions(memberInfo)
    local guid = ns.Plain(memberInfo.guid)
    local guild = ns.Data.CurrentGuild(false)
    local record = guid and guild and guild.members[guid]
    if ns.Data.IsShareable(record) then
        return ns.Data.SortedProfessions(record), guid, record
    end
    local list = {}
    for i = 1, 2 do
        local skillLine = ns.Plain(memberInfo["profession" .. i .. "ID"])
        local rank = ns.Plain(memberInfo["profession" .. i .. "Rank"])
        if type(skillLine) == "number" and skillLine > 0 then
            -- WoW Forever reports every rank as 1 there, which is not true.
            list[#list + 1] = { sl = skillLine, r = type(rank) == "number" and rank > 1 and rank or nil, native = true }
        end
    end
    return list, guid
end

-- Tooltip and click ------------------------------------------------------------

local function IconOnEnter(button)
    local prof = button.prof
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    local name = ns.ProfessionName(prof.sl, prof.lk)
    GameTooltip:SetText(prof.r and ("%s (%d)"):format(name, prof.r) or name, 1, 1, 1)
    if prof.native then
        GameTooltip:AddLine(L["This member does not share recipes (Guild Recipes is not installed)."], 0.7, 0.7, 0.7, true)
    else
        if prof.m and prof.m > 0 then
            GameTooltip:AddLine(L["Skill %d/%d"]:format(prof.r, prof.m), NORMAL_FONT_COLOR:GetRGB())
        end
        if type(prof.k) == "table" then
            GameTooltip:AddLine(L["%d |4recipe:recipes;"]:format(#prof.k), 1, 1, 1)
            GameTooltip:AddLine(L["Click to see the recipes."], GREEN_FONT_COLOR:GetRGB())
        elseif prof.k == nil then
            GameTooltip:AddLine(L["Recipes not shared yet: this member has to open the profession once."], 0.7, 0.7, 0.7, true)
        end
        if button.record then
            GameTooltip:AddLine(L["Updated %s ago"]:format(ns.Ago(button.record.t)), 0.6, 0.6, 0.6)
        end
    end
    GameTooltip:Show()
end

local function IconOnClick(button)
    if type(button.prof.k) == "table" and button.key then
        ns.Viewer.OpenMember(button.key, button.prof.sl)
    end
end

local function CreateHolder(row)
    local holder = CreateFrame("Frame", nil, row)
    holder:SetSize(HOLDER_WIDTH, ICON_SIZE)
    holder.icons = {}
    for i = 1, MAX_ICONS do
        local button = CreateFrame("Button", nil, holder)
        button:SetSize(ICON_SIZE, ICON_SIZE)
        button:SetPoint("LEFT", (i - 1) * (ICON_SIZE + ICON_GAP), 0)
        button.Icon = button:CreateTexture(nil, "ARTWORK")
        button.Icon:SetAllPoints()
        button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnEnter", IconOnEnter)
        button:SetScript("OnLeave", GameTooltip_Hide)
        button:SetScript("OnClick", IconOnClick)
        holder.icons[i] = button
    end
    holders[row] = holder
    return holder
end

-- Rows -------------------------------------------------------------------------

-- Runs after Blizzard refreshes a row's columns. Without an extra column the
-- icons sit at the right end and the Note column ends where they begin.
-- While Blizzard shows an extra column (achievement points...), it fills that
-- space, so the icons take the Note column's place instead.
local function UpdateRow(row)
    local holder = holders[row]
    local memberInfo = row.GetMemberInfo and row:GetMemberInfo()
    local show = row.expanded and not row.isInvitation and ns.CanRead(memberInfo)
        and not (row.ProfessionHeader and row.ProfessionHeader:IsShown()) and IsGuildClub(memberList)
    if not show then
        if holder then
            holder:Hide()
            if holder.noteMoved and row.guildColumnIndex == nil then
                -- Back to Blizzard's own layout for a roster without an extra column.
                row.Note:SetPoint("RIGHT", row, "RIGHT", -RIGHT_PADDING, 0)
                holder.noteMoved = false
            end
        end
        return
    end

    holder = holder or CreateHolder(row)
    holder:ClearAllPoints()
    if row.guildColumnIndex ~= nil then
        holder:SetPoint("LEFT", row.Rank, "RIGHT", 8, 0)
        row.Note:Hide()
    else
        local padding = (row.FactionButton and row.FactionButton:IsShown()) and FACTION_PADDING or RIGHT_PADDING
        holder:SetPoint("RIGHT", row, "RIGHT", -padding, 0)
        row.Note:SetPoint("RIGHT", holder, "LEFT", -4, 0)
        holder.noteMoved = true
    end

    local professions, key, record = MemberProfessions(memberInfo)
    for i, button in ipairs(holder.icons) do
        local prof = professions[i]
        if prof then
            button.prof, button.key, button.record = prof, key, record
            button.Icon:SetTexture(ns.ProfessionIcon(prof.sl, prof.lk))
            -- Faded: nothing to open (no recipes known, or not our data).
            local openable = type(prof.k) == "table"
            button.Icon:SetDesaturated(prof.native or prof.k == nil)
            button.Icon:SetAlpha((openable or prof.k == false) and 1 or 0.6)
            button:Show()
        else
            button.prof, button.key, button.record = nil, nil, nil
            button:Hide()
        end
    end
    holder:Show()
end

local function HookRow(row)
    if hooked[row] or not row.RefreshExpandedColumns then
        return
    end
    hooked[row] = true
    -- Every path that redraws a row (new member, expanded, extra column,
    -- roster update) ends in RefreshExpandedColumns.
    hooksecurefunc(row, "RefreshExpandedColumns", UpdateRow)
end

-- Header -------------------------------------------------------------------------

local function UpdateHeader(list)
    local columns = list.ColumnDisplay
    if not columns then
        return
    end
    if not header then
        header = CreateFrame("Button", nil, columns, "ColumnDisplayButtonNoScriptsTemplate")
        header:SetWidth(HOLDER_WIDTH + 2 * RIGHT_PADDING + 4)
        header:SetPoint("BOTTOMRIGHT", columns, "BOTTOMRIGHT", -28, 1)
        header:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L["Professions"], 1, 1, 1)
            GameTooltip:AddLine(L["Shared by Guild Recipes. Point at an icon for the skill, click it for the recipes."], nil, nil, nil, true)
            GameTooltip:Show()
        end)
        header:SetScript("OnLeave", GameTooltip_Hide)
    end
    header:SetText(L["Professions"])
    local show = list.expandedDisplay and columns:IsShown() and IsGuildClub(list)
    header:SetShown(show)
    if not show or not columns.columnHeaders then
        return
    end
    -- Blizzard's Note header is the last of its regular columns.
    local noteID = type(list.columnInfo) == "table" and #list.columnInfo or 6
    local note
    for other in columns.columnHeaders:EnumerateActive() do
        if other:GetID() == noteID then
            note = other
        end
    end
    header:ClearAllPoints()
    if not note then
        header:SetPoint("BOTTOMRIGHT", columns, "BOTTOMRIGHT", -28, 1)
    elseif list:GetGuildColumnIndex() ~= nil then
        -- An extra column is shown: our header takes the Note header's place.
        header:SetPoint("BOTTOMLEFT", note, "BOTTOMLEFT")
        header:SetPoint("BOTTOMRIGHT", note, "BOTTOMRIGHT")
        note:Hide()
    else
        -- The Note header stretches to the right edge; it now stops where
        -- ours begins.
        header:SetWidth(HOLDER_WIDTH + 2 * RIGHT_PADDING + 4)
        header:SetPoint("BOTTOMRIGHT", columns, "BOTTOMRIGHT", -28, 1)
        note:SetPoint("BOTTOMRIGHT", header, "BOTTOMLEFT", 2, 0)
    end
end

-- Setup --------------------------------------------------------------------------

local function RefreshVisible()
    if memberList and CommunitiesFrame:IsVisible() then
        memberList.ScrollBox:ForEachFrame(UpdateRow)
    end
end

local function Setup()
    if memberList or not (CommunitiesFrame and CommunitiesFrame.MemberList and CommunitiesFrame.MemberList.ScrollBox) then
        return
    end
    memberList = CommunitiesFrame.MemberList
    hooksecurefunc(memberList, "RefreshLayout", UpdateHeader)
    ScrollUtil.AddAcquiredFrameCallback(memberList.ScrollBox, function(_, row)
        HookRow(row)
    end, RosterColumn, false)
    memberList.ScrollBox:ForEachFrame(function(row)
        HookRow(row)
        UpdateRow(row)
    end)
    UpdateHeader(memberList)

    local function Refresh()
        ns.Debounce("RosterColumnRefresh", 0.3, RefreshVisible)
    end
    ns.On("DataChanged", Refresh)
    ns.On("RosterUpdated", Refresh)
end

function RosterColumn.Init()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Communities", Setup)
end

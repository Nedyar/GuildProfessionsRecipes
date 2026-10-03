-- Viewer.lua: a profession window for any guild member, drawn from the saved
-- data, so it works while that member is offline.
--
-- Recipes are stored as IDs only; names, icons, reagents and categories are
-- looked up on this client, in its own language. Lookups the client cannot
-- answer yet (data not cached) are requested and the window redraws when
-- they arrive.
local _, ns = ...
local L = ns.L

local Viewer = {}
ns.Viewer = Viewer

local WIDTH, HEIGHT = 760, 540
local LIST_WIDTH = 310
local ROW_HEIGHT = 18
local MAX_REAGENTS = 10
local MAX_TABS = 8
local MAX_KNOWN_BY = 12
local UNKNOWN_ICON = 134400

local TradeSkill = C_TradeSkillUI or {}
local REAGENT_BASIC = Enum.CraftingReagentType and Enum.CraftingReagentType.Basic or 1

local frame
local state = { key = nil, skillLine = nil, recipeID = nil, search = "" }
local collapsed = {}   -- [group key] = true
local recipeInfo = {}  -- [recipeID] = resolved name, icon, item...
local requested = {}   -- [recipeID] = true once its spell data was asked for

-- Recipe data ----------------------------------------------------------------

local function ResolveRecipe(recipeID)
    local info = recipeInfo[recipeID]
    if info and info.name then
        return info
    end
    info = info or {}
    local recipe = ns.Try(TradeSkill.GetRecipeInfo, recipeID)
    if type(recipe) == "table" and type(recipe.name) == "string" and recipe.name ~= "" then
        info.name, info.icon, info.categoryID = recipe.name, recipe.icon, recipe.categoryID
    end
    local schematic = ns.Try(TradeSkill.GetRecipeSchematic, recipeID, false)
    if type(schematic) == "table" then
        info.schematic = schematic
        if not info.name and type(schematic.name) == "string" and schematic.name ~= "" then
            info.name = schematic.name
        end
        info.icon = info.icon or schematic.icon
        if schematic.outputItemID and schematic.outputItemID > 0 then
            info.itemID = schematic.outputItemID
        end
    end
    if not info.itemID then
        local output = ns.Try(TradeSkill.GetRecipeOutputItemData, recipeID)
        if type(output) == "table" and output.itemID and output.itemID > 0 then
            info.itemID = output.itemID
            info.icon = info.icon or output.icon
        end
    end
    if not info.name then
        -- Recipes are spells: the spell's name is the recipe's.
        info.name = C_Spell.GetSpellName(recipeID)
        if not info.name and not requested[recipeID] then
            requested[recipeID] = true
            C_Spell.RequestLoadSpellData(recipeID)
        end
    end
    if info.itemID then
        info.icon = info.icon or C_Item.GetItemIconByID(info.itemID)
        info.quality = C_Item.GetItemQualityByID(info.itemID)
        if not info.quality then
            C_Item.RequestLoadItemDataByID(info.itemID)
        end
    end
    info.icon = info.icon or C_Spell.GetSpellTexture(recipeID)
    recipeInfo[recipeID] = info
    return info
end

local function DisplayName(recipeID, info)
    return info.name or L["Recipe #%d"]:format(recipeID)
end

local function ColoredName(recipeID, info)
    local name = DisplayName(recipeID, info)
    if info.quality then
        local _, _, _, hex = C_Item.GetItemQualityColor(info.quality)
        if hex then
            return "|c" .. hex .. name .. "|r"
        end
    end
    return name
end

-- The group a recipe is listed under: its profession category when known,
-- else the kind of item it makes. Returns key, name, order.
local function GroupOf(recipeID, info)
    local cache = ns.db.cache
    local categoryID = info.categoryID or cache.recCat[recipeID]
    if categoryID and categoryID > 0 then
        local categories = cache.cats[ns.CLIENT_LOCALE]
        local category = categories and categories[categoryID]
        if not category then
            local live = ns.Try(TradeSkill.GetCategoryInfo, categoryID)
            if type(live) == "table" and type(live.name) == "string" and live.name ~= "" then
                category = { n = live.name, u = live.uiOrder }
                cache.cats[ns.CLIENT_LOCALE] = categories or {}
                cache.cats[ns.CLIENT_LOCALE][categoryID] = category
            end
        end
        if category then
            return "c" .. categoryID, category.n, category.u or 500
        end
    end
    if info.itemID then
        local _, _, subType, _, _, classID, subclassID = C_Item.GetItemInfoInstant(info.itemID)
        if subType and subType ~= "" then
            return ("i%d-%d"):format(classID or 0, subclassID or 0), subType, 1000
        end
    end
    return "other", L["Other"], 2000
end

local function Contains(list, value)
    local low, high = 1, #list
    while low <= high do
        local mid = math.floor((low + high) / 2)
        if list[mid] == value then
            return true
        elseif list[mid] < value then
            low = mid + 1
        else
            high = mid - 1
        end
    end
    return false
end

local function CurrentRecord()
    local guild = ns.Data.CurrentGuild(false)
    return guild and state.key and guild.members[state.key]
end

local function CurrentProfession()
    local record = CurrentRecord()
    return record and state.skillLine and record.p[state.skillLine]
end

-- Professions of a record that have a recipe list, in display order.
local function ListedProfessions(record)
    local list = {}
    for _, prof in ipairs(ns.Data.SortedProfessions(record)) do
        if type(prof.k) == "table" then
            list[#list + 1] = prof
        end
    end
    return list
end

local function RecipeLink(recipeID)
    local link = ns.Try(TradeSkill.GetRecipeLink, recipeID) or C_Spell.GetSpellLink(recipeID)
    local info = recipeInfo[recipeID]
    if not link and info and info.itemID then
        link = select(2, C_Item.GetItemInfo(info.itemID))
    end
    return link
end

local function InsertLink(link)
    if not link then
        return
    end
    if ChatFrameUtil and ChatFrameUtil.InsertLink then
        ChatFrameUtil.InsertLink(link)
    elseif ChatEdit_InsertLink then
        ChatEdit_InsertLink(link)
    end
end

local function ShowRecipeTooltip(owner, recipeID)
    local info = ResolveRecipe(recipeID)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if info.itemID then
        GameTooltip:SetItemByID(info.itemID)
    else
        GameTooltip:SetSpellByID(recipeID)
    end
    GameTooltip:Show()
end

-- Recipe list -------------------------------------------------------------------

local Refresh

local function BuildList(prof)
    local groups, byKey = {}, {}
    local search = state.search:lower()
    local shown = 0
    for _, recipeID in ipairs(prof.k) do
        local info = ResolveRecipe(recipeID)
        local name = DisplayName(recipeID, info)
        if search == "" or name:lower():find(search, 1, true) then
            local key, groupName, order = GroupOf(recipeID, info)
            local group = byKey[key]
            if not group then
                group = { key = key, name = groupName, order = order, recipes = {} }
                byKey[key] = group
                groups[#groups + 1] = group
            end
            table.insert(group.recipes, { recipeID = recipeID, info = info, name = name })
            shown = shown + 1
        end
    end
    table.sort(groups, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.name < b.name
    end)
    local elements = {}
    for _, group in ipairs(groups) do
        table.sort(group.recipes, function(a, b)
            return a.name < b.name
        end)
        -- While searching every group stays open.
        local isCollapsed = collapsed[group.key] and search == ""
        elements[#elements + 1] = { header = true, key = group.key, name = group.name, count = #group.recipes, collapsed = isCollapsed }
        if not isCollapsed then
            for _, recipe in ipairs(group.recipes) do
                elements[#elements + 1] = recipe
            end
        end
    end
    return elements, shown
end

local function RowOnClick(row)
    local data = row.data
    if data.header then
        collapsed[data.key] = not collapsed[data.key] or nil
        Refresh(true)
        return
    end
    if IsModifiedClick("CHATLINK") then
        InsertLink(RecipeLink(data.recipeID))
        return
    end
    state.recipeID = data.recipeID
    Refresh(true)
end

local function RowOnEnter(row)
    if row.data and not row.data.header then
        ShowRecipeTooltip(row, row.data.recipeID)
    end
end

local function InitRow(row, data)
    if not row.Text then
        row:SetHeight(ROW_HEIGHT)
        row:RegisterForClicks("LeftButtonUp")
        row.Selected = row:CreateTexture(nil, "BACKGROUND")
        row.Selected:SetAllPoints()
        row.Selected:SetColorTexture(1, 0.82, 0, 0.2)
        row.Highlight = row:CreateTexture(nil, "HIGHLIGHT")
        row.Highlight:SetAllPoints()
        row.Highlight:SetColorTexture(1, 1, 1, 0.08)
        row.Toggle = row:CreateTexture(nil, "ARTWORK")
        row.Toggle:SetSize(14, 14)
        row.Toggle:SetPoint("LEFT", 2, 0)
        row.Icon = row:CreateTexture(nil, "ARTWORK")
        row.Icon:SetSize(16, 16)
        row.Icon:SetPoint("LEFT", 14, 0)
        row.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.Text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.Text:SetJustifyH("LEFT")
        row.Text:SetWordWrap(false)
        row.Text:SetPoint("RIGHT", -4, 0)
        row:SetScript("OnClick", RowOnClick)
        row:SetScript("OnEnter", RowOnEnter)
        row:SetScript("OnLeave", GameTooltip_Hide)
    end
    row.data = data
    row.Text:ClearAllPoints()
    row.Text:SetPoint("RIGHT", -4, 0)
    if data.header then
        row.Icon:Hide()
        row.Selected:Hide()
        row.Toggle:Show()
        row.Toggle:SetTexture(data.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
        row.Text:SetFontObject(GameFontNormal)
        row.Text:SetPoint("LEFT", row.Toggle, "RIGHT", 4, 0)
        row.Text:SetText(("%s (%d)"):format(data.name, data.count))
    else
        row.Toggle:Hide()
        row.Icon:Show()
        row.Icon:SetTexture(data.info.icon or UNKNOWN_ICON)
        row.Selected:SetShown(data.recipeID == state.recipeID)
        row.Text:SetFontObject(GameFontHighlightSmall)
        row.Text:SetPoint("LEFT", row.Icon, "RIGHT", 4, 0)
        row.Text:SetText(ColoredName(data.recipeID, data.info))
    end
end

-- Detail pane ---------------------------------------------------------------------

local function ShowReagents(detail, recipeID, info)
    local schematic = info.schematic
    local reagents = {}
    if schematic and type(schematic.reagentSlotSchematics) == "table" then
        for _, slot in ipairs(schematic.reagentSlotSchematics) do
            local reagent = slot.reagents and slot.reagents[1]
            if reagent and reagent.itemID and (slot.reagentType == nil or slot.reagentType == REAGENT_BASIC) then
                reagents[#reagents + 1] = { itemID = reagent.itemID, quantity = slot.quantityRequired or 1 }
            end
        end
    end
    detail.ReagentsTitle:SetShown(#reagents > 0)
    detail.NoReagents:SetShown(schematic == nil)
    for i, row in ipairs(detail.reagents) do
        local reagent = reagents[i]
        if reagent then
            row.itemID = reagent.itemID
            row.Icon:SetTexture(C_Item.GetItemIconByID(reagent.itemID) or UNKNOWN_ICON)
            local function SetName()
                if state.recipeID ~= recipeID then
                    return
                end
                local name = C_Item.GetItemNameByID(reagent.itemID) or RETRIEVING_ITEM_INFO or "..."
                row.Text:SetText(("%d x %s"):format(reagent.quantity, name))
            end
            SetName()
            if not C_Item.GetItemNameByID(reagent.itemID) then
                Item:CreateFromItemID(reagent.itemID):ContinueOnItemLoad(SetName)
            end
            row:Show()
        else
            row.itemID = nil
            row:Hide()
        end
    end
end

-- Other members of the guild who know the recipe.
local function KnownBy(recipeID)
    local guild = ns.Data.CurrentGuild(false)
    local names = {}
    for key, record in pairs(guild and guild.members or {}) do
        local prof = key ~= state.key and record.p[state.skillLine]
        if prof and type(prof.k) == "table" and Contains(prof.k, recipeID) then
            names[#names + 1] = ns.Data.NameOf(key, record)
        end
    end
    table.sort(names)
    local count = #names
    if count > MAX_KNOWN_BY then
        for i = count, MAX_KNOWN_BY + 1, -1 do
            names[i] = nil
        end
        names[#names + 1] = L["and %d more"]:format(count - MAX_KNOWN_BY)
    end
    return names
end

local function UpdateDetail()
    local detail = frame.Detail
    local recipeID = state.recipeID
    if not recipeID then
        detail.Content:Hide()
        detail.Empty:Show()
        return
    end
    detail.Empty:Hide()
    detail.Content:Show()
    local info = ResolveRecipe(recipeID)
    detail.Icon.Texture:SetTexture(info.icon or UNKNOWN_ICON)
    detail.Name:SetText(ColoredName(recipeID, info))
    local schematic = info.schematic
    local subText = ""
    if schematic and schematic.quantityMax and schematic.quantityMax > 1 then
        if schematic.quantityMin ~= schematic.quantityMax then
            subText = L["Creates %d-%d"]:format(schematic.quantityMin, schematic.quantityMax)
        else
            subText = L["Creates %d"]:format(schematic.quantityMax)
        end
    end
    detail.Sub:SetText(subText)
    ShowReagents(detail, recipeID, info)
    local names = KnownBy(recipeID)
    detail.KnownBy:SetText(#names > 0 and L["Also known by: %s"]:format(table.concat(names, ", ")) or L["Nobody else in the guild is known to have this recipe."])
end

-- Header, tabs ---------------------------------------------------------------------

local function UpdateHeader(record, prof)
    local name = ns.ProfessionName(state.skillLine, prof.lk)
    frame:SetPortraitToAsset(ns.ProfessionIcon(state.skillLine, prof.lk))
    frame:SetTitle(("%s - %s"):format(ns.Data.NameOf(state.key, record), name))
    frame.SkillBar:SetMinMaxValues(0, math.max(prof.m, 1))
    frame.SkillBar:SetValue(prof.r)
    frame.SkillBar.Text:SetText(("%s %d/%d"):format(name, prof.r, prof.m))
    local source = state.key == ns.playerGUID and L["your own data"] or (record.fh and L["from the member"] or L["passed on by the guild"])
    frame.Updated:SetText(L["Updated %s ago"]:format(ns.Ago(record.t)) .. " (" .. source .. ")")
    local online = state.key == ns.playerGUID or ns.Roster.IsOnline(state.key)
    frame.LiveButton:SetEnabled(online)
end

local function UpdateTabs(record)
    local professions = ListedProfessions(record)
    frame.Tabs = frame.Tabs or {}
    for i = 1, math.min(#professions, MAX_TABS) do
        local tab = frame.Tabs[i]
        if not tab then
            tab = CreateFrame("Button", nil, frame, "PanelTabButtonTemplate")
            tab:SetID(i)
            if i == 1 then
                tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 11, 2)
            end
            tab:SetScript("OnClick", function(self)
                PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
                state.skillLine, state.recipeID = self.skillLine, nil
                Refresh()
            end)
            frame.Tabs[i] = tab
        end
        local prof = professions[i]
        tab.skillLine = prof.sl
        tab:SetText(ns.ProfessionName(prof.sl, prof.lk))
        tab:Show()
        PanelTemplates_TabResize(tab, 0)
        if prof.sl == state.skillLine then
            frame.selectedTab = i
        end
    end
    for i = #professions + 1, #frame.Tabs do
        frame.Tabs[i]:Hide()
    end
    PanelTemplates_SetNumTabs(frame, math.min(#professions, MAX_TABS))
    PanelTemplates_UpdateTabs(frame)
end

-- keepScroll: redraw in place (selection, data arriving) instead of a new view.
function Refresh(keepScroll)
    if not frame or not frame:IsShown() then
        return
    end
    local record = CurrentRecord()
    local prof = CurrentProfession()
    if not record or type(prof and prof.k) ~= "table" then
        -- The data changed under us: pick another profession, or close.
        local professions = record and ListedProfessions(record) or {}
        if #professions == 0 then
            frame:Hide()
            return
        end
        state.skillLine, state.recipeID = professions[1].sl, nil
        prof = record.p[state.skillLine]
    end
    UpdateHeader(record, prof)
    UpdateTabs(record)
    local elements, shown = BuildList(prof)
    frame.Count:SetText(L["%d of %d |4recipe:recipes;"]:format(shown, #prof.k))
    local provider = CreateDataProvider(elements)
    if keepScroll and ScrollBoxConstants then
        frame.ScrollBox:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
    else
        frame.ScrollBox:SetDataProvider(provider)
    end
    UpdateDetail()
end

-- The window ----------------------------------------------------------------------

local function SavePosition()
    local point, _, relativePoint, x, y = frame:GetPoint()
    ns.db.settings.viewer = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function RestorePosition()
    frame:ClearAllPoints()
    local saved = ns.db.settings.viewer
    if type(saved) == "table" and type(saved.point) == "string" and type(saved.x) == "number" and type(saved.y) == "number" then
        frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x, saved.y)
    else
        frame:SetPoint("CENTER")
    end
end

local function OpenLive()
    local record, prof = CurrentRecord(), CurrentProfession()
    if not record or not prof then
        return
    end
    if state.key == ns.playerGUID then
        ns.Try(TradeSkill.OpenTradeSkill, state.skillLine)
        return
    end
    if ns.Try(TradeSkill.IsGuildTradeSkillsEnabled) then
        ns.Try(C_GuildInfo.QueryGuildMemberRecipes, state.key, state.skillLine)
        return
    end
    if prof.lk then
        -- Built here from checked values; links are never taken from other clients.
        local inner = ("trade:%s:%d:%d"):format(state.key, prof.lk, state.skillLine)
        local text = ("|cffffd000|H%s|h[%s]|h|r"):format(inner, ns.ProfessionName(state.skillLine, prof.lk))
        ns.Try(SetItemRef, inner, text, "LeftButton")
    end
end

local function CreateWindow()
    frame = CreateFrame("Frame", "GuildRecipesViewer", UIParent, "PortraitFrameTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    frame:Hide()
    tinsert(UISpecialFrames, frame:GetName())
    RestorePosition()

    -- Skill bar and data age.
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetPoint("TOPLEFT", 70, -32)
    bar:SetSize(300, 16)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.1, 0.5, 0.9)
    bar.Background = bar:CreateTexture(nil, "BACKGROUND")
    bar.Background:SetAllPoints()
    bar.Background:SetColorTexture(0, 0, 0, 0.5)
    bar.Text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.Text:SetPoint("CENTER")
    frame.SkillBar = bar

    frame.Updated = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    frame.Updated:SetPoint("TOPRIGHT", -16, -36)
    frame.Updated:SetJustifyH("RIGHT")

    local live = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    live:SetPoint("TOPRIGHT", -12, -56)
    live:SetText(L["View live"])
    live:SetSize(math.max(120, live:GetTextWidth() + 24), 22)
    live:SetScript("OnClick", OpenLive)
    live:SetMotionScriptsWhileDisabled(true)
    live:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["View live"], 1, 1, 1)
        GameTooltip:AddLine(L["Opens the game's own profession window for this member. Only while they are online."], nil, nil, nil, true)
        GameTooltip:Show()
    end)
    live:SetScript("OnLeave", GameTooltip_Hide)
    frame.LiveButton = live

    -- Search and recipe list.
    local search = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    search:SetSize(LIST_WIDTH - 10, 20)
    search:SetPoint("TOPLEFT", 20, -60)
    search:HookScript("OnTextChanged", function(self)
        state.search = self:GetText() or ""
        ns.Debounce("ViewerSearch", 0.2, Refresh)
    end)
    frame.Search = search

    local listInset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    listInset:SetPoint("TOPLEFT", 12, -86)
    listInset:SetPoint("BOTTOMLEFT", 12, 26)
    listInset:SetWidth(LIST_WIDTH)

    local scrollBox = CreateFrame("Frame", nil, listInset, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", 4, -4)
    scrollBox:SetPoint("BOTTOMRIGHT", -20, 4)
    local scrollBar = CreateFrame("EventFrame", nil, listInset, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Button", InitRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    frame.ScrollBox = scrollBox

    frame.Count = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    frame.Count:SetPoint("BOTTOMLEFT", 18, 10)

    -- Detail pane.
    local detail = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    detail:SetPoint("TOPLEFT", listInset, "TOPRIGHT", 6, 0)
    detail:SetPoint("BOTTOMRIGHT", -12, 26)
    frame.Detail = detail

    detail.Empty = detail:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    detail.Empty:SetPoint("CENTER")
    detail.Empty:SetText(L["Select a recipe."])

    local content = CreateFrame("Frame", nil, detail)
    content:SetAllPoints()
    detail.Content = content

    local icon = CreateFrame("Button", nil, content)
    icon:SetSize(40, 40)
    icon:SetPoint("TOPLEFT", 14, -14)
    icon.Texture = icon:CreateTexture(nil, "ARTWORK")
    icon.Texture:SetAllPoints()
    icon:SetScript("OnEnter", function(self)
        if state.recipeID then
            ShowRecipeTooltip(self, state.recipeID)
        end
    end)
    icon:SetScript("OnLeave", GameTooltip_Hide)
    icon:SetScript("OnClick", function()
        if state.recipeID and IsModifiedClick("CHATLINK") then
            InsertLink(RecipeLink(state.recipeID))
        end
    end)
    detail.Icon = icon

    detail.Name = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    detail.Name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    detail.Name:SetPoint("RIGHT", -14, 0)
    detail.Name:SetJustifyH("LEFT")

    detail.Sub = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail.Sub:SetPoint("TOPLEFT", detail.Name, "BOTTOMLEFT", 0, -4)

    detail.ReagentsTitle = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    detail.ReagentsTitle:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -16)
    detail.ReagentsTitle:SetText(L["Reagents:"])

    detail.NoReagents = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    detail.NoReagents:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -16)
    detail.NoReagents:SetPoint("RIGHT", -14, 0)
    detail.NoReagents:SetJustifyH("LEFT")
    detail.NoReagents:SetText(L["The game gives no reagents for this recipe here; point at the icon for its details."])

    detail.reagents = {}
    for i = 1, MAX_REAGENTS do
        local row = CreateFrame("Button", nil, content)
        row:SetSize(300, 22)
        row:SetPoint("TOPLEFT", detail.ReagentsTitle, "BOTTOMLEFT", 4, -6 - (i - 1) * 24)
        row.Icon = row:CreateTexture(nil, "ARTWORK")
        row.Icon:SetSize(20, 20)
        row.Icon:SetPoint("LEFT")
        row.Text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.Text:SetPoint("LEFT", row.Icon, "RIGHT", 6, 0)
        row.Text:SetPoint("RIGHT")
        row.Text:SetJustifyH("LEFT")
        row:SetScript("OnEnter", function(self)
            if self.itemID then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(self.itemID)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
        detail.reagents[i] = row
    end

    detail.KnownBy = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail.KnownBy:SetPoint("BOTTOMLEFT", 14, 14)
    detail.KnownBy:SetPoint("RIGHT", -14, 0)
    detail.KnownBy:SetJustifyH("LEFT")
    detail.KnownBy:SetSpacing(2)

    frame:SetScript("OnHide", function()
        GameTooltip_Hide()
    end)
end

-- Opens the window on a member, by GUID. skillLine: the profession to show
-- first (any listed one otherwise).
function Viewer.OpenMember(guid, skillLine)
    local guild = ns.Data.CurrentGuild(false)
    if not guild then
        ns.Print(L["you are not in a guild (or the guild has not loaded yet)."])
        return
    end
    local key = guid
    local record = guild.members[key]
    if not ns.Data.IsShareable(record) then
        ns.Print(L["no data on %s yet."], ns.Data.NameOf(key))
        return
    end
    local professions = ListedProfessions(record)
    if #professions == 0 then
        if key == ns.playerGUID then
            ns.Print(L["none of your recipes have been read yet: open each profession window once."])
        else
            ns.Print(L["%s has not shared any recipes yet."], ns.Data.NameOf(key, record))
        end
        return
    end
    if not frame then
        CreateWindow()
    end
    local chosen = professions[1].sl
    for _, prof in ipairs(professions) do
        if prof.sl == skillLine then
            chosen = skillLine
        end
    end
    if state.key ~= key or state.skillLine ~= chosen then
        state.recipeID = nil
    end
    state.key, state.skillLine = key, chosen
    frame.Search:SetText("")
    state.search = ""
    frame:Show()
    Refresh()
end

-- name: what the user typed ("Name", "name", "Name-Realm"), or nil for our
-- own professions.
function Viewer.Open(name)
    if not name or strtrim(name) == "" then
        Viewer.OpenMember(ns.playerGUID)
        return
    end
    local guid = ns.Data.FindByName(ns.Data.CurrentGuild(false), name)
    if not guid then
        ns.Print(L["no data on %s yet."], strtrim(name))
        return
    end
    Viewer.OpenMember(guid)
end

function Viewer.Init()
    local events = CreateFrame("Frame")
    ns.RegisterEvents(events, "ITEM_DATA_LOAD_RESULT", "SPELL_DATA_LOAD_RESULT")
    events:SetScript("OnEvent", function(_, event, id)
        if event == "SPELL_DATA_LOAD_RESULT" then
            -- Only spells we asked for; each is asked for once.
            if not requested[id] then
                return
            end
            recipeInfo[id] = nil
        end
        if frame and frame:IsShown() then
            ns.Debounce("ViewerData", 0.3, function()
                -- Items that just loaded may change names and colors.
                for _, info in pairs(recipeInfo) do
                    if info.itemID and not info.quality then
                        info.quality = C_Item.GetItemQualityByID(info.itemID)
                    end
                end
                Refresh(true)
            end)
        end
    end)
    ns.On("DataChanged", function()
        if frame and frame:IsShown() then
            ns.Debounce("ViewerData", 0.3, function()
                Refresh(true)
            end)
        end
    end)
end

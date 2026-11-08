-- GuildTab.lua: a "Recipes & Orders" tab on the guild window, under
-- Blizzard's own side tabs (Chat, Roster, Guild Info...). Its subtabs:
--   - Professions: every profession as a button. Those whose recipes some
--     member has shared open the recipe window on all of them; the others
--     are disabled.
--   - Pending orders, Order list and Requested orders: crafting orders
--     (OrderList.lua, Orders.lua).
--
-- Like the roster column, it only hooks and reads Blizzard's frames. It never
-- changes the guild window's display mode, which would taint the window.
-- Instead, it makes Blizzard's view invisible while its panel is open, and
-- closes as soon as one of Blizzard's tabs is clicked.
local _, ns = ...
local L = ns.L

local GuildTab = {}
ns.GuildTab = GuildTab

local ICON = "Interface\\Icons\\INV_Scroll_03"
local TAB_GAP = 20          -- between Blizzard's tabs
local TAB_LEVEL = 510       -- Blizzard's tabs' frame level
local PAGE_LEVEL = 1250     -- over everything in the content (the chat's edit box is at 1200)
local BUTTON_WIDTH, BUTTON_HEIGHT, BUTTON_GAP = 190, 46, 6
local COLUMNS = 3
local CARD_BAND_CENTER = 0.45  -- where on the profession's card art the button's band is cut
-- Blizzard's tabs, top to bottom.
local BLIZZARD_TABS = { "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab", "GuildPreferredPlaySettingsTab" }

-- Every profession of WoW Forever, with its spell: the client names it in
-- its own language even when nobody in the guild has it.
local PRIMARY = {
    { sl = 171, spell = 2259 }, -- Alchemy
    { sl = 164, spell = 2018 }, -- Blacksmithing
    { sl = 333, spell = 7411 }, -- Enchanting
    { sl = 202, spell = 4036 }, -- Engineering
    { sl = 182, spell = 2366 }, -- Herbalism
    { sl = 165, spell = 2108 }, -- Leatherworking
    { sl = 186, spell = 2575 }, -- Mining
    { sl = 393, spell = 8613 }, -- Skinning
    { sl = 197, spell = 3908 }, -- Tailoring
}
local SECONDARY = {
    { sl = 185, spell = 2550 }, -- Cooking
    { sl = 129, spell = 3273 }, -- First Aid
    { sl = 356, spell = 7620 }, -- Fishing
}

local communities, tab, page
local remembered     -- the Blizzard tab that was selected when our panel opened
local hiddenChatBar  -- the chat's scroll bar, while our panel hides it
local faded = {}     -- [Blizzard frame] = its alpha, while our panel hides it
local buttons = {}
-- The subtabs: their list mode (OrderList), nil for the professions.
local SUBTABS = { "professions", "pending", "open", "mine" }
local selected = 1
-- The order list's filters.
local craftableOnly = true
local hideMine = true

-- Profession buttons ------------------------------------------------------------

-- A band across the middle of the profession's card art, as wide as the button.
local function SetCardArt(texture, skillLine)
    local atlas = C_Texture.GetAtlasInfo(ns.Viewer.CardAtlas(skillLine))
    if not (atlas and atlas.file and atlas.width and atlas.height and atlas.width > 0 and atlas.height > 0) then
        texture:SetColorTexture(0.1, 0.1, 0.1, 1)
        return
    end
    local band = BUTTON_HEIGHT / BUTTON_WIDTH * atlas.width / atlas.height
    local span = atlas.bottomTexCoord - atlas.topTexCoord
    texture:SetTexture(atlas.file)
    texture:SetTexCoord(atlas.leftTexCoord, atlas.rightTexCoord,
        atlas.topTexCoord + span * (CARD_BAND_CENTER - band / 2), atlas.topTexCoord + span * (CARD_BAND_CENTER + band / 2))
end

local function ButtonOnEnter(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(button.name, 1, 1, 1)
    local entry = button.entry
    if entry then
        GameTooltip:AddLine(L["%d |4recipe:recipes;"]:format(#entry.k), 1, 1, 1)
        GameTooltip:AddLine(L["Shared by %d |4member:members;"]:format(entry.members), NORMAL_FONT_COLOR:GetRGB())
        GameTooltip:AddLine(L["Click to see the recipes."], GREEN_FONT_COLOR:GetRGB())
    else
        GameTooltip:AddLine(L["No guild member has shared recipes of this profession yet."], 0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
end

local function ButtonOnClick(button)
    if button.entry then
        ns.Viewer.OpenGuild(button.skillLine)
    end
end

local function CreateProfessionButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button.Art = button:CreateTexture(nil, "BACKGROUND")
    button.Art:SetAllPoints()
    -- Darkens the art so the text reads.
    button.Shade = button:CreateTexture(nil, "BACKGROUND", nil, 1)
    button.Shade:SetAllPoints()
    button.Shade:SetColorTexture(0, 0, 0, 0.5)
    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetSize(36, 36)
    button.Icon:SetPoint("LEFT", 6, 0)
    button.IconBorder = button:CreateTexture(nil, "ARTWORK", nil, 1)
    button.IconBorder:SetAtlas("Professions-Slot-Frame")
    button.IconBorder:SetSize(37, 37)
    button.IconBorder:SetPoint("TOPLEFT", button.Icon, "TOPLEFT")
    button.Name = button:CreateFontString(nil, "OVERLAY", "GameFontNormalMed2")
    button.Name:SetPoint("TOPLEFT", button.Icon, "TOPRIGHT", 8, -3)
    button.Name:SetPoint("RIGHT", -6, 0)
    button.Name:SetJustifyH("LEFT")
    button.Name:SetWordWrap(false)
    button.Detail = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.Detail:SetPoint("TOPLEFT", button.Name, "BOTTOMLEFT", 0, -4)
    button.Detail:SetPoint("RIGHT", -6, 0)
    button.Detail:SetJustifyH("LEFT")
    button.Detail:SetWordWrap(false)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAtlas("PetList-ButtonHighlight")
    highlight:SetAllPoints()
    highlight:SetBlendMode("ADD")
    -- Disabled ones still explain themselves.
    button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnEnter", ButtonOnEnter)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:SetScript("OnClick", ButtonOnClick)
    return button
end

-- entry: the guild's recipes of the profession (Data.GuildRecipes), or nil.
local function UpdateButton(button, profession, entry)
    button.skillLine, button.entry = profession.sl, entry
    button.name = ns.ProfessionName(profession.sl, profession.spell)
    button.Name:SetText(button.name)
    button.Icon:SetTexture(ns.ProfessionIcon(profession.sl, profession.spell))
    SetCardArt(button.Art, profession.sl)
    local enabled = entry ~= nil
    button:SetEnabled(enabled)
    button.Art:SetDesaturated(not enabled)
    button.Icon:SetDesaturated(not enabled)
    button.Art:SetAlpha(enabled and 1 or 0.5)
    if enabled then
        button.Name:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
        button.Detail:SetText(L["%d |4recipe:recipes; · %d |4member:members;"]:format(#entry.k, entry.members))
    else
        button.Name:SetTextColor(0.5, 0.5, 0.5)
        button.Detail:SetText(L["No recipes shared yet"])
    end
    button:Show()
end

local function ByName(list)
    for _, profession in ipairs(list) do
        profession.name = ns.ProfessionName(profession.sl, profession.spell)
    end
    table.sort(list, function(a, b)
        if a.name ~= b.name then
            return a.name < b.name
        end
        return a.sl < b.sl
    end)
    return list
end

-- The two sections: the fixed professions, by name in the client's
-- language, and with the secondary ones any other recipe window the guild
-- has shared (rogues' Poisons...).
local function Sections(byLine)
    local primary, secondary, known = {}, {}, {}
    for _, profession in ipairs(PRIMARY) do
        primary[#primary + 1] = { sl = profession.sl, spell = profession.spell }
        known[profession.sl] = true
    end
    for _, profession in ipairs(SECONDARY) do
        secondary[#secondary + 1] = { sl = profession.sl, spell = profession.spell }
        known[profession.sl] = true
    end
    local others = {}
    for skillLine, entry in pairs(byLine) do
        if not known[skillLine] then
            others[#others + 1] = { sl = skillLine, spell = entry.lk }
        end
    end
    secondary = ByName(secondary)
    for _, profession in ipairs(ByName(others)) do
        secondary[#secondary + 1] = profession
    end
    return ByName(primary), secondary
end

-- Lays out one section under y (from the inset's top); returns the y below it.
local function LayOutSection(title, list, byLine, index, y)
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", page.Content, "TOPLEFT", 12, -y)
    y = y + 20
    for i, profession in ipairs(list) do
        index = index + 1
        local button = buttons[index] or CreateProfessionButton(page.Professions)
        buttons[index] = button
        local column, row = (i - 1) % COLUMNS, math.floor((i - 1) / COLUMNS)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", page.Content, "TOPLEFT", 12 + column * (BUTTON_WIDTH + BUTTON_GAP), -(y + row * (BUTTON_HEIGHT + BUTTON_GAP)))
        UpdateButton(button, profession, byLine[profession.sl])
    end
    local rows = math.ceil(#list / COLUMNS)
    return index, y + rows * (BUTTON_HEIGHT + BUTTON_GAP) + 4
end

local function RefreshProfessions()
    local byLine = ns.Data.GuildRecipes(ns.Data.CurrentGuild(false))
    local primary, secondary = Sections(byLine)
    local index, y = LayOutSection(page.PrimaryTitle, primary, byLine, 0, 10)
    index = LayOutSection(page.SecondaryTitle, secondary, byLine, index, y)
    for i = index + 1, #buttons do
        buttons[i]:Hide()
    end
end

-- The subtabs' names, with how many orders wait for us.
local function UpdateSubTabs()
    local waiting, mine = ns.OrderList.WaitingForMe(), ns.OrderList.WaitingOnMine()
    local texts = {
        L["Professions"],
        waiting > 0 and ("%s (%d)"):format(L["Pending orders"], waiting) or L["Pending orders"],
        L["Order list"],
        mine > 0 and ("%s (%d)"):format(L["Requested orders"], mine) or L["Requested orders"],
    }
    for i, subtab in ipairs(page.SubTabs.Tabs) do
        subtab:SetText(texts[i])
        PanelTemplates_TabResize(subtab, 0)
    end
    PanelTemplates_SetTab(page.SubTabs, selected)
end

local function RefreshPage()
    if not page or not page:IsShown() then
        return
    end
    UpdateSubTabs()
    local mode = SUBTABS[selected]
    local professions = mode == "professions"
    page.Professions:SetShown(professions)
    page.Hint:SetShown(professions)
    page.Orders:SetShown(not professions)
    for _, check in ipairs({ page.Craftable, page.HideMine }) do
        check:SetShown(mode == "open")
        check.Label:SetShown(mode == "open")
    end
    if professions then
        RefreshProfessions()
    else
        ns.OrderList.Show(page.Orders, mode, craftableOnly, not hideMine)
    end
end

local function SelectSubTab(index)
    if SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    end
    selected = index
    RefreshPage()
end

-- A filter of the order list: a checkbox whose label takes clicks too.
-- onClick(checked) keeps the new value.
local function FilterCheck(text, checked, onClick)
    local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    check:SetSize(22, 22)
    check:SetChecked(checked)
    check.Label = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    check.Label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    check.Label:SetText(text)
    check:SetHitRectInsets(0, -(check.Label:GetStringWidth() + 2), 0, 0)
    check:SetScript("OnClick", function(self)
        onClick(self:GetChecked() == true)
        RefreshPage()
    end)
    return check
end

-- Above the window's inset, where Guild Info has its headings: the
-- subtabs, as the game's panels have them on top.
local function CreateSubTabs()
    local holder = CreateFrame("Frame", nil, page)
    holder:SetAllPoints(page.Content)
    local tabs = {}
    for i in ipairs(SUBTABS) do
        local subtab = CreateFrame("Button", nil, holder, "PanelTopTabButtonTemplate")
        subtab:SetID(i)
        if i == 1 then
            subtab:SetPoint("BOTTOMLEFT", page.Content, "TOPLEFT", 4, -2)
        else
            subtab:SetPoint("LEFT", tabs[i - 1], "RIGHT", 2, 0)
        end
        subtab:SetScript("OnClick", function(self)
            SelectSubTab(self:GetID())
        end)
        tabs[i] = subtab
    end
    holder.Tabs = tabs
    PanelTemplates_SetNumTabs(holder, #tabs)
    page.SubTabs = holder
end

-- The panel ------------------------------------------------------------------------

-- Blizzard's view is made invisible while our panel is open (SetAlpha runs
-- none of its code), so the window's own background, inset and borders show
-- around our buttons exactly as in its other tabs. These are every piece its
-- views show, but the communities list.
local function ContentFrames()
    local names = { PostingExpirationText = true }
    for _, mode in pairs(COMMUNITIES_FRAME_DISPLAY_MODES or {}) do
        for _, name in ipairs(mode) do
            names[name] = true
        end
    end
    names.CommunitiesList, names.CommunitiesListDropdown = nil, nil
    local list = {}
    for name in pairs(names) do
        local subframe = communities[name]
        if type(subframe) == "table" and subframe.SetAlpha then
            list[#list + 1] = subframe
        end
    end
    return list
end

local function FadeContent()
    for _, subframe in ipairs(ContentFrames()) do
        if faded[subframe] == nil then
            faded[subframe] = subframe:GetAlpha()
            subframe:SetAlpha(0)
        end
    end
end

local function RestoreContent()
    for subframe, alpha in pairs(faded) do
        subframe:SetAlpha(alpha)
    end
    wipe(faded)
end

local function ShowPage()
    if page:IsShown() then
        return
    end
    remembered = nil
    for _, key in ipairs(BLIZZARD_TABS) do
        local other = communities[key]
        if other then
            if other:GetChecked() then
                remembered = other
            end
            other:SetChecked(false)
        end
    end
    tab:SetChecked(true)
    FadeContent()
    -- The chat's scroll bar is on a higher layer (HIGH strata) than the
    -- whole window: invisible with the chat, it would still take clicks
    -- over our buttons.
    local chatBar = communities.Chat and communities.Chat.ScrollBar
    if chatBar and chatBar:IsShown() then
        chatBar:Hide()
        hiddenChatBar = chatBar
    end
    page:Show()
    RefreshPage()
end

-- restore: put back the selection on Blizzard's tab that was selected; not
-- when one of Blizzard's tabs was just clicked, which marks itself.
local function HidePage(restore)
    if not page:IsShown() then
        return
    end
    page:Hide()
    tab:SetChecked(false)
    if restore and remembered then
        remembered:SetChecked(true)
    end
    remembered = nil
    if hiddenChatBar then
        hiddenChatBar:Show()
        hiddenChatBar = nil
    end
    RestoreContent()
end

local function CreatePage()
    -- It draws nothing of its own: it holds our buttons and keeps the mouse
    -- off Blizzard's invisible view, from right of the communities list's
    -- scroll bar to the window's edges.
    page = CreateFrame("Frame", "GuildProfessionsRecipesGuildPanel", communities)
    page:SetFrameLevel(PAGE_LEVEL)
    page:SetPoint("TOPLEFT", communities.CommunitiesList, "TOPRIGHT", 18, 0)
    page:SetPoint("BOTTOMRIGHT", communities, "BOTTOMRIGHT", -4, 4)
    page:EnableMouse(true)

    -- Inside the window's inset, where the game puts its Guild Info and
    -- Benefits panels.
    page.Content = CreateFrame("Frame", nil, page)
    page.Content:SetPoint("TOPLEFT", communities.CommunitiesList, "TOPRIGHT", 24, -40)
    page.Content:SetPoint("BOTTOMRIGHT", communities, "BOTTOMRIGHT", -12, 30)

    page.Professions = CreateFrame("Frame", nil, page.Content)
    page.Professions:SetAllPoints()
    page.PrimaryTitle = page.Professions:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    page.PrimaryTitle:SetText(L["Primary professions"])
    page.SecondaryTitle = page.Professions:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    page.SecondaryTitle:SetText(L["Secondary professions"])
    page.Orders = ns.OrderList.Create(page.Content)
    ns.OrderList.onChange = RefreshPage
    CreateSubTabs()

    -- Under the inset, where Guild Info has its buttons: a hint, or the
    -- order list's filters.
    page.Hint = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    page.Hint:SetPoint("LEFT", page.Content, "BOTTOMLEFT", 4, -15)
    page.Hint:SetText(L["Choose a profession to see every recipe your guild knows."])
    page.Craftable = FilterCheck(L["Only orders I can make"], craftableOnly, function(checked)
        craftableOnly = checked
    end)
    page.Craftable:SetPoint("LEFT", page.Content, "BOTTOMLEFT", 0, -15)
    page.HideMine = FilterCheck(L["Hide my orders"], hideMine, function(checked)
        hideMine = checked
    end)
    page.HideMine:SetPoint("LEFT", page.Craftable.Label, "RIGHT", 16, 0)
    page:Hide()
end

-- The tab ---------------------------------------------------------------------------

-- Blizzard's notification mark, as its Roster tab shows for applicants:
-- while some order waits for us to act.
local function UpdateBadge()
    if tab then
        tab.Badge:SetShown(ns.OrderList.WaitingForMe() + ns.OrderList.WaitingOnMine() > 0)
    end
end

-- Runs after Blizzard lays out its tabs. Ours goes under the lowest one,
-- and only while Guild Info shows: on the guild, in the views with tabs.
local function Update()
    local last
    for _, key in ipairs(BLIZZARD_TABS) do
        local other = communities[key]
        if other and other:IsShown() then
            last = other
        end
    end
    local guildInfo = communities.GuildInfoTab
    local show = last ~= nil and guildInfo ~= nil and guildInfo:IsShown()
    tab:SetShown(show)
    if show then
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -TAB_GAP)
    else
        HidePage(true)
    end
end

local function Setup()
    communities = CommunitiesFrame
    if tab or not (communities and communities.UpdateCommunitiesTabs and communities.CommunitiesList) then
        return
    end
    CreatePage()
    tab = CreateFrame("CheckButton", "GuildProfessionsRecipesGuildTab", communities, "RightSideTabTemplate")
    tab:SetFrameLevel(TAB_LEVEL)
    tab.Icon:SetTexture(ICON)
    tab.tooltip = L["Recipes & Orders"]
    tab.Badge = tab:CreateTexture(nil, "OVERLAY")
    tab.Badge:SetAtlas("communities-icon-notification", true)
    tab.Badge:SetPoint("CENTER", tab, "TOPRIGHT", 0, 0)
    tab.Badge:Hide()
    -- After the template's own click (its sound, and marking itself).
    tab:HookScript("OnClick", ShowPage)
    tab:Hide()
    hooksecurefunc(communities, "UpdateCommunitiesTabs", Update)
    -- One of Blizzard's tabs was clicked (or the window changed its view).
    hooksecurefunc(communities, "SetDisplayMode", function()
        HidePage(false)
    end)
    communities:HookScript("OnHide", function()
        HidePage(true)
    end)
    ns.On("DataChanged", function()
        ns.Debounce("GuildTabRefresh", 0.3, function()
            UpdateBadge()
            RefreshPage()
        end)
    end)
    Update()
    UpdateBadge()
end

function GuildTab.Init()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Communities", Setup)
end

-- GuildTab.lua: a "Recipes & Orders" tab on the guild window, under
-- Blizzard's own side tabs (Chat, Roster, Guild Info...). It shows every
-- profession as a button. Those whose recipes some member has shared open
-- the recipe window on all of them; the others are disabled. Crafting
-- orders come in a later version.
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
        local button = buttons[index] or CreateProfessionButton(page.Content)
        buttons[index] = button
        local column, row = (i - 1) % COLUMNS, math.floor((i - 1) / COLUMNS)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", page.Content, "TOPLEFT", 12 + column * (BUTTON_WIDTH + BUTTON_GAP), -(y + row * (BUTTON_HEIGHT + BUTTON_GAP)))
        UpdateButton(button, profession, byLine[profession.sl])
    end
    local rows = math.ceil(#list / COLUMNS)
    return index, y + rows * (BUTTON_HEIGHT + BUTTON_GAP) + 4
end

local function RefreshPage()
    if not page or not page:IsShown() then
        return
    end
    local byLine = ns.Data.GuildRecipes(ns.Data.CurrentGuild(false))
    local primary, secondary = Sections(byLine)
    local index, y = LayOutSection(page.PrimaryTitle, primary, byLine, 0, 10)
    index = LayOutSection(page.SecondaryTitle, secondary, byLine, index, y)
    for i = index + 1, #buttons do
        buttons[i]:Hide()
    end
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

    -- Above the inset, where Guild Info has its headings.
    page.Hint = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    page.Hint:SetPoint("LEFT", page.Content, "TOPLEFT", 4, 20)
    page.Hint:SetText(L["Choose a profession to see every recipe your guild knows."])
    page.PrimaryTitle = page.Content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    page.PrimaryTitle:SetText(L["Primary professions"])
    page.SecondaryTitle = page.Content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    page.SecondaryTitle:SetText(L["Secondary professions"])
    page:Hide()
end

-- The tab ---------------------------------------------------------------------------

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
        if page:IsShown() then
            ns.Debounce("GuildTabRefresh", 0.3, RefreshPage)
        end
    end)
    Update()
end

function GuildTab.Init()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Communities", Setup)
end

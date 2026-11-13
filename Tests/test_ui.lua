local H = ...

local GUILD = "Test Guild"

local FakeCommunities = H.FakeCommunities


local function ChildrenOf(client, parent)
    local children = {}
    for _, frame in ipairs(client.created or {}) do
        if frame._parent == parent then
            children[#children + 1] = frame
        end
    end
    return children
end

local function Recipes(count, base)
    local list = {}
    for i = 1, count do
        list[i] = base + i * 3
    end
    return list
end

H.section("UI: roster column")
local world = H.NewWorld({ seed = 31, communities = FakeCommunities })
local alchemy = Recipes(30, 2000)
local cooking = Recipes(12, 8000)
local A = world:NewClient("Alice", { professions = {
    { sl = 171, r = 150, m = 225, spell = 2259, hasRecipes = true },
    { sl = 182, r = 200, m = 225, spell = 2366, hasRecipes = false },
    nil, nil,
    { sl = 185, r = 75, m = 150, spell = 2550, hasRecipes = true },
} })
local B = world:NewClient("Bob", { professions = { { sl = 164, r = 100, m = 150, spell = 2018, hasRecipes = true } } })
world:AddMember("Silent")
world:Login(B)
world:RunFor(5)
world:Login(A)
world:RunFor(5)
world:OpenProfession(A, 171, alchemy, alchemy)
world:RunFor(1)
world:OpenProfession(A, 185, cooking, cooking)
world:RunFor(1)
world:CloseProfession(A)
world:RunFor(200)

local communities = A.env.CommunitiesFrame
local list = communities.MemberList
for _, row in ipairs(list.rows) do
    row:RefreshExpandedColumns()
end
list:RefreshLayout()

local function HolderOf(row)
    return ChildrenOf(A, row)[1]
end

local aliceRow, bobRow, silentRow = list.rows[1], list.rows[2], list.rows[3]
local holder = HolderOf(aliceRow)
H.check(holder ~= nil and holder._shown, "Alice's row has an icon holder")
H.check(aliceRow.Note._right == holder, "the Note column ends where the icons begin")
local shown = {}
for _, button in ipairs(holder and holder.icons or {}) do
    if button._shown then
        shown[#shown + 1] = button
    end
end
H.eq(#shown, 3, "Alice shows three profession icons")
H.eq(shown[1] and shown[1].prof.sl, 171, "first icon is the first profession")
H.eq(shown[3] and shown[3].prof.sl, 185, "Cooking comes after the gap in GetProfessions")
H.eq(shown[2] and shown[2].prof.k, false, "Herbalism has no recipes to open")
if shown[1] then
    shown[1]._scripts.OnEnter(shown[1])
    shown[1]._scripts.OnClick(shown[1])
end
local viewer = A.env.GuildProfessionsRecipesViewer
H.check(viewer ~= nil and viewer._shown, "clicking an icon opens the recipe window")

local bobHolder = HolderOf(bobRow)
H.check(bobHolder ~= nil and bobHolder.icons[1]._shown and bobHolder.icons[1].prof.sl == 164, "Bob's row shows his profession")
local silentHolder = HolderOf(silentRow)
H.check(silentHolder == nil or not silentHolder.icons[1]._shown, "a member without the addon or roster data shows no icons")
silentRow.memberInfo.profession1ID = 333
silentRow.memberInfo.profession1Rank = 180
silentRow:RefreshExpandedColumns()
silentHolder = HolderOf(silentRow)
H.check(silentHolder and silentHolder.icons[1]._shown and silentHolder.icons[1].prof.native, "the roster's own profession data is shown when given")
silentHolder.icons[1]._scripts.OnEnter(silentHolder.icons[1])
H.check(list.headers[6]._lastPoint ~= nil, "the Note header is shortened")

-- Blizzard's extra column fills the right end: the icons take the Note's place.
aliceRow.guildColumnIndex = 1
aliceRow:RefreshExpandedColumns()
H.check(holder._shown, "the icons stay while a Blizzard extra column is shown")
H.check(not aliceRow.Note._shown, "they take the Note column's place")
list.guildColumnIndex = 1
list:RefreshLayout()
H.check(not list.headers[6]._shown, "our header replaces the Note header")
list.guildColumnIndex = nil
list.headers[6]:Show()
list:RefreshLayout()
aliceRow.guildColumnIndex = nil
aliceRow.Note:Show()
aliceRow:RefreshExpandedColumns()
H.check(holder._shown and aliceRow.Note._right == holder, "without the extra column the Note comes back, next to the icons")
aliceRow.isInvitation = true
aliceRow:RefreshExpandedColumns()
H.check(not holder._shown, "no icons on invitation rows")
aliceRow.isInvitation = false
aliceRow.expanded = false
aliceRow:RefreshExpandedColumns()
H.check(not holder._shown, "no icons in the narrow list next to the chat")
aliceRow.expanded = true
aliceRow:RefreshExpandedColumns()
H.check(holder._shown, "icons back in the Roster tab")

H.section("UI: guild window tab")
local guildTab = A.env.GuildProfessionsRecipesGuildTab
H.check(guildTab ~= nil and guildTab._shown, "the guild window gets our tab")
H.eq(guildTab and guildTab._point and guildTab._point[2], communities.GuildInfoTab, "under the lowest of Blizzard's tabs")
H.eq(guildTab and guildTab.tooltip, "Recipes & Orders", "its name in the tooltip")
communities.GuildPreferredPlaySettingsTab:Show()
communities:UpdateCommunitiesTabs()
H.eq(guildTab._point[2], communities.GuildPreferredPlaySettingsTab, "it moves down when Blizzard shows another tab")
communities.GuildPreferredPlaySettingsTab:Hide()
communities.GuildInfoTab:Hide()
communities:UpdateCommunitiesTabs()
H.check(not guildTab._shown, "hidden wherever Guild Info is (a community, a view without tabs)")
communities.GuildInfoTab:Show()
communities:UpdateCommunitiesTabs()
H.check(guildTab._shown and guildTab._point[2] == communities.GuildInfoTab, "and back on the guild")
local chatBar = communities.Chat.ScrollBar

-- Its panel: every profession, those with shared recipes enabled. Alice has
-- shared her Alchemy and Cooking; Bob has not shared his Blacksmithing yet.
local panel = A.env.GuildProfessionsRecipesGuildPanel
H.check(panel ~= nil and not panel._shown, "the panel starts hidden")
-- What Blizzard's views show (COMMUNITIES_FRAME_DISPLAY_MODES), in short.
A.env.COMMUNITIES_FRAME_DISPLAY_MODES = { CHAT = { "CommunitiesList", "MemberList", "Chat" }, ROSTER = { "CommunitiesList", "MemberList" } }
guildTab._scripts.OnClick(guildTab)
H.check(list:GetAlpha() == 0 and communities.Chat:GetAlpha() == 0, "Blizzard's view turns invisible, so its window's own art shows around ours")
H.check(communities.CommunitiesList:GetAlpha() == 1, "but not the communities list")
H.check(panel._shown and guildTab._checked and not communities.RosterTab._checked, "clicking the tab shows its panel, marked as the selected tab")
H.check(not chatBar._shown, "the chat's scroll bar, drawn above the whole window, is hidden meanwhile")
local professionButtons = {}
for _, child in ipairs(ChildrenOf(A, panel.Professions)) do
    if child._type == "Button" and child._shown then
        professionButtons[child.skillLine] = child
    end
end
local professionCount = 0
for _ in pairs(professionButtons) do
    professionCount = professionCount + 1
end
H.eq(professionCount, 12, "a button for every profession")
local alchemyButton, smithButton = professionButtons[171], professionButtons[164]
H.check(alchemyButton._enabled and professionButtons[185]._enabled, "those with shared recipes can be clicked")
H.check(smithButton._enabled == false and professionButtons[182]._enabled == false, "the others are disabled")
H.check(smithButton.entry == nil and smithButton._scripts.OnEnter ~= nil, "a disabled one still has its tooltip")
smithButton._scripts.OnEnter(smithButton)
H.eq(smithButton.Detail._text, "No recipes shared yet", "and says so")
H.check((alchemyButton.Detail._text or ""):find("^30 ") ~= nil, "an enabled one counts its recipes")
alchemyButton._scripts.OnClick(alchemyButton)
H.check(viewer._shown and #viewer.ScrollBox._provider.elements - 1 == #alchemy, "clicking it opens the guild's recipes of that profession")
H.check((viewer.Updated._text or ""):find("Shared by 1", 1, true) ~= nil, "saying how many members shared them")

-- Leaving the panel.
communities.RosterTab:SetChecked(true)
communities:SetDisplayMode("Roster")
H.check(not panel._shown and not guildTab._checked and communities.RosterTab._checked, "clicking one of Blizzard's tabs closes it")
H.check(chatBar._shown, "and the chat's scroll bar comes back")
H.check(list:GetAlpha() == 1 and communities.Chat:GetAlpha() == 1, "and Blizzard's view")
guildTab._scripts.OnClick(guildTab)
communities._scripts.OnHide(communities)
H.check(not panel._shown and communities.RosterTab._checked, "closing the window closes it, Blizzard's tab selected again")
guildTab._scripts.OnClick(guildTab)
communities.GuildInfoTab:Hide()
communities:UpdateCommunitiesTabs()
H.check(not panel._shown and not guildTab._shown, "so does leaving the guild for another community")
communities.GuildInfoTab:Show()
communities:UpdateCommunitiesTabs()

-- Another addon's panel on the guild window (Guild Bank Alts'), through the
-- shared list GuildWindowAddonPanels.
local panels = A.env.GuildWindowAddonPanels
H.check(type(panels) == "table" and panels[1] and panels[1].id == "GuildProfessionsRecipes" and panels[1].tab == guildTab,
    "our tab is in the shared list of the guild window's addon panels")
local otherOpen, otherClosed = false, 0
local otherTab = H.NewObject(A, "CheckButton")
local other = { id = "Other", order = 20, tab = otherTab, Close = function()
    if not otherOpen then
        return nil
    end
    otherOpen, otherClosed = false, otherClosed + 1
    return communities.RosterTab
end }
table.insert(panels, other)
communities:UpdateCommunitiesTabs()
H.eq(guildTab._point[2], communities.GuildInfoTab, "an addon of a higher order goes under us, not we under it")
-- The other panel is open, Blizzard's tab already unmarked by it.
otherOpen = true
communities.RosterTab:SetChecked(false)
guildTab._scripts.OnClick(guildTab)
H.eq(otherClosed, 1, "opening ours closes the other addon's panel")
H.check(panel._shown, "and ours shows")
communities._scripts.OnHide(communities)
H.check(communities.RosterTab._checked, "closing the window selects the Blizzard tab the other addon remembered")
-- Ours is open: the other addon takes over.
guildTab._scripts.OnClick(guildTab)
local ours = panels[1]
H.eq(ours.Close(), communities.RosterTab, "the other addon closing ours gets the Blizzard tab we remembered")
H.check(not panel._shown and not guildTab._checked, "our panel is closed")
H.check(list:GetAlpha() == 1, "and Blizzard's view shown again, for the other addon to hide")
H.eq(ours.Close(), nil, "closing it again gives nothing")
-- An addon of a lower order: we go under its tab.
other.order = 5
communities:UpdateCommunitiesTabs()
H.eq(guildTab._point[2], otherTab, "under the tab of an addon of a lower order")
table.remove(panels, 2)
communities:UpdateCommunitiesTabs()
communities.RosterTab:SetChecked(true)
A.ns.Viewer.OpenMember(A.guid, 171)

H.section("UI: recipe window")
local order = viewer.OrderButton
H.check(order ~= nil and order._enabled == true and order._text == "Request an order", "a crafting order button for the selected recipe")
H.check(viewer.CreateButton == nil and viewer.CreateAllButton == nil and viewer.CreateMultipleInputBox == nil, "instead of the game's crafting controls")
local provider = viewer.ScrollBox._provider
local elements = provider and provider.elements or {}
local headers, recipes = 0, 0
for _, element in ipairs(elements) do
    if element.header then
        headers = headers + 1
    else
        recipes = recipes + 1
    end
end
H.eq(recipes, #alchemy, "all of Alice's Alchemy recipes are listed")
H.check(headers >= 1, "recipes are grouped")
H.eq(elements[1] and elements[1].name, "Category", "grouped by the profession's categories, noted while its window was open")
local init = viewer.ScrollBox._view.init
local rows = {}
for i, element in ipairs(elements) do
    rows[i] = H.NewObject(A, "Button")
    init(rows[i], element)
end
local recipeRow
for i, element in ipairs(elements) do
    if not element.header then
        recipeRow = rows[i]
        break
    end
end
recipeRow._scripts.OnClick(recipeRow)
recipeRow._scripts.OnEnter(recipeRow)
H.check((viewer.Detail.Name._text or ""):find("Item" .. (recipeRow.data.recipeID + 100000), 1, true) ~= nil, "selecting a recipe shows the item it makes")
H.check((viewer.Detail.Description._text or ""):find(tostring(recipeRow.data.recipeID), 1, true) ~= nil, "and its description")
H.check((viewer.Detail.reagents[1].Text._text or ""):find("0/2 Item2447", 1, true) ~= nil, "reagents show what we carry over what it takes")
H.eq((viewer.Detail.reagents[1].Text._text or ""):sub(1, 10), "|cff7f7f7f", "in grey while it is not enough")
A.bags = { [2447] = 2 }
world:FireEvent(A, "BAG_UPDATE_DELAYED")
world:RunFor(1)
H.eq(viewer.Detail.reagents[1].Text._text, "|cffffffff2/2 Item2447|r", "and in white once it is")
A.bags = nil
world:FireEvent(A, "BAG_UPDATE_DELAYED")
world:RunFor(1)
H.check((viewer.Detail.KnownBy.Text._text or ""):find("Nobody", 1, true) ~= nil and viewer.Detail.WhoButton._shown == false,
    "nobody else knows it, and there is nobody to see")
A.shiftDown = true
recipeRow._scripts.OnClick(recipeRow)
A.shiftDown = false
H.check(A.linked ~= nil, "shift-click links the recipe in chat")

-- Collapse the first group.
rows[1]._scripts.OnClick(rows[1])
H.eq(#viewer.ScrollBox._provider.elements, headers, "a collapsed group hides its recipes")
rows[1].data.collapsed = true
init(rows[1], viewer.ScrollBox._provider.elements[1])
rows[1]._scripts.OnClick(rows[1])
H.eq(#viewer.ScrollBox._provider.elements, headers + recipes, "and shows them again")

-- Search.
viewer.Search._text = "zzz"
viewer.Search._scripts.OnTextChanged(viewer.Search)
world:RunFor(1)
H.eq(#viewer.ScrollBox._provider.elements, 0, "a search with no match lists nothing")
H.check((viewer.Count._text or ""):find("0 of 30", 1, true) ~= nil, "the count shows what the search kept")
viewer.Search._text = tostring(alchemy[5])
viewer.Search._scripts.OnTextChanged(viewer.Search)
world:RunFor(1)
H.eq(#viewer.ScrollBox._provider.elements, 2, "a search finds the recipe (and its group)")
viewer.Search._text = ""
viewer.Search._scripts.OnTextChanged(viewer.Search)
world:RunFor(1)

-- Tabs.
local tabs = 0
for _, tab in ipairs(viewer.Tabs or {}) do
    if tab._shown then
        tabs = tabs + 1
    end
end
H.eq(tabs, 2, "one tab per profession with recipes")
viewer.Tabs[2]._scripts.OnMouseUp(viewer.Tabs[2], "LeftButton", true)
H.eq(#viewer.ScrollBox._provider.elements - 1, #cooking, "the second tab shows Cooking")

-- Another member, and members with nothing to show.
A.ns.Viewer.Open("bob")
H.check(viewer._shown, "a member can be opened by name, in any case")
A.ns.Viewer.Open("Silent")
H.check(A.printed[#A.printed]:find("no data", 1, true) ~= nil, "a member without data gets a message")
A.ns.Viewer.Open(nil)
H.check(viewer._shown, "our own recipes")

-- The window follows the data.
local before = #viewer.ScrollBox._provider.elements
world.recipeSkill[9999] = 171
world:FireEvent(A, "NEW_RECIPE_LEARNED", 9999)
world:RunFor(2)
viewer.Tabs[1]._scripts.OnMouseUp(viewer.Tabs[1], "LeftButton", true)
H.check(#viewer.ScrollBox._provider.elements >= before, "a new recipe appears in the open window")

H.section("UI: clicking a profession")
local function IconsOf(row)
    local icons = {}
    for _, button in ipairs(HolderOf(row).icons) do
        if button._shown then
            icons[#icons + 1] = button
        end
    end
    return icons
end
-- Bob shares his Blacksmithing.
world:OpenProfession(B, 164, { 50, 51 }, { 50, 51 })
world:RunFor(1)
world:CloseProfession(B)
world:RunFor(200)
bobRow:RefreshExpandedColumns()
local bobIcon = IconsOf(bobRow)[1]
H.check(type(bobIcon.prof.k) == "table", "Bob's recipes arrived")

-- A member's profession: the saved recipes at once, online or not.
viewer:Hide()
bobIcon._scripts.OnClick(bobIcon)
H.check(viewer._shown, "a member's profession opens the saved recipes")
H.eq(#A.itemRefs, 0, "without asking the game for a link")
H.check((viewer.Updated._text or ""):find("Saved data", 1, true) ~= nil, "saying they are saved")
H.check((viewer.Detail.Name._text or ""):find("Item100050", 1, true) ~= nil, "with the first recipe selected")
viewer:Hide()
world:Logout(B)
world:RunFor(15)
bobIcon._scripts.OnClick(bobIcon)
H.check(viewer._shown, "the same while the member is offline")
world:Login(B)
world:RunFor(10)

-- Our own professions open in the game's own window.
viewer:Hide()
local opened
A.env.C_TradeSkillUI.OpenTradeSkill = function(skillLine)
    opened = skillLine
    return true
end
local ownIcon = IconsOf(aliceRow)[1]
ownIcon._scripts.OnClick(ownIcon)
H.eq(opened, 171, "our own profession opens in the game's window")
H.check(not viewer._shown, "not in the saved recipes")
A.env.C_TradeSkillUI.OpenTradeSkill = function()
    return false
end
ownIcon._scripts.OnClick(ownIcon)
H.check(viewer._shown, "if the game will not open it, the saved recipes")
A.env.C_TradeSkillUI.OpenTradeSkill = nil
H.eq(#world.errors, 0, "clicks: no Lua errors")

-- Slash commands.
A.env.SlashCmdList.GUILDPROFESSIONSRECIPES("status")
A.env.SlashCmdList.GUILDPROFESSIONSRECIPES("help")
A.env.SlashCmdList.GUILDPROFESSIONSRECIPES("language esES")
H.eq(A.ns.L["Professions"], "Profesiones", "/grecipes language switches the texts")
A.env.SlashCmdList.GUILDPROFESSIONSRECIPES("language dede")
H.eq(A.ns.L["Professions"], "Berufe", "a language code in any case")
H.eq(A.env.GuildProfessionsRecipesDB.settings.locale, "deDE", "the language is remembered")
local printedBefore = #A.printed
A.env.SlashCmdList.GUILDPROFESSIONSRECIPES("language")
H.check((A.printed[#A.printed] or ""):find("zhTW", 1, true) ~= nil and #A.printed == printedBefore + 1, "without a code: the list of languages")
A.env.SlashCmdList.GUILDPROFESSIONSRECIPES("language xxXX")
H.eq(A.ns.LOCALE, "deDE", "an unknown code changes nothing")
A.env.SlashCmdList.GUILDPROFESSIONSRECIPES("language auto")
H.eq(A.ns.LOCALE, "enUS", "auto: back to the client's language")
H.eq(A.env.GuildProfessionsRecipesDB.settings.locale, nil, "auto is not remembered as a code")
A.env.SlashCmdList.GUILDPROFESSIONSRECIPES("sync")
world:RunFor(30)
A.env.SlashCmdList.GUILDPROFESSIONSRECIPES("reset")
A.env.SlashCmdList.GUILDPROFESSIONSRECIPES("reset confirm")
H.check(A.env.GuildProfessionsRecipesDB.guilds[GUILD].members[A.guid] ~= nil, "reset keeps our own record")
H.eq(A.env.GuildProfessionsRecipesDB.guilds[GUILD].members[B.guid], nil, "reset forgets the others")

H.eq(#world.errors, 0, "UI: no Lua errors")
for i = 1, math.min(#world.errors, 5) do
    print(world.errors[i])
end

H.section("UI: probe report")
A.env.GetBuildInfo = function()
    return "1.60.1", "70170", "Oct 1 2026", 16001
end
A.env.SlashCmdList.GUILDPROFESSIONSRECIPES("probe burst")
world:RunFor(5)
local probe = A.env.GuildProfessionsRecipesProbe
local report = probe and probe.Edit and probe.Edit._text or ""
H.check(report:find("== Own professions", 1, true) ~= nil, "the probe report opens")
H.check(report:find("section failed", 1, true) == nil, "every probe section runs")
H.check(report:find("SendMail=yes", 1, true) ~= nil and report:find("ERR_TRADE_COMPLETE: Trade complete.", 1, true) ~= nil,
    "the probe tells what trades and mail can be read with")
H.check(report:find("whisper-name via WHISPER", 1, true) ~= nil and report:find("guild via GUILD", 1, true) ~= nil, "the probe hears its own pings")
H.check(report:find("burst of 12 GUILD pings", 1, true) ~= nil, "the burst test runs")
H.eq(#world.errors, 0, "probe: no Lua errors")
for i = 1, math.min(#world.errors, 5) do
    print(world.errors[i])
end
if os.getenv("SHOW_PROBE") then
    print(report)
end

-- The layout of the game's own profession window.
local printedCount = #A.printed
A.env.SlashCmdList.GUILDPROFESSIONSRECIPES("probe ui")
H.check(#A.printed == printedCount + 1 and A.printed[#A.printed]:find("open a profession window", 1, true) ~= nil, "probe ui without the window: one line in the chat")
local function Placed(kind, left, top, width, height, regions, children)
    local object = H.NewObject(A, kind)
    object._shown = true
    for name, value in pairs({ GetLeft = left, GetTop = top, GetWidth = width, GetHeight = height, GetFrameLevel = 1, GetObjectType = kind }) do
        rawset(object, name, function()
            return value
        end)
    end
    rawset(object, "GetRegions", function()
        return unpack(regions or {})
    end)
    rawset(object, "GetChildren", function()
        return unpack(children or {})
    end)
    return object
end
local title = Placed("FontString", 120, 590, 200, 14)
title._text = "Leatherworking"
rawset(title, "GetFontObject", function() end)
rawset(title, "GetTextColor", function()
    return 1, 0.82, 0
end)
local bar = Placed("Frame", 210, 560, 453, 18)
A.env.ProfessionsFrame = Placed("Frame", 100, 600, 782, 594, { title }, { bar })
A.env.ProfessionsFrame.RankBar = bar
A.env.SlashCmdList.GUILDPROFESSIONSRECIPES("probe ui")
report = probe.Edit._text or ""
H.check(report:find("ProfessionsFrame w=782 h=594", 1, true) ~= nil, "probe ui reports the window's size")
H.check(report:find("ProfessionsFrame.RankBar [Frame] x=110 y=40 w=453 h=18", 1, true) ~= nil, "and where each piece sits")
H.check(report:find("text=Leatherworking", 1, true) ~= nil and report:find("!! failed", 1, true) == nil, "and its texts")
if os.getenv("SHOW_PROBE") then print(report) end
A.env.ProfessionsFrame = nil

H.section("UI: names with spaces")
do
    local w = H.NewWorld({ seed = 44 })
    local named = w:NewClient("Alice Smith", { professions = { { sl = 171, r = 10, m = 75, spell = 2259, hasRecipes = true } } })
    local friend = w:NewClient("Bob Jones", { professions = { { sl = 171, r = 10, m = 75, spell = 2259, hasRecipes = true } } })
    w:Login(named)
    w:Login(friend)
    w:RunFor(5)
    w:OpenProfession(friend, 171, { 10, 20, 30 }, { 10, 20 })
    w:RunFor(2)
    w:CloseProfession(friend)
    w:RunFor(200)
    named.env.SlashCmdList.GUILDPROFESSIONSRECIPES("bob jones")
    local window = named.env.GuildProfessionsRecipesViewer
    H.check(window ~= nil and window._shown, "/grecipes with a name that has a space opens the window")
    H.check(window and (window.ScrollBox._provider.elements[2] or {}).recipeID == 10, "showing that member's recipes")
    H.eq(#w.errors, 0, "names with spaces: no Lua errors")
    for i = 1, math.min(#w.errors, 5) do
        print(w.errors[i])
    end
end

H.section("UI: filters")
do
    local w = H.NewWorld({ seed = 52 })
    local me = w:NewClient("Alice", { professions = {
        { sl = 171, r = 150, m = 225, spell = 2259, hasRecipes = true },
        { sl = 186, r = 50, m = 75, spell = 2575, hasRecipes = true },
    } })
    local smith = w:NewClient("Bob", { professions = { { sl = 164, r = 100, m = 150, spell = 2018, hasRecipes = true } } })
    w:Login(me)
    w:Login(smith)
    w:RunFor(5)
    -- Bob's Blacksmithing: 101 makes a chest piece, 102 a robe, 104 boots,
    -- 103 something not worn, 105 no item at all (like an enchantment), 106
    -- an item that binds when it is made. 102 takes one item 2840, the
    -- others two of item 2447.
    local all = { 101, 102, 103, 104, 105, 106 }
    w.itemSlots = { [100101] = "INVTYPE_CHEST", [100102] = "INVTYPE_ROBE", [100104] = "INVTYPE_FEET" }
    w.reagents = { [102] = { { 2840, 1 } } }
    w.noItem = { [105] = true }
    w:OpenProfession(smith, 164, all, all)
    w:RunFor(1)
    w:CloseProfession(smith)
    -- Alice shares her Alchemy, which makes nothing to wear, and her
    -- Mining, a gathering profession (its Smelting makes bars).
    w:OpenProfession(me, 171, { 201, 202 }, { 201, 202 })
    w:RunFor(1)
    w:CloseProfession(me)
    w:OpenProfession(me, 186, { 301 }, { 301 })
    w:RunFor(1)
    w:CloseProfession(me)
    w:RunFor(200)
    -- The game's bind type of each item: 1 (binds when picked up, so when
    -- made) for item 100106, 0 for the others.
    local itemInfo = me.env.C_Item.GetItemInfo
    rawset(me.env.C_Item, "GetItemInfo", function(item)
        local name, link, quality = itemInfo(item)
        if not name then
            return nil
        end
        local itemID = tonumber(tostring(item):match("%d+"))
        return name, link, quality, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, itemID == 100106 and 1 or 0
    end)

    me.ns.Viewer.Open("Bob")
    local window = me.env.GuildProfessionsRecipesViewer
    local function Listed()
        local ids = {}
        for _, element in ipairs(window.ScrollBox._provider.elements) do
            if not element.header then
                ids[#ids + 1] = element.recipeID
            end
        end
        table.sort(ids)
        return table.concat(ids, ",")
    end
    local function Toggle(entry)
        entry.setSelected(entry.data)
    end
    H.eq(Listed(), "101,102,103,104,105", "no filter: every recipe but the one whose item binds when made")
    H.check(not window.Filter._resetShown, "and no reset button")
    local menu = H.MenuOf(window.Filter)
    H.check(#menu == 3 and menu[1].text == "Have Materials" and menu[2].text == "Show items that bind when made" and menu[3].text == "Slots",
        "the menu: Have Materials, ours for items that bind when made, and Slots; no Has skill up")

    H.eq(menu[1].tooltip, "Only recipes whose reagents you carry in your bags.", "the materials entry says whose bags")
    me.bags = { [2840] = 1 }
    Toggle(menu[1])
    H.eq(Listed(), "102", "have materials: what our bags can make")
    H.check(menu[1].isSelected(menu[1].data) and window.Filter._resetShown, "checked, with the reset button")
    me.bags[2447] = 2
    w:FireEvent(me, "BAG_UPDATE_DELAYED")
    w:RunFor(1)
    H.eq(Listed(), "101,102,103,104,105", "and it follows the bags")
    Toggle(menu[1])

    local slots = menu[3].entries
    local texts = {}
    for i, entry in ipairs(slots) do
        texts[i] = entry.text
    end
    H.eq(table.concat(texts, ","), "Check All,Uncheck All,Chest,Feet,Created Items",
        "slots: those the profession makes, Chest and Robe as one, then the game's Created Items")
    Toggle(slots[3])
    H.eq(Listed(), "103,104,105", "unchecking Chest hides chest pieces and robes")
    H.check(not slots[3].isSelected(slots[3].data) and slots[4].isSelected(slots[4].data), "the boxes show it")
    Toggle(slots[3])
    Toggle(slots[5])
    H.eq(Listed(), "101,102,104,105", "unchecking Created Items hides what is not worn")
    H.eq(slots[2].callback(slots[2].data), me.env.MenuResponse.Refresh, "Uncheck All keeps the menu open")
    H.eq(Listed(), "105", "and leaves only recipes that make no item")
    slots[1].callback(slots[1].data)
    H.eq(Listed(), "101,102,103,104,105", "Check All shows every slot again")

    Toggle(menu[1])
    Toggle(slots[4])
    window.Filter._default()
    H.eq(Listed(), "101,102,103,104,105", "the reset button clears every filter")
    H.check(not window.Filter._resetShown, "and hides itself")

    -- Recipes whose item binds when made: hidden unless asked for.
    H.eq(menu[2].tooltip, "Recipes whose item binds to its crafter as it is made: nobody can craft it for you.",
        "the entry says why they are hidden")
    H.check(not menu[2].isSelected(menu[2].data), "unticked by default")
    Toggle(menu[2])
    H.eq(Listed(), "101,102,103,104,105,106", "ticked, they show")
    H.check(window.Filter._resetShown, "which counts as a filter")
    local function SelectRecipe(recipeID)
        for _, element in ipairs(window.ScrollBox._provider.elements) do
            if element.recipeID == recipeID then
                local row = H.NewObject(me, "Button")
                window.ScrollBox._view.init(row, element)
                row._scripts.OnClick(row)
            end
        end
    end
    SelectRecipe(106)
    H.check(window.OrderButton._enabled == false
        and window.OrderButton.reason == "It binds when it is made: its crafter could not give it to you.",
        "no order for it, saying why")
    SelectRecipe(101)
    H.check(window.OrderButton._enabled ~= false and window.OrderButton.reason == nil, "other recipes can be ordered")
    window.Filter._default()
    H.eq(Listed(), "101,102,103,104,105", "the reset button hides them again")

    -- Like the game's, another profession starts with no filters and no search.
    Toggle(slots[3])
    Toggle(menu[1])
    me.ns.Viewer.OpenMember(me.guid, 171)
    H.eq(Listed(), "201,202", "opening another profession clears the filters")
    H.check(not window.Filter._resetShown and not menu[1].isSelected(menu[1].data), "the menu shows it")
    local alchemySlots = H.MenuOf(window.Filter)[3]
    H.eq(alchemySlots and #alchemySlots.entries, 3, "its Slots: Check All, Uncheck All and Created Items")
    Toggle(alchemySlots.entries[3])
    window.Search._text = "201"
    window.Search._scripts.OnTextChanged(window.Search)
    w:RunFor(1)
    H.check(Listed() == "" and window.Filter._resetShown, "Created Items hides its potions")
    local miningTab = window.Tabs[2]
    H.eq(miningTab and miningTab.skillLine, 186, "a side tab for our Mining")
    miningTab._scripts.OnMouseUp(miningTab, "LeftButton", true)
    w:RunFor(1)
    H.eq(Listed(), "301", "changing tab clears the filters")
    H.check(window.Search._text == "" and not window.Filter._resetShown, "and the search")
    H.check(#H.MenuOf(window.Filter) == 2, "a gathering profession has no Slots entry, like the game's")
    window.Tabs[1]._scripts.OnMouseUp(window.Tabs[1], "LeftButton", true)
    H.eq(Listed(), "201,202", "and back, still clear")
    me.ns.Viewer.Open("Bob")
    H.check(not window.Filter._resetShown and Listed() == "101,102,103,104,105", "Bob's recipes again, unfiltered")
    -- Opened on such a recipe (an order's), it is shown, its box ticked.
    me.ns.Viewer.OpenGuild(164, 106)
    H.check(Listed():find("106", 1, true) and window.Filter._resetShown, "opened on one, it shows")
    me.ns.Viewer.ShowKnownBy()
    local known = me.env.GuildProfessionsRecipesKnownBy
    local row = H.NewObject(me, "Frame")
    known.ScrollBox._view.init(row, known.ScrollBox._provider.elements[1])
    H.check(row.Name._text == "Bob" and row.Order._enabled == false
        and row.Order.reason == "It binds when it is made: its crafter could not give it to you.",
        "and who knows it cannot be asked for it")
    known._scripts.OnHide(known)
    me.ns.Viewer.Open("Bob")

    -- The search also looks at the item made and the reagents, like the game's.
    local function Search(text)
        window.Search._text = text
        window.Search._scripts.OnTextChanged(window.Search)
        w:RunFor(1)
    end
    Search("100104")
    H.eq(Listed(), "104", "search: the name of the item a recipe makes")
    w.unloaded[2840] = true
    Search("ITEM2840")
    H.eq(Listed(), "102", "search: a reagent's name, in any case, once the client has loaded it")
    Search("item2447")
    H.eq(Listed(), "101,103,104,105", "search: a reagent shared by several recipes")
    Search("")
    H.eq(#w.errors, 0, "filters: no Lua errors")
    for i = 1, math.min(#w.errors, 5) do
        print(w.errors[i])
    end
end

H.section("UI: the guild's recipes")
do
    local w = H.NewWorld({ seed = 61 })
    local alice = w:NewClient("Alice", { professions = { { sl = 164, r = 120, m = 150, spell = 2018, hasRecipes = true } } })
    local bob = w:NewClient("Bob", { professions = {
        { sl = 164, r = 60, m = 75, spell = 2018, hasRecipes = true },
        { sl = 197, r = 40, m = 75, spell = 3908, hasRecipes = true },
    } })
    w:Login(alice)
    w:Login(bob)
    w:RunFor(5)
    -- Both know Blacksmithing 12 and 13; only Alice 11, only Bob 14.
    w:OpenProfession(alice, 164, { 11, 12, 13, 14 }, { 11, 12, 13 })
    w:RunFor(1)
    w:CloseProfession(alice)
    w:OpenProfession(bob, 164, { 11, 12, 13, 14 }, { 12, 13, 14 })
    w:RunFor(1)
    w:CloseProfession(bob)
    w:OpenProfession(bob, 197, { 21, 22 }, { 21, 22 })
    w:RunFor(1)
    w:CloseProfession(bob)
    w:RunFor(200)

    alice.ns.Viewer.OpenGuild(164)
    local window = alice.env.GuildProfessionsRecipesViewer
    local function Listed()
        local ids = {}
        for _, element in ipairs(window.ScrollBox._provider.elements) do
            if not element.header then
                ids[#ids + 1] = element.recipeID
            end
        end
        table.sort(ids)
        return table.concat(ids, ",")
    end
    H.eq(Listed(), "11,12,13,14", "every recipe some member shared, once each")
    H.check(window.RankBar._shown == false, "no skill bar: a guild has no single skill")
    H.check((window.Updated._text or ""):find("Shared by 2", 1, true) ~= nil, "shared by both members")
    local detail = window.Detail
    H.check(detail.KnownBy.Text._text == "Known by 1 |4member:members;" and detail.WhoButton._shown ~= false,
        "how many know the selected recipe, ourselves included")
    -- Their names on hover.
    local lines = {}
    rawset(alice.env.GameTooltip, "AddLine", function(_, text)
        lines[#lines + 1] = text
    end)
    local function Hover()
        lines = {}
        detail.KnownBy._scripts.OnEnter(detail.KnownBy)
        return table.concat(lines, "|")
    end
    H.eq(Hover(), "Alice|Click to see who knows it.", "their names on hover")
    local function Select(recipeID)
        for _, element in ipairs(window.ScrollBox._provider.elements) do
            if element.recipeID == recipeID then
                local row = H.NewObject(alice, "Button")
                window.ScrollBox._view.init(row, element)
                row._scripts.OnClick(row)
            end
        end
    end
    Select(12)
    H.check(detail.KnownBy.Text._text == "Known by 2 |4member:members;" and Hover() == "Alice|Bob|Click to see who knows it.",
        "a recipe both know: both, online first, then by name")

    -- Everyone who knows it, in a window of its own.
    detail.WhoButton._scripts.OnClick(detail.WhoButton)
    local known = alice.env.GuildProfessionsRecipesKnownBy
    H.check(known and known._shown, "the button opens who knows it")
    -- What the recipe makes: its tooltip, and shift-click links it.
    local tooltipItem
    rawset(alice.env.GameTooltip, "SetItemByID", function(_, itemID)
        tooltipItem = itemID
    end)
    known.Item._scripts.OnEnter(known.Item)
    H.eq(tooltipItem, 100012, "pointing at the item shows its tooltip")
    alice.linked = nil
    alice.shiftDown = true
    known.Item._scripts.OnClick(known.Item)
    alice.shiftDown = false
    H.check(alice.linked ~= nil, "shift-click on it links the recipe")
    local function KnownRows()
        local rows = {}
        for _, element in ipairs(known.ScrollBox._provider.elements) do
            local row = H.NewObject(alice, "Frame")
            known.ScrollBox._view.init(row, element)
            rows[#rows + 1] = row
        end
        return rows
    end
    local rows = KnownRows()
    H.check(#rows == 2 and rows[1].Name._text == "Alice" and rows[2].Name._text == "Bob", "a row for each, with their name")
    H.check(rows[1].Whisper._enabled == false and rows[1].Order._enabled == false and rows[1].Order.reason == "This is you.",
        "nothing to do with ourselves")
    H.check(rows[2].Whisper._enabled ~= false and rows[2].Order._enabled ~= false, "Bob can be whispered and asked for an order")
    rows[2].Whisper._scripts.OnClick(rows[2].Whisper)
    H.eq(alice.whispered, "Bob", "Whisper opens a whisper to him")
    rows[2].Order._scripts.OnClick(rows[2].Order)
    local form = alice.env.GuildProfessionsRecipesOrderForm
    H.check(form._shown and form.Personal._checked and form.Target._text == "Bob" and (form.Recipe._text or ""):find("Item100012", 1, true),
        "Order opens the form, a personal order to him for this recipe")
    form.Cancel._scripts.OnClick(form.Cancel)
    -- The window follows the recipe selected.
    Select(11)
    H.check(#KnownRows() == 1 and known._shown, "another recipe selected: its own list")
    Select(12)
    -- Bob on 0.8 cannot get orders; offline, he cannot be whispered.
    local bobRecord = alice.ns.Data.CurrentGuild(false).members[bob.guid]
    local version = bobRecord.av
    bobRecord.av = 802
    w:Logout(bob)
    w:RunFor(5)
    Select(12)
    rows = KnownRows()
    H.check(rows[2].Name._text:find("Bob (Offline)", 1, true) and rows[2].Whisper._enabled == false
        and rows[2].Whisper.reason == "Bob is offline.", "offline: greyed, and no whisper")
    H.check(rows[2].Order._enabled == false and rows[2].Order.reason == "Bob needs version 0.9 or later to receive orders.",
        "on 0.8: no order, saying why")
    bobRecord.av = version
    w:Login(bob)
    w:RunFor(10)
    known._scripts.OnHide(known)
    -- Those online come first: seen by Bob, with Alice away.
    local aliceMember = bob.ns.Roster.members[alice.guid]
    aliceMember.on = false
    bob.ns.Viewer.OpenGuild(164)
    local bobWindow = bob.env.GuildProfessionsRecipesViewer
    for _, element in ipairs(bobWindow.ScrollBox._provider.elements) do
        if element.recipeID == 12 then
            local row = H.NewObject(bob, "Button")
            bobWindow.ScrollBox._view.init(row, element)
            row._scripts.OnClick(row)
        end
    end
    local order = {}
    for _, entry in ipairs(bobWindow.Detail.known) do
        order[#order + 1] = entry.name .. (entry.online and "" or " (away)")
    end
    H.eq(table.concat(order, ", "), "Bob, Alice (away)", "those online first, whatever their names")
    aliceMember.on = true

    local tabs = {}
    for _, tab in ipairs(window.Tabs) do
        if tab._shown then
            tabs[#tabs + 1] = tab
        end
    end
    H.eq(#tabs, 2, "side tabs for the guild's professions with recipes")
    H.check(tabs[1]._scale == 1 and tabs[1]._point[5] == -60, "at the game's size while they fit")
    tabs[2]._scripts.OnMouseUp(tabs[2], "LeftButton", true)
    H.eq(Listed(), "21,22", "another tab, another profession")

    alice.ns.Viewer.OpenMember(bob.guid, 164)
    H.check(Listed() == "12,13,14" and window.RankBar._shown ~= false, "a member's own recipes again, with their skill")
    H.eq(window.Detail.KnownBy.Text._text, "Also known by 1 |4member:members;", "and how many others know the recipe")
    alice.ns.Viewer.OpenGuild(129)
    H.eq(Listed(), "12,13,14", "a profession nobody shared does not open")
    H.eq(#w.errors, 0, "guild's recipes: no Lua errors")
    for i = 1, math.min(#w.errors, 5) do
        print(w.errors[i])
    end
end

H.section("UI: a guild with recipes of every profession")
do
    local w = H.NewWorld({ seed = 73 })
    -- Between them, Carol and Dave have recipes of all twelve professions.
    local carol = w:NewClient("Carol", { professions = {
        { sl = 164, r = 50, m = 75, spell = 2018, hasRecipes = true },
        { sl = 165, r = 50, m = 75, spell = 2108, hasRecipes = true },
        { sl = 171, r = 50, m = 75, spell = 2259, hasRecipes = true },
        { sl = 182, r = 50, m = 75, spell = 2366, hasRecipes = true },
        { sl = 185, r = 50, m = 75, spell = 2550, hasRecipes = true },
        { sl = 186, r = 50, m = 75, spell = 2575, hasRecipes = true },
    } })
    local dave = w:NewClient("Dave", { professions = {
        { sl = 197, r = 50, m = 75, spell = 3908, hasRecipes = true },
        { sl = 202, r = 50, m = 75, spell = 4036, hasRecipes = true },
        { sl = 333, r = 50, m = 75, spell = 7411, hasRecipes = true },
        { sl = 393, r = 50, m = 75, spell = 8613, hasRecipes = true },
        { sl = 129, r = 50, m = 75, spell = 3273, hasRecipes = true },
        { sl = 356, r = 50, m = 75, spell = 7620, hasRecipes = true },
    } })
    w:Login(carol)
    w:Login(dave)
    w:RunFor(5)
    for _, member in ipairs({ carol, dave }) do
        for _, prof in ipairs(member.professions) do
            w:OpenProfession(member, prof.sl, { prof.sl * 10 }, { prof.sl * 10 })
            w:RunFor(1)
            w:CloseProfession(member)
        end
    end
    w:RunFor(200)
    carol.ns.Viewer.OpenGuild(164)
    local window = carol.env.GuildProfessionsRecipesViewer
    local tabs = {}
    for _, tab in ipairs(window.Tabs or {}) do
        if tab._shown then
            tabs[#tabs + 1] = tab
        end
    end
    H.eq(#tabs, 12, "a side tab for each of the twelve professions")
    -- 12 tabs of 55 with 11 gaps of 2 make 682; 594 - 60 - 8 = 526 is left.
    local scale = tabs[1]._scale or 0
    H.check(math.abs(scale - 526 / 682) < 0.001, "scaled down together to fit the window's height")
    H.check(tabs[12]._scale == scale and math.abs(tabs[1]._point[5] * scale + 60) < 0.001, "the first one still 60 below the window's top")
    H.eq(#w.errors, 0, "every profession: no Lua errors")
    for i = 1, math.min(#w.errors, 5) do
        print(w.errors[i])
    end
end

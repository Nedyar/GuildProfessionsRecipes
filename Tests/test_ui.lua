local H = ...

local GUILD = "Test Guild"

-- A stand-in for Blizzard's roster: a member list with rows for every
-- roster member, a column display with six headers.
local function FakeCommunities(client)
    local world = client.world
    local frame = H.NewObject(client, "Frame")
    local list = H.NewObject(client, "Frame")
    rawset(frame, "MemberList", list)
    rawset(frame, "IsVisible", function()
        return true
    end)
    list.expandedDisplay = true
    rawset(list, "GetSelectedClubInfo", function()
        return { clubType = 2 }
    end)
    rawset(list, "GetGuildColumnIndex", function()
        return list.guildColumnIndex
    end)
    rawset(list, "RefreshLayout", function() end)
    list.ColumnDisplay = H.NewObject(client, "Frame")
    local headers = {}
    for i = 1, 6 do
        local header = H.NewObject(client, "Button")
        rawset(header, "GetID", function()
            return i
        end)
        rawset(header, "SetPoint", function(self, ...)
            self._lastPoint = { ... }
        end)
        headers[i] = header
    end
    list.ColumnDisplay.columnHeaders = {
        EnumerateActive = function()
            local i = 0
            return function()
                i = i + 1
                return headers[i]
            end
        end,
    }
    list.headers = headers
    list.columnInfo = { {}, {}, {}, {}, {}, {} }
    local rows = {}
    for _, member in ipairs(world.roster) do
        local row = H.NewObject(client, "Button")
        row.expanded = true
        row.isInvitation = false
        row.memberInfo = { guid = member.guid, name = member.short }
        rawset(row, "GetMemberInfo", function(self)
            return self.memberInfo
        end)
        rawset(row, "RefreshExpandedColumns", function() end)
        row.ProfessionHeader = H.NewObject(client, "Frame")
        row.ProfessionHeader:Hide()
        row.FactionButton = H.NewObject(client, "Button")
        row.FactionButton:Hide()
        row.Rank = H.NewObject(client, "FontString")
        row.Note = H.NewObject(client, "FontString")
        rawset(row.Note, "SetPoint", function(self, point, relative)
            self._right = relative
        end)
        rows[#rows + 1] = row
    end
    list.rows = rows
    list.ScrollBox = H.NewObject(client, "Frame")
    rawset(list.ScrollBox, "ForEachFrame", function(_, fn)
        for _, row in ipairs(rows) do
            fn(row)
        end
    end)
    return frame
end

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
local viewer = A.env.GuildRecipesViewer
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

H.section("UI: recipe window")
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
H.check((viewer.Detail.Name._text or ""):find("Recipe", 1, true) ~= nil, "selecting a recipe shows its details")
H.check((viewer.Detail.reagents[1].Text._text or ""):find("2 x Item2447", 1, true) ~= nil, "reagents are listed with their counts")
H.check((viewer.Detail.KnownBy._text or ""):find("Nobody", 1, true) ~= nil, "nobody else knows it")
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
viewer.Tabs[2]._scripts.OnClick(viewer.Tabs[2])
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
viewer.Tabs[1]._scripts.OnClick(viewer.Tabs[1])
H.check(#viewer.ScrollBox._provider.elements >= before, "a new recipe appears in the open window")

-- Slash commands.
A.env.SlashCmdList.GUILDRECIPES("status")
A.env.SlashCmdList.GUILDRECIPES("help")
A.env.SlashCmdList.GUILDRECIPES("language esES")
H.eq(A.ns.L["Professions"], "Profesiones", "/grecipes language switches the texts")
A.env.SlashCmdList.GUILDRECIPES("language dede")
H.eq(A.ns.L["Professions"], "Berufe", "a language code in any case")
H.eq(A.env.GuildRecipesDB.settings.locale, "deDE", "the language is remembered")
local printedBefore = #A.printed
A.env.SlashCmdList.GUILDRECIPES("language")
H.check((A.printed[#A.printed] or ""):find("zhTW", 1, true) ~= nil and #A.printed == printedBefore + 1, "without a code: the list of languages")
A.env.SlashCmdList.GUILDRECIPES("language xxXX")
H.eq(A.ns.LOCALE, "deDE", "an unknown code changes nothing")
A.env.SlashCmdList.GUILDRECIPES("language auto")
H.eq(A.ns.LOCALE, "enUS", "auto: back to the client's language")
H.eq(A.env.GuildRecipesDB.settings.locale, nil, "auto is not remembered as a code")
A.env.SlashCmdList.GUILDRECIPES("sync")
world:RunFor(30)
A.env.SlashCmdList.GUILDRECIPES("reset")
A.env.SlashCmdList.GUILDRECIPES("reset confirm")
H.check(A.env.GuildRecipesDB.guilds[GUILD].members[A.guid] ~= nil, "reset keeps our own record")
H.eq(A.env.GuildRecipesDB.guilds[GUILD].members[B.guid], nil, "reset forgets the others")

H.eq(#world.errors, 0, "UI: no Lua errors")
for i = 1, math.min(#world.errors, 5) do
    print(world.errors[i])
end

H.section("UI: probe report")
A.env.GetBuildInfo = function()
    return "1.60.1", "70170", "Oct 1 2026", 16001
end
A.env.SlashCmdList.GUILDRECIPES("probe burst")
world:RunFor(5)
local probe = A.env.GuildRecipesProbe
local report = probe and probe.Edit and probe.Edit._text or ""
H.check(report:find("== Own professions", 1, true) ~= nil, "the probe report opens")
H.check(report:find("section failed", 1, true) == nil, "every probe section runs")
H.check(report:find("whisper-name via WHISPER", 1, true) ~= nil and report:find("guild via GUILD", 1, true) ~= nil, "the probe hears its own pings")
H.check(report:find("burst of 12 GUILD pings", 1, true) ~= nil, "the burst test runs")
H.eq(#world.errors, 0, "probe: no Lua errors")
for i = 1, math.min(#world.errors, 5) do
    print(world.errors[i])
end
if os.getenv("SHOW_PROBE") then
    print(report)
end

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
    named.env.SlashCmdList.GUILDRECIPES("bob jones")
    local window = named.env.GuildRecipesViewer
    H.check(window ~= nil and window._shown, "/grecipes with a name that has a space opens the window")
    H.check(window and (window.ScrollBox._provider.elements[2] or {}).recipeID == 10, "showing that member's recipes")
    H.eq(#w.errors, 0, "names with spaces: no Lua errors")
    for i = 1, math.min(#w.errors, 5) do
        print(w.errors[i])
    end
end

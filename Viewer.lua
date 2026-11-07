-- Viewer.lua: a guild member's professions, from the saved data, so it works
-- while that member is offline. Our own professions open in the game's own
-- window instead when clicked in the roster.
--
-- The window copies the game's own profession window in WoW Forever
-- (Blizzard_Professions, measured in game): its frame, art, recipe list,
-- recipe panel and side tabs. In place of its crafting controls, a button
-- for crafting orders, disabled until a later version.
--
-- Recipes are stored as IDs only; names, icons, reagents and categories are
-- looked up on this client, in its own language. Lookups the client cannot
-- answer yet (data not cached) are requested and the window redraws when
-- they arrive.
local _, ns = ...
local L = ns.L

local Viewer = {}
ns.Viewer = Viewer

-- Sizes of the game's own window in WoW Forever.
local WIDTH, HEIGHT = 673, 594
local LIST_WIDTH = 304
local PANEL_WIDTH, PANEL_HEIGHT = 360, 484
local PANEL_RIGHT_GAP = WIDTH - 5 - LIST_WIDTH - 2 - PANEL_WIDTH  -- 2: the panel's right edge to the frame's
local ROW_WIDTH = 270
local HEADER_HEIGHT, RECIPE_HEIGHT = 25, 20
local RECIPE_INDENT = 10
-- The list's spacer rows: one of 1 pixel under an open category, one of 10
-- after its last recipe (each with the list's 1 pixel spacing).
local GROUP_TOP_PADDING, GROUP_BOTTOM_PADDING = 2, 11
local RANK_BAR_WIDTH, RANK_FILL_WIDTH = 453, 441
local FLIPBOOK_FRAME_HEIGHT, FLIPBOOK_COLUMNS = 34, 2
local REAGENT_ROWS = 4  -- reagents fill a column of four, then the next
local REAGENT_WIDTH, REAGENT_HEIGHT, REAGENT_GAP = 160, 49, 5
local MAX_REAGENTS = 8
local MAX_TABS = 8
local MAX_KNOWN_BY = 12
local UNKNOWN_ICON = 134400
local REAGENT_MASK = 2922105         -- the rounded square that crops reagent icons
local SLOT_BORDER = 130841           -- Interface\Buttons\UI-Quickslot2
local SLOT_HIGHLIGHT = 130718        -- Interface\Buttons\ButtonHilight-Square

local TradeSkill = C_TradeSkillUI or {}
local REAGENT_BASIC = Enum.CraftingReagentType and Enum.CraftingReagentType.Basic or 1

-- The order of the Slots filter: the game's inventory types. Types with the
-- same name (Chest and Robe) share one entry.
local SLOT_TYPES = { "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CLOAK", "INVTYPE_CHEST",
    "INVTYPE_ROBE", "INVTYPE_BODY", "INVTYPE_TABARD", "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_WAIST", "INVTYPE_LEGS",
    "INVTYPE_FEET", "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_WEAPON", "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND",
    "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD", "INVTYPE_HOLDABLE", "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT",
    "INVTYPE_THROWN", "INVTYPE_AMMO", "INVTYPE_RELIC", "INVTYPE_BAG", "INVTYPE_QUIVER" }
local SLOT_ORDER = {}
for i, equipLoc in ipairs(SLOT_TYPES) do
    SLOT_ORDER[equipLoc] = i
end
-- Other inventory types after those, then the game's "Created Items" entry
-- for items that are not worn.
local OTHER_SLOT_ORDER = #SLOT_TYPES + 1
local CREATED_ITEMS_ORDER = #SLOT_TYPES + 2
-- Professions the game gives no Slots filter (Professions.GetProfessionType).
local GATHERING = { Mining = true, Herbalism = true, Skinning = true, Fishing = true }

local frame
local state = { key = nil, skillLine = nil, recipeID = nil, search = "", slots = {} }
-- The Filter menu. Like the game's, it stays as set while the window is
-- closed and across professions, until /reload.
local filters = { makeable = false, hiddenSlots = {} }  -- hiddenSlots[slot name] = true
local collapsed = {}   -- [group key] = true
local recipeInfo = {}  -- [recipeID] = resolved name, icon, item...
local requested = {}   -- [recipeID] = true once its spell data was asked for
local requestedItems = {}  -- [itemID] = true once its data was asked for
local kits = {}        -- [skill line] = the profession's art name, or false

-- Colors and texts of the game, with their English values where they are
-- missing (the offline tests).
local function Color(color, r, g, b)
    return color or { GetRGB = function()
        return r, g, b
    end }
end

local function Paint(text, color)
    local r, g, b = color:GetRGB()
    return ("|cff%02x%02x%02x%s|r"):format(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), text)
end

local function GoldColor()
    return Color(NORMAL_FONT_COLOR, 1, 0.82, 0)
end

local function WhiteColor()
    return Color(HIGHLIGHT_FONT_COLOR, 1, 1, 1)
end

local function RecipeColor()
    return Color(PROFESSION_RECIPE_COLOR, 0.89, 0.86, 0.84)
end

local function MissingReagentColor()
    return Color(DISABLED_REAGENT_COLOR or DISABLED_FONT_COLOR, 0.5, 0.5, 0.5)
end

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

-- The name over the recipe panel: the item it makes, in its quality's color,
-- or the recipe's name in gold.
local function OutputName(recipeID, info)
    local itemName = info.itemID and C_Item.GetItemNameByID(info.itemID)
    if itemName and itemName ~= "" and info.quality then
        local _, _, _, hex = C_Item.GetItemQualityColor(info.quality)
        if hex then
            return "|c" .. hex .. itemName .. "|r"
        end
    end
    return Paint(DisplayName(recipeID, info), GoldColor())
end

-- The group a recipe is listed under: its profession category when known,
-- else the kind of item it makes. Returns key, name, order.
local function GroupOf(recipeID, info)
    local cache = ns.db.cache
    -- Away from the profession window the game says 0: use the one noted
    -- while a window was open.
    local categoryID = info.categoryID
    if not categoryID or categoryID <= 0 then
        categoryID = cache.recCat[recipeID]
    end
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

-- What a recipe takes: { itemID, quantity } for each basic reagent, or nil
-- when the game gives no schematic for it.
local function BasicReagents(schematic)
    if type(schematic) ~= "table" then
        return nil
    end
    local reagents = {}
    if type(schematic.reagentSlotSchematics) == "table" then
        for _, slot in ipairs(schematic.reagentSlotSchematics) do
            local reagent = slot.reagents and slot.reagents[1]
            if reagent and reagent.itemID and (slot.reagentType == nil or slot.reagentType == REAGENT_BASIC) then
                reagents[#reagents + 1] = { itemID = reagent.itemID, quantity = slot.quantityRequired or 1 }
            end
        end
    end
    return reagents
end

-- Filters ---------------------------------------------------------------------------

-- An item's name, or nil while the client loads it (the window redraws
-- when it arrives).
local function ItemName(itemID)
    local name = C_Item.GetItemNameByID(itemID)
    if not name and not requestedItems[itemID] then
        requestedItems[itemID] = true
        C_Item.RequestLoadItemDataByID(itemID)
    end
    return name
end

-- Whether the search text (lower case) is in the recipe's name, the item
-- it makes or one of its reagents, as the game's search looks.
local function MatchesSearch(search, name, info)
    if search == "" or name:lower():find(search, 1, true) then
        return true
    end
    local itemName = info.itemID and ItemName(info.itemID)
    if itemName and itemName:lower():find(search, 1, true) then
        return true
    end
    for _, reagent in ipairs(BasicReagents(info.schematic) or {}) do
        local reagentName = ItemName(reagent.itemID)
        if reagentName and reagentName:lower():find(search, 1, true) then
            return true
        end
    end
    return false
end

-- Whether we carry everything the recipe takes, as its reagents show.
local function HaveMaterials(info)
    local reagents = BasicReagents(info.schematic)
    if not reagents then
        return false
    end
    for _, reagent in ipairs(reagents) do
        if (ns.Try(C_Item.GetItemCount, reagent.itemID) or 0) < reagent.quantity then
            return false
        end
    end
    return true
end

-- The Slots entry of the item the recipe makes, as { name, order }: where
-- it is worn, or "Created Items" when it is not. Nil for recipes that make
-- no item (enchantments), which no slot hides.
local function SlotOf(info)
    if info.slot == nil and info.itemID then
        local equipLoc = select(4, C_Item.GetItemInfoInstant(info.itemID))
        local name = type(equipLoc) == "string" and equipLoc ~= "" and _G[equipLoc]
        if type(name) == "string" and name ~= "" then
            info.slot = { name = name, order = SLOT_ORDER[equipLoc] or OTHER_SLOT_ORDER }
        else
            info.slot = { name = NONEQUIPSLOT or "Created Items", order = CREATED_ITEMS_ORDER }
        end
    end
    return info.slot
end

-- useSlots: false for gathering professions, which have no Slots entry.
local function PassesFilters(info, useSlots)
    if filters.makeable and not HaveMaterials(info) then
        return false
    end
    local slot = useSlots and SlotOf(info)
    return not (slot and filters.hiddenSlots[slot.name])
end

-- The slots the profession's recipes make, in the game's order.
local function SlotsOf(prof)
    local slots, seen = {}, {}
    for _, recipeID in ipairs(prof.k) do
        local slot = SlotOf(ResolveRecipe(recipeID))
        if slot and not seen[slot.name] then
            seen[slot.name] = true
            slots[#slots + 1] = slot
        end
    end
    table.sort(slots, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.name < b.name
    end)
    return slots
end

local function FiltersAreDefault()
    if filters.makeable then
        return false
    end
    -- Slots hidden in another profession do not count here.
    for _, slot in ipairs(state.slots) do
        if filters.hiddenSlots[slot.name] then
            return false
        end
    end
    return true
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

local function RecordOf(key)
    local guild = ns.Data.CurrentGuild(false)
    return guild and key and guild.members[key]
end

local function CurrentRecord()
    return RecordOf(state.key)
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

local function ShowItemTooltip(owner, itemID, recipeID)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if itemID then
        GameTooltip:SetItemByID(itemID)
    elseif recipeID then
        GameTooltip:SetSpellByID(recipeID)
    end
    GameTooltip:Show()
end

-- Profession art ----------------------------------------------------------------

-- The profession's name in the game's art names ("Leatherworking" in
-- "Profession-background-card-Leatherworking"), or nil.
local function KitOf(skillLine)
    if kits[skillLine] == nil then
        local kit = false
        local info = ns.Try(TradeSkill.GetProfessionInfoBySkillLineID, skillLine)
        local profession = type(info) == "table" and ns.Plain(info.profession)
        if profession and Enum.Profession then
            for name, value in pairs(Enum.Profession) do
                if value == profession then
                    kit = name
                end
            end
        end
        kits[skillLine] = kit
    end
    return kits[skillLine] or nil
end

local function AtlasFor(format, kit, fallback)
    local name = kit and format:format(kit)
    if name and C_Texture.GetAtlasInfo(name) then
        return name
    end
    return fallback
end

-- The skill bar under the title: the profession's own fill, cut to the
-- skill reached. The fill is a flipbook; its last frame is shown.
local function UpdateRankBar(bar, skillLine, name, rank, maxRank)
    bar.Text:SetText((TRADESKILL_NAME_RANK or "%s %d/%d"):format(name, rank, maxRank))
    local kit = KitOf(skillLine)
    local fillAtlas = AtlasFor("Skillbar_Fill_Flipbook_%s", kit, "Skillbar_Fill_Flipbook_DefaultBlue")
    local fill = C_Texture.GetAtlasInfo(fillAtlas)
    local ratio = maxRank > 0 and math.min(rank / maxRank, 1) or 0
    local width = math.min(RANK_FILL_WIDTH, RANK_BAR_WIDTH * ratio)
    if fill and width >= 1 then
        local rows = math.max(1, math.floor(fill.height / FLIPBOOK_FRAME_HEIGHT + 0.5))
        local cellWidth = (fill.rightTexCoord - fill.leftTexCoord) / FLIPBOOK_COLUMNS
        local cellHeight = (fill.bottomTexCoord - fill.topTexCoord) / rows
        local left = fill.leftTexCoord + cellWidth * (FLIPBOOK_COLUMNS - 1)
        local top = fill.topTexCoord + cellHeight * (rows - 1)
        bar.Fill:SetTexture(fill.file)
        bar.Fill:SetTexCoord(left, left + cellWidth * width / RANK_FILL_WIDTH, top, top + cellHeight)
        bar.Fill:SetWidth(width)
        bar.Fill:Show()
    else
        bar.Fill:Hide()
    end
    local flare = AtlasFor("Skillbar_Flare_%s", kit, nil)
    if flare then
        bar.Flare:SetAtlas(flare)
    end
    bar.Flare:SetShown(flare ~= nil and width >= 1 and ratio < 1)
end

-- Our own professions in the game's window ---------------------------------------

-- Whether a click on this profession opens the game's own window instead:
-- only for our own professions, and those that have a window.
function Viewer.OpensInGame(key, skillLine)
    local record = RecordOf(key)
    local prof = record and record.p[skillLine]
    return key == ns.playerGUID and prof ~= nil and prof.k ~= false and TradeSkill.OpenTradeSkill ~= nil
end

-- Recipe list -------------------------------------------------------------------

local Refresh

local function BuildList(prof)
    local groups, byKey = {}, {}
    local search = state.search:lower()
    local shown = 0
    -- Like the game's, no Slots entry for a gathering profession.
    local useSlots = not GATHERING[KitOf(state.skillLine)]
    state.slots = useSlots and SlotsOf(prof) or {}
    for _, recipeID in ipairs(prof.k) do
        local info = ResolveRecipe(recipeID)
        local name = DisplayName(recipeID, info)
        if MatchesSearch(search, name, info) and PassesFilters(info, useSlots) then
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
            elements[#elements].last = true
        end
    end
    return elements, shown
end

local function ExtentOf(data)
    if data.header then
        return HEADER_HEIGHT + (data.collapsed and 0 or GROUP_TOP_PADDING)
    end
    return RECIPE_HEIGHT + (data.last and GROUP_BOTTOM_PADDING or 0)
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
    if SOUNDKIT.UI_90_BLACKSMITHING_TREEITEMCLICK then
        PlaySound(SOUNDKIT.UI_90_BLACKSMITHING_TREEITEMCLICK)
    end
    state.recipeID = data.recipeID
    Refresh(true)
end

local function RowOnEnter(row)
    if not row.data then
        return
    end
    if row.data.header then
        row.Title:SetTextColor(WhiteColor():GetRGB())
    else
        row.Label:SetTextColor(WhiteColor():GetRGB())
        if row.Label:IsTruncated() then
            GameTooltip:SetOwner(row.Label, "ANCHOR_RIGHT")
            GameTooltip:SetText(row.data.name, 1, 1, 1)
            GameTooltip:Show()
        end
    end
end

local function RowOnLeave(row)
    if row.data then
        row.Title:SetTextColor(GoldColor():GetRGB())
        row.Label:SetTextColor(RecipeColor():GetRGB())
    end
    GameTooltip_Hide()
end

-- One kind of row for the whole list: a category (Blizzard's collapsible
-- list header) or a recipe, drawn like the game's own.
local function InitRow(row, data)
    if not row.Label then
        row:RegisterForClicks("LeftButtonUp")

        row.HeaderArt = row:CreateTexture(nil, "ARTWORK")
        row.HeaderArt:SetAtlas("common-button-list-collapseExpand")
        row.HeaderArt:SetPoint("TOPLEFT")
        row.HeaderArt:SetPoint("TOPRIGHT")
        row.HeaderArt:SetHeight(HEADER_HEIGHT)
        row.HeaderGlow = row:CreateTexture(nil, "HIGHLIGHT")
        row.HeaderGlow:SetAtlas("common-button-list-collapseExpand")
        row.HeaderGlow:SetBlendMode("ADD")
        row.HeaderGlow:SetAlpha(0.4)
        row.HeaderGlow:SetAllPoints(row.HeaderArt)
        row.Toggle = row:CreateTexture(nil, "ARTWORK", nil, 1)
        row.Toggle:SetPoint("CENTER", row, "TOPRIGHT", -16, -HEADER_HEIGHT / 2)
        row.Title = row:CreateFontString(nil, "ARTWORK", "Game15Font_Shadow")
        row.Title:SetPoint("LEFT", row, "TOPLEFT", 8, -HEADER_HEIGHT / 2)
        row.Title:SetPoint("RIGHT", row, "TOPRIGHT", -30, -HEADER_HEIGHT / 2)
        row.Title:SetJustifyH("LEFT")
        row.Title:SetWordWrap(false)

        local center = RECIPE_INDENT + (ROW_WIDTH - RECIPE_INDENT) / 2
        row.Selected = row:CreateTexture(nil, "OVERLAY", nil, 2)
        row.Selected:SetAtlas("Professions_Recipe_Active", true)
        row.Selected:SetPoint("CENTER", row, "TOPLEFT", center, -RECIPE_HEIGHT / 2 - 1)
        row.Hover = row:CreateTexture(nil, "HIGHLIGHT")
        row.Hover:SetAtlas("Professions_Recipe_Hover", true)
        row.Hover:SetAlpha(0.5)
        row.Hover:SetPoint("CENTER", row, "TOPLEFT", center, -RECIPE_HEIGHT / 2 - 1)
        row.Label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight_NoShadow")
        row.Label:SetPoint("LEFT", row, "TOPLEFT", RECIPE_INDENT + 22, -RECIPE_HEIGHT / 2)
        row.Label:SetPoint("RIGHT", row, "TOPRIGHT", -8, -RECIPE_HEIGHT / 2)
        row.Label:SetJustifyH("LEFT")
        row.Label:SetWordWrap(false)

        row:SetScript("OnClick", RowOnClick)
        row:SetScript("OnEnter", RowOnEnter)
        row:SetScript("OnLeave", RowOnLeave)
    end
    row.data = data
    local header = data.header == true
    local selected = not header and data.recipeID == state.recipeID
    row.HeaderArt:SetShown(header)
    row.HeaderGlow:SetShown(header)
    row.Toggle:SetShown(header)
    row.Title:SetShown(header)
    row.Label:SetShown(not header)
    row.Selected:SetShown(selected)
    row.Hover:SetShown(not header and not selected)
    if header then
        row.Toggle:SetAtlas(data.collapsed and "common-button-list-plus" or "common-button-list-minus", true)
        row.Title:SetText(data.name)
        row.Title:SetTextColor(GoldColor():GetRGB())
    else
        row.Label:SetText(data.name)
        row.Label:SetTextColor(RecipeColor():GetRGB())
    end
end

-- Recipe panel ----------------------------------------------------------------------

-- Tools and places the recipe needs; the ones missing where we stand in red.
local function RequiredTools(recipeID)
    local requirements = ns.Try(TradeSkill.GetRecipeRequirements, recipeID)
    if type(requirements) ~= "table" or #requirements == 0 then
        return nil
    end
    local names = {}
    for _, requirement in ipairs(requirements) do
        local name = ns.Plain(requirement.name)
        if type(name) == "string" and name ~= "" then
            names[#names + 1] = requirement.met == false and Paint(name, Color(RED_FONT_COLOR, 1, 0.13, 0.13)) or name
        end
    end
    if #names == 0 then
        return nil
    end
    return (PROFESSIONS_REQUIRED_TOOLS or "Requires: %s"):format(table.concat(names, ", "))
end

local function ShowReagents(detail, recipeID, info)
    local schematic = info.schematic
    local reagents = BasicReagents(schematic) or {}
    detail.ReagentsTitle:SetShown(#reagents > 0)
    detail.NoReagents:SetShown(schematic == nil)
    for i, slot in ipairs(detail.reagents) do
        local reagent = reagents[i]
        if reagent then
            slot.itemID = reagent.itemID
            slot.Button.Icon:SetTexture(C_Item.GetItemIconByID(reagent.itemID) or UNKNOWN_ICON)
            -- Like the game's own: what we carry over what it takes.
            local function SetName()
                if state.recipeID ~= recipeID then
                    return
                end
                local have = ns.Try(C_Item.GetItemCount, reagent.itemID) or 0
                local name = C_Item.GetItemNameByID(reagent.itemID) or RETRIEVING_ITEM_INFO or "..."
                local text = (TRADESKILL_REAGENT_COUNT or "%s/%d"):format(have, reagent.quantity) .. " " .. name
                slot.Text:SetText(Paint(text, have >= reagent.quantity and WhiteColor() or MissingReagentColor()))
            end
            SetName()
            if not C_Item.GetItemNameByID(reagent.itemID) then
                Item:CreateFromItemID(reagent.itemID):ContinueOnItemLoad(SetName)
            end
            slot:Show()
        else
            slot.itemID = nil
            slot:Hide()
        end
    end
    -- What comes after the reagents starts under their longest column.
    local rows = math.min(#reagents, REAGENT_ROWS)
    local height = rows > 0 and (20 + rows * REAGENT_HEIGHT + (rows - 1) * REAGENT_GAP) or 20
    detail.KnownBy:ClearAllPoints()
    detail.KnownBy:SetPoint("TOPLEFT", detail.Reagents, "TOPLEFT", 0, -height - 16)
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
    local icon = detail.Icon
    icon.Icon:SetTexture(info.icon or UNKNOWN_ICON)
    if SetItemButtonQuality then
        SetItemButtonQuality(icon, info.quality or 1, info.itemID)
    end
    local schematic = info.schematic
    local quantityMin, quantityMax = schematic and schematic.quantityMin or 1, schematic and schematic.quantityMax or 1
    if quantityMax > 1 then
        icon.Amount:SetText(quantityMin == quantityMax and tostring(quantityMax) or ("%d-%d"):format(quantityMin, quantityMax))
        icon.AmountShadow:Show()
    else
        icon.Amount:SetText("")
        icon.AmountShadow:Hide()
    end
    detail.Name:SetText(OutputName(recipeID, info))
    local tools = RequiredTools(recipeID)
    detail.Tools:SetText(tools or "")
    detail.Tools:SetShown(tools ~= nil)
    -- The recipe's description, or its spell's ("Craft a Camp Tent.").
    local description = ns.Try(TradeSkill.GetRecipeDescription, recipeID, {}, nil)
    if type(description) ~= "string" or description == "" then
        description = ns.Try(C_Spell.GetSpellDescription, recipeID)
    end
    detail.Description:SetText(type(description) == "string" and description or "")
    ShowReagents(detail, recipeID, info)
    local names = KnownBy(recipeID)
    detail.KnownBy:SetText(#names > 0 and L["Also known by: %s"]:format(table.concat(names, ", ")) or L["Nobody else in the guild is known to have this recipe."])
end

-- Header, tabs, status --------------------------------------------------------------

local function UpdateHeader(record, prof)
    local name = ns.ProfessionName(state.skillLine, prof.lk)
    frame:SetPortraitToAsset(ns.ProfessionIcon(state.skillLine, prof.lk))
    local title = (TRADE_SKILL_TITLE or "%s"):format(name)
    if state.key ~= ns.playerGUID then
        -- As the game titles a profession seen through a link.
        title = ("%s %s[%s]|r"):format(title, HIGHLIGHT_FONT_COLOR_CODE or "|cffffffff", ns.Data.NameOf(state.key, record))
    end
    frame:SetTitle(title)
    UpdateRankBar(frame.RankBar, state.skillLine, name, prof.r, prof.m)
    frame.Detail.Background:SetAtlas(AtlasFor("Profession-background-card-%s", KitOf(state.skillLine), "Professions-Recipe-Background"))

    -- Where these recipes come from.
    local source = state.key == ns.playerGUID and L["your own data"] or (record.fh and L["from the member"] or L["passed on by the guild"])
    frame.Updated:SetText(("%s · %s (%s)"):format(Paint(L["Saved data"], GoldColor()), L["Updated %s ago"]:format(ns.Ago(record.t)), source))
end

local function UpdateTabs(record)
    local professions = ListedProfessions(record)
    frame.Tabs = frame.Tabs or {}
    for i = 1, math.min(#professions, MAX_TABS) do
        local tab = frame.Tabs[i]
        if not tab then
            tab = CreateFrame("Frame", nil, frame, "LargeSideTabButtonTemplate")
            if i == 1 then
                tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -60)
            else
                tab:SetPoint("TOPLEFT", frame.Tabs[i - 1], "BOTTOMLEFT", 0, -2)
            end
            tab:SetFillToInterior(true)
            tab:EnableMouse(true)
            tab:HookScript("OnMouseUp", function(self, button, upInside)
                if button == "LeftButton" and upInside ~= false and self.skillLine ~= state.skillLine then
                    state.skillLine, state.recipeID = self.skillLine, nil
                    Refresh()
                end
            end)
            frame.Tabs[i] = tab
        end
        local prof = professions[i]
        tab.skillLine = prof.sl
        tab.tooltipText = ns.ProfessionName(prof.sl, prof.lk)
        tab.Icon:SetTexture(ns.ProfessionIcon(prof.sl, prof.lk))
        tab:SetChecked(prof.sl == state.skillLine)
        tab:Show()
    end
    for i = #professions + 1, #frame.Tabs do
        frame.Tabs[i]:Hide()
    end
end

-- The first recipe of the list, as the game selects one when its window opens.
local function FirstRecipe(elements)
    for _, element in ipairs(elements) do
        if not element.header then
            return element.recipeID
        end
    end
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
    local elements, shown = BuildList(prof)
    if not (state.recipeID and Contains(prof.k, state.recipeID)) then
        state.recipeID = FirstRecipe(elements)
    end
    UpdateHeader(record, prof)
    UpdateTabs(record)
    frame.Count:SetText(L["%d of %d |4recipe:recipes;"]:format(shown, #prof.k))
    frame.Count:SetShown(shown == 0)
    frame.Filter:ValidateResetState()
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

-- The Filter menu: the game's own entries that make sense on saved recipes.
-- Its "Has skill up" is left out. "Have Materials" is about what we carry,
-- as the reagents show.
local function IsMakeableChecked()
    return filters.makeable
end

local function ToggleMakeable()
    filters.makeable = not filters.makeable
    Refresh()
end

local function IsSlotShown(name)
    return not filters.hiddenSlots[name]
end

local function ToggleSlot(name)
    filters.hiddenSlots[name] = not filters.hiddenSlots[name] or nil
    Refresh()
end

local function SetAllSlots(hidden)
    for _, slot in ipairs(state.slots) do
        filters.hiddenSlots[slot.name] = hidden or nil
    end
    Refresh()
    -- The submenu stays open, its boxes redrawn.
    return MenuResponse and MenuResponse.Refresh
end

local function SetupFilterMenu(_, root)
    local makeableText = CRAFT_IS_MAKEABLE or "Have Materials"
    local makeable = root:CreateCheckbox(makeableText, IsMakeableChecked, ToggleMakeable)
    if makeable and makeable.SetTitleAndTextTooltip then
        makeable:SetTitleAndTextTooltip(makeableText, L["Only recipes whose reagents you carry in your bags."])
    end
    -- Not for gathering professions, nor for one that makes no items.
    if #state.slots > 0 then
        local submenu = root:CreateButton(TRADESKILL_FILTER_SLOTS or "Slots")
        submenu:CreateButton(CHECK_ALL or "Check All", SetAllSlots, false)
        submenu:CreateButton(UNCHECK_ALL or "Uncheck All", SetAllSlots, true)
        for _, slot in ipairs(state.slots) do
            submenu:CreateCheckbox(slot.name, IsSlotShown, ToggleSlot, slot.name)
        end
    end
end

local function ResetFilters()
    filters.makeable = false
    wipe(filters.hiddenSlots)
    Refresh()
end

-- A button like the game's red ones, sized to its text.
local function RedButton(parent, text)
    local button = CreateFrame("Button", nil, parent, "SharedButtonSmallTemplate")
    button:SetText(text)
    button:SetWidth(math.max(80, button:GetTextWidth() + 30))
    return button
end

local function CreateRankBar(page)
    local bar = CreateFrame("Frame", nil, page)
    bar:SetSize(RANK_BAR_WIDTH, 18)
    bar:SetPoint("TOPLEFT", 110, -40)
    bar.Background = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    bar.Background:SetAtlas("Professions-skillbar-bg", true)
    bar.Background:SetPoint("TOPLEFT")
    bar.Fill = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    bar.Fill:SetSize(RANK_FILL_WIDTH, 18)
    bar.Fill:SetPoint("TOPLEFT", 5, -3)
    bar.Flare = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    bar.Flare:SetSize(53, 16)
    bar.Flare:SetBlendMode("ADD")
    bar.Flare:SetPoint("RIGHT", bar.Fill, "RIGHT")
    bar.Border = bar:CreateTexture(nil, "ARTWORK", nil, 3)
    bar.Border:SetAtlas("Professions-skillbar-frame", true)
    bar.Border:SetPoint("TOPLEFT")
    bar.Text = bar:CreateFontString(nil, "OVERLAY", "Number12FontOutline")
    bar.Text:SetPoint("CENTER", 0, -3)
    return bar
end

local function CreateRecipeList(page)
    local list = CreateFrame("Frame", nil, page)
    list:SetPoint("TOPLEFT", 5, -72)
    list:SetPoint("BOTTOMLEFT", 5, 5)
    list:SetWidth(LIST_WIDTH)
    list.Background = list:CreateTexture(nil, "BACKGROUND")
    list.Background:SetAtlas("Professions-background-summarylist")
    list.Background:SetAllPoints()

    -- The game's Filter button, with its reset button.
    local filter = CreateFrame("DropdownButton", nil, list, "WowStyle1FilterDropdownTemplate")
    filter:SetPoint("TOPRIGHT", -8, -9)
    filter:SetDefaultCallback(ResetFilters)
    filter:SetIsDefaultCallback(FiltersAreDefault)
    filter:SetupMenu(SetupFilterMenu)
    frame.Filter = filter

    local search = CreateFrame("EditBox", nil, list, "SearchBoxTemplate")
    search:SetHeight(20)
    search:SetPoint("TOPLEFT", 13, -8)
    search:SetPoint("RIGHT", filter, "LEFT", -4, 0)
    search:HookScript("OnTextChanged", function(self)
        state.search = self:GetText() or ""
        ns.Debounce("ViewerSearch", 0.2, Refresh)
    end)
    frame.Search = search

    local scrollBox = CreateFrame("Frame", nil, list, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", 8, -35)
    scrollBox:SetPoint("BOTTOMRIGHT", -20, 5)
    local scrollBar = CreateFrame("EventFrame", nil, list, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 0, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 0, 0)
    local view = CreateScrollBoxListLinearView(5, 5, 0, 5, 1)
    view:SetElementExtentCalculator(function(_, data)
        return ExtentOf(data)
    end)
    view:SetElementInitializer("Button", InitRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    frame.ScrollBox = scrollBox

    -- Shown when a search finds nothing.
    frame.Count = list:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.Count:SetWidth(200)
    frame.Count:SetPoint("TOP", 0, -60)
    return list
end

local function CreateReagentSlot(parent, index)
    local slot = CreateFrame("Frame", nil, parent)
    slot:SetSize(REAGENT_WIDTH, REAGENT_HEIGHT)
    local column, row = math.floor((index - 1) / REAGENT_ROWS), (index - 1) % REAGENT_ROWS
    slot:SetPoint("TOPLEFT", 1 + column * (REAGENT_WIDTH + REAGENT_GAP), -20 - row * (REAGENT_HEIGHT + REAGENT_GAP))

    local button = CreateFrame("Button", nil, slot)
    button:SetSize(39, 39)
    button:SetPoint("LEFT")
    button.Background = button:CreateTexture(nil, "BACKGROUND")
    button.Background:SetAtlas("Professions-Slot-bg")
    button.Background:SetAllPoints()
    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetAllPoints()
    local mask = button:CreateMaskTexture()
    mask:SetTexture(REAGENT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(button.Icon)
    button.Icon:AddMaskTexture(mask)
    button.Slot = button:CreateTexture(nil, "BORDER")
    button.Slot:SetTexture(SLOT_BORDER)
    button.Slot:SetSize(64, 64)
    button.Slot:SetPoint("CENTER")
    button.Frame = button:CreateTexture(nil, "OVERLAY")
    button.Frame:SetAtlas("Professions-Slot-Frame")
    button.Frame:SetSize(40, 40)
    button.Frame:SetPoint("TOPLEFT")
    button:SetHighlightTexture(SLOT_HIGHLIGHT, "ADD")
    button:SetScript("OnEnter", function(self)
        if slot.itemID then
            ShowItemTooltip(self, slot.itemID)
        end
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:SetScript("OnClick", function()
        if slot.itemID and IsModifiedClick("CHATLINK") then
            InsertLink(select(2, C_Item.GetItemInfo(slot.itemID)))
        end
    end)
    slot.Button = button

    slot.Text = slot:CreateFontString(nil, "BORDER", "GameFontHighlight_NoShadow")
    slot.Text:SetSize(108, 36)
    slot.Text:SetPoint("LEFT", 46, 0)
    slot.Text:SetJustifyH("LEFT")
    return slot
end

local function CreatePanel(page, list)
    local detail = CreateFrame("Frame", nil, page)
    detail:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    detail:SetPoint("TOPLEFT", list, "TOPRIGHT", 2, 0)
    detail.Background = detail:CreateTexture(nil, "BACKGROUND")
    detail.Background:SetAllPoints()
    detail.Border = detail:CreateTexture(nil, "BORDER")
    detail.Border:SetAtlas("common-insideframe")
    detail.Border:SetAllPoints()
    frame.Detail = detail

    detail.Empty = detail:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    detail.Empty:SetPoint("CENTER")
    detail.Empty:SetText(L["Select a recipe."])

    local content = CreateFrame("Frame", nil, detail)
    content:SetAllPoints()
    detail.Content = content

    -- The item the recipe makes.
    local icon = CreateFrame("Button", nil, content, "CircularGiantItemButtonTemplate")
    icon:SetSize(47, 47)
    icon:SetPoint("TOPLEFT", 28, -28)
    icon.Icon:SetSize(53, 53)
    icon.Amount = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
    icon.Amount:SetPoint("BOTTOM", icon, "BOTTOMRIGHT", -4, 1)
    icon.AmountShadow = icon:CreateTexture(nil, "OVERLAY", nil, 3)
    icon.AmountShadow:SetAtlas("BattleBar-SwapPetShadow")
    icon.AmountShadow:SetAlpha(0.8)
    icon.AmountShadow:SetPoint("TOPLEFT", icon.Amount, "TOPLEFT", -10, 10)
    icon.AmountShadow:SetPoint("BOTTOMRIGHT", icon.Amount, "BOTTOMRIGHT", 10, -10)
    icon:SetScript("OnEnter", function(self)
        if state.recipeID then
            local info = ResolveRecipe(state.recipeID)
            ShowItemTooltip(self, info.itemID, state.recipeID)
        end
    end)
    icon:SetScript("OnLeave", GameTooltip_Hide)
    icon:SetScript("OnClick", function()
        if state.recipeID and IsModifiedClick("CHATLINK") then
            InsertLink(RecipeLink(state.recipeID))
        end
    end)
    detail.Icon = icon

    detail.Name = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightMed2")
    detail.Name:SetWidth(225)
    detail.Name:SetPoint("LEFT", icon, "RIGHT", 14, 17)
    detail.Name:SetJustifyH("LEFT")

    detail.Tools = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall2")
    detail.Tools:SetWidth(250)
    detail.Tools:SetPoint("TOPLEFT", detail.Name, "BOTTOMLEFT", 0, -4)
    detail.Tools:SetJustifyH("LEFT")

    detail.Description = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall2")
    detail.Description:SetWidth(305)
    detail.Description:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", -1, -12)
    detail.Description:SetJustifyH("LEFT")

    local reagents = CreateFrame("Frame", nil, content)
    reagents:SetSize(180, 20)
    reagents:SetPoint("TOPLEFT", detail.Description, "BOTTOMLEFT", 0, -20)
    detail.Reagents = reagents
    detail.ReagentsTitle = reagents:CreateFontString(nil, "BACKGROUND", "GameFontNormalSmall")
    detail.ReagentsTitle:SetSize(180, 20)
    detail.ReagentsTitle:SetPoint("TOPLEFT")
    detail.ReagentsTitle:SetJustifyH("LEFT")
    detail.ReagentsTitle:SetText(PROFESSIONS_REAGENT_CONTAINER_LABEL or L["Reagents:"])
    detail.NoReagents = reagents:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    detail.NoReagents:SetWidth(305)
    detail.NoReagents:SetPoint("TOPLEFT")
    detail.NoReagents:SetJustifyH("LEFT")
    detail.NoReagents:SetText(L["The game gives no reagents for this recipe here; point at the icon for its details."])
    detail.reagents = {}
    for i = 1, MAX_REAGENTS do
        detail.reagents[i] = CreateReagentSlot(reagents, i)
    end

    detail.KnownBy = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall2")
    detail.KnownBy:SetWidth(305)
    detail.KnownBy:SetJustifyH("LEFT")
    detail.KnownBy:SetSpacing(2)

    -- Where Blizzard's Track Recipe sits: where these recipes come from.
    frame.Updated = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.Updated:SetWidth(305)
    frame.Updated:SetPoint("BOTTOMLEFT", 28, 14)
    frame.Updated:SetJustifyH("LEFT")
end

local function CreateWindow()
    frame = CreateFrame("Frame", "GuildProfessionsRecipesViewer", UIParent, "PortraitFrameTemplate")
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
    if frame.Bg then
        frame.Bg:SetAtlas("Profession-Background-Overview")
    end

    -- Everything else sits on a page under the frame's border, as the game's
    -- crafting page does.
    local page = CreateFrame("Frame", nil, frame)
    page:SetAllPoints()
    page:SetFrameLevel(frame:GetFrameLevel() + 99)
    local art = page:CreateTexture(nil, "BACKGROUND", nil, -3)
    art:SetAtlas("Profession-Background-Template2", true)
    art:SetPoint("TOPLEFT", 3, -21)

    frame.RankBar = CreateRankBar(page)

    local list = CreateRecipeList(page)
    CreatePanel(page, list)

    -- Where the game has its crafting controls, centred under the recipe
    -- panel: crafting orders, disabled until a later version.
    local order = RedButton(page, L["Request an order (coming soon)"])
    order:SetPoint("BOTTOM", page, "BOTTOMRIGHT", -(PANEL_RIGHT_GAP + PANEL_WIDTH / 2), 7)
    order:SetEnabled(false)
    frame.OrderButton = order

    frame:SetScript("OnHide", function()
        GameTooltip_Hide()
    end)
end

-- Opens the window on a member's saved data, by GUID. skillLine: the
-- profession to show first (any listed one otherwise).
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

-- A profession clicked in the roster: ours in the game's own window, a
-- member's (or ours, if the game will not open it) from the saved data.
function Viewer.ShowProfession(guid, skillLine)
    if Viewer.OpensInGame(guid, skillLine) then
        local ok, opened = pcall(TradeSkill.OpenTradeSkill, skillLine)
        if ok and opened ~= false then
            return
        end
    end
    Viewer.OpenMember(guid, skillLine)
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
    -- Bags: the reagent counts and the "Have Materials" filter.
    ns.RegisterEvents(events, "ITEM_DATA_LOAD_RESULT", "SPELL_DATA_LOAD_RESULT", "BAG_UPDATE_DELAYED")
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

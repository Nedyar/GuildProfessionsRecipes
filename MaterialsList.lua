-- MaterialsList.lua: what the orders we accepted take to make. The
-- Materials list button under Pending orders (GuildTab.lua) opens a window
-- with every material of the orders we accepted and have not completed
-- yet, summed over them for the crafts left (what is made already, in our
-- bags or delivered, takes nothing more), as the game's recipe window shows
-- reagents: how many we carry in our bags over how many they take.
-- What requesters who provide the materials have yet to send us is told
-- apart, and counts towards what we have: it is not ours to get. Its
-- Prepare button keeps the materials in our bags (Prepare.lua), and each
-- row says how many are kept.
local _, ns = ...
local L = ns.L

local MaterialsList = {}
ns.MaterialsList = MaterialsList

local ICON = "Interface\\Icons\\INV_Scroll_03"
local UNKNOWN_ICON = 134400
local ROW_HEIGHT = 44
local PADLOCK = "|A:Bags-padlock-authenticator:12:10|a"  -- as kept stacks show in the bags (BagLocks.lua)
local PREPARE_WIDTH = 140      -- the Prepare button, for its longest translation

local window
local requested = {}  -- [itemID] = true once its data was asked for

-- The orders we make: accepted by us, their materials in or not, and not
-- completed yet.
function MaterialsList.Orders()
    local list = {}
    for _, view in ipairs(ns.Orders.ForMe(ns.Data.CurrentGuild(false))) do
        if view.crafter == ns.playerGUID and (view.state == "accepted" or view.state == "materials") then
            list[#list + 1] = view
        end
    end
    return list
end

-- What the orders we make take, for the crafts left: { { itemID, need,
-- coming, have } }, coming being how many of need their requesters have yet
-- to send us, by name. Then the orders, and those of them whose materials
-- the game does not give. An order's items still to make are those not
-- delivered yet, but for the items of it our bags hold, made already: they
-- count for the oldest orders first, and are not counted again as a
-- material another order takes. An order with no item (an enchantment)
-- takes its materials until it is completed.
function MaterialsList.Totals()
    local byItem, list, unknown = {}, {}, {}
    local orders = MaterialsList.Orders()
    local oldest = {}
    for index, view in ipairs(orders) do
        oldest[index] = view
    end
    table.sort(oldest, function(a, b)
        if a.order.c ~= b.order.c then
            return a.order.c < b.order.c
        end
        return a.key < b.key
    end)
    local made, counted = {}, {}  -- [itemID] = made and not counted yet; counted for orders
    for _, view in ipairs(oldest) do
        local itemID, perCraft, reagents = ns.Viewer.OrderItems(view.order.r)
        local left = math.max(view.order.q - (view.delivered or 0), 0)
        if itemID then
            made[itemID] = made[itemID] or ns.Try(C_Item.GetItemCount, itemID) or 0
            local done = math.min(made[itemID], left)
            made[itemID], counted[itemID] = made[itemID] - done, (counted[itemID] or 0) + done
            left = left - done
        end
        if left <= 0 then
            -- Nothing left to make.
        elseif not reagents or #reagents == 0 then
            unknown[#unknown + 1] = view
        else
            local crafts = math.ceil(left / perCraft)
            local owed = view.state == "materials" and ns.Deliveries.MaterialsOwed(view) or {}
            local takes = {}
            for _, reagent in ipairs(reagents) do
                takes[reagent.itemID] = (takes[reagent.itemID] or 0) + reagent.quantity * crafts
            end
            for itemID, count in pairs(takes) do
                if count > 0 then
                    local entry = byItem[itemID]
                    if not entry then
                        entry = { itemID = itemID, need = 0, coming = 0 }
                        byItem[itemID] = entry
                        list[#list + 1] = entry
                    end
                    entry.need = entry.need + count
                    entry.coming = entry.coming + math.min(owed[itemID] or 0, count)
                end
            end
        end
    end
    for _, entry in ipairs(list) do
        entry.have = math.max((ns.Try(C_Item.GetItemCount, entry.itemID) or 0) - (counted[entry.itemID] or 0), 0)
        entry.name = C_Item.GetItemNameByID(entry.itemID)
        if not entry.name and not requested[entry.itemID] then
            -- Drawn again when it arrives (ITEM_DATA_LOAD_RESULT).
            requested[entry.itemID] = true
            C_Item.RequestLoadItemDataByID(entry.itemID)
        end
    end
    -- Those still loading last.
    table.sort(list, function(a, b)
        if (a.name ~= nil) ~= (b.name ~= nil) then
            return a.name ~= nil
        elseif a.name and a.name ~= b.name then
            return a.name < b.name
        end
        return a.itemID < b.itemID
    end)
    return list, orders, unknown
end

-- The window -----------------------------------------------------------------------

local function OrderText(order)
    local name = ns.Viewer.RecipeOutput(order.r)
    return order.q > 1 and ("%s x%d"):format(name, order.q) or name
end

-- Under a material: how many our bags keep for the orders, and how many
-- are still to come; "" for neither.
local function Detail(entry)
    local parts = {}
    if (entry.kept or 0) > 0 then
        parts[#parts + 1] = PADLOCK .. " " .. L["%d kept"]:format(entry.kept)
    end
    if (entry.coming or 0) > 0 then
        parts[#parts + 1] = L["%d still to be received"]:format(entry.coming)
    end
    return table.concat(parts, " · ")
end

-- A row: a material as the recipe window shows reagents, and under it how
-- many are kept and still to come; or an order whose materials are
-- unknown.
local function InitRow(row, entry)
    if not row.Text then
        row.Button = ns.Viewer.CreateReagentButton(row)
        row.Button:SetPoint("LEFT", 4, 0)
        row.Text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.Text:SetJustifyH("LEFT")
        row.Text:SetWordWrap(false)
        row.Coming = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        row.Coming:SetPoint("TOPLEFT", row.Text, "BOTTOMLEFT", 0, -3)
        row.Coming:SetPoint("TOPRIGHT", row.Text, "BOTTOMRIGHT", 0, -3)
        row.Coming:SetJustifyH("LEFT")
        row.Coming:SetWordWrap(false)
    end
    local coming = entry.coming or 0
    local detail = Detail(entry)
    -- Beside the button: one line in the middle, or two around it.
    local y = detail ~= "" and 7 or 0
    row.Text:ClearAllPoints()
    row.Text:SetPoint("LEFT", row.Button, "RIGHT", 8, y)
    row.Text:SetPoint("RIGHT", row, "RIGHT", -4, y)
    row.Coming:SetText(detail)
    row.Coming:SetShown(detail ~= "")
    if entry.order then
        local itemID = ns.Viewer.OrderItems(entry.order.r)
        local _, icon = ns.Viewer.RecipeOutput(entry.order.r)
        row.itemID = itemID
        row.Button.Icon:SetTexture(icon)
        row.Text:SetText(L["%s: materials unknown"]:format(OrderText(entry.order)))
        return
    end
    row.itemID = entry.itemID
    row.Button.Icon:SetTexture(C_Item.GetItemIconByID(entry.itemID) or UNKNOWN_ICON)
    row.Text:SetText(ns.Viewer.ReagentText(entry.itemID, entry.have, entry.need, entry.have + coming >= entry.need))
end

local function Draw()
    local list, orders, unknown = MaterialsList.Totals()
    local elements = {}
    for _, entry in ipairs(list) do
        entry.kept = ns.Prepare.Kept(entry.itemID)
        elements[#elements + 1] = entry
    end
    for _, view in ipairs(unknown) do
        elements[#elements + 1] = { order = view.order }
    end
    window.Summary:SetText(L["For %d accepted |4order:orders;"]:format(#orders))
    window.Summary:SetShown(#orders > 0)
    window.ScrollBox:SetDataProvider(CreateDataProvider(elements), ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
    -- No orders, or all of them made, waiting to be delivered.
    window.Empty:SetText(#orders == 0 and L["You have no accepted orders to make."]
        or L["All of it is made: it only remains to deliver it."])
    window.Empty:SetShown(#elements == 0)
    local action = ns.Prepare.Action()
    local button = window.Prepare
    button.action, button.tip = action.action, action.tip
    button:SetText(action.text)
    button:SetEnabled(action.enabled == true)
end

-- Drawn again soon, while it is shown: our orders, our bags or an item's
-- data changed.
function MaterialsList.Refresh()
    if window and window:IsShown() then
        ns.Debounce("MaterialsList", 0.3, function()
            if window:IsShown() then
                Draw()
            end
        end)
    end
end

local function CreateWindow()
    window = CreateFrame("Frame", "GuildProfessionsRecipesMaterials", UIParent, "PortraitFrameTemplate")
    window:SetSize(340, 440)
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:Hide()
    tinsert(UISpecialFrames, window:GetName())
    window:SetTitle(L["Materials list"])
    window:SetPortraitToAsset(ICON)
    window.Summary = window:CreateFontString(nil, "ARTWORK", "GameFontHighlightMed2")
    window.Summary:SetPoint("TOPLEFT", 62, -38)
    window.Summary:SetPoint("TOPRIGHT", -12, -38)
    window.Summary:SetJustifyH("LEFT")
    window.Summary:SetWordWrap(false)
    -- At the bottom, as the game's windows have their buttons: Prepare (or
    -- Release all), its tooltip saying what it does or why it cannot.
    local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    button:SetSize(PREPARE_WIDTH, 22)
    button:SetPoint("BOTTOMRIGHT", -10, 8)
    button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnClick", function(self)
        ns.Prepare.Run(self.action)
        Draw()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self:GetText() or "", 1, 1, 1)
        if self.tip then
            GameTooltip:AddLine(self.tip, nil, nil, nil, true)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    window.Prepare = button
    local scrollBox = CreateFrame("Frame", nil, window, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", 12, -70)
    scrollBox:SetPoint("BOTTOMRIGHT", -28, 36)
    local scrollBar = CreateFrame("EventFrame", nil, window, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)
    local view = CreateScrollBoxListLinearView(0, 0, 0, 0, 0)
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Frame", InitRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    window.ScrollBox = scrollBox
    window.Empty = window:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    window.Empty:SetPoint("CENTER", scrollBox)
    window.Empty:SetWidth(260)
    window:SetScript("OnHide", GameTooltip_Hide)

    local events = CreateFrame("Frame")
    ns.RegisterEvents(events, "BAG_UPDATE_DELAYED", "ITEM_DATA_LOAD_RESULT")
    events:SetScript("OnEvent", MaterialsList.Refresh)
    ns.On("DataChanged", MaterialsList.Refresh)
    -- The bank opened or closed, stacks kept or let go, Prepare started or done.
    ns.On("PrepareChanged", MaterialsList.Refresh)
end

-- Opens the window, beside the guild window, or closes it.
function MaterialsList.Toggle()
    if window and window:IsShown() then
        window:Hide()
        return
    end
    if not window then
        CreateWindow()
    end
    Draw()
    window:ClearAllPoints()
    if CommunitiesFrame and CommunitiesFrame:IsShown() then
        window:SetPoint("TOPLEFT", CommunitiesFrame, "TOPRIGHT", 10, 0)
    else
        window:SetPoint("CENTER")
    end
    window:Show()
end

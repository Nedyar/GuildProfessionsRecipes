-- OrderList.lua: the lists of crafting orders in the Recipes & Orders tab
-- of the guild window (see GuildTab.lua):
--   - "pending": ours to act on, directed to us or accepted by us;
--   - "open": open orders anyone who knows the recipe may take;
--   - "mine": the orders we requested.
-- Each row shows what is ordered, by whom, where it stands and how it is
-- paid, with the buttons that apply to it.
local _, ns = ...
local L = ns.L

local OrderList = {}
ns.OrderList = OrderList

local ROW_HEIGHT = 56
local BUTTON_WIDTH, BUTTON_HEIGHT = 84, 22
local NOTE_PREVIEW = 60  -- bytes of the note shown in a row; all of it in the tooltip

-- Money, as the game shows it (coins).
local function Money(copper)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(copper)
    elseif GetCoinTextureString then
        return GetCoinTextureString(copper)
    end
    return ("%dg %ds %dc"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end
OrderList.Money = Money

local function Name(guid)
    return ns.Data.NameOf(guid, ns.Data.CurrentGuild(false) and ns.Data.CurrentGuild(false).members[guid])
end

-- Where a taken order stands, before any count of its items delivered.
local function TakenText(view, mode)
    local byUs = view.crafter == ns.playerGUID
    if view.state == "materials" then
        if mode == "mine" then
            return L["Accepted by %s: waiting for your materials"]:format(Name(view.crafter))
        end
        return byUs and L["Accepted by you: waiting for the materials"] or L["Accepted by %s"]:format(Name(view.crafter))
    elseif view.state == "accepted" then
        return byUs and L["Accepted by you"] or L["Accepted by %s"]:format(Name(view.crafter))
    elseif mode == "mine" then
        return L["Completed by %s"]:format(Name(view.crafter))
    end
    return L["Completed: waiting for %s to finish it"]:format(Name(view.requester))
end

-- Where an order stands, as seen from the list it is in.
local function StateText(view, mode)
    local order, state = view.order, view.state
    if state == "pending" then
        if order.d == ns.playerGUID then
            return L["Personal order for you"]
        elseif order.d then
            return L["Personal order for %s"]:format(Name(order.d))
        end
        return L["Open order"]
    elseif state == "denied" then
        return L["Denied by %s"]:format(Name(order.d))
    elseif ns.Orders.IsTaken(state) then
        local text = TakenText(view, mode)
        if state ~= "completed" and (view.delivered or 0) > 0 then
            text = ("%s · %s"):format(text, L["%d/%d delivered"]:format(view.delivered, order.q))
        end
        return text
    elseif state == "cancelled" then
        return L["Cancelled"]
    end
    return L["Finished"]
end

-- The tip, and once the order is taken, whether its crafter has it.
local function TipText(view)
    local tip = view.order.tip or 0
    if not ns.Orders.IsTaken(view.state) then
        return L["Tip: %s"]:format(Money(tip))
    end
    local missing = ns.Orders.TipMissing(view)
    if missing == 0 then
        return L["Tip: %s (paid)"]:format(Money(tip))
    end
    return L["Tip: %s (%s missing)"]:format(Money(tip), Money(missing))
end

local function PaymentText(view)
    local order = view.order
    local parts = {}
    if order.m then
        parts[#parts + 1] = L["Materials provided"]
    end
    if (order.tip or 0) > 0 then
        parts[#parts + 1] = TipText(view)
    end
    if order.note ~= "" then
        local note = order.note:gsub("\n", " ")
        if #note > NOTE_PREVIEW then
            note = note:sub(1, NOTE_PREVIEW):gsub("[\128-\191]*$", ""):gsub("[\192-\255]$", "") .. "..."
        end
        parts[#parts + 1] = "\"" .. note .. "\""
    end
    return table.concat(parts, " · ")
end

-- Actions ---------------------------------------------------------------------------

local function Run(action, view)
    local ok
    if action == "modify" then
        ns.OrderForm.Open(view.order.sl, view.order.r, view.id)
        return
    elseif action == "accept" then
        ok = ns.Orders.Accept(view.requester, view.id)
    elseif action == "deny" then
        ok = ns.Orders.Deny(view.requester, view.id)
    elseif action == "received" then
        ok = ns.Orders.Receive(view.requester, view.id)
    elseif action == "complete" then
        ok = ns.Orders.Complete(view.requester, view.id)
    elseif action == "release" then
        ok = ns.Orders.Release(view.requester, view.id)
    elseif action == "cancel" then
        ok = ns.Orders.Cancel(view.id)
    elseif action == "finish" then
        ok = ns.Orders.Finish(view.id)
    elseif action == "tip" then
        ok = ns.Orders.ConfirmTip(view.requester, view.id)
    elseif action == "delete" then
        ok = ns.Orders.Remove(view.id)
    end
    if not ok then
        ns.Print(L["this order changed meanwhile."])
    end
    if OrderList.onChange then
        OrderList.onChange()
    end
end

-- The buttons an order has in a list: { action, text, enabled, reason }.
local function Actions(view, mode)
    local state = view.state
    if mode == "pending" then
        if state == "pending" then
            return { { "accept", ACCEPT or "Accept", true }, { "deny", DECLINE or "Decline", true } }
        elseif state == "materials" then
            return { { "received", L["Received"], true, L["Mark the materials as received."] }, { "release", L["Release"], true } }
        elseif state == "accepted" then
            return { { "complete", L["Complete"], true }, { "release", L["Release"], true } }
        elseif state == "completed" and ns.Orders.TipMissing(view) > 0 then
            return { { "tip", L["Tip paid"], true, L["Mark the tip as paid, or forgive it."] } }
        end
    elseif mode == "open" then
        if view.requester == ns.playerGUID then
            return { { "accept", ACCEPT or "Accept", false, L["This is your own order."] } }
        end
        local craftable = ns.Orders.CanCraft(view.order)
        return { { "accept", ACCEPT or "Accept", craftable, not craftable and L["You don't know this recipe."] or nil } }
    elseif mode == "mine" then
        if state == "pending" or state == "denied" then
            return { { "modify", L["Modify"], true }, { "cancel", CANCEL or "Cancel", true } }
        elseif ns.Orders.IsTaken(state) then
            local paid = ns.Orders.TipMissing(view) == 0
            return { { "finish", L["Finish"], paid, not paid and L["Waiting for %s to confirm the tip."]:format(Name(view.crafter)) or nil },
                { "cancel", CANCEL or "Cancel", true } }
        elseif ns.Orders.IsClosed(state) then
            return { { "delete", DELETE or "Delete", true } }
        end
    end
    return {}
end

-- Rows -------------------------------------------------------------------------------

-- Whether a click on an order opens the game's profession window: in our
-- pending orders (taken by us, or directed to us), when we know the recipe.
local function InGame(view, mode)
    return mode == "pending" and ns.Orders.CanCraft(view.order)
end

local function RowOnEnter(row)
    local view = row.view
    if not view then
        return
    end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(row.Title:GetText() or "", 1, 1, 1)
    GameTooltip:AddLine(L["From %s"]:format(Name(view.requester)), NORMAL_FONT_COLOR:GetRGB())
    GameTooltip:AddLine(StateText(view, row.mode), 1, 1, 1, true)
    if view.order.m then
        GameTooltip:AddLine(L["Materials provided"], 1, 1, 1)
    end
    if (view.order.tip or 0) > 0 then
        GameTooltip:AddLine(TipText(view), 1, 1, 1)
    end
    if view.order.note ~= "" then
        GameTooltip:AddLine(view.order.note, 0.9, 0.9, 0.9, true)
    end
    local hint = InGame(view, row.mode) and L["Click to open it in your profession window."] or L["Click to see the recipe."]
    GameTooltip:AddLine(hint, GREEN_FONT_COLOR:GetRGB())
    GameTooltip:Show()
end

-- The recipe window on the order's recipe, among the guild's; for one of
-- our pending orders, the game's own profession window, to craft it.
local function ShowRecipe(view, mode)
    if InGame(view, mode) and ns.Viewer.OpenRecipeInGame(view.order.sl, view.order.r) then
        return
    end
    ns.Viewer.OpenGuild(view.order.sl, view.order.r)
end

local function ButtonOnEnter(button)
    if button.reason then
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(button.reason, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end
end

local function CreateRow(row)
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(36, 36)
    row.Icon:SetPoint("LEFT", 8, 0)
    -- Over the icon, what the order makes, as in the recipe window; a click
    -- does what a click on the row does, and shift-click links it.
    row.Item = CreateFrame("Button", nil, row)
    row.Item:SetAllPoints(row.Icon)
    row.Item:SetScript("OnEnter", function(self)
        if row.view then
            ns.Viewer.ShowOutputTooltip(self, row.view.order.r)
        end
    end)
    row.Item:SetScript("OnLeave", GameTooltip_Hide)
    row.Item:SetScript("OnClick", function()
        if not row.view then
            return
        elseif IsModifiedClick("CHATLINK") then
            ns.Viewer.LinkRecipe(row.view.order.r)
        else
            ShowRecipe(row.view, row.mode)
        end
    end)
    row.Title =row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.Title:SetPoint("TOPLEFT", row.Icon, "TOPRIGHT", 8, -1)
    row.Title:SetJustifyH("LEFT")
    row.Title:SetWordWrap(false)
    row.State = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.State:SetPoint("TOPLEFT", row.Title, "BOTTOMLEFT", 0, -3)
    row.State:SetJustifyH("LEFT")
    row.State:SetWordWrap(false)
    row.Payment = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.Payment:SetPoint("TOPLEFT", row.State, "BOTTOMLEFT", 0, -3)
    row.Payment:SetJustifyH("LEFT")
    row.Payment:SetWordWrap(false)
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAtlas("PetList-ButtonHighlight")
    highlight:SetAllPoints()
    highlight:SetBlendMode("ADD")
    row.buttons = {}
    for i = 1, 2 do
        local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
        if i == 1 then
            button:SetPoint("RIGHT", -8, 0)
        else
            button:SetPoint("RIGHT", row.buttons[1], "LEFT", -4, 0)
        end
        button:SetMotionScriptsWhileDisabled(true)
        button:SetScript("OnClick", function(self)
            Run(self.action, row.view)
        end)
        button:SetScript("OnEnter", ButtonOnEnter)
        button:SetScript("OnLeave", GameTooltip_Hide)
        row.buttons[i] = button
    end
    -- The texts stop before the buttons.
    for _, text in ipairs({ row.Title, row.State, row.Payment }) do
        text:SetPoint("RIGHT", row.buttons[2], "LEFT", -8, 0)
    end
    row:EnableMouse(true)
    row:SetScript("OnEnter", RowOnEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    -- A click on the row (its buttons take their own) shows the recipe
    -- (ShowRecipe).
    row:SetScript("OnMouseUp", function(self, mouseButton)
        if mouseButton == "LeftButton" and self.view and self:IsMouseOver() then
            ShowRecipe(self.view, self.mode)
        end
    end)
end

local function InitRow(row, data)
    if not row.Title then
        CreateRow(row)
    end
    local view = data.view
    row.view, row.mode = view, data.mode
    local name, icon = ns.Viewer.RecipeOutput(view.order.r)
    row.Icon:SetTexture(icon)
    row.Icon:SetDesaturated(ns.Orders.IsClosed(view.state))
    row.Title:SetText(view.order.q > 1 and ("%s x%d"):format(name, view.order.q) or name)
    local state = StateText(view, data.mode)
    if data.mode ~= "mine" then
        state = ("%s · %s"):format(L["From %s"]:format(Name(view.requester)), state)
    end
    row.State:SetText(state)
    row.Payment:SetText(PaymentText(view))
    local actions = Actions(view, data.mode)
    for i, button in ipairs(row.buttons) do
        -- The first action sits rightmost.
        local action = actions[#actions - i + 1]
        button.action = action and action[1]
        button.reason = action and action[4]
        if action then
            button:SetText(action[2])
            button:SetEnabled(action[3])
        end
        button:SetShown(action ~= nil)
    end
end

-- The list --------------------------------------------------------------------------

-- A list in parent, filling it.
function OrderList.Create(parent)
    local list = CreateFrame("Frame", nil, parent)
    list:SetAllPoints()
    local scrollBox = CreateFrame("Frame", nil, list, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", 4, -4)
    scrollBox:SetPoint("BOTTOMRIGHT", -20, 4)
    local scrollBar = CreateFrame("EventFrame", nil, list, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)
    local view = CreateScrollBoxListLinearView(0, 0, 0, 0, 2)
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Frame", InitRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    list.ScrollBox = scrollBox
    list.Empty = list:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    list.Empty:SetPoint("CENTER")
    list.Empty:SetText(L["No orders here."])
    return list
end

-- The orders a list shows. mode: "pending", "open" or "mine"; in "open",
-- craftable: only those we know the recipe of; showMine: also those of our
-- account's characters.
function OrderList.Views(mode, craftable, showMine)
    local guild = ns.Data.CurrentGuild(false)
    if mode == "pending" then
        return ns.Orders.ForMe(guild)
    elseif mode == "open" then
        return ns.Orders.Open(guild, craftable, showMine)
    end
    return ns.Orders.Mine(guild)
end

function OrderList.Show(list, mode, craftable, showMine)
    local elements = {}
    for _, view in ipairs(OrderList.Views(mode, craftable, showMine)) do
        elements[#elements + 1] = { view = view, mode = mode }
    end
    list.ScrollBox:SetDataProvider(CreateDataProvider(elements), ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
    list.Empty:SetShown(#elements == 0)
end

-- How many orders wait for us to act: directed to us, or accepted by us.
function OrderList.WaitingForMe()
    local count = 0
    for _, view in ipairs(OrderList.Views("pending")) do
        if view.state == "pending" or view.state == "accepted" then
            count = count + 1
        end
    end
    return count
end

-- How many of our own orders wait for us: denied (to change or cancel),
-- waiting for our materials, or completed (to finish).
function OrderList.WaitingOnMine()
    local count = 0
    for _, view in ipairs(OrderList.Views("mine")) do
        if view.state == "denied" or view.state == "materials" or view.state == "completed" then
            count = count + 1
        end
    end
    return count
end

-- Notices ---------------------------------------------------------------------------

-- What a change of state means for us, as a chat line only we see. Our
-- own changes (and those Deliveries.lua makes for us) are not told here.
-- wasOurs: we were its crafter last time.
local function Announce(view, before, wasOurs)
    local name = ns.Viewer.RecipeOutput(view.order.r)
    local item = view.order.q > 1 and ("%s x%d"):format(name, view.order.q) or name
    local state = view.state
    if view.requester == ns.playerGUID then
        if state == "materials" then
            ns.Print(L["%s accepted your order: %s. Send them the materials."], Name(view.crafter), item)
        elseif state == "accepted" and before == "materials" then
            ns.Print(L["%s received your materials: %s."], Name(view.crafter), item)
        elseif state == "accepted" and before ~= "completed" then
            ns.Print(L["%s accepted your order: %s."], Name(view.crafter), item)
        elseif state == "completed" then
            ns.Print(L["%s completed your order: %s. Mark it finished once you have it."], Name(view.crafter), item)
        elseif state == "denied" then
            ns.Print(L["%s declined your order: %s."], Name(view.order.d), item)
        elseif state == "pending" and ns.Orders.IsTaken(before) then
            ns.Print(L["your order is open again: %s."], item)
        end
    elseif state == "pending" and view.order.d == ns.playerGUID and not wasOurs then
        ns.Print(L["%s asks you for a personal order: %s."], Name(view.requester), item)
    elseif state == "cancelled" and wasOurs then
        ns.Print(L["%s cancelled the order you accepted: %s."], Name(view.requester), item)
    end
end

-- Compares the orders that concern us (ours, personal ones for us, and
-- those we took) with how they stood last time, saved per character so
-- changes made while we were away are told at login too. The very first
-- time, nothing is told.
function OrderList.CheckNotices()
    local guild = ns.Data.CurrentGuild(false)
    if not guild or not ns.playerGUID then
        return
    end
    local own = ns.Data.OwnState()
    local before, takenBefore, owedBefore = own.orderStates, own.ordersTaken or {}, own.tipsOwed or {}
    local now, taken, owed = {}, {}, {}
    for _, view in ipairs(ns.Orders.List(guild)) do
        local ours = view.crafter == ns.playerGUID
        taken[view.key] = ours or nil
        -- A cancelled order has no crafter any more: one we had taken is
        -- followed through what we noted last time.
        if view.requester == ns.playerGUID or view.order.d == ns.playerGUID or ours or takenBefore[view.key] then
            now[view.key] = view.state
            if before and before[view.key] ~= view.state then
                Announce(view, before[view.key], takenBefore[view.key])
            end
        end
        -- The tips of our orders, until their crafters confirm them.
        if view.requester == ns.playerGUID and ns.Orders.IsTaken(view.state) then
            owed[view.key] = ns.Orders.TipMissing(view) > 0 or nil
            if owedBefore[view.key] and not owed[view.key] then
                local name = ns.Viewer.RecipeOutput(view.order.r)
                ns.Print(L["%s confirmed your tip: %s."], Name(view.crafter), view.order.q > 1 and ("%s x%d"):format(name, view.order.q) or name)
            end
        end
    end
    own.orderStates, own.ordersTaken, own.tipsOwed = now, taken, owed
end

function OrderList.Init()
    ns.On("DataChanged", function()
        ns.Debounce("OrderNotices", 1, OrderList.CheckNotices)
    end)
end

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

local function Name(guid)
    return ns.Data.NameOf(guid, ns.Data.CurrentGuild(false) and ns.Data.CurrentGuild(false).members[guid])
end

local function TimeLeft(order)
    local seconds = math.max(ns.Orders.Deadline(order) - ns.Now(), 60)
    return L["%s left"]:format(SecondsToTime(seconds, true, false, 1))
end

-- Where an order stands, as seen from the list it is in.
local function StateText(view, mode)
    local order, state = view.order, view.state
    if state == "pending" then
        local who
        if order.d == ns.playerGUID then
            who = L["Personal order for you"]
        elseif order.d then
            who = L["Personal order for %s"]:format(Name(order.d))
        else
            who = L["Open order"]
        end
        return ("%s · %s"):format(who, TimeLeft(order))
    elseif state == "denied" then
        return L["Denied by %s"]:format(Name(order.d))
    elseif state == "accepted" then
        return view.crafter == ns.playerGUID and L["Accepted by you"] or L["Accepted by %s"]:format(Name(view.crafter))
    elseif state == "completed" then
        if mode == "mine" then
            return L["Completed by %s"]:format(Name(view.crafter))
        end
        return L["Completed: waiting for %s to finish it"]:format(Name(view.requester))
    elseif state == "expired" then
        return L["Expired"]
    elseif state == "cancelled" then
        return L["Cancelled"]
    end
    return L["Finished"]
end

local function PaymentText(order)
    local parts = {}
    if order.m then
        parts[#parts + 1] = L["Materials provided"]
    end
    if (order.tip or 0) > 0 then
        parts[#parts + 1] = L["Tip: %s"]:format(Money(order.tip))
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
    elseif action == "complete" then
        ok = ns.Orders.Complete(view.requester, view.id)
    elseif action == "release" then
        ok = ns.Orders.Release(view.requester, view.id)
    elseif action == "cancel" then
        ok = ns.Orders.Cancel(view.id)
    elseif action == "finish" then
        ok = ns.Orders.Finish(view.id)
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
        elseif state == "accepted" then
            return { { "complete", L["Complete"], true }, { "release", L["Release"], true } }
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
        elseif state == "completed" then
            return { { "finish", L["Finish"], true } }
        elseif state == "finished" or state == "cancelled" or state == "expired" then
            return { { "delete", DELETE or "Delete", true } }
        end
    end
    return {}
end

-- Rows -------------------------------------------------------------------------------

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
        GameTooltip:AddLine(L["Tip: %s"]:format(Money(view.order.tip)), 1, 1, 1)
    end
    if view.order.note ~= "" then
        GameTooltip:AddLine(view.order.note, 0.9, 0.9, 0.9, true)
    end
    GameTooltip:AddLine(L["Click to see the recipe."], GREEN_FONT_COLOR:GetRGB())
    GameTooltip:Show()
end

-- The recipe window on the order's recipe, among the guild's.
local function ShowRecipe(view)
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
    -- shows the recipe, as on the row, and shift-click links it.
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
            ShowRecipe(row.view)
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
    -- A click on the row (its buttons take their own) shows the recipe.
    row:SetScript("OnMouseUp", function(self, mouseButton)
        if mouseButton == "LeftButton" and self.view and self:IsMouseOver() then
            ShowRecipe(self.view)
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
    local closed = view.state == "finished" or view.state == "cancelled" or view.state == "expired"
    row.Icon:SetDesaturated(closed)
    row.Title:SetText(view.order.q > 1 and ("%s x%d"):format(name, view.order.q) or name)
    local state = StateText(view, data.mode)
    if data.mode ~= "mine" then
        state = ("%s · %s"):format(L["From %s"]:format(Name(view.requester)), state)
    end
    row.State:SetText(state)
    row.Payment:SetText(PaymentText(view.order))
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

-- How many of our own orders wait for us: completed (to finish) or denied
-- (to change or cancel).
function OrderList.WaitingOnMine()
    local count = 0
    for _, view in ipairs(OrderList.Views("mine")) do
        if view.state == "completed" or view.state == "denied" then
            count = count + 1
        end
    end
    return count
end

-- Notices ---------------------------------------------------------------------------

-- What a change of state means for us, as a chat line only we see.
local function Announce(view, before)
    local name = ns.Viewer.RecipeOutput(view.order.r)
    local item = view.order.q > 1 and ("%s x%d"):format(name, view.order.q) or name
    local state = view.state
    if view.requester == ns.playerGUID then
        if state == "accepted" and before ~= "completed" then
            ns.Print(L["%s accepted your order: %s."], Name(view.crafter), item)
        elseif state == "completed" then
            ns.Print(L["%s completed your order: %s. Mark it finished once you have it."], Name(view.crafter), item)
        elseif state == "denied" then
            ns.Print(L["%s declined your order: %s."], Name(view.order.d), item)
        elseif state == "expired" then
            ns.Print(L["your order expired: %s."], item)
        elseif state == "pending" and before == "accepted" then
            ns.Print(L["your order is open again: %s."], item)
        end
    elseif state == "pending" then
        ns.Print(L["%s asks you for a personal order: %s."], Name(view.requester), item)
    end
end

-- Compares the orders that concern us (ours, and personal ones for us)
-- with how they stood last time, saved per character so changes made while
-- we were away are told at login too. The very first time, nothing is told.
function OrderList.CheckNotices()
    local guild = ns.Data.CurrentGuild(false)
    if not guild or not ns.playerGUID then
        return
    end
    local own = ns.Data.OwnState()
    local before = own.orderStates
    local now = {}
    for _, view in ipairs(ns.Orders.List(guild)) do
        if view.requester == ns.playerGUID or view.order.d == ns.playerGUID then
            now[view.key] = view.state
            if before and before[view.key] ~= view.state then
                Announce(view, before[view.key])
            end
        end
    end
    own.orderStates = now
end

function OrderList.Init()
    ns.On("DataChanged", function()
        ns.Debounce("OrderNotices", 1, OrderList.CheckNotices)
    end)
end

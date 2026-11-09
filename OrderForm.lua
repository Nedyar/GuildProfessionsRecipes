-- OrderForm.lua: the window to request a crafting order, or to change one
-- of ours that nobody has taken yet. It opens from the recipe window's
-- "Request an order" button (and later from the list of our orders).
--
-- Built only from Blizzard's always-loaded templates, like the recipe window.
local _, ns = ...
local L = ns.L

local OrderForm = {}
ns.OrderForm = OrderForm

local WIDTH, HEIGHT = 340, 500
local LEFT = 20
-- Past the portrait, which hangs over the frame's top left corner.
local ITEM_LEFT = 62
local MAX_SUGGESTIONS = 6
local SUGGESTION_HEIGHT = 18
local TARGET_WIDTH = 160
local COPPER_PER_SILVER, COPPER_PER_GOLD = 100, 10000

local frame
-- What the form is about: { sl, r, id = our order's id when modifying,
-- target = the chosen member's GUID }.
local current = {}

-- Text cut to max bytes without splitting a character.
local function Truncate(text, max)
    if #text <= max then
        return text
    end
    local cut = max
    while cut > 0 and text:byte(cut + 1) and text:byte(cut + 1) >= 0x80 and text:byte(cut + 1) < 0xC0 do
        cut = cut - 1
    end
    return text:sub(1, cut)
end

local function Number(editBox)
    return tonumber(editBox:GetText() or "")
end

local function ShowError(text)
    frame.Error:SetText(text or "")
    frame.Error:SetShown(text ~= nil)
end

-- Widgets ------------------------------------------------------------------------

local function Label(parent, text, font)
    local label = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormal")
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

-- A check or radio button with its label, which takes clicks too; tooltip
-- (optional) on both, also while disabled, so it can say why.
local function Choice(parent, template, text, tooltip)
    local button = CreateFrame("CheckButton", nil, parent, template)
    button:SetSize(24, 24)
    button.Label = Label(parent, text, "GameFontHighlight")
    button.Label:SetPoint("LEFT", button, "RIGHT", 2, 0)
    button:SetHitRectInsets(0, -(button.Label:GetStringWidth() + 2), 0, 0)
    button:SetMotionScriptsWhileDisabled(true)
    if tooltip then
        button.tooltipText = tooltip
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(text, 1, 1, 1)
            GameTooltip:AddLine(self.tooltipText, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
    end
    return button
end

local function NumberBox(parent, width, maxLetters)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(maxLetters)
    box:SetJustifyH("RIGHT")
    -- The template's right border lies inside the box: keep the digits off it.
    box:SetTextInsets(0, 6, 0, 0)
    box:SetScript("OnEnterPressed", EditBox_ClearFocus or function(self)
        self:ClearFocus()
    end)
    return box
end

local function Coin(parent, box, file)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(file)
    icon:SetSize(13, 13)
    icon:SetPoint("LEFT", box, "RIGHT", 2, 0)
    return icon
end

-- Type: open or personal --------------------------------------------------------

local function SetPersonal(personal)
    frame.Open:SetChecked(not personal)
    frame.Personal:SetChecked(personal)
    frame.Target:SetEnabled(personal)
    frame.Target:SetAlpha(personal and 1 or 0.5)
    if not personal then
        frame.Target:ClearFocus()
        frame.Suggestions:Hide()
    end
end

local function HideSuggestions()
    frame.Suggestions:Hide()
end

-- The members who know the recipe whose name contains what was typed.
local function ShowSuggestions()
    local matches = ns.Orders.Crafters(ns.Data.CurrentGuild(false), current.sl, current.r, frame.Target:GetText())
    local list = frame.Suggestions
    for i, button in ipairs(list.buttons) do
        local match = matches[i]
        button.guid = match and match.guid
        button.Text:SetText(match and match.name or "")
        button:SetShown(match ~= nil)
    end
    local shown = math.min(#matches, MAX_SUGGESTIONS)
    list:SetHeight(shown * SUGGESTION_HEIGHT + 8)
    list:SetShown(shown > 0)
end

local function PickSuggestion(button)
    current.target = button.guid
    frame.Target:SetText(button.Text:GetText())
    frame.Target:ClearFocus()
    HideSuggestions()
end

local function CreateSuggestions(parent, anchor)
    local list = CreateFrame("Frame", nil, parent, "TooltipBackdropTemplate")
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:SetWidth(TARGET_WIDTH + 10)
    list:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -6, -2)
    list.buttons = {}
    for i = 1, MAX_SUGGESTIONS do
        local button = CreateFrame("Button", nil, list)
        button:SetHeight(SUGGESTION_HEIGHT)
        button:SetPoint("TOPLEFT", 5, -4 - (i - 1) * SUGGESTION_HEIGHT)
        button:SetPoint("RIGHT", -5, 0)
        button.Text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        button.Text:SetPoint("LEFT", 4, 0)
        button.Text:SetJustifyH("LEFT")
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        button:SetScript("OnClick", PickSuggestion)
        list.buttons[i] = button
    end
    list:Hide()
    return list
end

-- Sending ------------------------------------------------------------------------

local function Submit()
    local personal = frame.Personal:GetChecked()
    if personal and not current.target then
        ShowError(L["Choose who the order is for."])
        return
    end
    local tip = 0
    if frame.Tip:GetChecked() then
        tip = (Number(frame.Gold) or 0) * COPPER_PER_GOLD + (Number(frame.Silver) or 0) * COPPER_PER_SILVER + (Number(frame.Copper) or 0)
    end
    local fields = {
        sl = current.sl, r = current.r,
        d = personal and current.target or nil,
        m = frame.Materials:GetChecked() == true,
        tip = tip,
        q = Number(frame.Quantity) or 1,
        note = Truncate(frame.Note.EditBox:GetText() or "", ns.Pack.LIMITS.note),
    }
    local ok, reason
    if current.id then
        ok, reason = ns.Orders.Modify(current.id, fields)
    else
        ok, reason = ns.Orders.Create(fields)
    end
    if not ok then
        if reason == "full" then
            ShowError(L["You have too many open orders."])
        elseif reason == "taken" then
            ShowError(L["Someone has already taken this order."])
        else
            ShowError(L["The order could not be saved."])
        end
        return
    end
    local name = ns.Viewer.RecipeOutput(current.r)
    if current.id then
        ns.Print(L["order updated: %s x%d."], name, fields.q)
    else
        ns.Print(L["order requested: %s x%d."], name, fields.q)
    end
    frame:Hide()
end

-- The window ----------------------------------------------------------------------

local function CreateForm()
    frame = CreateFrame("Frame", "GuildProfessionsRecipesOrderForm", UIParent, "PortraitFrameTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    tinsert(UISpecialFrames, frame:GetName())

    -- What is ordered, right of the portrait: its tooltip, and shift-click
    -- to link it.
    frame.Item = CreateFrame("Button", nil, frame)
    frame.Item:SetSize(32, 32)
    frame.Item:SetPoint("TOPLEFT", ITEM_LEFT, -32)
    frame.Item.Icon = frame.Item:CreateTexture(nil, "ARTWORK")
    frame.Item.Icon:SetAllPoints()
    frame.Item:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    frame.Item:SetScript("OnEnter", function(self)
        ns.Viewer.ShowOutputTooltip(self, current.r)
    end)
    frame.Item:SetScript("OnLeave", GameTooltip_Hide)
    frame.Item:SetScript("OnClick", function()
        if IsModifiedClick("CHATLINK") then
            ns.Viewer.LinkRecipe(current.r)
        end
    end)
    frame.Recipe = Label(frame, "", "GameFontHighlightMed2")
    frame.Recipe:SetPoint("LEFT", frame.Item, "RIGHT", 8, 0)
    frame.Recipe:SetPoint("RIGHT", -LEFT, 0)
    frame.Recipe:SetWordWrap(false)

    -- Type.
    local typeTitle = Label(frame, L["Type"])
    typeTitle:SetPoint("TOPLEFT", LEFT, -80)
    frame.Open = Choice(frame, "UIRadioButtonTemplate", L["Open"], L["Any guild member who knows this recipe can accept this order."])
    frame.Open:SetPoint("TOPLEFT", typeTitle, "BOTTOMLEFT", -2, -4)
    frame.Personal = Choice(frame, "UIRadioButtonTemplate", L["Personal"], L["Only the member you choose can accept this order."])
    frame.Personal:SetPoint("TOPLEFT", frame.Open, "BOTTOMLEFT", 0, -2)
    frame.Open:SetScript("OnClick", function()
        SetPersonal(false)
    end)
    frame.Personal:SetScript("OnClick", function()
        SetPersonal(true)
        frame.Target:SetFocus()
    end)
    frame.Target = CreateFrame("EditBox", nil, frame, "InputBoxInstructionsTemplate")
    frame.Target:SetSize(TARGET_WIDTH, 20)
    frame.Target:SetAutoFocus(false)
    frame.Target:SetPoint("LEFT", frame.Personal.Label, "RIGHT", 12, 0)
    frame.Target.Instructions:SetText(L["Member's name"])
    frame.Target:HookScript("OnTextChanged", function(self, userInput)
        if userInput then
            current.target = nil
            ShowSuggestions()
        end
    end)
    frame.Target:HookScript("OnEditFocusGained", ShowSuggestions)
    -- Not at once: a click on a suggestion takes the focus away first.
    frame.Target:HookScript("OnEditFocusLost", function()
        C_Timer.After(0.2, HideSuggestions)
    end)
    frame.Target:SetScript("OnEnterPressed", function()
        local first = frame.Suggestions.buttons[1]
        if frame.Suggestions:IsShown() and first.guid then
            PickSuggestion(first)
        end
    end)
    frame.Suggestions = CreateSuggestions(frame, frame.Target)

    -- Payment.
    local paymentTitle = Label(frame, L["Payment"])
    paymentTitle:SetPoint("TOPLEFT", LEFT, -170)
    frame.Materials = Choice(frame, "UICheckButtonTemplate", L["I provide the materials"])
    frame.Materials:SetPoint("TOPLEFT", paymentTitle, "BOTTOMLEFT", -2, -4)
    frame.Tip = Choice(frame, "UICheckButtonTemplate", L["I add a tip of"])
    frame.Tip:SetPoint("TOPLEFT", frame.Materials, "BOTTOMLEFT", 0, -2)
    frame.Gold = NumberBox(frame, 50, 5)
    frame.Gold:SetPoint("LEFT", frame.Tip.Label, "RIGHT", 14, 0)
    local gold = Coin(frame, frame.Gold, "Interface\\MoneyFrame\\UI-GoldIcon")
    frame.Silver = NumberBox(frame, 26, 2)
    frame.Silver:SetPoint("LEFT", gold, "RIGHT", 10, 0)
    local silver = Coin(frame, frame.Silver, "Interface\\MoneyFrame\\UI-SilverIcon")
    frame.Copper = NumberBox(frame, 26, 2)
    frame.Copper:SetPoint("LEFT", silver, "RIGHT", 10, 0)
    Coin(frame, frame.Copper, "Interface\\MoneyFrame\\UI-CopperIcon")
    -- Typing an amount ticks the tip.
    for _, box in ipairs({ frame.Gold, frame.Silver, frame.Copper }) do
        box:HookScript("OnTextChanged", function(_, userInput)
            if userInput then
                frame.Tip:SetChecked(true)
            end
        end)
    end

    -- Quantity.
    local quantityTitle = Label(frame, L["Quantity"])
    quantityTitle:SetPoint("TOPLEFT", LEFT, -260)
    frame.Quantity = NumberBox(frame, 40, 3)
    frame.Quantity:SetPoint("LEFT", quantityTitle, "RIGHT", 12, 0)

    -- Note.
    local noteTitle = Label(frame, L["Note (optional)"])
    noteTitle:SetPoint("TOPLEFT", LEFT, -300)
    frame.Note = CreateFrame("ScrollFrame", nil, frame, "InputScrollFrameTemplate")
    frame.Note:SetPoint("TOPLEFT", noteTitle, "BOTTOMLEFT", 6, -10)
    frame.Note:SetSize(WIDTH - 2 * LEFT - 12, 96)
    -- The template sized its edit box before we sized it.
    frame.Note.EditBox:SetWidth(WIDTH - 2 * LEFT - 30)
    frame.Note.EditBox:SetMaxLetters(ns.Pack.LIMITS.note)
    if frame.Note.CharCount then
        frame.Note.CharCount:Hide()
    end

    frame.Error = Label(frame, "", "GameFontRedSmall")
    frame.Error:SetPoint("BOTTOMLEFT", LEFT, 40)
    frame.Error:SetPoint("RIGHT", -LEFT, 0)
    frame.Error:SetWordWrap(true)

    frame.Cancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.Cancel:SetSize(100, 22)
    frame.Cancel:SetPoint("BOTTOMRIGHT", -12, 12)
    frame.Cancel:SetText(CANCEL or "Cancel")
    frame.Cancel:SetScript("OnClick", function()
        frame:Hide()
    end)
    frame.Submit = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.Submit:SetSize(130, 22)
    frame.Submit:SetPoint("RIGHT", frame.Cancel, "LEFT", -6, 0)
    frame.Submit:SetScript("OnClick", Submit)

    frame:SetScript("OnHide", function()
        HideSuggestions()
        GameTooltip_Hide()
    end)
end

local function SetMoney(copper)
    copper = copper or 0
    frame.Gold:SetText(copper >= COPPER_PER_GOLD and tostring(math.floor(copper / COPPER_PER_GOLD)) or "")
    local silver = math.floor(copper / COPPER_PER_SILVER) % 100
    frame.Silver:SetText(silver > 0 and tostring(silver) or "")
    frame.Copper:SetText(copper % 100 > 0 and tostring(copper % 100) or "")
end

-- Opens the form for a recipe of a profession. id: one of our orders, to
-- change it; target: a member to suggest for a personal order.
function OrderForm.Open(skillLine, recipeID, id, target)
    if not ns.Data.CurrentGuild(false) then
        ns.Print(L["you are not in a guild (or the guild has not loaded yet)."])
        return
    end
    if not frame then
        CreateForm()
    end
    local order = id and ns.Data.GetOwnRecord(false).o[id]
    local crafters = ns.Orders.Crafters(ns.Data.CurrentGuild(false), skillLine, recipeID)
    if not order then
        -- The member whose recipes we were looking at, if they can take it.
        local suggested
        for _, crafter in ipairs(crafters) do
            if crafter.guid == target then
                suggested = crafter.guid
            end
        end
        target = suggested
    end
    current = { sl = skillLine, r = recipeID, id = order and id or nil, target = order and order.d or target }
    local name, icon = ns.Viewer.RecipeOutput(recipeID)
    frame:SetTitle(order and L["Change the order"] or L["Request an order"])
    frame:SetPortraitToAsset(ns.ProfessionIcon(skillLine))
    frame.Item.Icon:SetTexture(icon)
    frame.Recipe:SetText(name)

    -- Personal orders need a member who knows the recipe and runs a version
    -- with orders like ours. Disabled, its tooltip says which is missing.
    frame.Personal:SetEnabled(#crafters > 0)
    local labelColor = #crafters > 0 and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR
    if labelColor then
        frame.Personal.Label:SetTextColor(labelColor:GetRGB())
    end
    if #crafters > 0 then
        frame.Personal.tooltipText = L["Only the member you choose can accept this order."]
    elseif ns.Orders.KnownByOthers(ns.Data.CurrentGuild(false), skillLine, recipeID) then
        -- "0.9", as the version is spoken of.
        local version = ns.VersionString(ns.Orders.MIN_VERSION):gsub("%.0$", "")
        frame.Personal.tooltipText = L["Nobody else in the guild who knows this recipe can receive orders yet: they need version %s or later."]:format(version)
    else
        frame.Personal.tooltipText = L["Nobody else in the guild knows this recipe."]
    end
    frame.Target:SetText(current.target and ns.Data.NameOf(current.target) or "")
    SetPersonal(current.target ~= nil)

    frame.Materials:SetChecked(order ~= nil and order.m)
    frame.Tip:SetChecked(order ~= nil and (order.tip or 0) > 0)
    SetMoney(order and order.tip)
    frame.Quantity:SetText(tostring(order and order.q or 1))
    frame.Note.EditBox:SetText(order and order.note or "")
    frame.Submit:SetText(order and L["Save"] or L["Request"])
    ShowError(nil)

    frame:ClearAllPoints()
    local viewer = _G.GuildProfessionsRecipesViewer
    if viewer and viewer:IsShown() then
        frame:SetPoint("TOPLEFT", viewer, "TOPRIGHT", 40, 0)
    else
        frame:SetPoint("CENTER")
    end
    frame:Show()
end

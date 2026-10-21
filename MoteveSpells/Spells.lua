-- Moteve Spells - a tab on the side of the spellbook. It opens a panel that lists the class trainer
-- spells you can learn right now (with the total cost), and everything that comes later, level by
-- level, with the price. Spells you already know are left out.
local ADDON_NAME, ns = ...
local C = ns.C
local format, max, min, floor = string.format, math.max, math.min, math.floor

local W, ROW_H, HEAD_H = 330, 24, 26
local db

---------------------------------------------------------------------------
-- Spell helpers
---------------------------------------------------------------------------
-- What the character knows. The game replaces lower ranks with the newest one, so a lower rank
-- often reports "not known" - therefore the spellbook is scanned: every spell ID in it, and the
-- highest rank per spell name. A trainer spell counts as known if it, or any higher rank, is there.
local bookIDs, bookRank, bookStamp = {}, {}, -1

local function RankNumber(sub)
    return sub and tonumber(tostring(sub):match("(%d+)")) or nil
end

local function ScanBook()
    wipe(bookIDs); wipe(bookRank)
    local function Add(id, name, sub)
        if id then bookIDs[id] = true end
        if name then
            local r = RankNumber(sub) or 1
            if not bookRank[name] or r > bookRank[name] then bookRank[name] = r end
        end
    end
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(i)
            if info then
                for idx = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local it = C_SpellBook.GetSpellBookItemInfo(idx, bank)
                    local name, sub = C_SpellBook.GetSpellBookItemName(idx, bank)
                    Add(it and it.spellID, name or (it and it.name), sub or (it and it.subName))
                end
            end
        end
    elseif GetNumSpellTabs then
        for i = 1, GetNumSpellTabs() do
            local _, _, offset, num = GetSpellTabInfo(i)
            for idx = offset + 1, offset + num do
                local name, sub = GetSpellBookItemName(idx, BOOKTYPE_SPELL or "spell")
                local _, id = GetSpellBookItemInfo(idx, BOOKTYPE_SPELL or "spell")
                Add(id, name, sub)
            end
        end
    end
end

local function DirectKnown(id)
    if bookIDs[id] then return true end
    local fns = { (C_SpellBook and C_SpellBook.IsSpellKnown) or false, IsSpellKnown or false, IsPlayerSpell or false }
    for i = 1, 3 do
        local fn = fns[i]
        if fn then
            local ok, v = pcall(fn, id)
            if ok and v then return true end
        end
    end
    return false
end

local nextRank = {}   -- [spell ID] = the next rank's spell ID (from the trainer data)

local SpellName -- forward
local function Known(id)
    if not id then return false end
    local seen = 0
    local cur = id
    while cur and seen < 20 do
        if DirectKnown(cur) then return true end
        cur, seen = nextRank[cur], seen + 1
    end
    -- same name with an equal or higher rank in the spellbook
    local name, sub = SpellName(id)
    local r = RankNumber(sub) or 1
    if name and bookRank[name] and bookRank[name] >= r then return true end
    return false
end

SpellName = function(id)
    local name, icon
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        if info then name, icon = info.name, info.iconID end
    elseif GetSpellInfo then
        local n, _, ic = GetSpellInfo(id)
        name, icon = n, ic
    end
    local rank = (C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id))
        or (GetSpellSubtext and GetSpellSubtext(id)) or nil
    if not name and C_Spell and C_Spell.RequestLoadSpellData then pcall(C_Spell.RequestLoadSpellData, id) end
    return name, rank, icon
end

local function Money(copper)
    copper = copper or 0
    if GetCoinTextureString then return GetCoinTextureString(copper, 11) end
    local g, s, c = floor(copper / 10000), floor(copper / 100) % 100, copper % 100
    local t = {}
    if g > 0 then t[#t + 1] = g .. "g" end
    if s > 0 then t[#t + 1] = s .. "s" end
    if c > 0 or #t == 0 then t[#t + 1] = c .. "c" end
    return table.concat(t, " ")
end

-- which trainer spells concern this character, split into "now" and "later" (by level)
local function Collect()
    local _, class = UnitClass("player")
    local data = ns.DATA[class]
    if not data then return nil end
    local level = UnitLevel("player") or 1
    local faction = UnitFactionGroup("player")
    local _, _, raceID = UnitRace("player")

    pcall(ScanBook)
    wipe(nextRank)
    for _, list in pairs(data) do
        for _, s in ipairs(list) do
            for _, r in ipairs(s.req or {}) do nextRank[r] = s.id end
        end
    end

    local now, later, nowCost = {}, {}, 0
    local planned = {}   -- spells counted as "will be learned" for the prerequisite check
    local levels = {}
    for lv in pairs(data) do levels[#levels + 1] = lv end
    table.sort(levels)
    for _, lv in ipairs(levels) do
        for _, s in ipairs(data[lv]) do
            local ok = true
            if s.faction and s.faction ~= faction then ok = false end
            if ok and s.races then
                ok = false
                for _, r in ipairs(s.races) do if r == raceID then ok = true end end
            end
            -- ranks of talent spells only once the talent itself is learned
            if ok and s.talent and not Known(s.talent) then ok = false end
            if ok and not Known(s.id) then
                local e = { id = s.id, cost = s.cost or 0, level = lv, req = s.req }
                if lv <= level then
                    -- the previous rank must be known (or be learnable now as well)
                    e.missing = nil
                    for _, r in ipairs(s.req or {}) do
                        if not Known(r) and not planned[r] then e.missing = r end
                    end
                    now[#now + 1] = e
                    if not e.missing then nowCost = nowCost + e.cost; planned[s.id] = true end
                else
                    later[lv] = later[lv] or {}
                    table.insert(later[lv], e)
                end
            end
        end
    end
    return now, later, nowCost, level
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local P = CreateFrame("Frame", "MoteveSpellsPanel", UIParent)
P:SetSize(W, 470)
P:SetFrameStrata("HIGH")
P:SetClampedToScreen(true)
P:EnableMouse(true)
P:Hide()
ns.Glass(P, { radius = 14, alpha = 0.92, edge = 0.3 })
tinsert(UISpecialFrames, "MoteveSpellsPanel")

local title = ns.Font(P, "title", 16, C.text)
title:SetPoint("TOPLEFT", 16, -14)
local sub = ns.Font(P, "body", 11, C.muted)
sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
local close = CreateFrame("Button", nil, P)
close:SetSize(20, 20)
close:SetPoint("TOPRIGHT", -8, -8)
close.t = ns.Font(close, "bold", 15, C.muted, "CENTER")
close.t:SetPoint("CENTER")
close.t:SetText("×")
close:SetScript("OnClick", function() P:Hide() end)

-- "now" summary chip
local summary = ns.Pill(P, 11)
summary:SetPoint("TOPRIGHT", -34, -15)

local view = CreateFrame("Frame", nil, P)
view:SetPoint("TOPLEFT", 10, -54)
view:SetPoint("BOTTOMRIGHT", -10, 12)
view:SetClipsChildren(true)
local content = CreateFrame("Frame", nil, view)
content:SetPoint("TOPLEFT")
content:SetWidth(W - 20)
content:SetHeight(10)
local scroll = 0

local function Pool(ctor)
    local p = { all = {}, n = 0 }
    function p:Get() self.n = self.n + 1; local o = self.all[self.n] or ctor(); self.all[self.n] = o; o:Show(); return o end
    function p:Reset() for i = 1, #self.all do self.all[i]:Hide() end; self.n = 0 end
    return p
end

local heads = Pool(function()
    local f = CreateFrame("Frame", nil, content)
    f:SetHeight(HEAD_H)
    f.rule = ns.Rule(f)
    f.rule:SetPoint("BOTTOMLEFT", 6, 2); f.rule:SetPoint("BOTTOMRIGHT", -6, 2)
    f.text = ns.Font(f, "bold", 11, C.sub)
    f.text:SetPoint("BOTTOMLEFT", 6, 6)
    f.right = ns.Font(f, "body", 11, C.muted, "RIGHT")
    f.right:SetPoint("BOTTOMRIGHT", -6, 6)
    return f
end)

local rows = Pool(function()
    local b = CreateFrame("Button", nil, content)
    b:SetHeight(ROW_H)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    ns.Grad(b.hl, "HORIZONTAL", C.edge, 0.1, C.edge, 0)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(18, 18)
    b.icon:SetPoint("LEFT", 6, 0)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.name = ns.Font(b, "body", 12.5, C.text)
    b.name:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
    b.cost = ns.Font(b, "body", 11.5, C.text, "RIGHT")
    b.cost:SetPoint("RIGHT", -6, 0)
    b.name:SetPoint("RIGHT", b.cost, "LEFT", -8, 0)
    b:SetScript("OnEnter", function(self)
        if not self.spellID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID)
        if self.missing then
            local n, r = SpellName(self.missing)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Előbb kell: " .. (n or "?") .. (r and r ~= "" and (" (" .. r .. ")") or ""), 1, 0.45, 0.45)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end)

local function Head(y, text, right)
    local f = heads:Get()
    f:ClearAllPoints(); f:SetPoint("TOPLEFT", 0, -y); f:SetPoint("RIGHT", content, "RIGHT")
    f.text:SetText(text); f.right:SetText(right or "")
    return y + HEAD_H + 2
end

local function Row(y, e, dim)
    local b = rows:Get()
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, -y); b:SetPoint("RIGHT", content, "RIGHT")
    local name, rank, icon = SpellName(e.id)
    b.spellID, b.missing = e.id, e.missing
    b.icon:SetTexture(icon or 134400)
    b.icon:SetDesaturated(dim or e.missing ~= nil)
    local label = (name or ("#" .. e.id)) .. ((rank and rank ~= "") and ("  " .. ns.Hex(C.low) .. rank .. "|r") or "")
    if e.missing then label = label .. "  " .. ns.Hex(ns.C.kill or { 1, 0.45, 0.45 }) .. "(előző rank hiányzik)|r" end
    b.name:SetText(label)
    local c = (dim or e.missing) and C.sub or C.text
    b.name:SetTextColor(c[1], c[2], c[3])
    b.cost:SetText(Money(e.cost))
    return y + ROW_H
end

function P:Refresh()
    if not self:IsShown() then return end
    heads:Reset(); rows:Reset()
    local _, classFile = UnitClass("player")
    local className = UnitClass("player")
    title:SetText("Tanulható spellek")
    local now, later, nowCost, level = Collect()
    if not now then
        sub:SetText("Ehhez a classhoz nincs adat.")
        summary:Hide()
        content:SetHeight(10)
        return
    end
    sub:SetText(format("%s  ·  %d. szint", className or classFile, level))
    summary:Set("Most: " .. #now .. "  ·  " .. Money(nowCost), C.cyanPale, C.cyan, 0.15, C.cyan, 0.45)
    summary:Show()

    local y = 4
    y = Head(y, "MOST TANULHATÓ", #now > 0 and ("összesen " .. Money(nowCost)) or "")
    if #now == 0 then
        local b = rows:Get()
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, -y); b:SetPoint("RIGHT", content, "RIGHT")
        b.spellID, b.missing = nil, nil
        b.icon:SetTexture(nil)
        b.name:SetText("Most nincs új spell a trénernél.")
        b.name:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        b.cost:SetText("")
        y = y + ROW_H
    end
    for _, e in ipairs(now) do y = Row(y, e) end

    local lvls = {}
    for lv in pairs(later) do lvls[#lvls + 1] = lv end
    table.sort(lvls)
    local shown = 0
    for _, lv in ipairs(lvls) do
        if db.future == "all" or shown < (db.futureLevels or 10) then
            shown = shown + 1
            local sum = 0
            for _, e in ipairs(later[lv]) do sum = sum + e.cost end
            y = y + 6
            y = Head(y, format("%d. SZINT", lv), Money(sum))
            for _, e in ipairs(later[lv]) do y = Row(y, e, true) end
        end
    end
    y = y + 8
    content:SetHeight(y)
    local vh = view:GetHeight() or 400
    scroll = max(0, min(scroll, y - vh))
    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", 0, scroll)
end

view:EnableMouseWheel(true)
view:SetScript("OnMouseWheel", function(_, d)
    scroll = scroll - d * ROW_H * 3
    P:Refresh()
end)
P:SetScript("OnShow", function(self) scroll = 0; self:Refresh() end)

-- names of spells that were not cached yet arrive a moment later
local pendingT = 0
P:SetScript("OnUpdate", function(self, el)
    pendingT = pendingT + el
    if pendingT > 2 then pendingT = 0; self:Refresh() end
end)

---------------------------------------------------------------------------
-- Spellbook tab
---------------------------------------------------------------------------
local tab

local function Book() return SpellBookFrame or PlayerSpellsFrame end

local function PlacePanel()
    local book = Book()
    P:ClearAllPoints()
    if book and book:IsShown() then
        -- right of the spellbook (past the button); on the left if there is no room on the right
        local right = (book:GetRight() or 0) * book:GetEffectiveScale() / UIParent:GetEffectiveScale()
        if right + W + 70 > (UIParent:GetWidth() or 1920) then
            P:SetPoint("TOPRIGHT", book, "TOPLEFT", -8, -12)
        else
            P:SetPoint("TOPLEFT", book, "TOPRIGHT", 60, -12)
        end
        P:SetHeight(max(380, min(560, (book:GetHeight() or 470) - 60)))
    else
        P:SetPoint("CENTER", UIParent, "CENTER", 200, 40)
        P:SetHeight(470)
    end
end

local function Toggle()
    if P:IsShown() then P:Hide() else PlacePanel(); P:Show() end
    if tab then tab:SetChecked(P:IsShown()) end
end

local function MakeTab()
    local book = Book()
    if tab or not book then return end
    -- a large glass button on the outer right edge of the spellbook (independent of the
    -- spellbook's own layout, so it looks the same on every client)
    tab = CreateFrame("CheckButton", "MoteveSpellsTab", book)
    tab:SetSize(46, 46)
    tab:SetFrameStrata("HIGH")
    ns.Glass(tab, { radius = 10, alpha = 0.9, edge = 0.45 })
    tab.glow = ns.Img(tab, "glow", "BACKGROUND", -8, C.violet, 0.35)
    tab.glow:SetBlendMode("ADD")
    tab.glow:SetPoint("TOPLEFT", -14, 14); tab.glow:SetPoint("BOTTOMRIGHT", 14, -14)
    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetPoint("TOPLEFT", 6, -6); tab.icon:SetPoint("BOTTOMRIGHT", -6, 6)
    tab.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tab.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    tab.hl = tab:CreateTexture(nil, "HIGHLIGHT")
    tab.hl:SetAllPoints(tab.icon)
    tab.hl:SetColorTexture(1, 1, 1, 0.15)
    tab:SetScript("OnClick", Toggle)
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Tanulható spellek", 1, 1, 1)
        GameTooltip:AddLine("Mit tanulhatsz most a trénernél, és mi jön később.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- a small number on the tab: how many spells you can learn now
    tab.badge = ns.Pill(tab, 11)
    tab.badge.padX = 6
    tab.badge:SetPoint("CENTER", tab, "TOPRIGHT", -2, -2)
    tab.badge:SetFrameLevel(tab:GetFrameLevel() + 5)
    tab.badge:Hide()

    local function Place()
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", book, "TOPRIGHT", 6, -40)
        local now = Collect()
        if now and #now > 0 then
            tab.badge:Set(tostring(#now), C.ink, C.gold, 1)
            tab.badge:Show()
        else
            tab.badge:Hide()
        end
    end
    book:HookScript("OnShow", function() Place(); if P:IsShown() then PlacePanel() end end)
    book:HookScript("OnHide", function() P:Hide(); tab:SetChecked(false) end)
    tab.Place = Place
    Place()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
for _, e in ipairs({ "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_LEVEL_UP", "TRAINER_UPDATE", "SPELL_DATA_LOAD_RESULT" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e, a1)
    if e == "ADDON_LOADED" then
        if a1 == ADDON_NAME then
            MoteveSpellsDB = MoteveSpellsDB or {}
            db = MoteveSpellsDB
            if db.futureLevels == nil then db.futureLevels = 10 end
            if db.future == nil then db.future = "some" end
        elseif a1 == "Blizzard_PlayerSpells" or a1 == "Blizzard_SpellBook" then
            pcall(MakeTab)
        end
        return
    end
    if e == "PLAYER_LOGIN" then pcall(MakeTab) return end
    if tab and tab.Place then pcall(tab.Place) end
    if P:IsShown() then P:Refresh() end
end)

---------------------------------------------------------------------------
-- Slash
---------------------------------------------------------------------------
SLASH_MOTEVESPELLS1, SLASH_MOTEVESPELLS2 = "/msp", "/motevespells"
SlashCmdList.MOTEVESPELLS = function(input)
    local cmd = (input or ""):lower():match("^(%S*)")
    if cmd == "all" then
        db.future = (db.future == "all") and "some" or "all"
        print("|cffa88bffMoteve Spells|r: jövőbeli szintek: " .. (db.future == "all" and "mind (60-ig)" or "a következő 10"))
        P:Refresh()
    else
        Toggle()
    end
end

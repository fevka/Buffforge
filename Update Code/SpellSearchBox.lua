--[[
    SpellSearchBox.lua
    
    A standalone module that creates a search box with autocomplete for Spells and Items.
    It scans the player's Spellbook and Bags to populate the search list.
    
    Usage:
    local searchBox = SpellSearchBox:Create(UIParent, function(id, name, type)
        print("Selected:", name, "ID:", id, "Type:", type)
    end)
    searchBox:SetPoint("CENTER", 0, 0)
]]

local SpellSearchBox = {}
_G.SpellSearchBox = SpellSearchBox

-- Constants
local AUTOCOMPLETE_MAX_ROWS = 10
local AUTOCOMPLETE_ROW_HEIGHT = 22
local AUTOCOMPLETE_ICON_SIZE = 20

-- Cache
local autocompleteCache = nil

------------------------------------------------------------------------
-- 1. Build Cache: Spells & Items
------------------------------------------------------------------------
local function BuildAutocompleteCache()
    local cache = {}
    local seen = {} -- Prevent duplicates

    -- A. Scan Spellbook
    local numLines = C_SpellBook.GetNumSpellBookSkillLines()
    for lineIdx = 1, numLines do
        local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(lineIdx)
        if lineInfo and not lineInfo.shouldHide then
            local category = lineInfo.name or "Spells"
            for slotOffset = 1, lineInfo.numSpellBookItems do
                local slotIdx = lineInfo.itemIndexOffset + slotOffset
                local itemInfo = C_SpellBook.GetSpellBookItemInfo(slotIdx, Enum.SpellBookSpellBank.Player)
                
                if itemInfo and itemInfo.spellID
                    and not itemInfo.isPassive
                    and not itemInfo.isOffSpec
                    and itemInfo.itemType ~= Enum.SpellBookItemType.Flyout
                    and itemInfo.itemType ~= Enum.SpellBookItemType.FutureSpell
                then
                    local id = itemInfo.spellID
                    if not seen[id] then
                        seen[id] = true
                        table.insert(cache, {
                            id = id,
                            name = itemInfo.name,
                            nameLower = itemInfo.name:lower(),
                            icon = itemInfo.iconID or 134400,
                            category = category,
                            isItem = false,
                        })
                    end
                end
            end
        end
    end

    -- B. Scan Bags for Usable Items
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local containerInfo = C_Container.GetContainerItemInfo(bag, slot)
            if containerInfo and containerInfo.itemID then
                local itemID = containerInfo.itemID
                if not seen["item:" .. itemID] then
                    local spellName, spellID = C_Item.GetItemSpell(itemID)
                    if spellName then
                        -- FIX: Use GetItemInfoInstant to avoid nil returns on uncached items
                        local itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
                        
                        local isValid = false
                        
                        -- 1. Consumables (ClassID 0)
                        if classID == 0 then isValid = true end
                        
                        -- 2. Trinkets (ClassID 4=Armor, EquipLoc="INVTYPE_TRINKET") 
                        -- Note: Checking EquipLoc string directly or ID. 
                        if classID == 4 and (itemEquipLoc == "INVTYPE_TRINKET" or itemEquipLoc == 13 or itemEquipLoc == 14) then
                            isValid = true
                        end
                        
                        -- 3. Also allow Weapons with Use effects (ClassID 2) if needed, but sticking to user request for now.
                        
                        -- SPECIAL: Battle Pets are completely excluded (ClassID 17)
                        if classID == 17 then isValid = false end

                        if isValid then
                            seen["item:" .. itemID] = true
                            local itemName = containerInfo.itemName or C_Item.GetItemNameByID(itemID) or "Unknown Item"
                            local finalIcon = containerInfo.iconFileID or icon or 134400
                            
                            local cat = "Item"
                            if classID == 0 then cat = "Consumable"
                            elseif itemEquipLoc == "INVTYPE_TRINKET" then cat = "Trinket" end
                            
                            table.insert(cache, {
                                id = itemID,
                                name = itemName,
                                nameLower = itemName:lower(),
                                icon = finalIcon,
                                category = cat,
                                isItem = true,
                            })
                        end
                    end
                end
            end
        end
    end

    autocompleteCache = cache
    return cache
end

------------------------------------------------------------------------
-- 2. Search Logic
------------------------------------------------------------------------
local function SearchAutocomplete(query)
    if not query or #query < 1 then return nil end

    local cache = autocompleteCache or BuildAutocompleteCache()
    local queryLower = query:lower()
    local queryNum = tonumber(query)
    
    local prefixMatches = {}
    local substringMatches = {}
    
    -- 0. DIRECT ID MATCH (For Hidden/Proc Spells not in Spellbook)
    if queryNum then
        -- Check Spell
        local info = C_Spell.GetSpellInfo(queryNum)
        if info then
            table.insert(prefixMatches, {
                id = queryNum,
                name = info.name,
                nameLower = info.name:lower(),
                icon = info.iconID,
                category = "Exact ID",
                isItem = false,
                desc = " (Hidden/Proc)"
            })
        end
        
        -- Check Item
        local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(queryNum)
        if name then
             table.insert(prefixMatches, {
                id = queryNum,
                name = name,
                nameLower = name:lower(),
                icon = icon,
                category = "Exact Item ID",
                isItem = true
            })
        end
    end

    for _, entry in ipairs(cache) do
        local isMatch = false
        local isPrefix = false

        -- Match by numeric ID (avoid duplicates if we already added exact match)
        if queryNum and entry.id == queryNum then
             -- Already added via direct check above, or we can skip duplicate check
             -- visual redundancy is fine, but let's avoid it if possible
             isMatch = false 
        elseif queryNum and tostring(entry.id):find(query, 1, true) == 1 then
            isMatch = true
            isPrefix = true
        end

        -- Match by name
        if not isMatch then
            local pos = entry.nameLower:find(queryLower, 1, true)
            if pos then
                isMatch = true
                isPrefix = (pos == 1)
            end
        end

        if isMatch then
            if isPrefix then
                table.insert(prefixMatches, entry)
            else
                table.insert(substringMatches, entry)
            end
        end

        if #prefixMatches >= AUTOCOMPLETE_MAX_ROWS then break end
    end

    -- Merge results
    local results = {}
    for _, entry in ipairs(prefixMatches) do
        table.insert(results, entry)
        if #results >= AUTOCOMPLETE_MAX_ROWS then break end
    end
    if #results < AUTOCOMPLETE_MAX_ROWS then
        for _, entry in ipairs(substringMatches) do
            table.insert(results, entry)
            if #results >= AUTOCOMPLETE_MAX_ROWS then break end
        end
    end

    return #results > 0 and results or nil
end

------------------------------------------------------------------------
-- 3. Dropdown UI
------------------------------------------------------------------------
local function CreateAutocompleteDropdown(parent)
    local dropdown = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    dropdown:SetFrameStrata("TOOLTIP")
    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dropdown:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    dropdown:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    dropdown:SetWidth(parent:GetWidth())
    dropdown:SetHeight(1) -- Dynamic
    dropdown:Hide()
    dropdown:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -2)
    dropdown:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", 0, -2)

    dropdown.rows = {}

    for i = 1, AUTOCOMPLETE_MAX_ROWS do
        local row = CreateFrame("Button", nil, dropdown)
        row:SetHeight(AUTOCOMPLETE_ROW_HEIGHT)
        row:SetPoint("LEFT", 2, 0)
        row:SetPoint("RIGHT", -2, 0)
        row:SetPoint("TOP", 0, -((i - 1) * AUTOCOMPLETE_ROW_HEIGHT) - 2)
        
        -- Highlights
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0.3, 0.5, 0.8, 0.3)
        
        -- Icon
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(AUTOCOMPLETE_ICON_SIZE, AUTOCOMPLETE_ICON_SIZE)
        row.icon:SetPoint("LEFT", 4, 0)
        
        -- Text
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetPoint("RIGHT", -60, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        
        -- Category
        row.cat = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.cat:SetPoint("RIGHT", -4, 0)
        row.cat:SetTextColor(0.5, 0.5, 0.5)

        row:SetScript("OnClick", function(self)
            if self.entry then
                parent:OnSelect(self.entry)
            end
        end)

        dropdown.rows[i] = row
    end

    return dropdown
end

------------------------------------------------------------------------
-- 4. Main Widget Creator
------------------------------------------------------------------------
function SpellSearchBox:Create(parent, onSelectCallback)
    -- Main Container
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(200, 30)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

    -- Search Icon (Left)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    -- Shift down by 1px
    icon:SetPoint("LEFT", frame, "LEFT", 6, -1) 
    icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    icon:SetVertexColor(0.6, 0.6, 0.6)

    -- EditBox
    local editbox = CreateFrame("EditBox", nil, frame)
    editbox:SetPoint("LEFT", 24, 0) -- Space for icon
    editbox:SetPoint("RIGHT", -8, 0)
    editbox:SetHeight(20)
    editbox:SetFontObject("ChatFontNormal")
    editbox:SetAutoFocus(false)
    editbox:EnableMouse(true)
    
    -- Placeholder Text
    editbox.placeholder = editbox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    editbox.placeholder:SetPoint("LEFT", 0, 0)
    editbox.placeholder:SetText("Search Spell/Item...")
    editbox.placeholder:SetTextColor(0.5, 0.5, 0.5)
    
    editbox:SetScript("OnEditFocusGained", function(self) self.placeholder:Hide() end)
    editbox:SetScript("OnEditFocusLost", function(self) if self:GetText()=="" then self.placeholder:Show() end end)
    
    -- Dropdown
    local dropdown = CreateAutocompleteDropdown(frame)
    frame.dropdown = dropdown

    -- Colors
    local _, classFilename = UnitClass("player")
    local classColor = C_ClassColor.GetClassColor(classFilename)
    local COLOR_CONSUMABLE = {r=0.2, g=1, b=0.2} -- Green
    local COLOR_TRINKET = {r=1, g=0.5, b=0} -- Orange
    local COLOR_DEFAULT = {r=0.6, g=0.6, b=0.6} -- Gray

    -- Logic
    function frame:OnSelect(entry)
        -- Simplify: Just trigger callback. Don't touch EditBox text to avoid taint.
        dropdown:Hide()
        editbox:ClearFocus()
        if onSelectCallback then
            -- Pure data pass-through
            onSelectCallback(entry.id, entry.name, entry.isItem and "item" or "spell")
        end
    end

    editbox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        local results = SearchAutocomplete(text)

        if results then
            dropdown:SetHeight(#results * AUTOCOMPLETE_ROW_HEIGHT + 4)
            dropdown:Show()
            for i, row in ipairs(dropdown.rows) do
                if results[i] then
                    row:Show()
                    local entry = results[i]
                    row.entry = entry
                    row.name:SetText(entry.name)
                    row.cat:SetText(entry.category)
                    row.icon:SetTexture(entry.icon)
                    
                    -- Apply Category Color
                    local c = COLOR_DEFAULT
                    if entry.isItem then
                        if entry.category == "Consumable" then c = COLOR_CONSUMABLE
                        elseif entry.category == "Trinket" then c = COLOR_TRINKET end
                    elseif entry.category then
                        -- Assume Spells (or class categories) use Class Color
                        c = classColor
                    end
                    row.cat:SetTextColor(c.r, c.g, c.b)
                else
                    row:Hide()
                end
            end
        else
            dropdown:Hide()
        end
    end)

    editbox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        dropdown:Hide()
    end)
    
    editbox:SetScript("OnEditFocusLost", function(self)
        -- Small delay to allow clicking on a dropdown row
        C_Timer.After(0.2, function()
            if not self:HasFocus() then
                dropdown:Hide()
            end
        end)
    end)



    return frame
end

------------------------------------------------------------------------
-- 5. Global Pick Mode Logic
------------------------------------------------------------------------
local pickerFrame = nil



local function IsPicking()
    return pickerFrame and pickerFrame:IsShown()
end

function SpellSearchBox:StartPickMode(onSelect)
    if not pickerFrame then
        pickerFrame = CreateFrame("Frame", "BuffForgePickFrame", UIParent)
        pickerFrame:SetAllPoints(UIParent)
        pickerFrame:SetFrameStrata("TOOLTIP")
        pickerFrame:EnableMouse(false) -- DO NOT ENABLE MOUSE (We want clicks to pass through)
        pickerFrame:Hide()
        
        -- Instruction Text
        local t = pickerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        t:SetPoint("CENTER", 0, 100)
        pickerFrame.text = t
    end

    pickerFrame.text:SetText("PICK SKILL MODE\n|cffffffffClick on a spell/item in your spellbook, bag, or action bar|r\n|cffaaaaaa(Right-click or ESC to cancel)|r")
    SetCursor("CAST_CURSOR")
    pickerFrame:Show()
    
    -- We use a separate frame for the listener to avoid conflicts
    if not pickerFrame.listener then
        pickerFrame.listener = CreateFrame("Frame")
    end
    
    pickerFrame.listener:SetScript("OnUpdate", function(self)
        if not IsPicking() then 
            self:SetScript("OnUpdate", nil)
            return 
        end
        
        -- Handle ESC
        if IsKeyDown("ESCAPE") then
            pickerFrame:Hide()
            ResetCursor()
            print("|cff00ccffBuffForge:|r Pick mode cancelled.")
            return
        end

        -- Handle Click (Passive Detection)
        if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
            local isRight = IsMouseButtonDown("RightButton")
            
             self:SetScript("OnUpdate", function(innerSelf)
                if not IsMouseButtonDown("LeftButton") and not IsMouseButtonDown("RightButton") then
                    pickerFrame:Hide()
                    ResetCursor()
                    
                    if isRight then
                        print("|cff00ccffBuffForge:|r Pick cancelled.")
                    else
                        -- Use the new GetTargetUnderMouse logic from BlizzardAuraTracker
                        if BlizzardAuraTracker and BlizzardAuraTracker.GetTargetUnderMouse then
                             local id, name, type = BlizzardAuraTracker:GetTargetUnderMouse()
                             
                             if id then
                                 print("|cff00ccffBuffForge:|r Picked: "..(name or "Unknown").." ("..id..")")
                                 -- Pass back to the SearchBox (Config logic)
                                 if onSelect then 
                                     onSelect(id, name, type) 
                                 end
                                 
                                 if Config and Config.RefreshUI then
                                     C_Timer.After(0.1, function() Config:RefreshUI() end)
                                 end
                             else
                                 print("|cffff0000BuffForge:|r No valid spell or item found under mouse.")
                             end
                        else
                             print("|cffff0000BuffForge Error:|r BlizzardAuraTracker module missing!")
                        end
                    end
                    innerSelf:SetScript("OnUpdate", nil)
                end
            end)
        end
    end)
end

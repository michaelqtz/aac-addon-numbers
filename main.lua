local api = require("api")

local numbers_addon = {
	name = "Numbers",
	author = "Michaelqt",
	version = "1.0.0",
	desc = "Numbers diff or skill diff? (It's numbers)"
}

local numbersWindow
local categories = {
    "Guilds",
    "Players",
    "Kills",
    "Deaths",
    "K/D Ratio",
}
local currentCategory = 1
local clockTimer = 2990
local CLOCK_RESET_TIMER = 3000

local isLoaded = false

local currentUiTime
local names
local factions
local guilds
local guildFactions
local kills 
local deaths

local function getKeysSortedByValue(tbl, sortFunction)
    local keys = {}
    for key in pairs(tbl) do
      table.insert(keys, key)
    end
    table.sort(keys, function(a, b)
      return sortFunction(tbl[a], tbl[b])
    end)
    return keys
  end

local function addUnitToInfoTables(unitInfo) 
    if unitInfo.type ~= "character" then return end -- only log player names
    local name = unitInfo.name
    local lastSeen = api.Time:GetUiMsec()
    names[name] = lastSeen
    if unitInfo.expeditionName ~= nil and unitInfo.expeditionName ~= "" then 
        guilds[name] = unitInfo.expeditionName
        guildFactions[unitInfo.expeditionName] = unitInfo.faction
    else
        guilds[name] = ""
        guildFactions[""] = "neutral"
    end
    factions[name] = unitInfo.faction 
end 

local function processCombatMessage(targetUnitId, combatEvent, source, target, ...)

    -- api.Log:Info("Combat Message: "..combatEvent)
    -- for i = 1, #arg do 
    --     api.Log:Info("Arg "..i..": "..tostring(arg[i]))
    -- end 
end

local function processCombatText(sourceUnitId, targetUnitId, amount, skillType, hitOrMissType, weaponDamage, isSynergy, distance)
    local unitInfos = {}
    if sourceUnitId ~= nil then 
        table.insert(unitInfos, api.Unit:GetUnitInfoById(sourceUnitId))
    end
    if targetUnitId ~= nil then 
        table.insert(unitInfos, api.Unit:GetUnitInfoById(targetUnitId))
    end
    for i, unitInfo in ipairs(unitInfos) do 
        addUnitToInfoTables(unitInfo)
    end
    -- api.Log:Info(string.format("Combat Text: Type=%s Amount=%d Critical=%s Color=%s OverHeal=%s", combatType, amount, tostring(isCritical), tostring(color), tostring(overHeal)))
    -- if combatType == "DAMAGE" then 
    --     api.Log:Info("Damage dealt: "..amount)
    -- elseif combatType == "HEAL" then 
    --     api.Log:Info("Heal done: "..amount.." Overheal: "..tostring(overHeal))
    -- end 
end

local function getNumbersList(category, leftList, rightList)
    local numbersListTable = {}
    numbersListTable["left"] = {}
    numbersListTable["right"] = {}
    local factionCounts = { friendly=0, hostile=0 }
    local guildCounts = {}
    if currentCategory == 1 then 
        -- Guilds
        for name, _ in pairs(names) do 
            local listEntry = {}
            local faction = factions[name]
            local guild = guilds[name]
            factionCounts[faction] = factionCounts[faction] + 1

            if guild == nil or guild == "" and faction == "friendly" then 
                guild = "FRIENDLY (No Guild)"
            elseif guild == nil or guild == "" and faction == "hostile" then 
                guild = "HOSTILE (No Guild)"
            end 

            if guildCounts[guild] == nil then 
                guildCounts[guild] = 1
            else 
                guildCounts[guild] = guildCounts[guild] + 1
            end
        end 
        local sortedGuilds = getKeysSortedByValue(guildCounts, function(a, b) return a > b end)
        for _, guild in pairs(sortedGuilds) do 
            local count = guildCounts[guild]
            local listEntry = {}
            if guild == "FRIENDLY (No Guild)" or guild == "HOSTILE (No Guild)" then 
                listEntry.text = tostring(count) .. " Guildless"
            else 
                listEntry.text = tostring(count) .. " <"..guild..">"
            end

            if guildFactions[guild] == "friendly" then 
                table.insert(numbersListTable["left"], listEntry)
            else 
                table.insert(numbersListTable["right"], listEntry)
            end
        end
    end    
    numbersListTable["friendly"] = factionCounts["friendly"]
    numbersListTable["hostile"] = factionCounts["hostile"]
    return numbersListTable
end

local function reinitializeList()
    names = {}
    guilds = {}
    kills = {}
    deaths = {}
    factions = {}
    guildFactions = {}
    currentUiTime = api.Time:GetUiMsec()
    numbersWindow.leftList:SetItemTrees({})
    numbersWindow.rightList:SetItemTrees({})
    numbersWindow.labelTotalFriendlies:SetText("Greens: 0")
    numbersWindow.labelTotalHostiles:SetText("Reds: 0")
end 

local function refreshUi()
    local numbersList = getNumbersList(nil, numbersWindow.leftList, numbersWindow.rightList)
    
    numbersWindow.leftList:ResetScroll(0)
    numbersWindow.rightList:ResetScroll(0)
    numbersWindow.leftList:SetItemTrees(numbersList["left"])
    numbersWindow.rightList:SetItemTrees(numbersList["right"])
    numbersWindow.labelTotalFriendlies:SetText("Greens: "..tostring(numbersList["friendly"]))
    numbersWindow.labelTotalHostiles:SetText("Reds: "..tostring(numbersList["hostile"]))
    -- api.Log:Info("Total Friendly: "..tostring(numbersList["friendly"]).." Total Hostile: "..tostring(numbersList["hostile"]))
end

local function OnUpdate(dt)
    
    clockTimer = clockTimer + dt
    if clockTimer > CLOCK_RESET_TIMER then 
        clockTimer = 0
        refreshUi()

        if isLoaded == false then 
            isLoaded = true
            local settings = api.GetSettings("numbers")
            if settings.x ~= nil and settings.y ~= nil then 
                numbersWindow:RemoveAllAnchors()
                numbersWindow:AddAnchor("TOPLEFT", "UIParent", settings.x, settings.y)
            end
        end


        -- for name, lastSeen in pairs(names) do 
        --     api.Log:Info("Name: "..name.." Guild: "..guilds[name].." Faction: "..factions[name])
        -- end 
    end 
end 

local function OnLoad()
    -- Initializations
	local settings = api.GetSettings("numbers")
    names = {}
    guilds = {}
    kills = {}
    deaths = {}
    factions = {}
    guildFactions = {}

    -- Main Window
	numbersWindow = api.Interface:CreateEmptyWindow("numbersWindow", "UIParent")
    numbersWindow:AddAnchor("CENTER", "UIParent", 10, 10)
    numbersWindow:SetExtent(300, 200)
    

    --- Add dragable bar across top
    local moveWnd = numbersWindow:CreateChildWidget("label", "moveWnd", 0, true)
    moveWnd:AddAnchor("TOPLEFT", numbersWindow, 12, 0)
    moveWnd:AddAnchor("TOPRIGHT", numbersWindow, 0, 0)
    moveWnd:SetHeight(35)
    moveWnd.style:SetFontSize(FONT_SIZE.LARGE)
    moveWnd.style:SetAlign(ALIGN.LEFT)
    moveWnd:SetText("Numbers")
    ApplyTextColor(moveWnd, FONT_COLOR.WHITE)
    -- Drag handlers for dragable bar
    function moveWnd:OnDragStart()
        if api.Input:IsShiftKeyDown() then
            numbersWindow:StartMoving()
            api.Cursor:ClearCursor()
            api.Cursor:SetCursorImage(CURSOR_PATH.MOVE, 0, 0)
        end
    end
    moveWnd:SetHandler("OnDragStart", moveWnd.OnDragStart)
    function moveWnd:OnDragStop()
        numbersWindow:StopMovingOrSizing()
        settings.x, settings.y = numbersWindow:GetOffset()
        api.Cursor:ClearCursor()
    end
    moveWnd:SetHandler("OnDragStop", moveWnd.OnDragStop)
    moveWnd:EnableDrag(true)
    -- Background for Title Bar
    moveWnd.bg = moveWnd:CreateNinePartDrawable(TEXTURE_PATH.HUD, "background")
    moveWnd.bg:SetTextureInfo("bg_quest")
    moveWnd.bg:SetColor(0, 0, 0, 0.7)
    moveWnd.bg:AddAnchor("TOPLEFT", moveWnd, -12, 0)
    moveWnd.bg:AddAnchor("BOTTOMRIGHT", moveWnd, 0, 0)

    -- Labels for total friendly and hostile counts
    labelTotalFriendlies = numbersWindow:CreateChildWidget("label", "labelTotalFriendlies", 0, true)
    labelTotalFriendlies:AddAnchor("TOPLEFT", numbersWindow, 20, 40)
    labelTotalFriendlies.style:SetFontSize(FONT_SIZE.MIDDLE)
    labelTotalFriendlies.style:SetAlign(ALIGN.LEFT)
    ApplyTextColor(labelTotalFriendlies, FONT_COLOR.GREEN)
    labelTotalFriendlies:SetText("Greens: 0")
    numbersWindow.labelTotalFriendlies = labelTotalFriendlies
    

    labelTotalHostiles = numbersWindow:CreateChildWidget("label", "labelTotalHostiles", 0, true)
    labelTotalHostiles:AddAnchor("RIGHT", labelTotalFriendlies, 140, 0)
    labelTotalHostiles.style:SetFontSize(FONT_SIZE.MIDDLE)
    labelTotalHostiles.style:SetAlign(ALIGN.LEFT)
    ApplyTextColor(labelTotalHostiles, FONT_COLOR.RED)
    labelTotalHostiles:SetText("Reds: 0")
    numbersWindow.labelTotalHostiles = labelTotalHostiles

    -- Refresh Button
    local refreshButton = numbersWindow:CreateChildWidget("button", "refreshButton", 0, true)
    refreshButton:AddAnchor("TOPRIGHT", numbersWindow, -35, 6)
    refreshButton:Show(true)
    api.Interface:ApplyButtonSkin(refreshButton, BUTTON_BASIC.RESET)
    refreshButton:SetExtent(20, 20)
    numbersWindow.refreshButton = refreshButton
    function refreshButton:OnClick()
        reinitializeList()
    end
    refreshButton:SetHandler("OnClick", refreshButton.OnClick)

    -- Minimize button
    local minimizeButton = numbersWindow:CreateChildWidget("button", "minimizeButton", 0, true)
    minimizeButton:SetExtent(26, 28)
    minimizeButton:AddAnchor("TOPRIGHT", numbersWindow, -9, 3)
    local minimizeButtonTexture = minimizeButton:CreateImageDrawable(TEXTURE_PATH.HUD, "background")
    minimizeButtonTexture:SetTexture(TEXTURE_PATH.HUD)
    minimizeButtonTexture:SetCoords(754, 121, 26, 28)
    minimizeButtonTexture:AddAnchor("TOPLEFT", minimizeButton, 0, 0)
    minimizeButtonTexture:SetExtent(26, 28)

    -- Left & Right Numbers Lists
    local leftList = W_CTRL.CreateScrollListBox("leftList", numbersWindow)
	leftList:SetExtent(numbersWindow:GetWidth() / 2, numbersWindow:GetHeight() - 60)
	leftList:AddAnchor("TOPLEFT", numbersWindow, 5, 50)
	leftList.content:UseChildStyle(false)
	-- leftList.content:EnableSelectParent(false)
	leftList.content:SetInset(-12, 1, -16, 1)
	leftList.content.itemStyle:SetFontSize(FONT_SIZE.SMALL)
	-- leftList.content.childStyle:SetFontSize(FONT_SIZE.MIDDLE)
	leftList.content.itemStyle:SetAlign(ALIGN.LEFT)
	-- leftList.content:SetTreeTypeIndent(true, 20)
	leftList.content:SetHeight(0)
	-- leftList.content:SetSubTextOffset(20, 0, true)
	local color = FONT_COLOR.WHITE
	leftList.content:SetDefaultItemTextColor(color[1], color[2], color[3], color[4])
	-- color = FONT_COLOR.WHITE
	-- leftList.content.childStyle:SetColor(color[1], color[2], color[3], color[4])
    leftList.bg:Show(false)
    leftList:Clickable(false)
    numbersWindow.leftList = leftList


    local rightList = W_CTRL.CreateScrollListBox("rightList", numbersWindow)
    rightList:SetExtent(numbersWindow:GetWidth() / 2, numbersWindow:GetHeight() - 60)
    rightList:AddAnchor("LEFT", leftList, "RIGHT", -10, 0)
    -- rightList.content:UseChildStyle(false)
    -- rightList.content:EnableSelectParent(false)
    rightList.content:SetInset(-10, 1, -16, 1)
    rightList.content.itemStyle:SetFontSize(FONT_SIZE.SMALL)
    rightList.content.itemStyle:SetAlign(ALIGN.LEFT)
    rightList.content:SetHeight(0)
    local color = FONT_COLOR.WHITE
    rightList.content:SetDefaultItemTextColor(color[1], color[2], color[3], color[4])
    -- color = FONT_COLOR.DEFAULT
    -- rightList.content.childStyle:SetColor(color[1], color[2], color[3], color[4])
    rightList.bg:Show(false)
    rightList:Clickable(false)
    numbersWindow.rightList = rightList

    -- Main Window Background Styling
    numbersWindow.bg = numbersWindow:CreateNinePartDrawable(TEXTURE_PATH.HUD, "background")
    numbersWindow.bg:SetTextureInfo("bg_quest")
    numbersWindow.bg:SetColor(0, 0, 0, 0.5)
    numbersWindow.bg:AddAnchor("TOPLEFT", numbersWindow, 0, 0)
    numbersWindow.bg:AddAnchor("BOTTOMRIGHT", numbersWindow, 0, 0)

    -- Minimized Window
    --- Minimized view & maximize button
    minimizedWnd = api.Interface:CreateEmptyWindow("minimizedWnd", "UIParent")
    minimizedWnd:SetExtent(130, 30)
    minimizedWnd:AddAnchor("TOPRIGHT", numbersWindow, 0, 0)
    local minimizedLabel = minimizedWnd:CreateChildWidget("label", "minimizedLabel", 0, true)
    minimizedLabel:SetText("Numbers")
    minimizedLabel.style:SetFontSize(FONT_SIZE.LARGE)
    minimizedLabel.style:SetAlign(ALIGN.RIGHT)
    minimizedLabel:AddAnchor("TOPRIGHT", minimizedWnd, -40, FONT_SIZE.LARGE - 2)
    -- Dragable bar for minimized window too
    local minimizedMoveWnd = minimizedWnd:CreateChildWidget("label", "minimizedMoveWnd", 0, true)
    minimizedMoveWnd:AddAnchor("TOPLEFT", minimizedWnd, 12, 0)
    minimizedMoveWnd:AddAnchor("TOPRIGHT", minimizedWnd, 0, 0)
    minimizedMoveWnd:SetHeight(30)
    -- Drag handlers for dragable bar
    function minimizedMoveWnd:OnDragStart(arg)
        if arg == "LeftButton" and api.Input:IsShiftKeyDown() then
        minimizedWnd:StartMoving()
        api.Cursor:ClearCursor()
        api.Cursor:SetCursorImage(CURSOR_PATH.MOVE, 0, 0)
        end
    end
    minimizedMoveWnd:SetHandler("OnDragStart", minimizedMoveWnd.OnDragStart)
    function minimizedMoveWnd:OnDragStop()
        minimizedWnd:StopMovingOrSizing()
        settings.x, settings.y = numbersWindow:GetOffset()
        api.Cursor:ClearCursor()
    end
    minimizedMoveWnd:SetHandler("OnDragStop", minimizedMoveWnd.OnDragStop)
    minimizedMoveWnd:EnableDrag(true)
    -- Toggle back to maximized view with this button
    local maximizeButton = minimizedWnd:CreateChildWidget("button", "maximizeButton", 0, true)
    maximizeButton:SetExtent(26, 28)
    maximizeButton:AddAnchor("TOPRIGHT", minimizedWnd, -12, 0)
    local maximizeButtonTexture = maximizeButton:CreateImageDrawable(TEXTURE_PATH.HUD, "background")
    maximizeButtonTexture:SetTexture(TEXTURE_PATH.HUD)
    maximizeButtonTexture:SetCoords(754, 94, 26, 28)
    maximizeButtonTexture:AddAnchor("TOPLEFT", maximizeButton, 0, 0)
    maximizeButtonTexture:SetExtent(26, 28)
    -- Minimized Window Background Styling
    minimizedWnd.bg = minimizedWnd:CreateNinePartDrawable(TEXTURE_PATH.HUD, "background")
    minimizedWnd.bg:SetTextureInfo("bg_quest")
    minimizedWnd.bg:SetColor(0, 0, 0, 0.5)
    minimizedWnd.bg:AddAnchor("TOPLEFT", minimizedWnd, 0, 0)
    minimizedWnd.bg:AddAnchor("BOTTOMRIGHT", minimizedWnd, 0, 0)

    minimizedWnd:Show(false) --> default to being hidden

    -- Button Handlers
    numbersWindow.minimizeButton:SetHandler("OnClick", function()
        local statsMeterX, statsMeterY = numbersWindow:GetOffset()
        minimizedWnd:RemoveAllAnchors()
        minimizedWnd:AddAnchor("TOPRIGHT", numbersWindow, 0, 0)
        numbersWindow:Show(false)
        minimizedWnd:Show(true)
    end)

    minimizedWnd.maximizeButton:SetHandler("OnClick", function()
        numbersWindow:RemoveAllAnchors()
        numbersWindow:AddAnchor("TOPLEFT", minimizedWnd, 0, 0)
        minimizedWnd:Show(false)
        numbersWindow:Show(true)
    end)

    -- Events
    function numbersWindow:OnEvent(event, ...)
        if event == "COMBAT_TEXT" then
            processCombatText(unpack(arg))
        end
        if event == "COMBAT_MSG" then
            processCombatMessage(unpack(arg))
            -- updateAbsorbedDmgNumbers()
        end
    end 
    numbersWindow:SetHandler("OnEvent", numbersWindow.OnEvent)
    numbersWindow:RegisterEvent("COMBAT_TEXT")
    numbersWindow:RegisterEvent("COMBAT_MSG")    
    --
    
    numbersWindow:Show(true)
    api.On("UPDATE", OnUpdate)
	api.SaveSettings()
end

local function OnUnload()
    api.SaveSettings()
	api.On("UPDATE", function() return end)
	if numbersWindow ~= nil then 
        numbersWindow:Show(false)
        api.Interface:Free(numbersWindow)
    end 
    
    numbersWindow = nil
end

numbers_addon.OnLoad = OnLoad
numbers_addon.OnUnload = OnUnload

return numbers_addon

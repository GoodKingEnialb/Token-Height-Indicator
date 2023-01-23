----------------------
--    OVERRIDES     --
----------------------

-- Variables
local notchScale = 5
local heightSuffix = ' ft'
local bFoundUnits = false
local heightFont = ''
local bPlayerControl = true
local updateEffectsHelper_orig = nil
local onTokenAdd_orig = nil
local onTokenDelete_orig = nil
local getCTFromToken_orig = nil
local updateSizeHelper_orig = nil
local getDistanceBetween_orig = nil

OOB_MSGTYPE_TOKENHEIGHTCHANGE = "UpdateHeightIndicator"
OOB_MSGTYPE_REQUESTOWNERSHIP = "RequestTokenOwnership"
OOB_MSGTYPE_REFRESHHEIGHTS = "RefreshHeights"
	
function onInit()
	registerOptions()
	
	-- squirrel away original functions
	updateEffectsHelper_orig = TokenManager.updateEffectsHelper
	onAdd_orig = Token.onAdd
	onTokenAdd_orig = TokenManager.onTokenAdd
	onTokenDelete_orig = TokenManager.onTokenDelete
	getCTFromToken_orig = CombatManager.getCTFromToken
	updateSizeHelper_orig = TokenManager.updateSizeHelper
	getDistanceBetween_orig = Token.getDistanceBetween

	-- override functions
	Token.onWheel = onWheel
	Token.getDistanceBetween = getDistanceBetween
	Token.getTokensWithinDistance = getTokensWithinDistance
	TokenManager.updateSizeHelper = updateSizeHelper

	TokenManager.onTokenAdd = onTokenAdd
	TokenManager.onTokenDelete = onTokenDelete
	CombatManager.getCTFromToken = getCTFromToken

	-- Register clients for height changes and server to give ownership if client tries to update first
    OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_TOKENHEIGHTCHANGE, updateTokenHeightIndicators)
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_REQUESTOWNERSHIP, updateOwnership)
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_REFRESHHEIGHTS, refreshHeights)
end

-- registerOptions fixed by bmos (removed duplicate entries between labels/values and baselabel/baseval)
function registerOptions()
	OptionsManager.registerOption2 (
        "THIALLOWUSERADJUST",
        false,
        "option_header_height_indicator",
        "option_label_allow_player_mod",
        "option_entry_cycler",
        {
            labels = "option_val_no",
            values = "no",
            baselabel = "option_val_yes",
            baseval = "yes",
            default = "yes"
        }
    ) 
	OptionsManager.registerOption2 (
        "THIPOSITION",
        false,
        "option_header_height_indicator",
        "option_label_height_position",
        "option_entry_cycler",
        {
            labels = "option_val_bottom_right|option_val_right|option_val_top_right|option_val_top|option_val_top_left|option_val_left|option_val_bottom_left",
            values = "bottom right|right|top right|top|top left|left|bottom left",
            baselabel = "option_val_bottom",
            baseval = "bottom",
            default = "bottom"
        }
    ) 
	OptionsManager.registerOption2 (
        "THIFONT",
        false,
        "option_header_height_indicator",
        "option_label_font",
        "option_entry_cycler",
        {
            labels = "option_val_large",
            values = "large",
            baselabel = "option_val_medium",
            baseval = "medium",
            default = "medium"
        }
    ) 
	OptionsManager.registerOption2 (
        "THIFONTCOLOR",
        false,
        "option_header_height_indicator",
        "option_label_font_color",
        "option_entry_cycler",
        {
            labels = "option_val_medium|option_val_light",
            values = "medium|light",
            baselabel = "option_val_dark",
            baseval = "dark",
            default = "dark"
        }
    ) 
	OptionsManager.registerOption2 (
        "THIDIAGONALS",
        false,
        "option_header_height_indicator",
        "option_label_variant_diagonals",
        "option_entry_cycler",
        {
            labels = "option_val_long",
            values = "long",
            baselabel = "option_val_short",
            baseval = "short",
            default = "short"
        }
    ) 
	
	OptionsManager.registerCallback("THIALLOWUSERADJUST", setPlayerControl)
	OptionsManager.registerCallback("THIPOSITION", changeOptions)
	OptionsManager.registerCallback("THIFONT", changeOptions)
	OptionsManager.registerCallback("THIFONTCOLOR", changeOptions)
	setFont()
end

function getDistanceBetween(sourceItem, targetItem)
	--Debug.console("GDB_orig = " .. getDistanceBetween_orig(sourceItem, targetItem))
	   local ctrlImage, winImage, bWindowOpened = ImageManager.getImageControl(sourceItem, false)
	   if ctrlImage then
		  return ctrlImage.getDistanceBetween(sourceItem, targetItem)
	   else
		  ctrlImage, winImage, bWindowOpened = ImageManager.getImageControl(targetItem, false)
		  if ctrlImage then
			 return ctrlImage.getDistanceBetween(sourceItem, targetItem)
		  else
			 return 0
		  end
	   end		 
	end
	
function getTokensWithinDistance(sourceItem, distance)
	local ctrlImage, winImage, bWindowOpened = ImageManager.getImageControl(sourceItem, false)
	if ctrlImage then
		return ctrlImage.getTokensWithinDistance(sourceItem, distance)
	else
		return {}
	end		 
end

-- Simplified greatly by Kelrugem (with help from Moon Wizard) - don't completely override onWheel, as the original gets run in semi-parallel
function onWheel(tokenCT, notches)
    if Input.isAltPressed() then  
        TokenHeight.updateHeight(tokenCT, notches)
        return true;
    end
end

-- Called when a token is first added to a map
function onTokenAdd(tokenMap)
	onTokenAdd_orig(tokenMap)
	local ctNode = getCTFromToken(tokenMap)
	local heightHolder = DB.getChild(ctNode, "heightvalue")
	if heightHolder and heightHolder.getValue() then
        local nHeight = tonumber(heightHolder.getValue())   
		setHeight(tokenMap, nHeight)
	end
end

-- Called when a token is removed to a map
function onTokenDelete(tokenMap)
	if Session.IsHost then
		setHeight(tokenMap, 0)
	end
	onTokenDelete_orig(tokenMap)
end

function getCTFromToken(token)
	if token and token.getContainerNode then
		return getCTFromToken_orig(token)
	else
		return nil
	end
end

function updateSizeHelper(ctToken, ctNode)
	updateSizeHelper_orig(ctToken, ctNode)

	local nDU = GameSystem.getDistanceUnitsPerGrid()
	ctToken.nSpace = math.ceil(DB.getValue(ctNode, "space", nDU) / nDU)
end


--------------------------
--    MAIN FUNCTIONS    --
--------------------------
	
-- Sets and displays the height of the token
function updateHeight(token, notches)
    if not token or notches == 0 then
        return
    end

	local nHeight = getHeight(token)

	updateUnitsForToken(token)
	
    -- update height
    nHeight = nHeight + (notchScale * notches)
	
	local ctNode = getCTFromToken(token)
	if not ctNode then
		return
	end
	
	if Session.IsHost then 
		setHeight(token, nHeight)
		notifyHeightChange(token)
	elseif bPlayerControl then
		requestOwnership(token, nHeight)
	end
end

function setHeight(token, nHeight)
    if not token then
        return
    end

	-- get the height value from the DB
	local cNode = token.getContainerNode()
	if not cNode then
		return
	end

	if nHeight ~= getHeight(token) then
		local ctNode = getCTFromToken(token)

		if ctNode and Session.IsHost then
			if (not token.getName or token.getName() == "") and ctNode.getName then

				token.setName(ctNode.getName())
			end
			DB.setValue(ctNode, "heightvalue", "number", nHeight)
			DB.setValue(cNode, getHeightKey(token), "number", nHeight)
			--Debug.console("Setting height of " .. token.getName() .. " (" .. getHeightKey(token) .. ") to " .. nHeight)
			jiggle(token)
		end
	end
end

-- See image.getTokensWithinShapeFromToken for parameter details
function getTokensWithinShape(originToken, shape, distance, height, width, azimuthalAngle, polarAngle)
	local ctrlImage, winImage, bWindowOpened = ImageManager.getImageControl(originToken, false)
	if ctrlImage then
	   return ctrlImage.getTokensWithinShapeFromToken(originToken, shape, distance, height, width, azimuthalAngle, polarAngle)
	else
	   return {}
	end		 
 end
 
function getHeight(token)
	local cNode = token.getContainerNode()
	local heightHolder = DB.getChild(cNode, getHeightKey(token))
	local nHeight = 0
	if heightHolder and heightHolder.getValue then
        nHeight = tonumber(heightHolder.getValue())  
		--Debug.console("Height of " .. token.getName() .. " (" .. heightHolder.getNodeName() .. " / " .. getHeightKey(token) .. ") is " .. nHeight) 
    --else
		--Debug.console("No HeightHolder of " .. token.getName() .. " (" .. getHeightKey(token) .. ") is " .. nHeight) 
	end
	return nHeight
end

--------------------------
-- SUPPORTING FUNCTIONS --
--------------------------

function setPlayerControl()
	if OptionsManager.getOption("THIALLOWUSERADJUST") == "yes" then
		bPlayerControl = true
	else
		bPlayerControl = false
	end
end

function setFont()
	local sFontOption = OptionsManager.getOption("THIFONT")
	local sFontColor = OptionsManager.getOption("THIFONTCOLOR")
	if sFontOption == "medium" then
		heightFont = "height_medium"
	elseif sFontOption == "large" then
		heightFont = "height_large"		
	else
		heightFont = ''
	end
	heightFont = heightFont .. "_" .. sFontColor
end

-- Moves a token one off of center or back to center.
function jiggle(token)
	if token then
		local x, y = token.getPosition()

		-- To avoid cascading, use the current x position to against the half of the grid size to see
		-- if we've previously skewed a little in one way and move it back the other
		local ctrlImage, _, _ = ImageManager.getImageControl(token, false)
		if ctrlImage then
			local gridsize, _, _, _ = ctrlImage.getImageSettings()
			local halfSquare = gridsize / 2
			local xNorm = math.floor(x-halfSquare) % 2
			local jiggleAmount = 1
			if xNorm == 0 then
				jiggleAmount = 1
			elseif xNorm == 1 then
				jiggleAmount = -1
			end
			token.setPosition(x+jiggleAmount,y)
		end	
	end
end

-- Displays the heights of all tokens
function refreshHeights(tokenList)
	for _,token in pairs(tokenList) do
		notifyHeightChange(token)
	end
end

function updateUnitsForToken(token)
	local ctrlImage, _, _ = ImageManager.getImageControl(token, false)
	if ctrlImage then
		_, notchScale, suffix, _ = ctrlImage.getImageSettings()
		if suffix == '\'' then
			heightSuffix = ' ft'
		elseif suffix == '' then
			heightSuffix = ' sq'
		else
			heightSuffix = suffix
		end
		--Debug.console("UUfT: Setting suffix to " .. heightSuffix)
	end	
end

function updateUnits(units, suffix)
	if suffix == '\'' then
		heightSuffix = ' ft'
	elseif suffix == '' then
		heightSuffix = ' sq'
	else
		heightSuffix = suffix
	end
	notchScale = units
	--Debug.console("UU: Setting suffix to " .. heightSuffix .. " and units to " .. notchScale)
end


-- notifies clients and other extensions that height changed
function notifyHeightChange(token)
	-- If the aura effect extension is loaded, force it to re-evaluate the token, with thanks to SilentRuin
	if AuraEffect and AuraEffect.notifyTokenMove then
		AuraEffect.notifyTokenMove(token); 
	end

    local msgOOB = {}
    msgOOB.type = OOB_MSGTYPE_TOKENHEIGHTCHANGE
	local ctNode = getCTFromToken(token)
	msgOOB.sNode = nil
	if ctNode then
		msgOOB.sNode = ctNode.getNodeName()
	end
    Comm.deliverOOBMessage(msgOOB)
end

-- notifies clients to update token height
function updateTokenHeightIndicators(msgOOB)
	if msgOOB.sNode then
		local ctNode = DB.findNode(msgOOB.sNode)
		if ctNode then
			local token = CombatManager.getTokenFromCT(ctNode)
			displayHeight(token)
		end
	end
end

-- requests host to grant ownership
function requestOwnership(token, nHeight)
	-- TODO Figure out how to pass token to host
    local msgOOB = {}
    msgOOB.type = OOB_MSGTYPE_REQUESTOWNERSHIP

	local ctNode = getCTFromToken(token)
	msgOOB.sNode = nil
	if ctNode then
		msgOOB.sNode = ctNode.getNodeName()
	end
	msgOOB.newHeight = nHeight
    Comm.deliverOOBMessage(msgOOB)
end

-- grant ownership
function updateOwnership(msgOOB)
	if Session.IsHost then
		if msgOOB.sNode then
			local ctNode = DB.findNode(msgOOB.sNode)
			if ctNode then
				local token = CombatManager.getTokenFromCT(ctNode)
				if token then
					setHeight(token, msgOOB.newHeight)
					notifyHeightChange(token)
				end
			end
		end
	end
end

function displayHeight(token)
    if not token then
        return
    end

	local cNode = token.getContainerNode()
	local heightValueContainer = DB.getChild(cNode, getHeightKey(token))
	local nHeight = 0
	
	if heightValueContainer and heightValueContainer.getValue() ~= nil then
        nHeight = tonumber(heightValueContainer.getValue())  
    end
	
	local widget = token.findWidget("heightindication")
	if widget == nil then
		widget = token.addTextWidget( "mini_name", '' )
		if heightFont ~= '' then
			widget.setFont(heightFont)
		end
		widget.setName("heightindication"); 
		widget.setFrame('mini_name', 5, 1, 5, 1)
		widget.setPosition(OptionsManager.getOption("THIPOSITION"), 0, 0)
	end
	
	-- manage CT DB entry
    if nHeight == 0 then
		widget.setVisible(false)
    else
		-- update height display        
		widget.setText(nHeight .. heightSuffix)
		widget.bringToFront();       
		widget.setVisible(true)
    end
end


-- Changes the location of the height indicator
function changeOptions()
	setFont()
	for _, ctNode in pairs(CombatManager.getCombatantNodes()) do
	    local token = CombatManager.getTokenFromCT(ctNode)
		if token then
			local cNode = token.getContainerNode()
			local widget = token.findWidget("heightindication")
			if widget then	
				local dbNode = DB.getChild(cNode, getHeightKey(token))
				local nHeight = 0
			
				if dbNode ~= nil and dbNode.getValue() ~= nil then
					nHeight = tonumber(dbNode.getValue());   
				end
			
				widget.destroy()
				if nHeight ~= 0 then
					widget = token.addTextWidget( "mini_name", '' )
					if heightFont ~= '' then
						widget.setFont(heightFont)
					end
					widget.setName("heightindication"); 
					widget.setFrame('mini_name', 5, 1, 5, 1)
					widget.setPosition(OptionsManager.getOption("THIPOSITION"), 0, 0)
			
					-- update height display        
					widget.setText(nHeight .. heightSuffix)
					widget.bringToFront();       
					widget.setVisible(true)
				end	
			end
		end
    end
end

function getHeightKey(token)
	local id = "noID"
	local name = "noName"
	if token.getId then
		id = token.getId()
	end

	if token.getName then
		name = token.getName()
	end
	local heightKey = id .. "-heightvalue-" .. name
	return heightKey
end
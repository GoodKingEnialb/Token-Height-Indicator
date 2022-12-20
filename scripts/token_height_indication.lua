-- Variables
local notchScale = 5
local heightUnits = ' ft'
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

	TokenManager.onTokenAdd = onTokenAdd
	TokenManager.onTokenDelete = onTokenDelete
	CombatManager.getCTFromToken = getCTFromToken
	TokenManager.updateSizeHelper = updateSizeHelper

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

-- See image.getTokensWithinShapeFromToken for parameter details
function getTokensWithinShape(originToken, shape, distance, height, width, azimuthalAngle, polarAngle)
	local ctrlImage, winImage, bWindowOpened = ImageManager.getImageControl(originToken, false)
	if ctrlImage then
	   return ctrlImage.getTokensWithinShapeFromToken(originToken, shape, distance, height, width, azimuthalAngle, polarAngle)
	else
	   return {}
	end		 
 end

-- Simplified greatly by Kelrugem (with help from Moon Wizard) - don't completely override onWheel, as the original gets run in semi-parallel
function onWheel(tokenCT, notches)
    if Input.isAltPressed() then  
        TokenHeight.updateHeight(tokenCT, notches);
        return true;
    end
end

-- Sets and displays the height of the token
function updateHeight(token, notches)
    if not token then
        return
    end

	-- get the height value from the DB
    local ctNode = CombatManager.getCTFromToken(token)
	if not ctNode then
		return
	end

    local dbNode = DB.getChild(ctNode, "heightvalue")
    local nHeight = 0
	
    if dbNode ~= nil and dbNode.getValue() ~= nil then
        nHeight = tonumber(dbNode.getValue());   
    end
	
    -- update height
    nHeight = nHeight + (notchScale * notches)
	
	if (ctNode.isOwner() and bPlayerControl) or Session.IsHost then
		DB.setValue(ctNode, "heightvalue", "number", nHeight)
		-- Jiggle the token to force a redraw of the range arrow
		if (notches ~= 0) then
--			local x, y = token.getPosition()
--			token.setPosition(x+1,y+1)
--			token.setPosition(x,y)
		end
	else
		requestOwnership(token, nHeight)
	end
			
	if Session.IsHost and token.getOwner then
	  DB.setOwner(ctNode, token.getOwner())
	end
	
	notifyHeightChange(ctNode)
end

function setHeight(token, nHeight)
    if not token then
        return
    end
	-- get the height value from the DB
    local ctNode = CombatManager.getCTFromToken(token)
	if not ctNode then
		return
	end

    local dbNode = DB.getChild(ctNode, "heightvalue")
	
	if (ctNode.isOwner() and bPlayerControl) or Session.IsHost then
		DB.setValue(ctNode, "heightvalue", "number", nHeight)
		local x, y = token.getPosition()
		token.setPosition(x+1,y+1)
		token.setPosition(x,y)	
	end
end

-- Displays the heights of all tokens
function refreshHeights()
	--if Session.IsHost then
		for _,ctNode in pairs(CombatManager.getCombatantNodes()) do
			local token = CombatManager.getTokenFromCT(ctNode)
			updateHeight(token, 0)	
		end
	--end
end

function updateUnits(image)
	_, notchScale, suffix, _ = image.getImageSettings()
	if suffix == '\'' then
		heightUnits = ' ft'
	elseif suffix == '' then
		heightUnits = ' sq'
	else
		heightUnits = suffix
	end
end

function getHeight(ctNode)
	local heightHolder = DB.getChild(ctNode, "heightvalue")
	local nHeight = 0
	if heightHolder and heightHolder.getValue() then
        nHeight = tonumber(heightHolder.getValue())   
    end
	return nHeight
end

-- notifies clients that height changed
function notifyHeightChange(ctNode)
    local msgOOB = {}
    msgOOB.type = OOB_MSGTYPE_TOKENHEIGHTCHANGE
	msgOOB.sNode = ctNode.getNodeName()
    Comm.deliverOOBMessage(msgOOB)
end

-- notifies clients to update token height
function updateTokenHeightIndicators(msgOOB)
	if (msgOOB.node == "all") then
		for _, ctNode in pairs(CombatManager.getCombatantNodes()) do
			if (msgOOB.node == "all") then
				displayHeight(DB.getChild(ctNode, "heightvalue"))
			elseif (msgOOB.node == tostring(ctNode)) then
				displayHeight(DB.getChild(ctNode, "heightvalue"))
				break
			end
		end
	else
		local ctNode = DB.findNode(msgOOB.sNode)
		if ctNode then
			displayHeight(DB.getChild(ctNode, "heightvalue"))
		end
	end
end

-- requests host to grant ownership
function requestOwnership(token, nHeight)
	-- TODO Figure out how to pass token to host
    local msgOOB = {}
    msgOOB.type = OOB_MSGTYPE_REQUESTOWNERSHIP
	msgOOB.token = token
	msgOOB.newHeight = nHeight
    Comm.deliverOOBMessage(msgOOB)
end

-- grant ownership
function updateOwnership(msgOOB)
	-- TODO ideally the client would pass the node and height, but not sure how to pass node, so set all the unowned owners here
	if Session.IsHost then
		for _, ctNode in pairs(CombatManager.getCombatantNodes()) do
			local token = CombatManager.getTokenFromCT(ctNode)
			if token and token.getOwner then
				DB.setOwner(ctNode, token.getOwner())
			end
		end
	end
end



function displayHeight(heightWidget) 
    if not heightWidget then
        return
    end
	
	local ctNode = heightWidget.getParent()
    local ctToken = CombatManager.getTokenFromCT(ctNode)
	if not (ctToken) then
		return
	end
	local nHeight = 0
	
	if heightWidget.getValue() ~= nil then
        nHeight = tonumber(heightWidget.getValue());   
    end
	
	local widget = ctToken.findWidget("heightindication")
	if widget == nil then
		widget = ctToken.addTextWidget( "mini_name", '' )
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
		widget.setText(nHeight .. heightUnits)
		widget.bringToFront();       
		widget.setVisible(true)
    end
end


-- Changes the location of the height indicator
function changeOptions()
	setFont()
	for _, ctNode in pairs(CombatManager.getCombatantNodes()) do
	    local ctToken = CombatManager.getTokenFromCT(ctNode)
		if ctToken then
			local widget = ctToken.findWidget("heightindication")
			if widget then	
				local dbNode = DB.getChild(ctNode, "heightvalue")
				local nHeight = 0
			
				if dbNode ~= nil and dbNode.getValue() ~= nil then
					nHeight = tonumber(dbNode.getValue());   
				end
			
				widget.destroy()
				if nHeight ~= 0 then
					widget = ctToken.addTextWidget( "mini_name", '' )
					if heightFont ~= '' then
						widget.setFont(heightFont)
					end
					widget.setName("heightindication"); 
					widget.setFrame('mini_name', 5, 1, 5, 1)
					widget.setPosition(OptionsManager.getOption("THIPOSITION"), 0, 0)
			
					-- update height display        
					widget.setText(nHeight .. heightUnits)
					widget.bringToFront();       
					widget.setVisible(true)
				end	
			end
		end
    end
end

-- Called when a token is first added to a map
function onTokenAdd(tokenMap)
	onTokenAdd_orig(tokenMap)
	if Session.IsHost then
		updateHeight(tokenMap, 0)
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
	local ctrlImage = ImageManager.getImageControl(ctToken, false)
end
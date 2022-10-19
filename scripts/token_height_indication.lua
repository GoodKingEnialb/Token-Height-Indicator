-- Variables
local notchScale = 5
local heightUnits = ' ft'
local bFoundUnits = false
local heightFont = ''
local bPlayerControl = true

OOB_MSGTYPE_TOKENHEIGHTCHANGE = "UpdateHeightIndicator"
OOB_MSGTYPE_REQUESTOWNERSHIP = "RequestTokenOwnership"
OOB_MSGTYPE_REFRESHHEIGHTS = "RefreshHeights"
	
function onInit()
	registerOptions()
	
	-- squirrel away original functions
	updateEffectsHelper_orig = TokenManager.updateEffectsHelper
	
	-- override functions
	Token.onWheel = onWheel
	Token.getDistanceBetween = getDistanceBetween
	Token.getTokensWithinDistance = getTokensWithinDistance

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
   local ctrlImage, winImage, bWindowOpened = ImageManager.getImageControl(sourceItem, true)
   if ctrlImage then
      return ctrlImage.getDistanceBetween(sourceItem, targetItem)
   else
      ctrlImage, winImage, bWindowOpened = ImageManager.getImageControl(targetItem, true)
      if ctrlImage then
         return ctrlImage.getDistanceBetween(sourceItem, targetItem)
      else
         return 0
	  end
   end		 
end

function getTokensWithinDistance(sourceItem, distance)
   local ctrlImage, winImage, bWindowOpened = ImageManager.getImageControl(sourceItem, true)
   if ctrlImage then
      return ctrlImage.getTokensWithinDistance(sourceItem, distance)
   else
      return {}
   end		 
end

-- Get all tokens within a shape (including the origin token).  Shapes supported are line, cube, sphere, cylinder, and cone.
-- Second point(x2,y2,z2) only applies to cones and lines, height only applies to cylinders, width only applies to lines.
-- For a cone, distance = length of cone, height = height of spherical cap (0 if not spherical), width = angle of cone in degrees (53 in 5e, 90 in 3.5)
function getTokensWithinShape(originToken, shape, distance, height, width, azimuthalAngle, polarAngle)
	local ctrlImage, winImage, bWindowOpened = ImageManager.getImageControl(originToken, true)
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
		local x, y = token.getPosition()
		token.setPosition(x+1,y+1)
		token.setPosition(x,y)	
-- TEST TEST TEST
print("SPHERE")
theTokens = getTokensWithinShape(token, "sphere", 30, nil, nil, nil, nil, nil)
if theTokens then
	for _,oneToken in pairs(theTokens) do
		print(oneToken.getName())
	end
else
	print("No tokens in range")
end

print("CUBE")
theTokens = getTokensWithinShape(token, "cube", 60, nil, nil, nil, nil, nil)
if theTokens then
	for _,oneToken in pairs(theTokens) do
		print(oneToken.getName())
	end
else
	print("No tokens in range")
end

print("CYLINDER")
theTokens = getTokensWithinShape(token, "cylinder", 30, 20, nil, nil, nil, nil)
if theTokens then
	for _,oneToken in pairs(theTokens) do
		print(oneToken.getName())
	end
else
	print("No tokens in range")
end

print("CONE")
local nx, ny = token.getPosition()
local nz = nHeight
theTokens = getTokensWithinShape(token, "cone", 30, 1, 53, 0, 0)
if theTokens then
	for _,oneToken in pairs(theTokens) do
		print(oneToken.getName())
	end
else
	print("No tokens in range")
end
-- TEST TEST TEST
	else
		requestOwnership(token, nHeight)
	end
			
	if Session.IsHost and token.getOwner then
	  DB.setOwner(ctNode, token.getOwner())
	end
	
	--notifyHeightChange(ctNode)
	notifyHeightChange("all")
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
	msgOOB.node = ctNode
    Comm.deliverOOBMessage(msgOOB)
end

-- notifies clients to update token height
function updateTokenHeightIndicators(msgOOB)
    for _, ctNode in pairs(CombatManager.getCombatantNodes()) do
		if (msgOOB.node == "all") then
			displayHeight(DB.getChild(ctNode, "heightvalue"))
		elseif (msgOOB.node == tostring(ctNode)) then
			-- TODO Figure out how to pass the reference to the node so it only updates once
			displayHeight(DB.getChild(ctNode, "heightvalue"))
			break
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

	-- SilentRuin optimization
	-- optimization requires reset of onMeasurePointer checks
	local ctrlImage = ImageManager.getImageControl(ctToken, false)
	if ctrlImage then
		ctrlImage.ResetOptData()
		updateUnits(ctrlImage)
	end
	
	
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
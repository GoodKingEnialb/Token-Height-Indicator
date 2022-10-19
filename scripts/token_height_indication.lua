-- Variables
local getWidgetList_orig = nil
local notchScale = 5
local heightUnits = ' ft'
local bFoundUnits = false
local heightFont = ''
local bPlayerControl = true

OOB_MSGTYPE_TOKENHEIGHTCHANGE = "UpdateHeightIndicator"
	
function onInit()

	registerOptions()

	-- height handler
    --DB.addHandler("combattracker.list.*.height", "onUpdate", dbWatcher)
		
	-- squirrel away original functions
	updateEffectsHelper_orig = TokenManager.updateEffectsHelper
	getWidgetList_orig = TokenManager.getWidgetList
	
	-- override functions
	Token.onWheel = onWheel
	TokenManager.getWidgetList = getWidgetList
	Token.getDistanceBetween = getDistanceBetween
	Token.getTokensWithinDistance = getTokensWithinDistance

	-- Register clients for height changes
    OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_TOKENHEIGHTCHANGE, updateTokenHeightIndicators)
	
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

-- Simplified greatly by Kelrugem (with help from Moon Wizard) - don't completely override onWheel, as the original gets run in semi-parallel
function onWheel(tokenCT, notches)
    if Input.isAltPressed() then  
        TokenHeight.updateHeight(tokenCT, notches, true);
        return true;
    end
end

-- Sets and displays the height of the token
function updateHeight(token, notches, forceRangeArrowRedraw)
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
		if forceRangeArrowRedraw then
			local x, y = token.getPosition()
			token.setPosition(x+1,y+1)
			token.setPosition(x,y)	
		end			
	end
			
	if Session.IsHost and token.getOwner then
	  DB.setOwner(ctNode, token.getOwner())
	end
	
	notifyHeightChange()
end

function setUnits(units, suffix)
	notchScale = units
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

-- notifies clients to update token height
function updateTokenHeightIndicators()
    for _, ctNode in pairs(CombatManager.getCombatantNodes()) do
        displayHeight(DB.getChild(ctNode, "heightvalue"))
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

	-- optimization requires reset of onMeasurePointer checks
	local ctrlImage = ImageManager.getImageControl(ctToken, false)
	if ctrlImage then
		ctrlImage.ResetOptData()
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

-- notifies clients that height changed
function notifyHeightChange()
    local msgOOB = {}
    msgOOB.type = OOB_MSGTYPE_TOKENHEIGHTCHANGE
    Comm.deliverOOBMessage(msgOOB)
end

-- Force display of height upon first opening the map (client and server)
function getWidgetList(tokenCT, sSet)
	TokenHeight.updateHeight(tokenCT, 0, false)
	return getWidgetList_orig(tokenCT, sSet)
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
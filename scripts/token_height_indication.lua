-- Variables
local onWheel_orig = nil
local getWidgetList_orig = nil
local notchScale = 5
local heightUnits = ' ft'
local heightFont = ''
local bPlayerControl = true
OOB_MSGTYPE_TOKENHEIGHTCHANGE = "UpdateHeightIndicator"

function onInit()

	registerOptions()

	-- height handler
    DB.addHandler("combattracker.list.*.height", "onUpdate", dbWatcher)
		
	-- squirrel away original functions
	onWheel_orig = TokenManager.onWheelHelper
	updateEffectsHelper_orig = TokenManager.updateEffectsHelper
	getWidgetList_orig = TokenManager.getWidgetList
	
	-- override functions
	Token.onWheel = onWheel
	TokenManager.getWidgetList = getWidgetList

	-- Register clients for height changes
    OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_TOKENHEIGHTCHANGE, updateTokenHeightIndicators)
	
	if (User.getRulesetName() == "4E") then
		notchScale = 1
		heightUnits = ' sq'
	end
end

function registerOptions()
	OptionsManager.registerOption2 (
        "THIALLOWUSERADJUST",
        false,
        "option_header_height_indicator",
        "option_label_allow_player_mod",
        "option_entry_cycler",
        {
            labels = "option_val_yes|option_val_no",
            values = "yes|no",
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
            labels = "option_val_top|option_val_top_right|option_val_right|option_val_bottom_right|option_val_bottom|option_val_bottom_left|option_val_left|option_val_top_left",
            values = "top|top right|right|bottom right|bottom|bottom left|left|top left",
            baselabel = "option_val_top",
            baseval = "top",
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
            labels = "option_val_medium|option_val_large",
            values = "medium|large",
            baselabel = "option_val_medium",
            baseval = "medium",
            default = "medium"
        }
    ) 
	
	OptionsManager.registerCallback("THIALLOWUSERADJUST", setPlayerControl)
	OptionsManager.registerCallback("THIPOSITION", changeOptions)
	OptionsManager.registerCallback("THIFONT", changeOptions)
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
	if sFontOption == "medium" then
		heightFont = "height_medium"
	elseif sFontOption == "large" then
		heightFont = "height_large"		
	else
		heightFont = ''
	end
end

function onWheel(tokenCT, notches)
	local stopProcessing = true
    if Input.isAltPressed() then  
		TokenHeight.updateHeight(tokenCT, notches, true)
	elseif Input.isShiftPressed() then
		local oldOrientation = tokenCT.getOrientation()
		local newOrientation = (oldOrientation+notches)%8
		tokenCT.setOrientation(newOrientation)
    elseif Input.isControlPressed() then
		local w = 0
		local h = 0
		local rectScale = 0
		w,h = tokenCT.getImageSize()
		if w > h then
			rectScale = w / h 
		elseif h > w then
			rectScale = h / w 
		else
			rectScale = 1
		end
		
		local newscale = tokenCT.getScale()
		if UtilityManager.isClientFGU() then
			local adj = notches * 0.1
			if adj < 0 then
				newscale = newscale * (1 + adj)
			else
				newscale = newscale * (1 / (1 - adj))
			end
		else
			newscale = newscale + (notches * 0.1)
			if newscale < 0.1 then
				newscale = 0.1
			end
		end
		tokenCT.setScale(newscale * rectScale)
    end
		
    return true
end

function dbWatcher(node)
    local token = CombatManager.getTokenFromCT(DB.getParent(node))
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
		--if OptionsManager.isOption("THIPOSITION", "Bottom")
		--option_val_top|option_val_right|option_val_bottom|option_val_left
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
		if not (ctToken) then
			return
		end
		local widget = ctToken.findWidget("heightindication")
		if not (widget) then
			return
		end
		
		local dbNode = DB.getChild(ctNode, "heightvalue")
		local nHeight = 0
		
		if dbNode ~= nil and dbNode.getValue() ~= nil then
			nHeight = tonumber(dbNode.getValue());   
		end
		
		--DB.deleteChild(ctNode, "heightvalue")
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
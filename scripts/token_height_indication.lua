-- Variables
local onWheel_orig = nil
local getWidgetList_orig = nil
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
end

function registerOptions()
    OptionsManager.registerOption2("THIALLOWUSERADJUST", false, "option_header_height_indicator", "option_label_allow_player_mod", "option_entry_cycler",
		{ labels = "option_val_yes", values = "Yes", baselabel = "option_val_no", baseval = "No", default = "Yes" })
end

function onWheel(tokenCT, notches)
	local stopProcessing = true
    if Input.isAltPressed() then  
		TokenHeight.updateHeight(tokenCT, notches)
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
	
		--stopProcessing = onWheel_orig(tokenCT, notches)
		
    end
		
    return true
end

function dbWatcher(node)
    local token = CombatManager.getTokenFromCT(DB.getParent(node))
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
    nHeight = nHeight + (5 * notches)
	
	if (ctNode.isOwner() and OptionsManager.isOption("THIALLOWUSERADJUST", "Yes")) or User.isHost() then
		DB.setValue(ctNode, "heightvalue", "number", nHeight)
	end
			
	if User.isHost() then
	  DB.setOwner(ctNode, token.getOwner())
	end
	
	notifyHeightChange()
end

-- notifies clients to update token height
function updateTokenHeightIndicators()
    for _, ctNode in pairs(CombatManager.getCombatantNodes()) do
        displayHeight(DB.getChild(ctNode, "heightvalue"))
    end
end


function displayHeight(height) 
    if not height then
        return
    end
	
	local ctNode = height.getParent()
    local ctToken = CombatManager.getTokenFromCT(ctNode)
	if not (ctToken) then
		return
	end
	local nHeight = 0
	
	if height.getValue() ~= nil then
        nHeight = tonumber(height.getValue());   
    end
	
	local widget = ctToken.findWidget("heightindication")
	if widget == nil then
		widget = ctToken.addTextWidget( "mini_name", '' )
		widget.setName("heightindication"); 
		widget.setFrame('mini_name', 5, 1, 5, 1)
		widget.setPosition("bottom", 0, 0)
	end
	
	-- manage CT DB entry
    if nHeight == 0 then
        --DB.deleteChild(ctNode, "heightvalue")

		widget.setVisible(false)
		--widget.destroy()
    else
		-- update height display        
		widget.setText(nHeight .. ' ft.')
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
	TokenHeight.updateHeight(tokenCT, 0)
	return getWidgetList_orig(tokenCT, sSet)
end
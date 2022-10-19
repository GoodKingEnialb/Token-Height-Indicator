-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--
----------------------------------------------------------------
-- TOP PORTION COPIED FROM CoreRPG campaign/scripts/image.lua --
----------------------------------------------------------------

function onInit()
	if Session.IsHost then
		setTokenOrientationMode(false);
	end
	onCursorModeChanged();
end

function onCursorModeChanged(sTool)
	window.onCursorModeChanged();
end

function onMaskingStateChanged(sTool)
	window.onMaskingStateChanged();
end

function onGridStateChanged(gridtype)
	window.onGridStateChanged();
end

function onTokenLockStateChanged(bLocked)
	window.onTokenLockStateChanged();
end

function onTargetSelect(aTargets)
	local aSelected = getSelectedTokens();
	if #aSelected == 0 then
		local tokenActive = TargetingManager.getActiveToken(self);
		if tokenActive then
			local bAllTargeted = true;
			for _,vToken in ipairs(aTargets) do
				if not vToken.isTargetedBy(tokenActive) then
					bAllTargeted = false;
					break;
				end
			end
			
			for _,vToken in ipairs(aTargets) do
				tokenActive.setTarget(not bAllTargeted, vToken);
			end
			return true;
		end
	end
end

function onDrop(x, y, draginfo)
	local sDragType = draginfo.getType();
	
	if sDragType == "shortcut" then
		local sClass,_ = draginfo.getShortcutData();
		if sClass == "charsheet" then
			if not Input.isShiftPressed() then
				return true;
			end
		end
		
	elseif sDragType == "combattrackerff" then
		return CombatManager.handleFactionDropOnImage(draginfo, self, x, y);
	end
end

----------------------
-- CUSTOM ADDITIONS --
----------------------

function onMeasurePointer(pixellength,pointertype,startx,starty,endx,endy)
	local gridsize = getGridSize()
	local units = getDistanceBaseUnits()
	local suffix = getDistanceSuffix()
	local diagMult = Interface.getDistanceDiagMult()

	if hasGrid() then
		local startz = 0
		local endz = 0
		local bToken = false
				
		local ctNodeOrigin = getCTNodeAt(startx,starty,gridsize)
		if ctNodeOrigin then
			local ctNodeTarget = getCTNodeAt(endx,endy,gridsize)
			
			if ctNodeTarget then
				startz = TokenHeight.getHeight(ctNodeOrigin) * gridsize / units
				endz = TokenHeight.getHeight(ctNodeTarget) * gridsize / units
				bToken = true
			end
		end
		
		local distance = distanceBetween(startx,starty,startz,endx,endy,endz,bToken)
		if distance == 0 then
			return ""
		else
			local stringDistance = nil
			if diagMult == 0 then
				stringDistance = string.format("%.1f", distance)
			else
				stringDistance = string.format("%.0f", distance)	
			end
			return stringDistance .. suffix
		end
	else
		return ""
	end
end

-- Distance between two locations in 3 dimensions.  bToken should be true for tokens and false otherwise
function distanceBetween(startx,starty,startz,endx,endy,endz,bToken)
	local diagMult = Interface.getDistanceDiagMult()
	local units = getDistanceBaseUnits()
	local gridsize = getGridSize()
	local totalDistance = 0
	local dx = math.abs(endx-startx)
	local dy = math.abs(endy-starty)
	local dz = math.abs(endz-startz)
	
	if diagMult == 1 then
		-- Just a max of each dimension
		local longestLeg = math.max(dx, dy, dz)
		totalDistance = math.floor(longestLeg/gridsize+0.5)*units

	elseif diagMult == 0 then
		-- Get 3D distance directly
		local hyp = math.sqrt((dx^2)+(dy^2)+(dz^2))
		totalDistance = (hyp / gridsize)* units
	else 	
		-- You get full amount of the longest path and half from each of the others
		local longest = math.max(dx, dy, dz)
		if longest == dx then
			totalDistance = dx + (dy+dz)/2
		elseif longest == dy then
			totalDistance = dy + (dx+dz)/2
		else	
			totalDistance = dz + (dx+dy)/2
		end
		
		-- Convert to feet
		totalDistance = (totalDistance / gridsize + 0.5) * units	
		totalDistance = math.floor(totalDistance / units) * units		
	end
		
	return totalDistance
end

function roundDown(val)
	return math.floor(val + gridsize / 2)
end

function getCTNodeAt(basex, basey, gridsize)
	local allTokens = getTokens()
	local theToken = nil
	for _, oneToken in pairs(allTokens) do
		x,y = oneToken.getPosition()
		local ctNode = CombatManager.getCTFromToken(oneToken)

		local sSize = StringManager.trim(DB.getValue(ctNode, "size", ""):lower());
		local bExact = true
		local sizeMultiplier = 0
		if sSize == "large" then
			sizeMultiplier = 0.5
		elseif sSize == "huge" then
			sizeMultiplier = 1
		elseif sSize == "gargantuan" then
			-- Gargantuan creatures behave a bit differently. Can be anywhere within bounds
			sizeMultiplier = 1.5
			bExact = false
		end
		
		local found = false
		if bExact then
			found = exactMatch(basex, basey, x, y, sizeMultiplier, gridsize)
		else
			found = matchWithinSize(basex, basey, x, y, sizeMultiplier, gridsize)
		end
		
		if found then
			local ctNode = CombatManager.getCTFromToken(oneToken)
			theToken = ctNode
			break
		end
    end
	return theToken
end

function exactMatch(startx, starty, endx, endy, sizeMultiplier, gridsize)
	local equal = false

	local modx = endx
	local mody = endy
	if modx > startx then
		modx = modx - gridsize * sizeMultiplier
	elseif modx < startx then
		modx = modx + gridsize * sizeMultiplier
	end
	if mody > starty then
		mody = mody - gridsize * sizeMultiplier
	elseif mody < starty then
		mody = mody + gridsize * sizeMultiplier
	end		
	if modx == startx and mody == starty then
		equal = true
	end

	return equal
end

function matchWithinSize(startx, starty, endx, endy, sizeMultiplier, gridsize)
	local equal = false

	local modx = endx
	local mody = endy
	local lowerBoundx = endx
	local lowerBoundy = endy
	local upperBoundx = endx
	local upperBoundy = endy
		
	if endx > startx then
		lowerBoundx = endx - gridsize * sizeMultiplier
	elseif endx < startx then
		upperBoundx = endx + gridsize * sizeMultiplier
	end
	if endy > starty then
		lowerBoundy = endy - gridsize * sizeMultiplier
	elseif endy < starty then
		upperBoundy = upperBoundy + gridsize * sizeMultiplier
	end		
	
	if startx >= lowerBoundx and startx <= upperBoundx and starty >= lowerBoundy and starty <= upperBoundy then
		equal = true
	end

	return equal
end

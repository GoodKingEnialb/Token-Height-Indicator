----------------------
-- CUSTOM ADDITIONS --
----------------------
local lastGridSize = 43
local lastUnits = 5
local lastSuffix = "ft"
local lastDiag = 0
local OptData = {}

function ResetOptData(hashtag)
	if hashtag then
		OptData[hashtag] = {}
	else
		OptData = {}
	end
end

function getImageSettings()
	local gridsize = lastGridSize
	if getGridSize then
		gridsize = getGridSize()
		lastGridSize = gridsize
	end
	
	local units = lastUnits
	if (getDatabaseNode and DB.getValue(getDatabaseNode(), "distancebaseunit")) or getDistanceBaseUnits then
		units = DB.getValue(getDatabaseNode(), "distancebaseunit") or getDistanceBaseUnits()
		lastUnits = units	
	end
		
	local suffix = lastSuffix
	if getDistanceSuffix then
		suffix = getDistanceSuffix()
		lastSuffix = suffix
	end
	
	local diagmult = lastDiag	
	if getDistanceDiagMult or (Interface and Interface.getDistanceDiagMult) then
		diagmult = getDistanceDiagMult() or Interface.getDistanceDiagMult()
		lastDiag = diagmult	
	end

	return gridsize, units, suffix, diagmult
end

function getDistanceBetween(sourceItem, targetItem)
	if not sourceItem or not targetItem or not CombatManager then
		return 0
	end
	
	local gridsize, units, _, _ = getImageSettings()

	local startx = 0
	local starty = 0
	local startz = 0

	local endx = 0
	local endy = 0
	local endz = 0

	local ctNodeOrigin
	local sourceToken
	local targetToken
	
	if type(sourceItem) == "number" then 
		sourceToken = getTokenOfTokenId(sourceItem)
	else
		sourceToken = sourceItem
	end

	if type(targetItem) == "number" then 
		targetToken = getTokenOfTokenId(targetItem)
	else
		targetToken = targetItem
	end
	
	if sourceToken.getContainerNode then
		ctNodeOrigin = CombatManager.getCTFromToken(sourceToken)
		if ctNodeOrigin then
			startz = TokenHeight.getHeight(ctNodeOrigin) * gridsize / units
	
			local ctNodeTarget
			if targetToken.getContainerNode then
				ctNodeTarget = CombatManager.getCTFromToken(targetToken)
				if ctNodeTarget then
					endz = TokenHeight.getHeight(ctNodeTarget) * gridsize / units
				end
			end
		end
	end

	if not sourceToken.getContainerNode and not targetToken.getContainerNode then
		startx, starty = sourceToken['x'], sourceToken['y']
		endx, endy = targetToken['x'], targetToken['y']
	elseif not sourceToken.getContainerNode and targetToken.getContainerNode then
		startx, starty = sourceToken['x'], sourceToken['y']
		endx, endy = targetToken.getPosition()
		endy = endy * -1
	elseif sourceToken.getContainerNode and not targetToken.getContainerNode then
		startx, starty = sourceToken.getPosition()
		starty = starty * -1
		endx, endy = targetToken['x'], targetToken['y']
	else
		startx, starty = getClosestPosition(sourceToken, targetToken)
		endx, endy = getClosestPosition(targetToken, sourceToken)
	end
	return distanceBetween(startx, starty, startz, endx, endy, endz, false)
end

function getTokensWithinDistance(sourceItem, distance)
	if not sourceItem or not CombatManager then
		return {}
	end
	
	local gridsize, units, _, _ = getImageSettings()

	local startx = 0
	local starty = 0
	local startz = 0

	local endx = 0
	local endy = 0
	local endz = 0

	local ctNodeOrigin
	local sourceToken
	local targetToken
	
	local closeTokens = {}
	
	if type(sourceItem) == "number" then 
		sourceToken = getTokenOfTokenId(sourceItem)
	else
		sourceToken = sourceItem
	end
	
	if sourceToken.getContainerNode then
		ctNodeOrigin = CombatManager.getCTFromToken(sourceToken)
		if ctNodeOrigin then
			startz = TokenHeight.getHeight(ctNodeOrigin) * gridsize / units
		end
	end
	
	for _,ctNode in pairs(CombatManager.getCombatantNodes()) do
		targetToken = CombatManager.getTokenFromCT(ctNode)
		-- Arnagus fix for targets on multiple maps
		if targetToken and targetToken ~= sourceToken then

			local endz = 0
			if targetToken then
				endz = TokenHeight.getHeight(ctNode) * gridsize / units
			end
			
			if not sourceToken.getContainerNode then
				startx, starty = sourceToken['x'], sourceToken['y']
				endx, endy = targetToken.getPosition()
				endy = endy * -1
			else
				startx, starty = getClosestPosition(sourceToken, targetToken)
				endx, endy = getClosestPosition(targetToken, sourceToken)
			end
			local distanceToToken = distanceBetween(startx, starty, startz, endx, endy, endz, false)
			if  distanceToToken <= distance then
				table.insert(closeTokens, targetToken)
			end
		end
	end
	
	return closeTokens
end

-- Get the closest position of token 1 (center of the square contained by token 1 which is closest
-- along a straight line to the center of token 2)
function getClosestPosition(token1, token2)
	local ctToken1 = CombatManager.getCTFromToken(token1)
	local ctToken2 = CombatManager.getCTFromToken(token2)
	if not ctToken1 or not ctToken2 then
		return 0,0,0,0
	end
	
	local gridsize, units, _, _ = getImageSettings()
	local centerPos1x, centerPos1y = token1.getPosition()
	local centerPos2x, centerPos2y = token2.getPosition()
	local dx = centerPos2x-centerPos1x
	local dy = centerPos2y-centerPos1y
	local slope = 0
	if dx ~= 0 then
		slope = (dy)/(dx)
	end
	
	local nSpace = DB.getValue(ctToken1, "space")
	local nHalfSpace = nSpace/2
	local nSquares = nSpace / units
	local center = (nSquares + 1)/2
	local minPosX, minPosY
	
	local intercept = 0
	local delta = 0
	local right = centerPos1x+nHalfSpace
	local left = centerPos1x-nHalfSpace
	local top = centerPos1y-nHalfSpace
	local bottom = centerPos1y+nHalfSpace
	
	if math.abs(dx) > math.abs(dy) then
		if dx < 0 then
			-- Look at the left edge
			intercept = centerPos1y - slope * nHalfSpace
			delta = math.max(1,math.ceil((intercept - top)/units))
			shiftedDelta = delta - center
			minPosX = centerPos1x + ((center-nSquares)*gridsize)
			minPosY = centerPos1y + (shiftedDelta*gridsize)
		else
			-- Look at the right edge
			intercept = centerPos1y + slope * nHalfSpace
			delta = math.max(1,math.ceil((intercept - top)/units))
			shiftedDelta = delta - center
			minPosX = centerPos1x + ((nSquares-center)*gridsize)
			minPosY = centerPos1y + (shiftedDelta*gridsize)
		end
	else
		if dy < 0 then
			-- Look at the top edge
			if slope == 0 then
				minPosX = centerPos1x
			else
				intercept = centerPos1x - nHalfSpace / slope
				delta = math.max(1,math.ceil((intercept - left)/units))
				shiftedDelta = delta - center
				minPosX = centerPos1x + (shiftedDelta*gridsize)
			end
			minPosY = centerPos1y + ((center-nSquares)*gridsize)
		else
			-- Look at the bottom edge
			if slope == 0 then
				minPosX = centerPos1x
			else
				intercept = centerPos1x + nHalfSpace / slope
				delta = math.max(1,math.ceil((intercept - left)/units))
				shiftedDelta = delta - center
				minPosX = centerPos1x + (shiftedDelta*gridsize)
			end
			minPosY = centerPos1y + ((nSquares-center)*gridsize)
		end
	end
	
	return minPosX, minPosY
end

function onInit()
	if super and super.onInit then
		super.onInit()
	end
	
	_, units, suffix, _ = getImageSettings()
--	TokenHeight.setUnits(units, suffix)
	TokenHeight.refreshHeights()
	ResetOptData()
end

-- Distance between two locations in 3 dimensions.
function distanceBetween(startx,starty,startz,endx,endy,endz,bSquare)
--Debug.console("distanceBetween " .. startx .. "," .. starty .. "," .. startz .. " and " ..  endx .. "," .. endy .. "," .. endz)
	local gridsize, units, suffix, diagmult = getImageSettings()

	local totalDistance = 0
	local dx = math.abs(endx-startx)
	local dy = math.abs(endy-starty)
	local dz = math.abs(endz-startz)

--Debug.console("gridsize " .. gridsize .. ", units " .. units .. ", suffix " .. suffix .. ", diagmult " ..  diagmult)
	
	if bSquare then
		local hyp = math.sqrt((dx^2)+(dy^2)+(dz^2))
		totalDistance = (hyp / gridsize)* units * 2
	else
		if diagmult == 1 then
			-- Just a max of each dimension
			local longestLeg = math.max(dx, dy, dz)		
			totalDistance = math.floor(longestLeg/gridsize+0.5)*units
		elseif diagmult == 0 then
			-- Get 3D distance directly
			local hyp = math.sqrt((dx^2)+(dy^2)+(dz^2))
			totalDistance = (hyp / gridsize)* units
		else 
			if OptionsManager.getOption("THIDIAGONALS") == "short" then
				-- You get full amount of the longest path plus half from the next (ignore the smallest)
				local straight = math.max(dx, dy, dz)
				local diagonal = 0
				local mid = 0
				if straight == dx then
					mid = math.max(dy, dz)
					diagonal = math.floor(math.ceil(mid/gridsize) / 2) * gridsize
				elseif straight == dy then
					mid = math.max(dx, dz)
					diagonal = math.floor(math.ceil(mid/gridsize) / 2) * gridsize
				else	
					mid = math.max(dx, dy)
					diagonal = math.floor(math.ceil(mid/gridsize) / 2) * gridsize
				end
				totalDistance = math.floor((straight + diagonal) / gridsize)
				totalDistance = totalDistance * units
			else
				-- You get full amount of the longest path and half from each of the others
				local straight = math.max(dx, dy, dz)
				local diagonal = 0
				if straight == dx then
					diagonal = math.floor((math.ceil(dy/gridsize) + math.ceil(dz/gridsize)) / 2) * gridsize
				elseif straight == dy then
					diagonal = math.floor((math.ceil(dx/gridsize) + math.ceil(dz/gridsize)) / 2) * gridsize
				else	
					diagonal = math.floor((math.ceil(dx/gridsize) + math.ceil(dy/gridsize)) / 2) * gridsize
				end
				totalDistance = math.floor((straight + diagonal) / gridsize)
				totalDistance = totalDistance * units
			end
		end
	end

--Debug.console(" is " .. totalDistance)
	return totalDistance
end

function onMeasurePointer(pixellength,pointertype,startx,starty,endx,endy)
	-- Modified by SilentRuin to better integrate with the superclasses and optimize
	local retStr = nil -- we will not do anything with label but if someone ever does we can handle the that code first
	if super and super.onMeasurePointer then
		retStr = super.onMeasurePointer(pixellength, pointertype, startx, starty, endx, endy)
	end

	local hashtag = tostring(startx) .. tostring(starty) .. tostring(endx) .. tostring(endy)
	if OptData and OptData[hashtag] and 
		OptData[hashtag].pixellength == pixellength and 
		OptData[hashtag].pointertype == pointertype then 
		if OptData[hashtag].retStr then
			return OptData[hashtag].retStr
		else
			return retStr
		end
	end
	ResetOptData(hashtag)

	local ctNodeOrigin, ctNodeTarget = getCTNodeAt(startx,starty, endx, endy)
	if ctNodeOrigin and ctNodeTarget then
		local heightOrigin = TokenHeight.getHeight(ctNodeOrigin)
		local heightTarget = TokenHeight.getHeight(ctNodeTarget)
		-- If height is on same plane then we don't need to waste time doing anything
		if heightOrigin == heightTarget then
			OptData[hashtag] = {pixellength = pixellength, pointertype = pointertype, endx = endx, endy = endy, retStr = nil}
			return retStr
		end
		
		local gridsize, units, suffix, diagmult = getImageSettings()
		if not (gridsize and units and suffix and diagmult) then 
			OptData[hashtag] = {pixellength = pixellength, pointertype = pointertype, endx = endx, endy = endy, retStr = nil}
			return retStr
		end
		local bSquare = false
		if pointertype == "rectangle" then
			bSquare = true
		end

		local startz = 0
		local endz = 0
		startz = heightOrigin * gridsize / units
		endz = heightTarget * gridsize / units
		local distance = distanceBetween(startx,starty,startz,endx,endy,endz,bSquare)
		if distance == 0 then
			retStr = ""
		else
			local stringDistance = nil
			if diagmult == 0 then
				stringDistance = string.format("%.1f", distance)
			else
				stringDistance = string.format("%.0f", distance)	
			end
			retStr = stringDistance .. suffix
		end
	end
	OptData[hashtag] = {pixellength = pixellength, pointertype = pointertype, endx = endx, endy = endy, retStr = retStr}
	return retStr
end

function getCTNodeAt(startx, starty, endx, endy)
	-- Rewrite by SilentRuin to look for both start and end at the same time
	-- and break when both are found 
	local allTokens = getTokens()
	local gridsize, units, _, _ = getImageSettings()
	local startCTnode = nil
	local endCTnode = nil
	local bFoundStart = false
	local bFoundEnd = false
	for _, oneToken in pairs(allTokens) do
		local x,y = oneToken.getPosition()
		local ctNode = CombatManager.getCTFromToken(oneToken)
		local bExact = true
		local sizeMultiplier = 0

		-- bmos / SoxMax 
		local nSpace = DB.getValue(ctNode, "space")
		if nSpace then
			sizeMultiplier = ((nSpace / units) - 1)  * 0.5
			if nSpace > units * 3 then
				bExact = false
			end
			
			if not bFoundStart then
				if bExact then
					bFoundStart = exactMatch(startx, starty, x, y, sizeMultiplier, gridsize)
				else
					bFoundStart = matchWithinSize(startx, starty, x, y, sizeMultiplier, gridsize)
				end
				if bFoundStart then
					startCTnode = ctNode
				end
			end
			
			if not bFoundEnd then
				if bExact then
					bFoundEnd = exactMatch(endx, endy, x, y, sizeMultiplier, gridsize)
				else
					bFoundEnd = matchWithinSize(endx, endy, x, y, sizeMultiplier, gridsize)
				end
				if bFoundEnd then
					endCTnode = ctNode
				end
			end
			
			if bFoundStart and bFoundEnd then
				break
			end
		end
    end
	return startCTnode, endCTnode
end

function getTokenOfTokenId(tokenid)	
	local allTokens = getTokens()
	for _, oneToken in pairs(allTokens) do
		if oneToken.getId() == tokenid then
			return oneToken
		end
	end
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

-- From diablobob and bratch9
function onDrop(x, y, draginfo)
	if draginfo.getType() == "token" then
		local custData = {}
		custData.x = x
		custData.y = y
		custData.imgCtrl = self
		draginfo.setCustomData(custData)
	end
	ResetOptData()

	if super and super.onDrop then
		return super.onDrop(x, y, draginfo)
	end
end
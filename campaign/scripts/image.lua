----------------------
-- CUSTOM ADDITIONS --
----------------------
local getDistanceBetween_orig

local function getDistanceBetween(sourceToken, targetToken)
	if not sourceToken or not targetToken then
		return
	end
	
	local gridsize = getGridSize()
	local units = getDistanceBaseUnits()
	
	local startz = 0
	local endz = 0

	local ctNodeOrigin = CombatManager.getCTFromToken(sourceToken)
	if ctNodeOrigin then
		startz = TokenHeight.getHeight(ctNodeOrigin) * gridsize / units
	
		local ctNodeTarget = CombatManager.getCTFromToken(targetToken)
		if ctNodeTarget then
			endz = TokenHeight.getHeight(ctNodeTarget) * gridsize / units
		end
	end
	
	local startx, starty = sourceToken.getPosition()
	local endx, endy = targetToken.getPosition()
	
	local nDistance = distanceBetween(startx,starty,startz,endx,endy,endz,false)

	return nDistance
end

function onInit()
	if super and super.onInit() then
		super.onInit()
	end
	getDistanceBetween_orig = Token.getDistanceBetween
	Token.getDistanceBetween = getDistanceBetween
end

function onMeasurePointer(pixellength,pointertype,startx,starty,endx,endy)
	if not (getGridSize and getDistanceBaseUnits and getDistanceSuffix and Interface.getDistanceDiagMult and getDistanceDiagMult) then
		return ""
	end
	
	local gridsize = getGridSize()
	local units = getDistanceBaseUnits()
	local suffix = getDistanceSuffix()
	local diagMult = Interface.getDistanceDiagMult()
	if getDistanceDiagMult() == 0 then
		diagMult = 0
	end
	local bSquare = false
	if pointertype == "rectangle" then
		bSquare = true
	end

	local startz = 0
	local endz = 0
			
	local ctNodeOrigin = getCTNodeAt(startx,starty,gridsize)
	if ctNodeOrigin then
		local ctNodeTarget = getCTNodeAt(endx,endy,gridsize)
		
		if ctNodeTarget then
			startz = TokenHeight.getHeight(ctNodeOrigin) * gridsize / units
			endz = TokenHeight.getHeight(ctNodeTarget) * gridsize / units
		end
	end
	
	local distance = distanceBetween(startx,starty,startz,endx,endy,endz,bSquare)
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
end

-- Distance between two locations in 3 dimensions.
function distanceBetween(startx,starty,startz,endx,endy,endz,bSquare)
	local diagMult = Interface.getDistanceDiagMult()
	if getDistanceDiagMult() == 0 then
		diagMult = 0
	end
	
	local units = getDistanceBaseUnits()
	local gridsize = getGridSize()
	local totalDistance = 0
	local dx = math.abs(endx-startx)
	local dy = math.abs(endy-starty)
	local dz = math.abs(endz-startz)
	
	if bSquare then
		local hyp = math.sqrt((dx^2)+(dy^2)+(dz^2))
		totalDistance = (hyp / gridsize)* units * 2
	else
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
		
	return totalDistance
end

function roundDown(val)
	return math.floor(val + gridsize / 2)
end

function getCTNodeAt(basex, basey, gridsize)
	local allTokens = getTokens()
	for _, oneToken in pairs(allTokens) do
		local x,y = oneToken.getPosition()
		local ctNode = CombatManager.getCTFromToken(oneToken)
		local bExact = true
		local sizeMultiplier = 0
			
--		if (User.getRulesetName() == "5E") then
--			local sSize = StringManager.trim(DB.getValue(ctNode, "size", ""):lower());
--
--			if sSize == "large" then
--				sizeMultiplier = 0.5
--			elseif sSize == "huge" then
--				sizeMultiplier = 1
--			elseif sSize == "gargantuan" then
--				-- Gargantuan creatures behave a bit differently. Can be anywhere within bounds
--				sizeMultiplier = 1.5
--				bExact = false
--			end
--		else
			--bmos / SoxMax supporting other rulesets	
			local distancePerGrid = GameSystem.getDistanceUnitsPerGrid()
			local nSpace = DB.getValue(ctNode, "space");
			sizeMultiplier = ((nSpace / distancePerGrid ) - 1) * 0.5
			if nSpace > distancePerGrid * 2 and nSpace % (distancePerGrid * 2) > 0 then
				bExact = false
			end
--		end

		local bFound = false
		if bExact then
			bFound = exactMatch(basex, basey, x, y, sizeMultiplier, gridsize)
		else
			bFound = matchWithinSize(basex, basey, x, y, sizeMultiplier, gridsize)
		end

		if bFound then
			return ctNode
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

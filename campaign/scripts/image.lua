----------------------
-- CUSTOM ADDITIONS --
----------------------
local lastGridSize = 43
local lastUnits = 5
local lastSuffix = "ft"
local lastDiag = 0
local OptData = {}
local tolerance = 0.005
local bFirstSpaceMissingWarningGiven = true

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

-- Returns the coordinates of an item and its corresponding token
function getCoordinatesOfItem(sourceItem)
	if not sourceItem or not CombatManager then
		return nil, nil, nil, nil
	end
	
	local gridsize, units, _, _ = getImageSettings()

	local startX = 0
	local startY = 0
	local startZ = 0

	local endX = 0
	local endY = 0
	local endZ = 0

	local ctNodeOrigin
	local sourceToken
	
	if type(sourceItem) == "number" then 
		sourceToken = getTokenOfTokenId(sourceItem)
	else
		sourceToken = sourceItem
	end
	
	if sourceToken.getContainerNode then
		ctNodeOrigin = CombatManager.getCTFromToken(sourceToken)
		if ctNodeOrigin then
			startZ = TokenHeight.getHeight(ctNodeOrigin) * gridsize / units
		end
	end

	if sourceToken.getContainerNode then
		startX, startY = sourceToken.getPosition()
--		startY = startY * -1
	else
		startX, startY = sourceToken['x'], sourceToken['y']
	end
	return startX, startY, startZ, sourceToken
end

function getDistanceBetween(sourceItem, targetItem)
	if not sourceItem or not targetItem or not CombatManager then
		return 0
	end

	-- Just use the coorindates of the two items unless they're both in containers, in which case we want the x/y/z coordinates
	-- of the containers closest to each other
	local startX, startY, startZ, sourceToken = getCoordinatesOfItem(sourceItem)
	local endX, endY, endZ, targetToken = getCoordinatesOfItem(targetItem)

	if sourceToken.getContainerNode and targetToken.getContainerNode then
		startX, startY, startZ = getClosestPosition(sourceToken, targetToken)
		endX, endY, endZ = getClosestPosition(targetToken, sourceToken)
	end

	return distanceBetween(startX, startY, startZ, endX, endY, endZ, false)
end

function getTokensWithinDistance(sourceItem, distance)
	if not sourceItem or not CombatManager then
		return {}
	end
	
	local gridsize, units, _, _ = getImageSettings()

	local startX = 0
	local startY = 0
	local startZ = 0

	local endX = 0
	local endY = 0
	local endZ = 0

	local ctNodeOrigin
	local sourceToken
	local targetToken
	
	local closeTokens = {}

	startX, startY, startZ, sourceToken = getCoordinatesOfItem(sourceItem)
	
	for _,ctNode in pairs(CombatManager.getCombatantNodes()) do
		targetToken = CombatManager.getTokenFromCT(ctNode)
		-- Arnagus fix for targets on multiple maps
		if targetToken and targetToken ~= sourceToken then

			local endZ = 0
			if targetToken then
				endZ = TokenHeight.getHeight(ctNode) * gridsize / units
			end
			
			if not sourceToken.getContainerNode then
				startX, startY = sourceToken['x'], sourceToken['y']
				endX, endY = targetToken.getPosition()
				endY = endY * -1
			else
				startX, startY, startZ = getClosestPosition(sourceToken, targetToken)
				endX, endY, endZ = getClosestPosition(targetToken, sourceToken)
			end
			local distanceToToken = distanceBetween(startX, startY, startZ, endX, endY, endZ, false)
			if  distanceToToken < distance then
				table.insert(closeTokens, targetToken)
			end
		end
	end
	
	return closeTokens
end

-- Get all tokens within a shape (including the origin token).  Shapes supported are line, cube, sphere, cylinder, and cone.
-- Second point(x2,y2,z2) only applies to cones and lines, height only applies to cylinders, width only applies to lines.
function getTokensWithinShapeFromToken(originItem, shape, distance, height, width, azimuthalAngle, polarAngle)
	originX, originY, originZ, originToken = getCoordinatesOfItem(originItem)
	if not originX then
		return nil
	end

	return getTokensWithinShape(originX, originY, originZ, shape, distance, height, width, azimuthalAngle, polarAngle)
end

-- Get all tokens within a shape (including the origin token).  Shapes supported are line, cube, sphere, cylinder, and cone.
-- Second point(x2,y2,z2) only applies to cones and lines, height only applies to cylinders, width only applies to lines..
function getTokensWithinShape(originX, originY, originZ, shape, distance, height, width, azimuthalAngle, polarAngle)
	if shape == "sphere" then
		return getTokensWithinSphere(originX, originY, originZ, distance)
	elseif shape == "cube" then
		return getTokensWithinCube(originX, originY, originZ, distance)
	elseif shape == "cylinder" then
		return getTokensWithinCylinder(originX, originY, originZ, distance, height)
	elseif shape == "line" then
		return getTokensWithinLine(originX, originY, originZ, distance, width, azimuthalAngle, polarAngle)
	elseif shape == "cone" then
		return getTokensWithinCone(originX, originY, originZ, distance, height, width, azimuthalAngle, polarAngle)
	end
end

function getTokensWithinSphere(startX, startY, startZ, radius)
	local gridsize, units, _, _ = getImageSettings()
	local closeTokens = {}
	
	for _,ctNode in pairs(CombatManager.getCombatantNodes()) do
		targetToken = CombatManager.getTokenFromCT(ctNode)
		if targetToken then
			local endX, endY, endZ = getClosestPositionToReference(targetToken, startX, startY, startZ)

			local distanceToToken = distanceBetween(startX, startY, startZ, endX, endY, endZ, true) / 2
--Debug.console("Distance to " .. targetToken.getName() .. " is " .. distanceToToken .. ": " .. startX .. "," .. startY .. "," .. startZ .. ": " .. endX .. "," .. endY .. "," .. endZ)
			if  distanceToToken < radius then
				table.insert(closeTokens, targetToken)
			end
		end
	end

	return closeTokens
end

function getTokensWithinCube(startX, startY, startZ, length)
	local gridsize, units, _, _ = getImageSettings()
	local halfLengthInPixels = length * gridsize / units / 2
	local testMinX = startX - halfLengthInPixels
	local testMaxX = startX + halfLengthInPixels
	local testMinY = startY - halfLengthInPixels
	local testMaxY = startY + halfLengthInPixels
	local testMinZ = startZ - halfLengthInPixels
	local testMaxZ = startZ + halfLengthInPixels	
	local closeTokens = {}
	
	for _,ctNode in pairs(CombatManager.getCombatantNodes()) do
		targetToken = CombatManager.getTokenFromCT(ctNode)
		if targetToken then
			local tokenMinX, tokenMaxX, tokenMinY, tokenMaxY, tokenMinZ, tokenMaxZ
			local tokenMinX, tokenMaxX, tokenMinY, tokenMaxY, tokenMinZ, tokenMaxZ = getTokenBounds(targetToken)

			if cubesOverlap(testMinX, testMaxX, testMinY, testMaxY, testMinZ, testMaxZ, tokenMinX, tokenMaxX, tokenMinY, tokenMaxY, tokenMinZ, tokenMaxZ) then
				table.insert(closeTokens, targetToken)
			end
		end
	end

	return closeTokens
end

function getTokensWithinCylinder(startX, startY, startZ, radius, height)
	local gridsize, units, _, _ = getImageSettings()
	local closeTokens = {}
	
	for _,ctNode in pairs(CombatManager.getCombatantNodes()) do
		local targetToken = CombatManager.getTokenFromCT(ctNode)
		if targetToken then
			local endX, endY, _ = getClosestPositionToReference(targetToken, startX, startY, 0)
			local endZ = TokenHeight.getHeight(ctNode)

			local flatDistance = (math.sqrt(((endX-startX)^2)+((endY-startY)^2))/ gridsize)* units
			local minHeight = startZ
			local maxHeight = startZ + height
--Debug.console("Cylinder (" .. targetToken.getName() .. "): " .. flatDistance .. " < " .. radius .. ", " .. endZ .. " > " .. minHeight .. ", " .. endZ .. " < " .. maxHeight)
			if (flatDistance <= radius) and (endZ >= minHeight) and (endZ <= maxHeight) then
				table.insert(closeTokens, targetToken)
			end
		end
	end

	return closeTokens
end

function getTokensWithinLine(originX, originY, originZ, distance, width, azimuthalAngle, polarAngle)
	local gridsize, units, _, _ = getImageSettings()
	local closeTokens = {}

	-- Get equation of line
	local a = x2 - originX
	local b = y2 - originY
	local c = z2 - originZ
	
	for _,ctNode in pairs(CombatManager.getCombatantNodes()) do
		targetToken = CombatManager.getTokenFromCT(ctNode)
		if targetToken then
			local endX, endY, endZ
			endX, endY, endZ = getClosestPositionToReference(targetToken, startX, startY, startZ)

			-- Get distance to point, the coordinate along that line at the appropiate angle, and see if point is within circle
			local distancetoTarget = (math.sqrt(((endX-originX)^2)+((endY-originY)^2)+((endZ-originZ)))/ gridsize)* units
			local x3 = 0
			local minHeight = startZ
			local maxHeight = startZ + height
			local minZ, maxZ
			_, _, _, _, minZ, maxZ = getTokenBounds(targetToken)
			if (flatDistance < radius) and (maxZ > minHeight) and (minZ < maxHeight) then
				table.insert(closeTokens, targetToken)
			end
		end
	end

	return closeTokens
end

function getTokensWithinConeOrig(originX, originY, originZ, radius, capHeight, angle, x2, y2, z2)
	local gridsize, units, _, _ = getImageSettings()
	local closeTokens = {}

	local aperture = math.rad(45)  -- 0.785398
	local cosHalfAperture = math.cos(aperture / 2)


	local endX, endY, endZ, avX, avY, avZ
	endX, endY, endZ = extrapolatePointOnLine(originX, originY, originZ, x2, y2, z2, distance)
	avX = endX-originX
	avY = endY-originY
	avZ = endZ-originZ
	local magAV = math.sqrt((avX^2)+(avY^2)+(avZ^2))

	for _,ctNode in pairs(CombatManager.getCombatantNodes()) do
		targetToken = CombatManager.getTokenFromCT(ctNode)
		if targetToken then
			endX, endY, endZ = getClosestPositionToReference(targetToken, startX, startY, startZ)

			local apexToTestX = endX - originX
			local apexToTestY = endY - originY
			local apexToTestZ = endZ - originZ
		
			local dotProdVectors = avX*apexToTestX + avY*apexToTestY + avZ*apexToTestZ
			local magApexToTest = math.sqrt((apexToTestX^2)+(apexToTestY^2)+(apexToTestZ^2))
		
			local bInInfiniteCone = (dotProdVectors / magApexToTest / magAV) > cosHalfAperture
Debug.console("Cone (" .. targetToken.getName() .. "): " .. dotProdVectors .. ", " .. magAV .. ", " .. magApexToTest .. ", " .. cosHalfAperture)

			if bInInfiniteCone then
				if (dotProdVectors / magAV) < magAV then
					table.insert(closeTokens, targetToken)
				end
			end
		end
	end

	return closeTokens
end

function getTokensWithinCone(originX, originY, originZ, radius, capHeight, vertexAngleDeg, azimuthalAngleDeg, polarAngleDeg)
	local gridsize, units, _, _ = getImageSettings()
	local closeTokens = {}

	local r = radius * gridsize / units
	local h = capHeight * gridsize / units
Debug.console("gridsize, units = " .. gridsize .. "," .. units)

	local azimuthalAngle = math.rad(azimuthalAngleDeg)
	local polarAngle = math.rad(polarAngleDeg)
	local tanVertexOver2 = math.tan(math.rad(vertexAngleDeg))/2
	local capRadius = tanVertexOver2*2*(r-h)

	for _,ctNode in pairs(CombatManager.getCombatantNodes()) do
		targetToken = CombatManager.getTokenFromCT(ctNode)
		if targetToken then
			local testX, testY, testZ = getClosestPositionToReference(targetToken, originX, originY, originZ)
			local distance = math.sqrt(((testX-originX)^2)+((testY-originY)^2)+((testZ-originZ)))
			local targetPolar = math.acos((testZ-originZ)/distance)
			local targetAzmuthal = math.acos((testX-originX)/(distance*math.sin(targetPolar)))

Debug.console("Cone (" .. targetToken.getName() .. "): " .. distance .. "," .. radius)

			if (distance >=0) and (distance <= radius) then
				Debug.console("       : " .. targetPolar .. "," .. polarAngle .. "," .. tanVertexOver2)
				if (targetPolar >= polarAngle - tanVertexOver2) and (targetPolar <= polarAngle + tanVertexOver2) then
					Debug.console("       : " .. targetAzmuthal .. "," .. azimuthalAngle .. "," .. tanVertexOver2)
					if (targetAzmuthal >= azimuthalAngle - tanVertexOver2) and (targetAzmuthal <= azimuthalAngle + tanVertexOver2) then
						table.insert(closeTokens, targetToken)
					end
				end
			end
		end
	end

	return closeTokens
end

-- Return coordinates of a point a distance d from (x1, y1, z2) in the direction of (x2, y2, z2)
function extrapolatePointOnLine(x1, y1, z1, x2, y2, z2, d)
	-- P1 P2 Vector
	local vx = x2-x1
	local vy = y2-y1
	local vz = z2-z1

	-- Distance from point 1 to point 2
	local normalizedDistance = math.sqrt(((endX-originX)^2)+((endY-originY)^2)+((endZ-originZ)))

	-- Normalize the vector
	vx = vx / normalizedDistance
	vy = vy / normalizedDistance
	vz = vz / normalizedDistance

	local extX = x1 + d * vx
	local extY = y1 + d * vy
	local extZ = z1 + d * vz

	return extX, extY, extZ

end

-- Get the closest position of token 1 (center of the square contained by token 1 which is closest
-- along a straight line to the center of token 2)
function getClosestPosition(token1, token2)
	local ctToken1 = CombatManager.getCTFromToken(token1)
	local ctToken2 = CombatManager.getCTFromToken(token2)
	if not ctToken1 or not ctToken2 then
		return 0,0,0
	end
	
	local x, y, z = getCoordinatesOfItem(token2)
--Debug.console(token2.getName() .. ": " .. x .. "," .. y .. "," .. z)
	return getClosestPositionToReference(token1, x, y, z)
end

-- Get the bounding cube for a token (min x, max x, min y, max y, min z, max z)
function getTokenBounds(token)
	local ctToken = CombatManager.getCTFromToken(token)
	if not ctToken then
		return 0,0,0,0,0,0
	end
	
	local gridsize, units, _, _ = getImageSettings()
	local centerPosX, centerPosY, centerPosZ = getCoordinatesOfItem(token)

	local nSpace = DB.getValue(ctToken, "space")
	if nil == nSpace then
		nSpace = 5
		if bFirstSpaceMissingWarningGiven then
			Debug.chat("Space data missing from target - setting to " .. nSpace .. ". Range results may be inaccurate.")
			bFirstSpaceMissingWarningGiven = false
		end
	end

	local nHalfSpace = nSpace/2 * gridsize / units
	local minPosX, minPosY, minPosZ, maxPosX, maxPosY, maxPosZ
	minPosX = centerPosX-nHalfSpace
	minPosY = centerPosY-nHalfSpace
	minPosZ = centerPosZ-nHalfSpace
	maxPosX = centerPosX+nHalfSpace
	maxPosY = centerPosY+nHalfSpace
	maxPosZ = centerPosZ+nHalfSpace

	return minPosX, maxPosX, minPosY, maxPosY, minPosZ, maxPosZ
end

-- Check for overlap between two cubes represented by min and max coordinates in each dimension
function cubesOverlap(cube1MinX, cube1MaxX, cube1MinY, cube1MaxY, cube1MinZ, cube1MaxZ, cube2MinX, cube2MaxX, cube2MinY, cube2MaxY, cube2MinZ, cube2MaxZ)
	return (cube1MinX < cube2MaxX) and (cube1MaxX > cube2MinX) and (cube1MinY < cube2MaxY) and (cube1MaxY > cube2MinY) and (cube1MinZ < cube2MaxZ) and (cube1MaxZ > cube2MinZ)
end

-- Get the closest position of token 1 (center of the cube contained by token 1 which is closest
-- along a straight line to the given reference coordinates
function getClosestPositionToReference(token, referencex, referencey, referencez)
	local closestx, closesty, closestz, minPosX, maxPosX, minPosY, maxPosY, minPosZ, maxPosZ

	minPosX, maxPosX, minPosY, maxPosY, minPosZ, maxPosZ = getTokenBounds(token)

	closestx=clamp(referencex,minPosX,maxPosX)
	closesty=clamp(referencey,minPosY,maxPosY)
	closestz=clamp(referencez,minPosZ,maxPosZ)
		
	return closestx, closesty, closestz
end


function clamp(x, minVal, maxVal)
	local result = 0
	if x < minVal then
		result = minVal
	elseif x > maxVal then
		result = maxVal
	else 
		result = x
	end
	return result
end

function onInit()
	if super and super.onInit then
		super.onInit()
	end

	_, units, suffix, _ = getImageSettings()
	
	--TokenHeight.refreshHeights()
	ResetOptData()
end	

-- Distance between two locations in 3 dimensions.  
function distanceBetween(startX,startY,startZ,endX,endY,endZ,bSquare)
--Debug.console("distanceBetween " .. startX .. "," .. startY .. "," .. startZ .. " and " ..  endX .. "," .. endY .. "," .. endZ)
	local gridsize, units, suffix, diagmult = getImageSettings()

	local totalDistance = 0
	local dx = math.abs(endX-startX)
	local dy = math.abs(endY-startY)
	local dz = math.abs(endZ-startZ)

--Debug.console("gridsize " .. gridsize .. ", units " .. units .. ", suffix " .. suffix .. ", diagmult " ..  diagmult)
	
	if bSquare then
		local hyp = math.sqrt((dx^2)+(dy^2)+(dz^2))
		totalDistance = (hyp / gridsize)* units * 2
	else
		if diagmult == 1 then
			-- Just a max of each dimension
			local longestLeg = math.max(dx, dy, dz)		
--Debug.console("longestLeg = " .. longestLeg)
			totalDistance = math.ceil(longestLeg/gridsize)*units
		elseif diagmult == 0 then
			-- Get 3D distance directly
			local hyp = math.sqrt((dx^2)+(dy^2)+(dz^2))
--Debug.console("hyp = " .. hyp)
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
				totalDistance = math.ceil((straight + diagonal) / gridsize)
--Debug.console("td = " .. totalDistance)
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
				totalDistance = math.ceil((straight + diagonal) / gridsize)
--Debug.console("td = " .. totalDistance)
				totalDistance = totalDistance * units
			end
		end
	end

--Debug.console(" is " .. totalDistance)
	return totalDistance
end

function onMeasurePointer(pixellength,pointertype,startX,startY,endX,endY)
	-- Modified by SilentRuin to better integrate with the superclasses and optimize
	local retStr = nil -- we will not do anything with label but if someone ever does we can handle the that code first
	if super and super.onMeasurePointer then
		retStr = super.onMeasurePointer(pixellength, pointertype, startX, startY, endX, endY)
	end

	local gridsize, units, suffix, diagmult = getImageSettings()
	local hashtag = tostring(startX) .. tostring(startY) .. tostring(endX) .. tostring(endY) .. tostring(diagmult)
	if OptData and OptData[hashtag] and 
		OptData[hashtag].pixellength == pixellength and 
		OptData[hashtag].pointertype == pointertype and OptData[hashtag].retStr then 
			return OptData[hashtag].retStr
	end
	ResetOptData(hashtag)

	local ctNodeOrigin, ctNodeTarget = getCTNodeAt(startX,startY, endX, endY)
	if ctNodeOrigin and ctNodeTarget then
		local heightOrigin = TokenHeight.getHeight(ctNodeOrigin)
		local heightTarget = TokenHeight.getHeight(ctNodeTarget)
		
		if not (gridsize and units and suffix and diagmult) then 
			OptData[hashtag] = {pixellength = pixellength, pointertype = pointertype, endX = endX, endY = endY, retStr = nil}
			return retStr
		end
		local bSquare = false
		if pointertype == "rectangle" then
			bSquare = true
		end

		local startZ = 0
		local endZ = 0
		startZ = heightOrigin * gridsize / units
		endZ = heightTarget * gridsize / units
		local distance = distanceBetween(startX,startY,startZ,endX,endY,endZ,bSquare)
--("OMP: " .. ctNodeTarget.getName() .. " is " .. distance .. ": " .. startX .. "," .. startY .. "," .. startZ .. ": " .. endX .. "," .. endY .. "," .. endZ)
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
	OptData[hashtag] = {pixellength = pixellength, pointertype = pointertype, endX = endX, endY = endY, retStr = retStr}
	return retStr
end

function getCTNodeAt(startX, startY, endX, endY)
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
		if nil == nSpace then
			nSpace = 5
			if bFirstSpaceMissingWarningGiven then
				Debug.chat("Space data missing from target - setting to " .. nSpace .. ". Range results may be inaccurate.")
				bFirstSpaceMissingWarningGiven = false
			end
		end
	
		if nSpace then
			sizeMultiplier = ((nSpace / units) - 1)  * 0.5
			if nSpace > units * 3 then
				bExact = false
			end
			
			if not bFoundStart then
				if bExact then
					bFoundStart = exactMatch(startX, startY, x, y, sizeMultiplier, gridsize)
				else
					bFoundStart = matchWithinSize(startX, startY, x, y, sizeMultiplier, gridsize)
				end
				if bFoundStart then
					startCTnode = ctNode
				end
			end
			
			if not bFoundEnd then
				if bExact then
					bFoundEnd = exactMatch(endX, endY, x, y, sizeMultiplier, gridsize)
				else
					bFoundEnd = matchWithinSize(endX, endY, x, y, sizeMultiplier, gridsize)
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

function exactMatch(startX, startY, endX, endY, sizeMultiplier, gridsize)
	local equal = false

	local modx = endX
	local mody = endY
	if modx > startX then
		modx = modx - gridsize * sizeMultiplier
	elseif modx < startX then
		modx = modx + gridsize * sizeMultiplier
	end
	if mody > startY then
		mody = mody - gridsize * sizeMultiplier
	elseif mody < startY then
		mody = mody + gridsize * sizeMultiplier
	end		
--	if modx == startX and mody == startY then
	if closeEnough(modx, startX) and closeEnough(mody, startY) then
		equal = true
	end
	return equal
end

function closeEnough(value1, value2)
    if ((value1 + tolerance > value2) and (value1 - tolerance < value2)) then
		return true
	else
		return false
	end
end

function matchWithinSize(startX, startY, endX, endY, sizeMultiplier, gridsize)
	local equal = false

	local modx = endX
	local mody = endY
	local lowerBoundx = endX
	local lowerBoundy = endY
	local upperBoundx = endX
	local upperBoundy = endY

	if endX > startX then
		lowerBoundx = endX - gridsize * sizeMultiplier
	elseif endX < startX then
		upperBoundx = endX + gridsize * sizeMultiplier
	end
	if endY > startY then
		lowerBoundy = endY - gridsize * sizeMultiplier
	elseif endY < startY then
		upperBoundy = upperBoundy + gridsize * sizeMultiplier
	end		

	if startX >= lowerBoundx and startX <= upperBoundx and startY >= lowerBoundy and startY <= upperBoundy then
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
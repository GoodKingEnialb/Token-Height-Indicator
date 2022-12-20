----------------------
-- CUSTOM ADDITIONS --
----------------------
local lastGridSize = 43
local lastUnits = 5
local lastSuffix = "ft"
local lastDiag = 0
local OptData = {}
local tolerance = 0.005

function onInit()
	if super and super.onInit then
		super.onInit();
	end

	_, units, suffix, _ = getImageSettings();

	TokenHeight.refreshHeights();
--	local tTokens = self.getTokens();
--	for _, token in pairs(tTokens) do
--		local nodeCT = CombatManager.getCTFromToken(token);
--		DB.addHandler(DB.getPath(nodeCT, "heightvalue"), "onUpdate", updatePointer);
--	end
end

--function onClose()
--	local tTokens = self.getTokens();
--	for _, token in pairs(tTokens) do
--		local nodeCT = CombatManager.getCTFromToken(token);
--		DB.removeHandler(DB.getPath(nodeCT, "heightvalue"), "onUpdate", updatePointer);
--	end
--	if super and super.onClose then
--		super.onClose();
--	end
--end

--function onTokenAdded(prototypename, x, y)
--	local token;
--	if super and super.onTokenAdded then
--		token = super.onTokenAdded(prototypename, x, y);
--	end
--	if token then
--		local nodeCT = CombatManager.getCTFromToken(token);
--		DB.addHandler(DB.getPath(nodeCT, "heightvalue"), "onUpdate", updatePointer);
--	end
--	return token;
--end

--function clearSelectedTokens()
--	local tTokens = self.getSelectedTokens();
--	for _, token in pairs(tTokens) do
--		local nodeCT = CombatManager.getCTFromToken(token);
--		DB.removeHandler(DB.getPath(nodeCT, "heightvalue"), "onUpdate", updatePointer);
--	end
--	if super and super.clearSelectedTokens then
--		super.clearSelectedTokens();
--	end
--end

-- Updates and gets the distance that is the label for the pointers that have changed because height changed however.....
-- When we get the value I have no idea how to set the label. Is this internal to the engine and we can never get to it?
-- That seems weird if so but perhaps. Anyhow all the pieces are here if you can get a handle to the pointer itself.
--function updatePointer(nodeHeightValue)
--	local nGridSize, nUnits, suffix, diagmult = getImageSettings();
--	if nGridSize ~= 0 then
--		local nodeCT = nodeHeightValue.getParent();
--		local tokenCT = CombatManager.getTokenFromCT(nodeCT);
--		local rActor = ActorManager.resolveActor(nodeCT);
--		local nTokenCTX, nTokenCTY = tokenCT.getPosition();
--		local tTargets = TargetingManager.getFullTargets(rActor);
--
--		for _, rTarget in pairs(tTargets) do
--			local nodeTargetCT = ActorManager.getCTNode(rTarget);
--			local tokenTargetCT = CombatManager.getTokenFromCT(nodeTargetCT);
--			local nTokenTargetCTX, nTokenTargetCTY = tokenTargetCT.getPosition();
--			local nDistance = super.getDistanceBetween(tokenCT, tokenTargetCT);
--
--			Debug.chat("Distance: " .. onMeasurePointer(nDistance*nGridSize/nUnits, "arrow", nTokenCTX, nTokenCTY, nTokenTargetCTX, nTokenTargetCTY));
--		end
--
--		local tTokens= self.getTokens();
--		for _, token in pairs(tTokens) do
--			if tokenCT.isTargetedBy(token) then
--				local nTokenX, nTokenY = token.getPosition();
--				local nDistance = super.getDistanceBetween(tokenCT, token);
--				Debug.chat("Distance: " .. onMeasurePointer(nDistance*nGridSize/nUnits, "arrow", nTokenCTX, nTokenCTY, nTokenX, nTokenY));
--			end
--		end
--	end
--end

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

	local ctNodeOrigin
	local sourceToken
	
	if type(sourceItem) == "number" then 
		sourceToken = getTokenOfTokenId(sourceItem)
	else
		sourceToken = sourceItem
	end
	
	if sourceToken.getContainerNode then
		startX, startY = sourceToken.getPosition()
		ctNodeOrigin = CombatManager.getCTFromToken(sourceToken)
		if ctNodeOrigin then
			startZ = TokenHeight.getHeight(ctNodeOrigin) * gridsize / units
		end
	else
		startX, startY = sourceToken['x'], sourceToken['y']  
	end
	return startX, startY, startZ, sourceToken
end

-- Get coordinates of two items (needed in case they're of different types because of needing to invert Y)
function getCoordinatesOfItems(sourceItem, targetItem)
	if not sourceItem or not CombatManager then
		return nil, nil, nil, nil, nil, nil, nil, nil
	end
	
	local gridsize, units, _, _ = getImageSettings()

	local startX, startY, startZ, sourceToken = getCoordinatesOfItem(sourceItem)
	local endX, endY, endZ, targetToken = getCoordinatesOfItem(targetItem)
	
	if not sourceToken.getContainerNode and targetToken.getContainerNode then
		startY = startY * -1 
	elseif sourceToken.getContainerNode and not targetToken.getContainerNode then
		endY = endY * -1 		
	end
	return startX, startY, startZ, sourceToken, endX, endY, endZ, targetToken
end

function getDistanceBetween(sourceItem, targetItem)
	if not sourceItem or not targetItem or not CombatManager then
		return 0
	end

	-- Just use the coorindates of the two items unless they're both in containers, in which case we want the x/y/z coordinates
	-- of the containers closest to each other (but if one is a container and the other is not, have to flip the y coordinate of the non-container)
	local startX, startY, startZ, sourceToken = getCoordinatesOfItem(sourceItem)
	local endX, endY, endZ, targetToken = getCoordinatesOfItem(targetItem)
--	local startX, startY, startZ, sourceToken, endX, endY, endZ, targetToken = getCoordinatesOfItems(sourceItem, targetItem)

	if sourceToken.getContainerNode and targetToken.getContainerNode then
		startX, startY, startZ = getClosestPosition(sourceToken, targetToken)
		endX, endY, endZ = getClosestPosition(targetToken, sourceToken)
	end

local distBet = distanceBetween(startX, startY, startZ, endX, endY, endZ, false)
--Debug.console("tokens: " .. startX .. "," .. startY .. "," .. startZ .. " / " .. endX .. "," .. endY .. "," .. endZ)
--Debug.console("GDB_new = " .. distBet)
--distBet = distanceBetween(startX, -startY, startZ, endX, endY, endZ, false)
--Debug.console("distanceb = " .. distBet)
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

-- Get all tokens within a shape (including the origin token).  See getTokensWithinShape for details.
function getTokensWithinShapeFromToken(originItem, shape, distance, height, width, azimuthalAngle, polarAngle)
	local originX, originY, originZ, originToken = getCoordinatesOfItem(originItem)
	if not originX then
		return nil
	end

	return getTokensWithinShape(originX, originY, originZ, shape, distance, height, width, azimuthalAngle, polarAngle)
end

-- Get all tokens within a shape (including the origin token, if any).  Any token with any part of its containing cube will be returned.
-- The parameters for each type of shape are:
--     - All:  
--            - originX, originY, originZ - the coordinates of the center / origin of the shape
--            - shape - "sphere", "cube", "cylinder", "line", "cone"
--     - sphere:
--            - distance = radius of the sphere
--     - cube:
--            - distance = length of each side of the cube
--     - cylinder:
--            - distance = radius of the sphere
--            - height = height of the cylinder
--     - line:
--            - distance = length of the line
--            - width = width of the line (half on each side of the line in all directions)
--            - azimuthalAngle = angle of the line leaving the origin in the X/Y plane in degrees. 0 = north, 90 = east
--            - polarAngle = angle of the line leaving the origin in the X/Z plane in degrees. 0 = flat, 90 = straight up
--     - cone:
--            - distance = length of the cone
--            - width = angle of the cone aperture (53 in 5E, 90 in 3.5/PFRPG)
--            - azimuthalAngle = angle of the center of the cone leaving the origin in the X/Y plane in degrees. 0 = north, 90 = east
--            - polarAngle = angle of the center of the cone leaving the origin in the X/Z plane in degrees. 0 = flat, 90 = straight up
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
		return getTokensWithinCone(originX, originY, originZ, distance, width, azimuthalAngle, polarAngle)
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
			local tokenMinX, tokenMaxX, tokenMinY, tokenMaxY, tokenMinZ, tokenMaxZ = getTokenBounds(targetToken)
			if MathFunctions.cubesOverlap(testMinX, testMaxX, testMinY, testMaxY, testMinZ, testMaxZ, tokenMinX, tokenMaxX, tokenMinY, tokenMaxY, tokenMinZ, tokenMaxZ) then
				table.insert(closeTokens, targetToken)
			end
		end
	end

	return closeTokens
end

function getTokensWithinSquare(startX, startY, length)
	local gridsize, units, _, _ = getImageSettings()
	local halfLengthInPixels = length * gridsize / units / 2
	local testMinX = startX - halfLengthInPixels
	local testMaxX = startX + halfLengthInPixels
	local testMinY = startY - halfLengthInPixels
	local testMaxY = startY + halfLengthInPixels
	local closeTokens = {}
	
	for _,ctNode in pairs(CombatManager.getCombatantNodes()) do
		targetToken = CombatManager.getTokenFromCT(ctNode)
		if targetToken then
			local tokenMinX, tokenMaxX, tokenMinY, tokenMaxY, _, _ = getTokenBounds(targetToken)
			if MathFunctions.squaresOverlap(testMinX, testMaxX, testMinY, testMaxY, tokenMinX, tokenMaxX, tokenMinY, tokenMaxY) then
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

			local flatDistance = MathFunctions.magnitude(endX-startX,endY-startY,0) / gridsize * units
			local minHeight = startZ
			local maxHeight = startZ + height

			if (flatDistance <= radius) and (endZ >= minHeight) and (endZ <= maxHeight) then
				table.insert(closeTokens, targetToken)
			end
		end
	end

	return closeTokens
end

function getTokensWithinLine(originX, originY, originZ, length, width, azimuthalAngleDeg, polarAngleDeg)
	local gridsize, units, _, _ = getImageSettings()
	local closeTokens = {}
	
	local r = length * gridsize / units
	local w = width * gridsize / units / 2

	azimuthalAngle = math.rad((90-azimuthalAngleDeg)%360)
	local polarAngle = math.rad(90-polarAngleDeg)
	
	-- Find endpoint of cylinder
	local cylinderEndX = originX + r * math.cos(azimuthalAngle) * math.sin(polarAngle)
	local cylinderEndY = originY - r * math.sin(azimuthalAngle) * math.sin(polarAngle)
	local cylinderEndZ = originZ + r * math.cos(polarAngle)
	local deltaCylX = cylinderEndX-originX
	local deltaCylY = cylinderEndY-originY
	local deltaCylZ = cylinderEndZ-originZ

	
	for _,ctNode in pairs(CombatManager.getCombatantNodes()) do
		targetToken = CombatManager.getTokenFromCT(ctNode)
		if targetToken then

			local overlapsLine = false

			-- Get closest point on line to the target, then the closest point on the target to that point.  Then see if within the line.
			local tx,ty,tz = getCoordinatesOfItem(targetToken)
			local cpx, cpy, cpz, bBeyondLine = MathFunctions.closestPointOnLine(tx, ty, tz, originX, originY, originZ, cylinderEndX, cylinderEndY, cylinderEndZ)
			if not bBeyondLine then
				local targetX, targetY, targetZ = getClosestPositionToReference(targetToken, cpx, cpy, cpz)

				-- Get deltas of test point to the end points of the cylinder
				local deltaStartX = targetX-originX
				local deltaStartY = targetY-originY
				local deltaStartZ = targetZ-originZ
				local deltaEndX = targetX-cylinderEndX
				local deltaEndY = targetY-cylinderEndY
				local deltaEndZ = targetZ-cylinderEndZ

				-- Check that target lies between the planes of the two circular facets of the cylinder
				if (MathFunctions.dotProduct(deltaStartX, deltaStartY, deltaStartZ, deltaCylX, deltaCylY, deltaCylZ) >= 0) and (MathFunctions.dotProduct(deltaEndX, deltaEndY, deltaEndZ, deltaCylX, deltaCylY, deltaCylZ) <= 0) then

					-- Check that target is inside of the curved surface of the cylinder
					local crossX, crossY, crossZ = MathFunctions.crossProduct(deltaStartX, deltaStartY, deltaStartZ, deltaCylX, deltaCylY, deltaCylZ)
					local crossMag = MathFunctions.magnitude(crossX, crossY, crossZ)
					local cylMag = MathFunctions.magnitude(deltaCylX, deltaCylY, deltaCylZ)
					if crossMag / cylMag <= w then
						overlapsLine = true
					end
				end

				if overlapsLine or lineIntersectsToken(targetToken, originX, originY, originZ, cylinderEndX, cylinderEndY, cylinderEndZ) then
					table.insert(closeTokens, targetToken)
				end
			end
		end
	end

	return closeTokens
end

function getTokensWithinCone(originX, originY, originZ, coneDistance, vertexAngleDeg, azimuthalAngleDeg, polarAngleDeg)
	local gridsize, units, _, _ = getImageSettings()
	local closeTokens = {}

	local cd = coneDistance * gridsize / units

	-- Y Axis is flipped plus we want 0 to be north, so translate angle before converting it
	local baseAzimuthalAngle = math.rad((270+azimuthalAngleDeg)%360)

	-- Similar for polar (0 is straight up, but want the function to assume 0 is flat)
	local polarAngle = math.rad(90-polarAngleDeg)
	local halfVertex = math.rad(vertexAngleDeg)/2

	local centerLineEndX = originX + cd * math.cos(math.rad((90-azimuthalAngleDeg)%360)) * math.sin(polarAngle)
	local centerLineEndY = originY - cd * math.sin(math.rad((90-azimuthalAngleDeg)%360)) * math.sin(polarAngle)
	local centerLineEndZ = originZ + cd * math.cos(polarAngle)

	for _,ctNode in pairs(CombatManager.getCombatantNodes()) do
		targetToken = CombatManager.getTokenFromCT(ctNode)
		if targetToken then
			local testX, testY, testZ = getClosestPositionToReference(targetToken, centerLineEndX, centerLineEndY, centerLineEndZ)
			local cpx, cpy, cpz, bBeyondLine = MathFunctions.closestPointOnLine(testX, testY, testZ, originX, originY, originZ, centerLineEndX, centerLineEndY, centerLineEndZ)

			if not bBeyondLine then
				local distanceFromApex = MathFunctions.magnitude(cpx - originX, cpy - originY, cpz - originZ)
				local radiusAtClosestPoint = distanceFromApex * math.tan(halfVertex)
				local distance = MathFunctions.magnitude(testX-cpx, testY-cpy, testZ-cpz)

				if (distance <= radiusAtClosestPoint) then
					table.insert(closeTokens, targetToken)
				end
			end
		end
	end

	return closeTokens
end

function lineIntersectsToken(targetToken, startX, startY, startZ, endX, endY, endZ)
	local tokenMinX, tokenMaxX, tokenMinY, tokenMaxY, tokenMinZ, tokenMaxZ = getTokenBounds(targetToken)

	-- If the line ends before the token or starts after the token, it doesn't intersect
	if (endX < tokenMinX and startX < tokenMinX) or (endX > tokenMaxX and startX > tokenMaxX) or 
		(endY < tokenMinY and startY < tokenMinY) or (endY > tokenMaxY and startY > tokenMaxY) or 
		(endZ < tokenMinZ and startZ < tokenMinZ) or (endZ > tokenMaxZ and startZ > tokenMaxZ) then
		return false
	end

	-- If the line starts or ends inside the token, it intersects it
	if (startX > tokenMinX and startX < tokenMaxX and
		startY > tokenMinY and startY < tokenMaxY and
		startZ > tokenMinZ and startZ < tokenMaxZ) or
	   (endX > tokenMinX and endX < tokenMaxX and
		endY > tokenMinY and endY < tokenMaxY and
		endZ > tokenMinZ and endZ < tokenMaxZ)  then
			return true
	end

	local dx = endX-startX
	local dy = endY-startY
	local dz = endZ-startZ

	return lineHit(startX-tokenMinX, endX-tokenMinX, startX, startY, startZ, dx, dy, dz, tokenMinX, tokenMaxX, tokenMinY, tokenMaxY, tokenMinZ, tokenMaxZ, 1)
		or lineHit(startY-tokenMinY, endY-tokenMinY, startX, startY, startZ, dx, dy, dztokenMinX, tokenMaxX, tokenMinY, tokenMaxY, tokenMinZ, tokenMaxZ, 2)
		or lineHit(startZ-tokenMinZ, endZ-tokenMinZ, startX, startY, startZ, dx, dy, dztokenMinX, tokenMaxX, tokenMinY, tokenMaxY, tokenMinZ, tokenMaxZ, 3)
		or lineHit(startX-tokenMaxX, endX-tokenMaxX, startX, startY, startZ, dx, dy, dztokenMinX, tokenMaxX, tokenMinY, tokenMaxY, tokenMinZ, tokenMaxZ, 1)
		or lineHit(startY-tokenMaxY, endY-tokenMaxY, startX, startY, startZ, dx, dy, dztokenMinX, tokenMaxX, tokenMinY, tokenMaxY, tokenMinZ, tokenMaxZ, 2)
		or lineHit(startZ-tokenMaxZ, endZ-tokenMaxZ, startX, startY, startZ, dx, dy, dztokenMinX, tokenMaxX, tokenMinY, tokenMaxY, tokenMinZ, tokenMaxZ, 3)
end

function lineHit(distance1, distance2, startX, startY, startZ, dx, dy, dz, tokenMinX, tokenMaxX, tokenMinY, tokenMaxY, tokenMinZ, tokenMaxZ, face)
	if ((distance1 * distance2) >= 0) then
		return nil, nil, nil
	end

	if (distance1 == distance2) then
		return nil, nil, nil
	end

	local ratio = distance1/(distance1-distance2)
	local hitX = startX + dx * ratio
	local hitY = startY + dy * ratio
	local hitZ = startZ + dz * ratio

	if (face==1 and hitZ > tokenMinZ and hitZ < tokenMaxZ and hitY > tokenMinY and hitY < tokenMaxY) then
		return true
	end
	if (face==2 and hitZ > tokenMinZ and hitZ < tokenMaxZ and hitX > tokenMinX and hitX < tokenMaxX) then
		return true
	end
	if (face==3 and hitX > tokenMinX and hitX < tokenMaxX and hitY > tokenMinY and hitY < tokenMaxY) then
		return true
	end

	return false
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

	return getClosestPositionToReference(token1, x, y, z)
end

-- Get the bounding cube for a token (min x, max x, min y, max y, min z, max z) - object is centered in the X/Y plane but at the bottom of the Z plane
function getTokenBounds(token)
	local ctToken = CombatManager.getCTFromToken(token)
	if not ctToken then
		return 0,0,0,0,0,0
	end
	
	local gridsize, units, _, _ = getImageSettings()
	local centerPosX, centerPosY, bottomPosZ = getCoordinatesOfItem(token)

--	local nSpace = ActorCommonManager.getSpaceReach(ctToken)
	local nSpace = DB.getValue(ctToken, "space")
--Debug.console("Midpoint = " .. centerPosX .. "," .. centerPosY .. "," .. bottomPosZ .. " / " .. nSpace)
--Debug.console(token.getName() .. ": " .. nSpace)
	if nil == nSpace then
		nSpace = units
	end

	local nHalfSpace = nSpace/2 * gridsize / units
	local minPosX, minPosY, minPosZ, maxPosX, maxPosY, maxPosZ
	minPosX = centerPosX-nHalfSpace
	minPosY = centerPosY-nHalfSpace
	minPosZ = bottomPosZ
	maxPosX = centerPosX+nHalfSpace
	maxPosY = centerPosY+nHalfSpace
	maxPosZ = bottomPosZ+nHalfSpace*2

--Debug.console("Bounds = " .. minPosX .. "," .. maxPosX .. "," .. minPosY.. "," .. maxPosY.. "," .. minPosZ.. "," .. maxPosZ)
	return minPosX, maxPosX, minPosY, maxPosY, minPosZ, maxPosZ
end

-- Get the closest position of token 1 (center of the cube contained by token 1 which is closest
-- along a straight line to the given reference coordinates.  It's not really the closest position, but the center
-- of the square in a grid that is closest, with the grid defined by the size of the token and centered on the token.
function getClosestPositionToReference(token, referenceX, referenceY, referenceZ)
	local midX, midY, midZ
	local closestX, closestY, closestZ, minPosX, maxPosX, minPosY, maxPosY, minPosZ, maxPosZ
	local gridsize, units, _, _ = getImageSettings()

	if token.getContainerNode then
		midX, midY = token.getPosition()
		ctNode = CombatManager.getCTFromToken(token)
		if ctNode then
			midZ = TokenHeight.getHeight(ctNode) * gridsize / units

			local nSpace = DB.getValue(ctNode, "space")
			if nSpace == nil then
				nSpace = units
				local tokenName = "Unknown Token Name"
				local ctNodeName = "Unknown CT Node Name"
				if token.getName then
					tokenName = token.getName()
				end
				if ctNode.getName then
					ctNodeName = ctNode.getName()
				end
				Debug.console("Missing module for " .. tokenName .. "/" .. ctNodeName .. ". Remove from map and re-add.")
			end

			local nGridSize = math.floor(nSpace / units)
			local nHalfSquare = gridsize / 2
			
			-- Form the grid
			minPosX, maxPosX, minPosY, maxPosY, minPosZ, maxPosZ = getTokenBounds(token)

			-- Get the real closest point and slide to the middle of the square
			closestX=MathFunctions.clampAndAdjust(referenceX,minPosX,maxPosX,nHalfSquare)
			closestY=MathFunctions.clampAndAdjust(referenceY,minPosY,maxPosY,nHalfSquare)
			closestZ=MathFunctions.clampAndAdjust(referenceZ,minPosZ,maxPosZ,nHalfSquare)
		end
	else
		closestX, closestY = token['x'], token['y']  
		closestZ = 0
	end


		
	return closestX, closestY, closestZ
end

-- Distance between two locations in 3 dimensions.  
function distanceBetween(startX,startY,startZ,endX,endY,endZ,bSquare)
--Debug.console("distanceBetween " .. startX .. "," .. startY .. "," .. startZ .. " and " ..  endX .. "," .. endY .. "," .. endZ .. ": " .. (bSquare and 'true' or 'false'))
	local gridsize, units, suffix, diagmult = getImageSettings()

	local totalDistance = 0
	local dx = math.abs(endX-startX)
	local dy = math.abs(endY-startY)
	local dz = math.abs(endZ-startZ)

--Debug.console("gridsize " .. gridsize .. ", units " .. units .. ", suffix " .. suffix .. ", diagmult " ..  diagmult)
	
	if bSquare then
		local hyp = MathFunctions.magnitude(dx,dy,dz)
		totalDistance = (hyp / gridsize)* units * 2
	else
		if diagmult == 1 then
			-- Just a max of each dimension
			local longestLeg = math.max(dx, dy, dz)		
--Debug.console("longestLeg = " .. longestLeg)
			totalDistance = math.ceil(longestLeg/gridsize)*units
		elseif diagmult == 0 then
			-- Get 3D distance directly
			local hyp = MathFunctions.magnitude(dx,dy,dz)
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
--Debug.console("OMP")
--Debug.chat("rhagelstrom: ", pixellength, pointertype, startX, startY, endX, endY);
	-- Modified by SilentRuin to better integrate with the superclasses and optimize
	local retStr = nil -- we will not do anything with label but if someone ever does we can handle the that code first
	if super and super.onMeasurePointer then
		retStr = super.onMeasurePointer(pixellength, pointertype, startX, startY, endX, endY)
	end

	local gridsize, units, suffix, diagmult = getImageSettings()
	local heightOrigin = 0
	local heightTarget = 0

	local ctNodeOrigin, ctNodeTarget = getCTNodeAt(startX, startY, endX, endY)
	if ctNodeOrigin and ctNodeTarget then
		heightOrigin = TokenHeight.getHeight(ctNodeOrigin)
		heightTarget = TokenHeight.getHeight(ctNodeTarget)
		local originSpace = 0
		local targetSpace = 0
--		if TokenManager.getTokenSpace then
			originSpace = DB.getValue(ctNodeOrigin, "space")
			targetSpace = DB.getValue(ctNodeTarget, "space")
--		end
--Debug.console("Space = " .. originSpace .. "," .. targetSpace)
		
		if not (gridsize and units and suffix and diagmult) then 
--Debug.chat("OMP1: Returning " .. retStr)
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
--local tokenSource = CombatManager.getTokenFromCT(ctNodeOrigin)
--local tokenTarget = CombatManager.getTokenFromCT(ctNodeTarget)
--Debug.console("distance(img) = " .. distance)
--local gdb = TokenHeight.getDistanceBetween(tokenSource, tokenTarget)
--Debug.console("distance(tkn) = " .. gdb)
--if super and super.onMeasurePointer then
--Debug.console("OMP orig = " .. super.onMeasurePointer(pixellength, pointertype, startX, startY, endX, endY))
--end

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
--		Debug.console("OMP: " .. ctNodeTarget.getName() .. " is " .. distance .. ": " .. startX .. "," .. startY .. "," .. startZ .. ": " .. endX .. "," .. endY .. "," .. endZ .. ": " .. retStr) 
	end
	return retStr
end

function getCTNodeAt_orig(startX, startY, endX, endY)
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
		local z = TokenHeight.getHeight(ctNode)
		local bExact = true
		local sizeMultiplier = 0

		-- bmos / SoxMax 
		local nSpaceNew = TokenManager.getTokenSpace(ctNode)
		local nSpace = DB.getValue(ctNode, "space")
		local nSpaceReach = ActorCommonManager.getSpaceReach(ctNode)

		if nil == nSpace then
			nSpace = 1
		end

		if nSpace then
			sizeMultiplier = math.max(0,((nSpace / units) - 1)  * 0.5)
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

function getCTNodeAt(startX, startY, endX, endY)
	local _, units, _, _ = getImageSettings()
	local startCTnode = nil
	local endCTnode = nil
	local startToken = nil
	local endToken = nil

	local startTokens = getTokensWithinSquare(startX, startY, units/4)
	if startTokens and startTokens[1] then
		startToken = startTokens[1]
		startCTnode = CombatManager.getCTFromToken(startToken)
	end
	
	local endTokens = getTokensWithinSquare(endX, endY, units/4)		
	if endTokens and endTokens[1] then
		endToken = endTokens[1]
		endCTnode = CombatManager.getCTFromToken(endToken)
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

	if super and super.onDrop then
		return super.onDrop(x, y, draginfo)
	end
end
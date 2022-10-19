---------------------------
-- CUSTOM MATH FUNCTIONS --
---------------------------
function magnitude(p1, p2, p3)
	return math.sqrt(p1^2 + p2^2 + p3^2)
end

function crossProduct(a1, a2, a3, b1, b2, b3)
	local r1 = a2*b3 - a3*b2
	local r2 = a3*b1 - a1*b3
	local r3 = a1*b2 - a2*b1

	return r1, r2, r3
end

function dotProduct(a1, a2, a3, b1, b2, b3)
	return a1*b1 + a2*b2 + a3*b3
end

-- Returns the closest point on line (start-end) to point p
function closestPointOnLine(qx, qy, qz, startX, startY, startZ, endX, endY, endZ)
	local ux = endX - startX
	local uy = endY - startY
	local uz = endZ - startZ

	local pqx = qx - startX
	local pqy = qy - startY
	local pqz = qz - startZ

	local s = dotProduct(pqx, pqy, pqz, ux, uy, uz) / dotProduct(ux, uy, uz, ux, uy, uz)
	
	-- Clamp to be within line segment
	local bClamped = false
	if s < 0 then
		s = 0
		bClamped = true
	elseif s > 1 then
		s = 1
		bClamped = true
	end

	local usx = ux * s
	local usy = uy * s
	local usz = uz * s
	local px = startX + usx
	local py = startY + usy
	local pz = startZ + usz

	return px, py, pz, bClamped
end

-- Return coordinates of a point a distance d from (x1, y1, z2) in the direction of (x2, y2, z2)
function extrapolatePointOnLine(x1, y1, z1, x2, y2, z2, d)
	-- P1 P2 Vector
	local vx = x2-x1
	local vy = y2-y1
	local vz = z2-z1

	-- Distance from point 1 to point 2
	local normalizedDistance = math.sqrt(((endX-originX)^2)+((endY-originY)^2)+((endZ-originZ)^2))

	-- Normalize the vector
	vx = vx / normalizedDistance
	vy = vy / normalizedDistance
	vz = vz / normalizedDistance

	local extX = x1 + d * vx
	local extY = y1 + d * vy
	local extZ = z1 + d * vz

	return extX, extY, extZ

end

-- Check for overlap between two cubes represented by min and max coordinates in each dimension
function cubesOverlap(cube1MinX, cube1MaxX, cube1MinY, cube1MaxY, cube1MinZ, cube1MaxZ, cube2MinX, cube2MaxX, cube2MinY, cube2MaxY, cube2MinZ, cube2MaxZ)
	return (cube1MinX < cube2MaxX) and (cube1MaxX > cube2MinX) and (cube1MinY < cube2MaxY) and (cube1MaxY > cube2MinY) and (cube1MinZ < cube2MaxZ) and (cube1MaxZ > cube2MinZ)
end

-- Check for overlap between two squares represented by min and max coordinates in each dimension
function squaresOverlap(cube1MinX, cube1MaxX, cube1MinY, cube1MaxY, cube2MinX, cube2MaxX, cube2MinY, cube2MaxY)
	return (cube1MinX < cube2MaxX) and (cube1MaxX > cube2MinX) and (cube1MinY < cube2MaxY) and (cube1MaxY > cube2MinY)
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
mysql = exports.mysql

armoredCars = { [427]=true, [528]=true, [432]=true, [601]=true, [428]=true } -- Enforcer, FBI Truck, Rhino, SWAT Tank, Securicar
governmentVehicle = { [416]=true, [427]=true, [490]=true, [528]=true, [407]=true, [544]=true, [523]=true, [596]=true, [597]=true, [598]=true, [599]=true, [601]=true, [428]=true }
factionsThatPayForRepair = { [1]=true, [2]=true, [3]=true, [4]=true, [5]=true, [47]=true, [59]=true, [50]=true }

function createSpray(thePlayer, commandName)
	if (exports.integration:isPlayerAdmin(thePlayer)) then
		local x, y, z = getElementPosition(thePlayer)
		local interior = getElementInterior(thePlayer)
		local dimension = getElementDimension(thePlayer)

		local id = dbExec(mysql:getConnection(), "INSERT INTO paynspray SET x='"  .. (x) .. "', y='" .. (y) .. "', z='" .. (z) .. "', interior='" .. (interior) .. "', dimension='" .. (dimension) .. "'")

		dbQuery(
			function(qh)
				local res, rows, err = dbPoll(qh, 0)
				if rows > 0 then
					local id = res[1]['id']
					if (id) then
						local shape = createColSphere(x, y, z, 5)
						exports.pool:allocateElement(shape)
						setElementInterior(shape, interior)
						setElementDimension(shape, dimension)
						setElementData(shape, "dbid", id, false)

						local sprayblip = createBlip(x, y, z, 63, 2, 255, 0, 0, 255, 0, 300)
						setElementData(sprayblip, "dbid", id, false)
						exports.pool:allocateElement(sprayblip)

						outputChatBox("Pay 'N Spray spawned with ID #" .. id .. ".", thePlayer, 0, 255, 0)
					else
						outputChatBox("Error 200000 - Report on mantis.", thePlayer, 255, 0, 0)
					end
				end
			end,
		mysql:getConnection(), "SELECT * FROM paynspray WHERE id = LAST_INSERT_ID()")
	end
end
addCommandHandler("makepaynspray", createSpray, false, false)

function loadAllSprays(res)
	local count = 0

	-- Set Garages Open
	setGarageOpen(8, true)
	setGarageOpen(11, true)
	setGarageOpen(12, true)
	setGarageOpen(19, true)
	setGarageOpen(27, true)

	dbQuery(
		function(qh)
			local res, rows, err = dbPoll(qh, 0)
			if rows > 0 then
				for index, row in ipairs(res) do
					local id = tonumber(row["id"])

					local x = tonumber(row["x"])
					local y = tonumber(row["y"])
					local z = tonumber(row["z"])

					local interior = tonumber(row["interior"])
					local dimension = tonumber(row["dimension"])

					local sprayblip = createBlip(x, y, z, 63, 2, 255, 0, 0, 255, 0, 300)
					setElementData(sprayblip, "dbid", id, false)
					exports.pool:allocateElement(sprayblip)

					local shape = createColSphere(x, y, z, 5)
					exports.pool:allocateElement(shape)
					setElementInterior(shape, interior)
					setElementDimension(shape, dimension)
					setElementData(shape, "dbid", id, false)
				end
			end
		end,
	mysql:getConnection(), "SELECT id, x, y, z, interior, dimension FROM paynspray")
end
addEventHandler("onResourceStart", getResourceRootElement(), loadAllSprays)

function getNearbySprays(thePlayer, commandName)
	if (exports.integration:isPlayerTrialAdmin(thePlayer)) then
		local posX, posY, posZ = getElementPosition(thePlayer)
		outputChatBox("Nearby Pay 'N Sprays:", thePlayer, 255, 126, 0)
		local count = 0

		for k, theColshape in ipairs(getElementsByType("colshape", getResourceRootElement())) do
			local x, y = getElementPosition(theColshape)
			local distance = getDistanceBetweenPoints2D(posX, posY, x, y)
			if (distance<=10) then
				local dbid = getElementData(theColshape, "dbid")
				outputChatBox("   Pay 'N Spray with ID " .. dbid .. ".", thePlayer, 255, 126, 0)
				count = count + 1
			end
		end

		if (count==0) then
			outputChatBox("   None.", thePlayer, 255, 126, 0)
		end
	end
end
addCommandHandler("nearbypaynsprays", getNearbySprays, false, false)

function delSpray(thePlayer, commandName)
	if (exports.integration:isPlayerAdmin(thePlayer)) then
		local colShape = nil

		for key, value in ipairs(getElementsByType("colshape", getResourceRootElement())) do
			if (isElementWithinColShape(thePlayer, value)) then
				colShape = value
			end
		end

		if (colShape) then
			local id = getElementData(colShape, "dbid")
			dbExec(mysql:getConnection(), "DELETE FROM paynspray WHERE id='" .. (id) .. "'")

			outputChatBox("Pay 'N Spray #" .. id .. " deleted.", thePlayer)
			destroyElement(colShape)

			for key, value in ipairs(getElementsByType("blip", getResourceRootElement())) do
				if getElementData(value, "dbid") == id then
					destroyElement(value)
				end
			end
		else
			outputChatBox("You are not in a Pay 'N Spray.", thePlayer, 255, 0, 0)
		end
	end
end
addCommandHandler("delpaynspray", delSpray, false, false)

function shapeHit(element, matchingDimension)
	if (isElement(element)) and (getElementType(element)=="vehicle") and (matchingDimension) then
		local thePlayer = getVehicleOccupant(element)

		if (thePlayer) then
			local factionPlayer = getElementData(thePlayer, "faction")
			local factionVehicle = getElementData(element, "faction")

			local vehicleHealth = getElementHealth(element)

			if (vehicleHealth >= 1000) then
				outputChatBox("Tamir garajına hoş geldin. " .. exports.global:getVehicleName(element) .. " iyi gözüküyor. Bir sorun yaşarsan yine gel!", thePlayer, 255, 194, 14)
			else
				local playerMoney = exports.global:getMoney(thePlayer, true)
				if playerMoney == 0 and not factionPlayer == factionVehicle and not factionsThatPayForRepair[factionPlayer] and not factionsThatPayForRepair[factionVehicle] then
					outputChatBox("Bu aracın üzerinde çalışamayız, üzgünüz.", thePlayer, 255, 0, 0)
				else
				--	outputChatBox("Welcome to the repair garage. Please wait while we work on your " .. exports.global:getVehicleName(element) .. ".", thePlayer, 255, 194, 14)
					setTimer(spraySoundEffect, 500, 5, thePlayer, source)
					setTimer(sprayEffect, 1000, 1, element, thePlayer, source, true)
				end

			end
		end
	end
end
addEventHandler("onColShapeHit", getResourceRootElement(), shapeHit)

function spraySoundEffect(thePlayer, shape)
	if (isElementWithinColShape(thePlayer, shape)) then
		playSoundFrontEnd(thePlayer, 46)
	end
end

local costDamageRatio = 1.25

function sprayEffect(vehicle, thePlayer, shape, returnBool, newPrice)
	if ((not returnBool) or isElementWithinColShape(thePlayer, shape)) then

		local completefix = false
		local vehicleHealth = getElementHealth(vehicle)
		local toFix = 0

		local damage = 1000 - vehicleHealth
		damage = math.floor(damage)
		local estimatedCosts = math.floor(damage * costDamageRatio)

		local factionPlayer = getElementData(thePlayer, "faction")
		local factionVehicle = getElementData(vehicle, "faction")
		if not factionPlayer == factionVehicle or not factionsThatPayForRepair[factionPlayer] or not factionsThatPayForRepair[factionVehicle] then
			completefix = false
			local playerMoney = exports.global:getMoney(thePlayer, true)
			if (estimatedCosts > playerMoney) then
				toFix = playerMoney / costDamageRatio
			else
				completefix = true
				toFix = damage
			end

			estimatedCosts =  math.floor ( toFix * costDamageRatio )



			if getElementData(vehicle, "dbid") > 0 then
				local vehicleCarshopPrice = tonumber(getElementData(vehicle, "carshop:cost") or 30000)
				--outputDebugString(vehicleCarshopPrice)
				estimatedCosts = math.floor ( ( vehicleCarshopPrice / 25 ) * ( damage / 1000 ) )
			else
				outputChatBox("OOC: (( This is a temporary vehicle. Repair is free. ))", thePlayer, 255, 194, 14)
				estimatedCosts = 0
			end

			if returnBool then
				setElementFrozen(vehicle, true)
				triggerClientEvent(thePlayer, "paynspray:Invoice", thePlayer, estimatedCosts)
				return
			end
			setElementFrozen(vehicle, false)

			--insurance, anumaz 2015-02-04
			local insured = getElementData(vehicle, "insurance:faction") or 0
			if insured > 0 then
				local insurerElement = exports.pool:getElement("team", insured)
				exports.global:takeMoney(insurerElement, estimatedCosts, true)
				outputChatBox("BILL: Your insurance company has been sent a bill of $".. exports.global:formatMoney(estimatedCosts) ..".", thePlayer, 255, 194, 14)
				triggerEvent("insurance:claims", root, getElementData(vehicle, "dbid"), estimatedCosts)

				exports.global:giveMoney(exports.pool:getElement("team", 4), estimatedCosts, true) -- to Rapid towing
			else
				exports.global:takeMoney(thePlayer, estimatedCosts, true)
				outputChatBox("BILL: Car Repair - $".. exports.global:formatMoney(estimatedCosts) ..".", thePlayer, 255, 194, 14)

				exports.global:giveMoney(exports.pool:getElement("team", 4), estimatedCosts, true) -- to Rapid towing
			end
			-- end of insurance


		else
			completefix = true
			local theTeam = getPlayerTeam(thePlayer)
			if exports.global:takeMoney(theTeam, estimatedCosts, true) then
				outputChatBox("The bill will be sent to your employer.", thePlayer, 255, 194, 14)
				dbExec(mysql:getConnection(), "INSERT INTO wiretransfers (`from`, `to`, `amount`, `reason`, `type`) VALUES (" .. (( -getElementData( theTeam, "id" ) )) .. ", " .. (getElementData(thePlayer, "dbid")) .. ", " .. (estimatedCosts) .. ", 'Repair', 10)" )
			end
		end

		--[[exports.global:giveMoney(getTeamFromName("326 Enterprises"), estimatedCosts)]]

		if (completefix) then
			fixVehicle(vehicle)
			for i = 0, 5 do
				setVehicleDoorState(vehicle, i, 0)
			end
		else
			outputChatBox("As you can't afford a full vehicle fix, we patched up what you could afford.", thePlayer, 255, 194, 14)
			setElementHealth(vehicle, vehicleHealth + toFix)
		end

		if armoredCars[ getElementModel( vehicle ) ] then
			setVehicleDamageProof(vehicle, true)
		else
			setVehicleDamageProof(vehicle, false)
		end
		if (getElementData(vehicle, "Impounded") == 0) then
			setElementData(vehicle, "enginebroke", 0, false)
		end

		exports.logs:dbLog(thePlayer, 6, {  vehicle }, "REPAIR PAYNSPRAY")
	else
		outputChatBox("You forgot to wait for your repair!", thePlayer, 255, 0, 0)
	end
end
addEvent("pns:PayInvoice", true)
addEventHandler("pns:PayInvoice", root, sprayEffect)

function pnsOnEnter(player, seat)
	if seat == 0 then
		for k, v in ipairs(getElementsByType("colshape", getResourceRootElement())) do
			if isElementWithinColShape(source, v) then
				triggerEvent( "onColShapeHit", v, source, getElementDimension(v) == getElementDimension(source))
			end
		end
	end
end
addEventHandler("onVehicleEnter", getRootElement(), pnsOnEnter)

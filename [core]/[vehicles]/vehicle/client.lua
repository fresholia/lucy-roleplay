addEvent("vehicleEngineSound", true)
addEventHandler("vehicleEngineSound", root,
	function(src)
		playSound("components/sound/"..src)
	end
)

local vt = getVehicleType
function getVehicleType( ... )
    local ret = vt( ... )
    if ret == "" then
        return "Trailer"
    end
    return ret
end

local disabledType = {
    ["BMX"] = true,
}
local oldx, oldy, oldz = 0,0,0
local oldOdometerFloor = 0
setTimer(
    function()
        local veh = getPedOccupiedVehicle(localPlayer)
        if veh then
            local seat = getPedOccupiedVehicleSeat(localPlayer)
            if getElementHealth(veh) > 300 and seat == 0 and not disabledType[getVehicleType(veh)] then
                if getElementData(veh, "engine") then
                    local newx, newy, newz = getElementPosition(veh)
                    local addKM = getDistanceBetweenPoints3D(oldx, oldy, oldz, newx, newy, newz) / 500
                    local oldOdometer = getElementData(veh, "odometer") or 0
                    oldx, oldy, oldz = newx, newy, newz
                    if addKM * 500 > 1 then
                        if getVehicleType(veh) ~= "BMX" then
                            local newOdometer = getElementData(veh, "odometer") or 0
                            if math.floor(newOdometer) > oldOdometerFloor then
                                local oldFuel = getElementData(veh, "fuel")
                                oldFuel = oldFuel - 1
                                if oldFuel <= 0 then
                                    if getElementData(veh, "engine") then
                                        setElementData(veh, "engine", false)
                                    end
                                    if getVehicleEngineState(veh) then
                                        setVehicleEngineState(veh, false)
                                    end
                                end
                                setElementData(veh, "fuel", oldFuel)
                                oldOdometerFloor = math.floor(newOdometer)
                            end
                        end
                    end
                end
            end
        end
    end, 500, 0
)

local vControlGUI = { }
local controllingVehicle = nil

local vTimers = { }

function openVehicleDoorGUI( vehicleElement )
    if vControlGUI["main"] then
        closeVehicleGUI()
        return
    end
    
    if not vehicleElement then
        controllingVehicle = getPedOccupiedVehicle ( getLocalPlayer() )
    else
        controllingVehicle = vehicleElement
        if controllingVehicle ~= getPedOccupiedVehicle( getLocalPlayer() ) then
            local vehicle1x, vehicle1y, vehicle1z = getElementPosition ( controllingVehicle )
            local player1x, player1y, player1z = getElementPosition ( getLocalPlayer() )
            
            if getDistanceBetweenPoints3D ( vehicle1x, vehicle1y, vehicle1z, player1x, player1y, player1z ) > 5 then
                return
            end
        end
    end
        
    local playerSeat = -1
    for checkingSeat = 0, ( getVehicleMaxPassengers ( controllingVehicle ) or 0 ) do
        if getVehicleOccupant( controllingVehicle, checkingSeat ) == localPlayer then
            playerSeat = checkingSeat
            break
        end
    end
    
    local doors = getDoorsFor(getElementModel(controllingVehicle), playerSeat)
    if #doors == 0 then
        return
    end

    local options = 0
    local guiPos = 30
    vControlGUI["main"] = guiCreateWindow(700,236,272,288,"Vehicle Control",false)  
    for index, doorEntry in ipairs(doors) do
        vControlGUI["scroll"..index] = guiCreateScrollBar(24,guiPos + 17,225,17,true,false,vControlGUI["main"])
        vControlGUI["label"..index] = guiCreateLabel(30,guiPos,135,15,doorEntry[1],false,vControlGUI["main"])
        guiSetFont(vControlGUI["label"..index] ,"default-bold-small")
        setElementData(vControlGUI["scroll"..index], "vehicle:doorcontrol:panel", doorEntry[2], false)
        addEventHandler ( "onClientGUIScroll",vControlGUI["scroll"..index], startTimerUpdateServerSide, false )
        guiPos = guiPos + 40
        
        local currentDoorPos = getVehicleDoorOpenRatio ( controllingVehicle, doorEntry[2] )
        if currentDoorPos then
            currentDoorPos = currentDoorPos * 100
            guiScrollBarSetScrollPosition (vControlGUI["scroll"..index], currentDoorPos )
        end 
    end
        
    guiSetSize(vControlGUI["main"],272,guiPos+40, false)
    vControlGUI["close"] = guiCreateButton(23,guiPos,230,14,"Close",false, vControlGUI["main"])
    addEventHandler ( "onClientGUIClick", vControlGUI["close"], closeVehicleGUI, false )
end
addCommandHandler("doors", openVehicleDoorGUI)

function closeVehicleGUI()
    if vControlGUI["main"] then
        destroyElement(vControlGUI["main"] )
        vControlGUI = { }
        controllingVehicle = nil
    end
end
addEventHandler("onClientPlayerVehicleExit", getLocalPlayer(), closeVehicleGUI)

function startTimerUpdateServerSide(theScrollBar)
    if vControlGUI["main"] then
        local door = getElementData(theScrollBar, "vehicle:doorcontrol:panel")
        if not door then
            return -- Not our element
        end
        
        if vTimers[theScrollBar] then
            return -- Already running a timer
        end
        
        vTimers[theScrollBar] = setTimer(updateServerSide, 400, 1, theScrollBar)
    end
end

function updateServerSide(theScrollBar, state)
    if vControlGUI["main"] then -- and state == "up" then
        
        local door = getElementData(theScrollBar, "vehicle:doorcontrol:panel")
        if not door then
            return
        end
        
        vehicle1x, vehicle1y, vehicle1z = getElementPosition ( controllingVehicle )
        player1x, player1y, player1z = getElementPosition ( getLocalPlayer() )
        if not (getPedOccupiedVehicle ( getLocalPlayer() ) == controllingVehicle) and not (getDistanceBetweenPoints3D ( vehicle1x, vehicle1y, vehicle1z, player1x, player1y, player1z ) < 5) then
            closeVehicleGUI()
            return
        end
        
        if (isVehicleLocked(controllingVehicle)) then
            return
        end
        
        
        local position = guiScrollBarGetScrollPosition(theScrollBar)
        triggerServerEvent("vehicle:control:doors", controllingVehicle, door, position)
        
        vTimers[theScrollBar] = nil
    end
end

local doorTypeRotation = {
    [1] = {-72, 0, 0}, -- scissor
    [2] = {-35, 0, -60} -- butterfly
}


local doorIDComponentTable = {
    [2] = "door_lf_dummy",
    [3] = "door_rf_dummy",
    [4] = "door_lr_dummy",
    [5] = "door_rr_dummy"
                        }
local vDoorType = {}
addEventHandler('onClientResourceStart', resourceRoot,
    function()
        for i, v in pairs ( getElementsByType("vehicle")) do
            local doorType = getElementData ( v, "vDoorType" )
            if doorType then
                vDoorType[v] = doorType
            end
        end
    end)

local function elementDataChange ( key, oldValue )
    if key == "vDoorType" and getElementType(source) == 'vehicle' then
        local t = getElementData ( source, "vDoorType" )
        if t and doorTypeRotation[t] then
            vDoorType[source] = t
        else
            vDoorType[source] = nil
            for door, dummyName in pairs(doorIDComponentTable) do
                local ratio = getVehicleDoorOpenRatio(source, door)
                setVehicleComponentRotation( source, dummyName, 0, 0, 0 )
                setVehicleDoorOpenRatio(source, door, ratio)
            end
        end
    end
end
addEventHandler ( "onClientElementDataChange", root, elementDataChange )
 
local function preRender ()
    for v, doorType in pairs ( vDoorType ) do
        if isElement(v) then
            if isElementStreamedIn(v) then
                for door, dummyName in pairs ( doorIDComponentTable ) do
                    local ratio = getVehicleDoorOpenRatio(v, door)
                    local rx, ry, rz = unpack(doorTypeRotation[doorType])
                    local rx, ry, rz = rx*ratio, ry*ratio, rz*ratio
                    if string.find(dummyName,"rf") or string.find(dummyName,"rr") then
                        ry, rz = ry*-1, rz*-1
                    end
                    setVehicleComponentRotation ( v, dummyName, rx, ry, rz )
                end
            end
        else
            vDoorType[v] = nil
        end
    end
end
addEventHandler ( "onClientPreRender", root, preRender )

addEventHandler('onClientPlayerVehicleEnter', localPlayer,
    function(vehicle, seat)
        if seat == 0 then
            setVehicleEngineState(vehicle, false)
        end
    end
)

local vehicle = nil
local ax, ay = 0, 0
function requestInventory(button)
    if button=="left" and not getElementData(localPlayer, "exclusiveGUI") then
        if isVehicleLocked(vehicle) and vehicle ~= getPedOccupiedVehicle(localPlayer) then
            triggerServerEvent("onVehicleRemoteAlarm", vehicle)
            outputChatBox("Bu araç kilitli.", 255, 0, 0)
        elseif not exports.global:hasItem(localPlayer, 3, getElementData(vehicle, "dbid")) then
            outputChatBox("Bu aracı aramak için anahtarlara ihtiyacınız var..", 255, 0, 0)
        else
            triggerServerEvent( "openFreakinInventory", localPlayer, vehicle, ax, ay )
            triggerServerEvent("item-system:setVehicleDoorState", vehicle, vehicle, 1)
        end
    end
end

function clickVehicle(button, state, absX, absY, wx, wy, wz, element)
    if getElementData(getLocalPlayer(), "exclusiveGUI") then
        return
    end
    if (element) and (getElementType(element)=="vehicle") and (button=="right") and (state=="down") then
        local x, y, z = getElementPosition(localPlayer)
        if (getDistanceBetweenPoints3D(x, y, z, wx, wy, wz)<=3) then
            ax = absX
            ay = absY
            vehicle = element
            showVehicleMenu(hasRamp)
        end
    end
end
addEventHandler("onClientClick", root, clickVehicle, true)

addEvent("vehicle:rightclick:data", true)
addEventHandler("vehicle:rightclick:data", root, function(...) if vehicle == source then showVehicleMenu(...) end end)

function isNotAllowedV(theVehicle)
    return false
end

function showVehicleMenu(hasRamp)
    local rightclick = exports.rightclick
    --Name
    local vName = exports.global:getVehicleName(vehicle)

    local row = {}
    local rcMenu = rightclick:create(vName)

    local isLocked = isVehicleLocked(vehicle)
    local inCar = ( getPedSimplestTask(localPlayer) == "TASK_SIMPLE_CAR_DRIVE" and getPedOccupiedVehicle(localPlayer) == vehicle ) or false

    if hasVehiclePlates(vehicle) and getElementData(vehicle, "show_plate") ~= 0 then -- Addded no plates support
        row.plate = rightclick:addRow(getVehiclePlateText(vehicle), true)
    end

    if (isVehicleImpounded(vehicle)) then
        local days = getRealTime().yearday-getElementData(vehicle, "Impounded")
        row.impounded = rightclick:addRow("Impounded: "..days.." days", false, true)
    end

    if (hasVehicleWindows(vehicle)) then
        local windowState = isVehicleWindowUp(vehicle, true) and "Up" or "Down"
        row.window = rightclick:addRow("Window: "..windowState, false, true)
    end

    --y = y + lineH

    if ( getPedSimplestTask(localPlayer) == "TASK_SIMPLE_CAR_DRIVE" and getPedOccupiedVehicle(localPlayer) == vehicle ) or exports.global:hasItem(localPlayer, 3, getElementData(vehicle, "dbid")) or (exports["factions"]:isPlayerInFaction(localPlayer, getElementData(vehicle, "faction"))) then

        local lockText
        if isLocked then
            lockText = "Unlock"
        else
            lockText = "Lock"
        end
        row.lock = rightclick:addRow(lockText)
        addEventHandler("onClientGUIClick", row.lock, lockUnlock, false)

        if not isLocked or inCar then --if vehicle is not locked or if player is inside vehicle
            row.inventory = rightclick:addRow("Inventory")
            addEventHandler("onClientGUIClick", row.inventory, requestInventory, false)

            -- Cabriolet (Exciter)
            if isCabriolet(vehicle) then
                row.cabriolet = rightclick:addRow("Toggle Roof")
                addEventHandler("onClientGUIClick", row.cabriolet, cabrioletToggleRoof, false)
            end

            --if hasRamp and getPedOccupiedVehicle(localPlayer) == vehicle then
            --  row.ramp = rightclick:addRow("Toggle Ramp")
            --  addEventHandler("onClientGUIClick", row.ramp, toggleRamp, false)
            --end
        end
    end

    --if not isNotAllowedV(vehicle)  then
        --if not ( getPedSimplestTask(localPlayer) == "TASK_SIMPLE_CAR_DRIVE" ) then
            if getElementData(localPlayer, "job") == 5 then -- Mechanic
            --[[local theTeam = getPlayerTeam(localPlayer)
            local factionType = tonumber(getElementData(theTeam, "type"))
            if factionType == 7 then -- Mechanic Faction / Adams]]
                row.fix = rightclick:addRow("Fix/Upgrade")
                addEventHandler("onClientGUIClick", row.fix, openMechanicWindow, false)
            end
        --end
    --end

    if not isLocked then
        local vx,vy,vz = getElementVelocity(vehicle)
        if vx < 0.05 and vy < 0.05 and vz < 0.05 and not getPedOccupiedVehicle(localPlayer) and not isVehicleLocked(vehicle) then -- completely stopped
            local trailers = { [606] = true, [607] = true, [610] = true, [590] = true, [569] = true, [611] = true, [584] = true, [608] = true, [435] = true, [450] = true, [591] = true }
            if trailers[ getElementModel( vehicle ) ] then
                if exports.global:hasItem(localPlayer, 3, getElementData(vehicle, "dbid")) then
                    row.park = rightclick:addRow("Park")
                    addEventHandler("onClientGUIClick", row.park, parkTrailer, false)
                else
                    local vehicleFactionID = getElementData(vehicle, "faction")
                    if exports["factions"]:hasMemberPermissionTo(localPlayer, vehicleFactionID, "respawn_vehs") then
                        row.park = rightclick:addRow("Park")
                        addEventHandler("onClientGUIClick", row.park, factionParkTrailer, false)
                    else
                        trailerAdminPark = true
                    end
                end
            else
                if exports.global:hasItem(localPlayer, 57) then -- FUEL CAN
                    row.fill = rightclick:addRow("Fill Tank")
                    addEventHandler("onClientGUIClick", row.fill, fillFuelTank, false)
                end
            end
        end
    end

    if (getElementModel(vehicle)==497) or (getElementModel(vehicle)==469) then -- HELICOPTER
        local players = getElementData(vehicle, "players")
        local found = false

        if (players) then
            for key, value in ipairs(players) do
                if (value==localPlayer) then
                    found = true
                end
            end
        end

        if not (found) then
            row.sit = rightclick:addRow("Sit")
            addEventHandler("onClientGUIClick", row.sit, sitInHelicopter, false)
        else
            row.sit = rightclick:addRow("Stand Up")
            addEventHandler("onClientGUIClick", row.sit, unsitInHelicopter, false)
        end
    end

    local entrance = getElementData( vehicle, "entrance" )
    if entrance then
        if not isPedInVehicle(localPlayer) then
            row.enter = rightclick:addRow("Enter Interior")
            addEventHandler("onClientGUIClick", row.enter, enterInterior, false)

            row.knock = rightclick:addRow("Knock on Door")
            addEventHandler("onClientGUIClick", row.knock, knockVehicle, false)
        elseif getElementModel(vehicle) == 435 then
            row.enter = rightclick:addRow("Enter Interior with Vehicle")
            addEventHandler("onClientGUIClick", row.enter, enterInterior, false)
        end
    end

    local seat = -1
    if vehicle == getPedOccupiedVehicle(localPlayer) then
        for i = 0, (getVehicleMaxPassengers(vehicle) or 0) do
            if getVehicleOccupant(vehicle, i) == localPlayer then
                seat = i
                break
            end
        end
    end
    if #getDoorsFor(getElementModel(vehicle), seat) > 0 then -- Now showing this outside of the check because people were abusing it to get away from the alarm.
        row.doorControl = rightclick:addRow("Door Control")
        addEventHandler("onClientGUIClick", row.doorControl, function(button, state) fDoorControl(button, state, isLocked) end, false)
    end

    if not isLocked then
        if (getVehicleType(vehicle) == "Trailer" or getVehicleNameFromModel( 608 ) == getVehicleName( vehicle )) then -- this is a trailer, zomg. But getVehicleType returns "" CLIENT-SIDE. Fine on the server.
            row.handbrake = rightclick:addRow("Handbrake")
            addEventHandler("onClientGUIClick", row.handbrake, handbrakeVehicle, false)
        end

        if (getElementModel(vehicle) == 416) or (getElementModel(vehicle) == 482 and getElementData(vehicle, "faction") == 210) then --Stretcher for ambulance and red rose funeral home.
            row.stretcher = rightclick:addRow("Stretcher")
            addEventHandler("onClientGUIClick", row.stretcher, fStretcher, false)
        elseif(getElementModel(vehicle) == 487 and getElementData(vehicle, "faction") == 2 or getElementModel(vehicle) == 417 and getElementData(vehicle, "faction") == 2) then --air ambulance and SAR heli
            row.stretcher = rightclick:addRow("Stretcher")
            addEventHandler("onClientGUIClick", row.stretcher, fStretcher, false)
        end

        if ( getPedSimplestTask(localPlayer) == "TASK_SIMPLE_CAR_DRIVE" and getPedOccupiedVehicle(localPlayer) == vehicle ) then
            if (getElementData(vehicle, "dbid") > 0 ) then
                row.look = rightclick:addRow("Edit Description")
                addEventHandler("onClientGUIClick", row.look, fLook, false)
            end
        end
    end

    --admin stuff (Exciter)
    if (exports.integration:isPlayerTrialAdmin(localPlayer) or exports.integration:isPlayerSupporter(localPlayer) or exports.integration:isPlayerScripter(localPlayer)) then
        if exports.global:isStaffOnDuty(localPlayer) then
            if trailerAdminPark then
                row.park = rightclick:addRow("ADM: Park")
                addEventHandler("onClientGUIClick", row.park, parkTrailer, false)
            end

            row.respawn = rightclick:addRow("ADM: Respawn")
            addEventHandler("onClientGUIClick", row.respawn, fRespawn, false)

            if (exports.integration:isPlayerTrialAdmin(localPlayer) or exports.integration:isPlayerScripter(localPlayer)) then
                row.textures = rightclick:addRow("ADM: Textures")
                addEventHandler("onClientGUIClick", row.textures, fTextures, false)
            end
        end
    end

    row.textures = rightclick:addRow("Preview Texture")
    addEventHandler("onClientGUIClick", row.textures, pTextures, false)
    
    if (getElementModel(vehicle) == 544) and not getPedOccupiedVehicle(localPlayer) then
        row.ladderTruck = rightclick:addRow("Climb ladder truck")
        addEventHandler("onClientGUIClick", row.ladderTruck, fLadder, false)
    end
end

function lockUnlock(button, state)
    if (button=="left") then
        if getPedSimplestTask(localPlayer) == "TASK_SIMPLE_CAR_DRIVE" and getPedOccupiedVehicle(localPlayer) == vehicle then
            triggerServerEvent("lockUnlockInsideVehicle", localPlayer, vehicle)
        elseif exports.global:hasItem(localPlayer, 3, getElementData(vehicle, "dbid")) or (exports["factions"]:isPlayerInFaction(localPlayer, getElementData(vehicle, "faction"))) then
            triggerServerEvent("lockUnlockOutsideVehicle", localPlayer, vehicle)
        end
    end
end

function fStretcher(button, state)
    if (button=="left") then
        if not (isVehicleLocked(vehicle)) then
            triggerServerEvent("stretcher:createStretcher", getLocalPlayer(), false, vehicle)
        end
    end
end

function fLook(button, state)
    if (button=="left") then
        triggerEvent("editdescription", getLocalPlayer())
    end
end

function fDoorControl(button, state, locked)
    if (button=="left") and (not locked) then
        openVehicleDoorGUI( vehicle )
    elseif locked then
        outputChatBox("Bu araç kilitli.", 255, 0, 0)
    end
end

function parkTrailer(button, state)
    if (button=="left") then
        triggerServerEvent("parkVehicle", localPlayer, vehicle)
    end
end
function factionParkTrailer(button, state)
    if (button=="left") then
        triggerServerEvent("fparkVehicle", localPlayer, localPlayer, false, vehicle)
    end
end

function fillFuelTank(button, state)
    if (button=="left") then
        local _,_, value = exports.global:hasItem(localPlayer, 57)
        if value > 0 then
            triggerServerEvent("fillFuelTankVehicle", localPlayer, vehicle)
        else
            outputChatBox("Bu yakıt boş olabilir...", 255, 0, 0)
        end
    end
end

function openMechanicWindow(button, state)
    if (button=="left") then
        triggerEvent("openMechanicFixWindow", localPlayer, vehicle)
    end
end

function toggleRamp(button)
    if (button=="left") then
        triggerServerEvent("vehicle:control:ramp", localPlayer, vehicle)
    end
end

function sitInHelicopter(button, state)
    if (button=="left") then
        triggerServerEvent("sitInHelicopter", localPlayer, vehicle)
    end
end

function unsitInHelicopter(button, state)
    if (button=="left") then
        triggerServerEvent("unsitInHelicopter", localPlayer, vehicle)
    end
end

function enterInterior()
    triggerServerEvent( "enterVehicleInterior", getLocalPlayer(), vehicle )
end

function knockVehicle()
    triggerServerEvent("onVehicleKnocking", getLocalPlayer(), vehicle)
end

function handbrakeVehicle()
    triggerServerEvent("vehicle:handbrake", vehicle)
end

function cabrioletToggleRoof()
    triggerServerEvent("vehicle:toggleRoof", getLocalPlayer(), vehicle)
end

function fRespawn()
    triggerServerEvent("vehicle_manager:respawn", getLocalPlayer(), vehicle)
end

function fTextures()
    triggerEvent("item-texture:vehtex", localPlayer, vehicle)
end

function pTextures()
    triggerEvent("item-texture:previewVehTex", localPlayer, vehicle) 
end

function fLadder(button, state)
    if (button=="left") then
        local vx, vy, vz = getElementPosition(vehicle)
        setElementPosition(localPlayer, vx, vy-4, vz+1.55)
    end
end

function clientUpdateSirens()
    if(source == localPlayer) then
        local vehicles = getElementsByType("vehicle")
        for k,v in ipairs(vehicles) do
            local model = getElementModel(v)
            --stage 1: Check models
            if(model == 525) then --towtruck
                addVehicleSirens(veh, 3, 4, true, true, true, true)
                triggerEvent("sirens:setroofsiren", localPlayer, veh, 1, -0.7, -0.35, -0.7, 255, 0, 0)
                triggerEvent("sirens:setroofsiren", localPlayer, veh, 2, 0, -0.35, -0.7)
                triggerEvent("sirens:setroofsiren", localPlayer, veh, 3, 0.7, -0.35, -0.7, 255, 0, 0)
                return true
            --stage 2: Check items
            elseif(exports.global:hasItem(v, 144)) then --single yellow strobe (airport, etc.)
                addVehicleSirens(veh, 1, 2, true, true, false, true)
                triggerClientEvent("sirens:setroofsiren", localPlayer, veh, 1, 0, 0, -0.2)
            end
        end
    end
end
addEventHandler("onClientPlayerJoin", getRootElement(), clientUpdateSirens)
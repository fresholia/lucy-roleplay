mysql = exports.mysql
function setElementDataEx(theElement, theParameter, theValue, syncToClient, noSyncAtall)
	if syncToClient == nil then
		syncToClient = false
	end
	
	if noSyncAtall == nil then
		noSyncAtall = false
	end
	
	if tonumber(theValue) then
		theValue = tonumber(theValue)
	end
	
	exports.anticheat:changeProtectedElementDataEx(theElement, theParameter, theValue, syncToClient, noSyncAtall)
	return true
end


addEventHandler( "onResourceStart", getResourceRootElement(),
	function()
		-- delete all old wiretransfers
		dbExec(mysql:getConnection(),"DELETE FROM wiretransfers WHERE time < NOW() - INTERVAL 4 WEEK" )
	end
)

function showGeneralServiceGUI(atm)
	local faction_id = tonumber( getElementData(client, "faction") )
	local faction_leader = tonumber( getElementData(client, "factionleader") )

	local isInFaction = false
	local isFactionLeader = false
	local factionType = -1
	
	if faction_id and faction_id > 0 then
		theTeam = getPlayerTeam(client)
		factionType = tonumber(getElementData(theTeam, "type"))
		isInFaction = true
		if faction_leader == 1 then
			isFactionLeader = true
		end
	end
	
	local faction = getPlayerTeam(client)
	local money = exports.global:getMoney(faction)

	local deposit = true
	local withdraw = true
	local limit = 0
	
	--outputDebugString(money)
	--outputDebugString(exports.global:getMoney(client))
	triggerClientEvent(client, "showBankUI", getRootElement(), isInFaction, isFactionLeader, money, deposit, limit, withdraw, factionType) -- last parameter is withdraw
end
addEvent( "bank:showGeneralServiceGUI", true )
addEventHandler( "bank:showGeneralServiceGUI", getRootElement(), showGeneralServiceGUI )

addEvent("computers:onlineBanking", true)
addEventHandler("computers:onlineBanking", root,
	function()
		triggerClientEvent(client, "showBankUI", getRootElement(), false, false, 0, true, 0, true, -1)
	end
)

function withdrawMoneyPersonal(amount)
	local state = tonumber(getElementData(client, "loggedin")) or 0
	if (state == 0) then
		return
	end
	
	local money = getElementData(client, "bankmoney") - amount
	if money >= 0 then
		exports.global:giveMoney(client, amount)
		
		setElementDataEx(client, "bankmoney", money, true)
		saveBank(client)
		
		dbExec(mysql:getConnection(),"INSERT INTO wiretransfers (`from`, `to`, `amount`, `reason`, `type`) VALUES (" .. (getElementData(client, "dbid")) .. ", 0, " .. (amount) .. ", '', 0)" )

		outputChatBox("You withdrew $" .. exports.global:formatMoney(amount) .. " from your personal account.", client, 255, 194, 14)
		exports.logs:dbLog(client, 25, client, "WITHDRAW " .. amount)
	else
		outputChatBox( "No.", client, 255, 0, 0 )
	end
end
addEvent("withdrawMoneyPersonal", true)
addEventHandler("withdrawMoneyPersonal", getRootElement(), withdrawMoneyPersonal)

function depositMoneyPersonal(amount)
	local state = tonumber(getElementData(client, "loggedin")) or 0
	if (state == 0) then
		return
	end
	if exports.global:takeMoney(client, amount) then
			local money = getElementData(client, "bankmoney")
			setElementDataEx(client, "bankmoney", money+amount, true)
			saveBank(client)
			dbExec(mysql:getConnection(),"INSERT INTO wiretransfers (`from`, `to`, `amount`, `reason`, `type`) VALUES (0, " .. (getElementData(client, "dbid")) .. ", " .. (amount) .. ", '', 1)" )
			outputChatBox("You deposited $" .. exports.global:formatMoney(amount) .. " into your personal account.", client, 255, 194, 14)
			exports.logs:dbLog(client, 25, client, "DEPOSIT " .. amount)
	else
		outputChatBox("You don't have that amount in one sorted money item.", client, 255, 194, 14)
	end
end
addEvent("depositMoneyPersonal", true)
addEventHandler("depositMoneyPersonal", getRootElement(), depositMoneyPersonal)

function withdrawMoneyBusiness(amount)
	local state = tonumber(getElementData(client, "loggedin")) or 0
	if (state == 0) then
		return
	end
	
	local theTeam = getPlayerTeam(client)
	if exports.global:takeMoney(theTeam, amount) then
		if exports.global:giveMoney(client, amount) then
			dbExec(mysql:getConnection(),"INSERT INTO wiretransfers (`from`, `to`, `amount`, `reason`, `type`) VALUES (" .. (-getElementData(theTeam, "id")) .. ", " .. (getElementData(client, "dbid")) .. ", " .. (amount) .. ", '', 4)" ) 
			outputChatBox("You withdrew $" .. exports.global:formatMoney(amount) .. " from your business account.", client, 255, 194, 14)
			exports.logs:dbLog(client, 25, theTeam, "WITHDRAW FROM BUSINESS " .. amount)
		end
	end
end
addEvent("withdrawMoneyBusiness", true)
addEventHandler("withdrawMoneyBusiness", getRootElement(), withdrawMoneyBusiness)

function depositMoneyBusiness(amount)
	local state = tonumber(getElementData(client, "loggedin")) or 0
	if (state == 0) then
		return
	end
	if exports.global:takeMoney(client, amount) then
		local theTeam = getPlayerTeam(client)
		if exports.global:giveMoney(theTeam, amount) then
			dbExec(mysql:getConnection(),"INSERT INTO wiretransfers (`from`, `to`, `amount`, `reason`, `type`) VALUES (" .. (getElementData(client, "dbid")) .. ", " .. (-getElementData(theTeam, "id")) .. ", " .. (amount) .. ", '', 5)" )
			outputChatBox("You deposited $" .. exports.global:formatMoney(amount) .. " into your business account.", client, 255, 194, 14)
			exports.logs:dbLog(client, 25, theTeam, "DEPOSIT TO BUSINESS " .. amount)
		end
	else
	outputChatBox("You don't have that amount in one sorted money item.", client, 255, 194, 14)
	end
end
addEvent("depositMoneyBusiness", true)
addEventHandler("depositMoneyBusiness", getRootElement(), depositMoneyBusiness)

function transferMoneyToPersonal(business, name, amount, reason)
	local state = tonumber(getElementData(client, "loggedin")) or 0
	if (state == 0) then
		return
	end
	
	reason = (reason)
	local reciever = getTeamFromName(name) or getPlayerFromName(string.gsub(name," ","_"))
	local dbid = nil
	if not reciever then
		local __index = 0
		local accounts, characters = exports.account:getTableInformations()
		for index, value in ipairs(characters) do
			if value.charactername == (string.gsub(name," ","_")) then
				__index = index
			end
		end
		local row = characters[__index]
		
		dbid = tonumber(row["id"])
		found = true
			
	else
		dbid = getElementData(reciever, "id") and -getElementData(reciever, "id") or getElementData(reciever, "dbid")
	end
	
	if not dbid and not reciever then
		outputChatBox("Player not found. Please enter the full character name.", client, 255, 0, 0)
	else
		if business then
			local theTeam = getPlayerTeam(client)
			if -getElementData(theTeam, "id") == dbid then
				outputChatBox("You can't wiretransfer money to yourself.", client, 255, 0, 0)
				return
			end
			if exports.global:takeMoney(theTeam, amount) then
				dbExec(mysql:getConnection(),"INSERT INTO wiretransfers (`from`, `to`, `amount`, `reason`, `type`) VALUES (" .. (( -getElementData( theTeam, "id" ) )) .. ", " .. (dbid) .. ", " .. (amount) .. ", '" .. (reason) .. "', 3)" )
			end
		else
			if reciever == client then
				outputChatBox("You can't wiretransfer money to yourself.", client, 255, 0, 0)
				return
			end
			if getElementData(client, "bankmoney") - amount >= 0 then
				setElementDataEx(client, "bankmoney", getElementData(client, "bankmoney") - amount, true)
				dbExec(mysql:getConnection(),"INSERT INTO wiretransfers (`from`, `to`, `amount`, `reason`, `type`) VALUES (" .. (getElementData(client, "dbid")) .. ", " .. (dbid) .. ", " .. (amount) .. ", '" .. (reason) .. "', 2)" ) 
			else
				outputChatBox( "No.", client, 255, 0, 0 )
				return
			end
		end
		
		if reciever then
			if dbid < 0 then
				exports.global:giveMoney(reciever, amount)
			else
				setElementDataEx(reciever, "bankmoney", getElementData(reciever, "bankmoney") + amount, true)
				saveBank(reciever)
			end
		else
			dbExec(mysql:getConnection(),"UPDATE characters SET bankmoney=bankmoney+" .. (amount) .. " WHERE id=" .. (dbid))
		end
		triggerClientEvent(client, "hideBankUI", client)
		outputChatBox("You transfered $" .. exports.global:formatMoney(amount) .. " from your "..(business and "business" or "personal").." account to "..name..(string.sub(name,-1) == "s" and "'" or "'s").." account.", client, 255, 194, 14)
		
		if business then
			exports.logs:dbLog(client, 25, { getPlayerTeam(client), "ch" .. dbid }, "TRANSFER FROM BUSINESS " .. amount .. " TO " .. name)
		else
			exports.logs:dbLog(client, 25, { client, "ch" .. dbid }, "TRANSFER " .. amount .. " TO " .. name)
		end
		
		saveBank(client)
	end
end
addEvent("transferMoneyToPersonal", true)
addEventHandler("transferMoneyToPersonal", getRootElement(), transferMoneyToPersonal)

function tellTransfersPersonal(cardInfo)
	local dbid = getElementData(client, "dbid")
	if cardInfo then
		dbid = cardInfo
	end
	tellTransfers(client, dbid, "recievePersonalTransfer")
end

function tellTransfersBusiness()
	local dbid = tonumber(getElementData(getPlayerTeam(client), "id")) or 0
	if dbid > 0 then
		tellTransfers(client, -dbid, "recieveBusinessTransfer")
	end
end

function tellTransfers(source, dbid, event)
	local where = ""
	if type(dbid) == "table" then
		where = "( ( `from` = (SELECT `card_owner` FROM `atm_cards` WHERE `card_number` = '" .. dbid[2] .. "' LIMIT 1) ) OR (`to` = (SELECT `card_owner` FROM `atm_cards` WHERE `card_number` = '" .. dbid[2] .. "' LIMIT 1) ) )"
	else
		where = "( `from` = " .. dbid .. " OR `to` = " .. dbid .. " )"
	end
	
	if tonumber(dbid) and dbid < 0 then
		where = where .. " AND type != 6" -- skip paydays for factions 
	else
		where = where .. " AND type != 4 AND type != 5" -- skip stuff that's not paid from bank money
	end
	
	-- `w.time` - INTERVAL 1 hour as 'newtime'
	-- hour correction
	
	dbQuery(
		function(qh, source)
			local res, rows, err = dbPoll(qh, 0)
			if rows > 0 then
				for index, row in ipairs(res) do
					local id = tonumber(row["id"])
					local amount = tonumber(row["amount"])
					local time = row["newtime"]
					local type = tonumber(row["type"])
					local reason = row["reason"]
					if reason == nil then
						reason = ""
					end
					
					local from, to = "-", "-"
					if row["characterfrom"] ~= nil then
						from = row["characterfrom"]:gsub("_", " ")
						if row["from_card"] ~= nil then
							from = from.." ("..row["from_card"]..")"
						end
					elseif tonumber(row["from"]) then
						num = tonumber(row["from"]) 
						if num < 0 then
							local theTeam = exports.pool:getElement("team", -num)
							from = theTeam and getTeamName(exports.pool:getElement("team", -num)) or "-"
						elseif num == 0 and ( type == 6 or type == 7 ) then
							from = "Government"
						end
					end
					if row["characterto"] ~= nil then
						to = row["characterto"]:gsub("_", " ")
						if row["to_card"] ~= nil then
							to = to.." ("..row["to_card"]..")"
						end
					elseif tonumber(row["to"]) and tonumber(row["to"]) < 0 then
						local theTeam = exports.pool:getElement("team", -tonumber(row["to"]))
						if theTeam then
							to = getTeamName(theTeam)
						end
					end
						
					if amount > 0 then
						if tonumber(dbid) then  -- Not ATM
							if tostring(row["from"]) == tostring(dbid) then
								amount = -amount
							end
						elseif tostring(row["from_card"]) == tostring(dbid[2]) or tostring(row["from"]) == tostring(dbid[4])  then
							amount = -amount
						end 
					end
					
					
					--if type >= 2 and type <= 5 and tonumber(row['from']) == dbid then
					--	amount = -amount
					--end
					
					--[[if amount < 0 then
						amount = "-$" .. -amount
					else
						amount = "$" .. amount
					end]]
					local details = "-"
					if row["details"] ~= nil then
						details = row["details"]
					end
					triggerClientEvent(source, event, source, id, amount, time, type, from, to, reason, details)
				end
			end
		end,
	{source}, mysql:getConnection(), "SELECT w.*, c.charactername as characterfrom, c2.charactername as characterto,w.`time` - INTERVAL 1 hour as 'newtime' FROM wiretransfers w LEFT JOIN characters c ON c.id = `from` LEFT JOIN characters c2 ON c2.id = `to` WHERE "..where.." ORDER BY id DESC LIMIT 40;")
end

addEvent("tellTransfersPersonal", true)
addEventHandler("tellTransfersPersonal", getRootElement(), tellTransfersPersonal)

addEvent("tellTransfersBusiness", true)
addEventHandler("tellTransfersBusiness", getRootElement(), tellTransfersBusiness)

function addBankTransactionLog(fromAccount, toAccount, amount, type, reason, details, fromCard, toCard)
	if not amount or not tonumber(amount) or not type or not tonumber(type) or fromAccount == toAccount then
		return false
	end

	local sql = "INSERT INTO wiretransfers SET `amount` = '"..amount.."', type = '"..type.."' "
	if fromAccount then
		sql = sql..", `from` = '"..(fromAccount).."' "
	end
	if fromCard then
		sql = sql..", `from_card` = '"..(fromCard).."' "
	end
	if toCard then
		sql = sql..", `to_card` = '"..(toCard).."' "
	end
	if toAccount then
		sql = sql..", `to` = '"..(toAccount).."' "
	end 
	if reason then
		sql = sql..", `reason` = '"..(reason).."' "
	end
	if details then
		sql = sql..", `details` = '"..(details).."' "
	end

	return dbExec(mysql:getConnection(),sql) 
end
addEvent("addBankTransactionLog", true)
addEventHandler("addBankTransactionLog", getRootElement(), addBankTransactionLog)


--MAXIME
function hasBankMoney(thePlayer, amount)
	amount = tonumber(amount) 
	amount = math.floor(math.abs(amount))
	if getElementType(thePlayer) == "player" then
		return getElementData(thePlayer, "bankmoney") >= amount
	elseif getElementType(thePlayer) == "team" then
		return getElementData(thePlayer, "money") >= amount
	end
end

function takeBankMoney(thePlayer, amount)
	amount = tonumber(amount)
	amount = math.floor(math.abs(amount))
	if not hasBankMoney(thePlayer, amount) then
		return false, "Lack of money in bank"
	end
	if getElementType(thePlayer) == "player" then
		return setElementDataEx(thePlayer, "bankmoney", getElementData(thePlayer, "bankmoney")-amount, true) and dbExec(mysql:getConnection(),"UPDATE `characters` SET `bankmoney`=bankmoney-"..amount.." WHERE `id`='"..getElementData(thePlayer, "dbid").."' ") 
	elseif getElementType(thePlayer) == "team" then
		return setElementDataEx(thePlayer, "money", getElementData(thePlayer, "money")-amount, true) and dbExec(mysql:getConnection(),"UPDATE `factions` SET `bankbalance`=bankbalance-"..amount.." WHERE `id`='"..getElementData(thePlayer, "id").."' ") 
	end
end

function giveBankMoney(thePlayer, amount)
	amount = tonumber(amount)
	amount = math.floor(math.abs(amount))
	if getElementType(thePlayer) == "player" then
		return setElementDataEx(thePlayer, "bankmoney", getElementData(thePlayer, "bankmoney")+amount, true) and dbExec(mysql:getConnection(),"UPDATE `characters` SET `bankmoney`=bankmoney+"..amount.." WHERE `id`='"..getElementData(thePlayer, "dbid").."' ") 
	elseif getElementType(thePlayer) == "team" then
		return setElementDataEx(thePlayer, "money", getElementData(thePlayer, "money")+amount, true) and dbExec(mysql:getConnection(),"UPDATE `factions` SET `bankbalance`=bankbalance+"..amount.." WHERE `id`='"..getElementData(thePlayer, "id").."' ") 
	end
end

function setBankMoney(thePlayer, amount)
	amount = tonumber(amount)
	amount = math.floor(math.abs(amount))
	if getElementType(thePlayer) == "player" then
		return setElementDataEx(thePlayer, "bankmoney", amount, true) and dbExec(mysql:getConnection(),"UPDATE `characters` SET `bankmoney`="..amount.." WHERE `id`='"..getElementData(thePlayer, "dbid").."' ") 
	elseif getElementType(thePlayer) == "team" then
		return setElementDataEx(thePlayer, "money", amount, true) and dbExec(mysql:getConnection(),"UPDATE `factions` SET `bankbalance`="..amount.." WHERE `id`='"..getElementData(thePlayer, "id").."' ") 
	end
end

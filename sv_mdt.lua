local QBCore = exports['qb-core']:GetCoreObject()
local call_index = 0
local caseno = nil

RegisterServerEvent("mdt:hotKeyOpen")
AddEventHandler("mdt:hotKeyOpen", function()
	local usource = source
    local xPlayer = QBCore.Functions.GetPlayer(usource)
    if xPlayer.PlayerData.job.name == 'police' then
    	MySQL.query("SELECT * FROM (SELECT * FROM `mdt_reports` ORDER BY `id` DESC LIMIT 3) sub ORDER BY `id` DESC", {}, function(reports)
    		for r = 1, #reports do
    			reports[r].charges = json.decode(reports[r].charges)
    		end
    		MySQL.query("SELECT * FROM (SELECT * FROM `mdt_warrants` ORDER BY `id` DESC LIMIT 3) sub ORDER BY `id` DESC", {}, function(warrants)
    			for w = 1, #warrants do
    				warrants[w].charges = json.decode(warrants[w].charges)
    			end
    			local officer = GetCharacterName(usource)
				--local officer = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname.. ', Rank: ' .. xPlayer.PlayerData.job.grade.name .. ', Callsign: ' .. xPlayer.PlayerData.metadata.callsign .. ', Citizen ID: ' .. xPlayer.PlayerData.citizenid .. 
		
    			TriggerClientEvent('mdt:toggleVisibilty', usource, reports, warrants, officer, xPlayer.PlayerData.job.name, xPlayer.PlayerData.job.grade.name)
    		end)
    	end)
    end
end)

RegisterServerEvent("mdt:getOffensesAndOfficer")
AddEventHandler("mdt:getOffensesAndOfficer", function()
	local usource = source
	local charges = {}
	MySQL.query('SELECT * FROM fine_types', {}, function(fines)
		for j = 1, #fines do
			if fines[j].category == 0 or fines[j].category == 1 or fines[j].category == 2 or fines[j].category == 3 then
				table.insert(charges, fines[j])
			end
		end

		local officer = GetCharacterName(usource)
		--local officer = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname.. ', Rank: ' .. xPlayer.PlayerData.job.grade.name .. ', Callsign: ' .. xPlayer.PlayerData.metadata.callsign .. ', Citizen ID: ' .. xPlayer.PlayerData.citizenid

		TriggerClientEvent("mdt:returnOffensesAndOfficer", usource, charges, officer)
	end)
end)

RegisterServerEvent("mdt:performOffenderSearch")
AddEventHandler("mdt:performOffenderSearch", function(query)
	local usource = source
	local matches = {}
	MySQL.query("SELECT * FROM `players` WHERE `citizenid` LIKE @search OR LOWER(`charinfo`) LIKE @search OR LOWER(`job`) LIKE @search OR LOWER(`gang`) LIKE @search", {
		["@search"] = string.lower('%'..query..'%')
	}, function(result)

		for index, data in ipairs(result) do
			if data.charinfo then
				local player = json.decode(data.charinfo)
				local metadata = json.decode(data.metadata)
				local core = QBCore.Functions.GetPlayerByCitizenId(data.citizenid)

				if core then
					player = core['PlayerData']['charinfo']
					metadata = core['PlayerData']['metadata']
				end

				player.id = data.id
				player.metadata = metadata
				player.citizenid = data.citizenid
				table.insert(matches, player)
			end
		end

		TriggerClientEvent("mdt:returnOffenderSearchResults", usource, matches)
	end)
end)

RegisterServerEvent("mdt:getOffenderDetails")
AddEventHandler("mdt:getOffenderDetails", function(offender)
	local usource = source
	GetLicenses(offender.citizenid, function(licenses) offender.licenses = licenses end)
	while offender.licenses == nil do Citizen.Wait(0) end
    MySQL.query('SELECT * FROM `user_mdt` WHERE `char_id` = ?', {offender.id}, function(result)

        offender.notes = ""
        offender.mugshot_url = ""
        offender.bail = false
        if result[1] then
            offender.notes = result[1].notes
            offender.mugshot_url = result[1].mugshot_url
            offender.bail = result[1].bail
        end

        MySQL.query('SELECT * FROM `user_convictions` WHERE `char_id` = ?', {offender.id}, function(convictions)

            if convictions[1] then
                offender.convictions = {}
                for i = 1, #convictions do
                    local conviction = convictions[i]
                    offender.convictions[conviction.offense] = conviction.count
                end
            end

            MySQL.query('SELECT * FROM `mdt_warrants` WHERE `char_id` = ?', {offender.id}, function(warrants)

                if warrants[1] then
                    offender.haswarrant = true
                end

				MySQL.query('SELECT * FROM `player_vehicles` WHERE `citizenid` = ?', {offender.id}, function(vehicles)
					for i = 1, #vehicles do
						vehicles[i].model = vehicles[i].vehicle
						if vehicles[i].mods then
							local vehmods = json.decode(vehicles[i].mods)
							if colors[tostring(vehmods.color2)] and colors[tostring(vehmods.color1)] then
								vehicles[i].color = colors[tostring(vehmods.color2)] .. " on " .. colors[tostring(vehmods.color1)]
							elseif colors[tostring(vehmods.color1)] then
								vehicles[i].color = colors[tostring(vehmods.color1)]
							elseif colors[tostring(vehmods.color2)] then
								vehicles[i].color = colors[tostring(vehmods.color2)]
							else
								vehicles[i].color = "Unknown"
							end
						end
						vehicles[i].vehicle = nil
					end
					offender.vehicles = vehicles
					offender.phone_number = offender.phone
					offender.dateofbirth = offender.birthdate
					TriggerClientEvent("mdt:returnOffenderDetails", usource, offender)
				end)
            end)
        end)
    end)
end)

RegisterServerEvent("mdt:getOffenderDetailsById")
AddEventHandler("mdt:getOffenderDetailsById", function(char_id)
    local usource = source
    MySQL.query('SELECT * FROM `players` WHERE `id` = ?', {char_id}, function(result)
		local charinfo = json.decode(result[1].charinfo)
        local offender = result[1]

        if not offender then
            TriggerClientEvent("mdt:closeModal", usource)
            TriggerClientEvent("mdt:sendNotification", usource, "This person no longer exists.")
            return
        end
    
        GetLicenses(offender.citizenid, function(licenses) offender.licenses = licenses end)
        while offender.licenses == nil do Citizen.Wait(0) end

        MySQL.query('SELECT * FROM `user_mdt` WHERE `char_id` = ?', {offender.id}, function(result)

            offender.notes = ""
            offender.mugshot_url = ""
            offender.bail = false
            if result[1] then
                offender.notes = result[1].notes
                offender.mugshot_url = result[1].mugshot_url
                offender.bail = result[1].bail
            end

            MySQL.query('SELECT * FROM `user_convictions` WHERE `char_id` = ?', {offender.id}, function(convictions) 

                if convictions[1] then
                    offender.convictions = {}
                    for i = 1, #convictions do
                        local conviction = convictions[i]
                        offender.convictions[conviction.offense] = conviction.count
                    end
                end

                MySQL.query('SELECT * FROM `mdt_warrants` WHERE `char_id` = ?', {offender.id}, function(warrants)
                    
                    if warrants[1] then
                        offender.haswarrant = true
                    end

                    MySQL.query('SELECT * FROM `player_vehicles` WHERE `citizenid` = ?', {offender.citizenid}, function(vehicles)
                        for i = 1, #vehicles do
                            vehicles[i].model = vehicles[i].vehicle
                            if vehicles[i].mods then
                                local vehmods = json.decode(vehicles[i].mods)
                                if colors[tostring(vehmods.color2)] and colors[tostring(vehmods.color1)] then
                                    vehicles[i].color = colors[tostring(vehmods.color2)] .. " on " .. colors[tostring(vehmods.color1)]
                                elseif colors[tostring(vehmods.color1)] then
                                    vehicles[i].color = colors[tostring(vehmods.color1)]
                                elseif colors[tostring(vehmods.color2)] then
                                    vehicles[i].color = colors[tostring(vehmods.color2)]
                                else
                                    vehicles[i].color = "Unknown"
                                end
                            end
                            vehicles[i].vehicle = nil
                        end
                        
						offender.vehicles = vehicles
						offender.firstname = charinfo.firstname
						offender.lastname = charinfo.lastname
                        offender.phone_number = charinfo.phone
                        offender.dateofbirth = charinfo.birthdate
                        TriggerClientEvent("mdt:returnOffenderDetails", usource, offender)
                    end)
                end)
            end)
        end)
    end)
end)

RegisterServerEvent("mdt:saveOffenderChanges")
AddEventHandler("mdt:saveOffenderChanges", function(id, changes, identifier)
	local usource = source
	MySQL.query('SELECT * FROM `user_mdt` WHERE `char_id` = ?', {id}, function(result)
		if result[1] then
			MySQL.query('UPDATE `user_mdt` SET `notes` = ?, `mugshot_url` = ?, `bail` = ? WHERE `char_id` = ?', {id, changes.notes, changes.mugshot_url, changes.bail})
		else
			MySQL.insert('INSERT INTO `user_mdt` (`char_id`, `notes`, `mugshot_url`, `bail`) VALUES (?, ?, ?, ?)', {id, changes.notes, changes.mugshot_url, changes.bail})
		end
		for i = 1, #changes.licenses_removed do
			local license = changes.licenses_removed[i]
			MySQL.query('DELETE FROM `user_licenses` WHERE `type` = ? AND `owner` = ?', {license.type, identifier})
		end

		if changes.convictions ~= nil then
			for conviction, amount in pairs(changes.convictions) do	
				MySQL.query('UPDATE `user_convictions` SET `count` = ? WHERE `char_id` = ? AND `offense` = ?', {id, amount, conviction})
			end
		end

		for i = 1, #changes.convictions_removed do
			MySQL.query('DELETE FROM `user_convictions` WHERE `char_id` = ? AND `offense` = ?', {id, changes.convictions_removed[i]})
		end

		TriggerClientEvent("mdt:sendNotification", usource, "Offender changes have been saved.")
	end)
end)

RegisterServerEvent("mdt:saveReportChanges")
AddEventHandler("mdt:saveReportChanges", function(data)
	MySQL.query('UPDATE `mdt_reports` SET `title` = ?, `incident` = ? WHERE `id` = ?', {data.id, data.title, data.incident})
	TriggerClientEvent("mdt:sendNotification", source, "Report changes have been saved.")
end)

RegisterServerEvent("mdt:deleteReport")
AddEventHandler("mdt:deleteReport", function(id)
	MySQL.query('DELETE FROM `mdt_reports` WHERE `id` = ?', {id})
	TriggerClientEvent("mdt:sendNotification", source, "Report has been successfully deleted.")
end)

RegisterServerEvent("mdt:submitNewReport")
AddEventHandler("mdt:submitNewReport", function(data)
	local usource = source
	local author = GetCharacterName(source)
	charges = json.encode(data.charges)
	chargesamount = json.encode(data.charges_amount)
	citizenidfromjs = json.encode(data.citizenid)
	citizenid = string.gsub(citizenidfromjs, '"', '')


	generateCaseNumber()
    
	data.date = os.date('%m-%d-%Y %H:%M:%S', os.time())
	MySQL.insert('INSERT INTO `mdt_reports` (`caseno`,`citizen_id`, `char_id`, `title`, `incident`, `charges`, `author`, `name`, `date`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {caseno, citizenid, data.char_id, data.title, data.incident, charges, author, data.name, data.date,}, function(id)
		TriggerEvent("mdt:getReportDetailsById", id, usource)
		TriggerClientEvent("mdt:sendNotification", usource, "A new report has been submitted.")
	end)
    
	local billed = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    
	if chargesamount then
	TriggerEvent("police:server:BillPlayer", billed, chargesamount, charges, usource, caseno)
	end

	for offense, count in pairs(data.charges) do
		MySQL.query('SELECT * FROM `user_convictions` WHERE `offense` = ? AND `char_id` = ?', {offense, data.char_id}, function(result)
			if result[1] then
				MySQL.query('UPDATE `user_convictions` SET `count` = ? WHERE `offense` = ? AND `char_id` = ?', {data.char_id, offense, count + 1})
			else
				MySQL.insert('INSERT INTO `user_convictions` (`char_id`, `offense`, `count`) VALUES (?, ?, ?)', {data.char_id, offense, count})
			end
		end)
	end
end)

RegisterServerEvent("mdt:performReportSearch")
AddEventHandler("mdt:performReportSearch", function(query)
	local usource = source
	local matches = {}
	MySQL.query("SELECT * FROM `mdt_reports` WHERE `id` LIKE :test OR LOWER(`title`) LIKE :test OR LOWER(`name`) LIKE :test OR LOWER(`caseno`) LIKE :test OR LOWER(`author`) LIKE :test or LOWER(`charges`) LIKE :test", {
		test = string.lower('%'..query..'%')
	}, function(result) -- % wildcard, needed to search for all alike results

		for index, data in ipairs(result) do
			data.charges = json.decode(data.charges)
			table.insert(matches, data)
		end

		TriggerClientEvent("mdt:returnReportSearchResults", usource, matches)
	end)
end)

RegisterServerEvent("mdt:performVehicleSearch")
AddEventHandler("mdt:performVehicleSearch", function(query)
	local usource = source
	local matches = {}

	
	MySQL.query("SELECT * FROM `player_vehicles` WHERE LOWER(`plate`) LIKE ?", {string.lower('%'..query..'%')}, function(result) -- % wildcard, needed to search for all alike results
		
		
		for index, data in ipairs(result) do
			data.model = data.vehicle
			data.cockgobbler = cockgobbler

		
			if data.mods ~= nil then
				local vehmods = json.decode(data.mods)
				data.color = colors[tostring(vehmods.color1)]
				if colors[tostring(vehmods.color2)] then
					data.color = colors[tostring(vehmods.color2)] .. " on " .. colors[tostring(vehmods.color1)]
				end
			end
			
			table.insert(matches, data)
		end

		TriggerClientEvent("mdt:returnVehicleSearchResults", usource, matches)
	end)

   
	



end)

RegisterServerEvent("mdt:performVehicleSearchInFront")
AddEventHandler("mdt:performVehicleSearchInFront", function(query)
	local usource = source
	local xPlayer = QBCore.Functions.GetPlayer(usource)
    if xPlayer.PlayerData.job.name == 'police' then
    	MySQL.query("SELECT * FROM (SELECT * FROM `mdt_reports` ORDER BY `id` DESC LIMIT 3) sub ORDER BY `id` DESC", {}, function(reports)
    		for r = 1, #reports do
    			reports[r].charges = json.decode(reports[r].charges)
    		end
    		MySQL.query("SELECT * FROM (SELECT * FROM `mdt_warrants` ORDER BY `id` DESC LIMIT 3) sub ORDER BY `id` DESC", {}, function(warrants)
    			for w = 1, #warrants do
    				warrants[w].charges = json.decode(warrants[w].charges)
    			end
    			MySQL.query("SELECT * FROM `player_vehicles` WHERE `plate` = ?", {query}, function(result)
					local officer = GetCharacterName(usource)
					--local officer = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname.. ', Rank: ' .. xPlayer.PlayerData.job.grade.name .. ', Callsign: ' .. xPlayer.PlayerData.metadata.callsign .. ', Citizen ID: ' .. xPlayer.PlayerData.citizenid
    				TriggerClientEvent('mdt:toggleVisibilty', usource, reports, warrants, officer, xPlayer.PlayerData.job.name)
					TriggerClientEvent("mdt:returnVehicleSearchInFront", usource, result, query)
				end)
    		end)
    	end)
	end
end)

RegisterServerEvent("mdt:getVehicle")
AddEventHandler("mdt:getVehicle", function(vehicle)
	local usource = source
    MySQL.query("SELECT * FROM `players` WHERE `citizenid` = ?", {vehicle.citizenid}, function(result)
    --print(vehicle.plate)
		if result[1] then
			local player = json.decode(result[1].charinfo)
			vehicle.owner = player.firstname .. ' ' .. player.lastname
			vehicle.owner_id = result[1].id
		end

        
		
		--MySQL.query('SELECT stolen FROM `player_vehicles` WHERE `plate` = ?', {vehicle.plate}, function(data)
        MySQL.query("SELECT `stolen` FROM `player_vehicles` WHERE `plate` = @plate", {["@plate"] = vehicle.plate}, function (result)
           print(result[1].stolen)
					
			--if data[1] then
                --if data[1].stolen == 1 then vehicle.cockgobbler = "Returned stolen flag" else vehicle.cockgobbler = "Returned no flags" end
                --if data[1].notes ~= null then vehicle.notes = data[1].notes else vehicle.notes = '' end
				
					if result[1].stolen == true then
						print(result[1].stolen)
					vehicle.cockgobbler = "Returned stolen flag"
					else
					
					vehicle.cockgobbler = "Returned no flags"
					end
					


            
                --vehicle.stolen = false
                --vehicle.notes = ''
        
            
            MySQL.query('SELECT * FROM `mdt_warrants` WHERE `char_id` = ?', {vehicle.owner_id}, function(warrants)

                if warrants[1] then
                    vehicle.haswarrant = true
                end

                MySQL.query('SELECT `bail` FROM user_mdt WHERE `char_id` = ?', {vehicle.owner_id}, function(bail)

                    if bail and bail[1] and bail[1].bail == 1 then
                        vehicle.bail = true
                    else
                        vehicle.bail = false
                    end
	                vehicle.type = 'Vehicle'
	                TriggerClientEvent("mdt:returnVehicleDetails", usource, vehicle)
                end)
            end)
        end)
    end)
end)

RegisterServerEvent("mdt:getWarrants")
AddEventHandler("mdt:getWarrants", function()
	local usource = source
	MySQL.query("SELECT * FROM `mdt_warrants`", {}, function(warrants)
		for i = 1, #warrants do
			warrants[i].expire_time = ""
			warrants[i].charges = json.decode(warrants[i].charges)
		end
		TriggerClientEvent("mdt:returnWarrants", usource, warrants)
	end)
end)

RegisterServerEvent("mdt:submitNewWarrant")
AddEventHandler("mdt:submitNewWarrant", function(data)
	local usource = source
	data.charges = json.encode(data.charges)
	data.author = GetCharacterName(source)
	data.date = os.date('%m-%d-%Y %H:%M:%S', os.time())
	MySQL.insert('INSERT INTO `mdt_warrants` (`citizen_id`,`name`, `char_id`, `report_id`, `report_title`, `charges`, `date`, `expire`, `notes`, `author`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {data.citizenid, data.name, data.char_id, data.report_id, data.report_title, data.charges, data.date, data.expire, data.notes, data.author}, function()
		TriggerClientEvent("mdt:completedWarrantAction", usource)
		TriggerClientEvent("mdt:sendNotification", usource, "A new warrant has been created.")
	end)
end)

RegisterServerEvent("mdt:deleteWarrant")
AddEventHandler("mdt:deleteWarrant", function(id)
	local usource = source
	MySQL.query('DELETE FROM `mdt_warrants` WHERE `id` = ?', {id}, function()
		TriggerClientEvent("mdt:completedWarrantAction", usource)
	end)
	TriggerClientEvent("mdt:sendNotification", usource, "Warrant has been successfully deleted.")
end)

RegisterServerEvent("mdt:getReportDetailsById")
AddEventHandler("mdt:getReportDetailsById", function(query, _source)
	if _source then source = _source end
	local usource = source
	MySQL.query("SELECT * FROM `mdt_reports` WHERE `id` = ?", {query}, function(result)
		if result and result[1] then
			result[1].charges = json.decode(result[1].charges)
			TriggerClientEvent("mdt:returnReportDetails", usource, result[1])
		else
			TriggerClientEvent("mdt:closeModal", usource)
			TriggerClientEvent("mdt:sendNotification", usource, "This report cannot be found.")
		end
	end)
end)

RegisterServerEvent("mdt:newCall")
AddEventHandler("mdt:newCall", function(details, caller, coords, sendNotification)
	call_index = call_index + 1
	local xPlayers = QBCore.Functions.GetPlayers()
	for i= 1, #xPlayers do
		local source = xPlayers[i]
		local xPlayer = QBCore.Functions.GetPlayer(source)
		if xPlayer.PlayerData.job.name == 'police' then
			TriggerClientEvent("mdt:newCall", source, details, caller, coords, call_index)
			if sendNotification ~= false then
				TriggerClientEvent("InteractSound_CL:PlayOnOne", source, 'demo', 0.0)
				TriggerClientEvent("mythic_notify:client:SendAlert", source, {type="infom", text="You have received a new call.", length=5000, style = { ['background-color'] = '#ffffff', ['color'] = '#000000' }})
			end
		end
	end
end)

RegisterServerEvent("mdt:attachToCall")
AddEventHandler("mdt:attachToCall", function(index)
	local usource = source
	local charname = GetCharacterName(usource)
	local xPlayers = QBCore.Functions.GetPlayers()
	for i= 1, #xPlayers do
		local source = xPlayers[i]
		local xPlayer = QBCore.Functions.GetPlayer(source)
		if xPlayer.PlayerData.job.name == 'police' then
			TriggerClientEvent("mdt:newCallAttach", source, index, charname)
		end
	end
	TriggerClientEvent("mdt:sendNotification", usource, "You have attached to this call.")
end)

RegisterServerEvent("mdt:detachFromCall")
AddEventHandler("mdt:detachFromCall", function(index)
	local usource = source
	local charname = GetCharacterName(usource)
	local xPlayers = QBCore.Functions.GetPlayers()
	for i= 1, #xPlayers do
		local source = xPlayers[i]
		local xPlayer = QBCore.Functions.GetPlayer(source)
		if xPlayer.PlayerData.job.name == 'police' then
			TriggerClientEvent("mdt:newCallDetach", source, index, charname)
		end
	end
	TriggerClientEvent("mdt:sendNotification", usource, "You have detached from this call.")
end)

RegisterServerEvent("mdt:editCall")
AddEventHandler("mdt:editCall", function(index, details)
	local usource = source
	local xPlayers = QBCore.Functions.GetPlayers()
	for i= 1, #xPlayers do
		local source = xPlayers[i]
		local xPlayer = QBCore.Functions.GetPlayer(source)
		if xPlayer.PlayerData.job.name == 'police' then
			TriggerClientEvent("mdt:editCall", source, index, details)
		end
	end
	TriggerClientEvent("mdt:sendNotification", usource, "You have edited this call.")
end)

RegisterServerEvent("mdt:deleteCall")
AddEventHandler("mdt:deleteCall", function(index)
	local usource = source
	local xPlayers = QBCore.Functions.GetPlayers()
	for i= 1, #xPlayers do
		local source = xPlayers[i]
		local xPlayer = QBCore.Functions.GetPlayer(source)
		if xPlayer.PlayerData.job.name == 'police' then
			TriggerClientEvent("mdt:deleteCall", source, index)
		end
	end
	TriggerClientEvent("mdt:sendNotification", usource, "You have deleted this call.")
end)

RegisterServerEvent("mdt:saveVehicleChanges")
AddEventHandler("mdt:saveVehicleChanges", function(data)
    if data.stolen then data.stolen = true else data.stolen = false end
    local usource = source
    MySQL.query("SELECT `stolen` FROM `player_vehicles` WHERE `plate` = @plate", {
        ["@plate"] = data.plate
    }, function (result)
        if result[1] then
           MySQL.query.await("UPDATE `player_vehicles` SET `stolen` = @stolen WHERE `plate` = @plate", {
                ["@plate"] = data.plate,
                ["@stolen"] = data.stolen
            })
        else
           MySQL.query.await("INSERT INTO `player_vehicles` (`plate`, `stolen`) VALUES (@plate, @stolen)", {
                ["@plate"] = data.plate,
                ["@stolen"] = data.stolen
            })
        end
        TriggerClientEvent("mdt:sendNotification", usource, "Vehicle changes have been saved.")
    end)
end)

function GetLicenses(identifier, cb)
	local player = QBCore.Functions.GetPlayerByCitizenId(identifier)
	if player ~= nil then
		local playerlicenses = player.PlayerData.metadata["licences"]
		local licenses = {}

		for type,_ in pairs(playerlicenses) do
			if playerlicenses[type] then
				local licenseType = nil
				local label = nil

				if type == "driver" then
					licenseType = "driver_license" label = "Drivers License"
				elseif type == "weapon" then
					licenseType = "weapon_license" label = "Weapons License"
				end

				table.insert(licenses, {
					type = licenseType,
					label = label
				})
			end
		end
		cb(licenses)
	else
		cb(false)
	end
end

function generateCaseNumber()
   caseno = "P-" .. math.random(11111, 99999) .. "/" .. math.random(1111, 9999)
end

function GetCharacterName(source)
	local xPlayer = QBCore.Functions.GetPlayer(source)
	if xPlayer then
		return xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname.. ', Rank: ' .. xPlayer.PlayerData.job.grade.name .. ', Callsign: ' .. xPlayer.PlayerData.metadata.callsign .. ', Citizen ID: ' .. xPlayer.PlayerData.citizenid
	end
end

function tprint (tbl, indent)
  if not indent then indent = 0 end
  local toprint = string.rep(" ", indent) .. "{\r\n"
  indent = indent + 2 
  for k, v in pairs(tbl) do
    toprint = toprint .. string.rep(" ", indent)
    if (type(k) == "number") then
      toprint = toprint .. "[" .. k .. "] = "
    elseif (type(k) == "string") then
      toprint = toprint  .. k ..  "= "   
    end
    if (type(v) == "number") then
      toprint = toprint .. v .. ",\r\n"
    elseif (type(v) == "string") then
      toprint = toprint .. "\"" .. v .. "\",\r\n"
    elseif (type(v) == "table") then
      toprint = toprint .. tprint(v, indent + 2) .. ",\r\n"
    else
      toprint = toprint .. "\"" .. tostring(v) .. "\",\r\n"
    end
  end
  toprint = toprint .. string.rep(" ", indent-2) .. "}"
  return toprint
end

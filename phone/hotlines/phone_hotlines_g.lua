--MAXIME

hotlines = {
	[911] = "LSPD Acil Servis", 
	[411] = "LSFMD Acil Servis",
	--[311] = "LSFD Acil Servis",
--	[511] = "Los Santos Government",
--	[711] = "Report Stolen Vehicle",
--	[9021] = "Rapid Towing",
	[8294] = "Yellow Cab Company",
--	[7332] = "Los Santos Network",
--	[7331] = "LSN - Advertisment",
--	[2552] = "RS Haul",
--	[5555] = "Federal Aviation Administration",
--	[211] = "Los Santos Courts",
--	[7233] = "Cargo Group",
--	[611] = "SASD Non-Emergency",
--	[8800] = "San Andreas Public Transport",
}

function isNumberAHotline(theNumber)
	local challengeNumber = tonumber(theNumber)
	return hotlines[challengeNumber]
end
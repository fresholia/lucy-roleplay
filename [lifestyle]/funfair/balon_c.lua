function BalonLoad()
	local balonTXD = engineLoadTXD("dosyalar/balon.txd")
	engineImportTXD(balonTXD, 1928)
	local balonDFF = engineLoadDFF("dosyalar/balon.dff", 1928)
	engineReplaceModel(balonDFF, 1928)
	local balonCOL = engineLoadCOL("dosyalar/balon.col")
	engineReplaceCOL(balonCOL, 1928)
end
addEventHandler("onClientResourceStart", getResourceRootElement(getThisResource()), BalonLoad)
addCommandHandler("reloadbalonstoriesp", BalonLoad)
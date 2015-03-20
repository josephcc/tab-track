
objects2csv = (objects, attributes) ->
	csvData = new Array()
	csvData.push '"' + attributes.join('","') + '"'
	for object in objects
		row = []
		for attribute in attributes
			row.push ("" + object[attribute]).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
		csvData.push '"' + row.join('","') + '"'
	return csvData.join('\n')

downloadCsv = (filename, csv) ->
	a = document.createElement('a')
	a.href = 'data:attachment/csv,' + encodeURI(csv)
	a.target ='_blank'
	a.download = filename + '.csv'
	a.click()

$('.download.tabs').click () ->
	#domain url urlHash domainHash index id windowId status snapshotAction time
	tabs = TabInfo.db({type: 'tab'}).get()
	attributes = ['snapshotId', 'windowId', 'id', 'openerTabId', 'index', 'status', 'snapshotAction', 'domain', 'url', 'domainHash', 'urlHash', 'favIconUrl', 'time']
	csv = objects2csv(tabs, attributes)
	downloadCsv('tabLogs', csv)

$('.download.focuses').click () ->
	#tabId time windowId
	focuses = TabInfo.db({type: 'focus'}).get()
	attributes = ['action', 'windowId', 'tabId', 'time']
	csv = objects2csv(focuses, attributes)
	downloadCsv('focusLogs', csv)

$('.database.kill').click () ->
	console.log "KILL DB"
	TabInfo.clearDB()
	alert 'database deleted'


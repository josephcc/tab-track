###
#
# API used for parsing the information stored in chrome.storage for searches
#
###

errorHandler = (e) ->
  msg = ''

  switch (e.code)
    when FileError.QUOTA_EXCEEDED_ERR
      msg = 'QUOTA_EXCEEDED_ERR'
    when FileError.NOT_FOUND_ERR
      msg = 'NOT_FOUND_ERR'
    when FileError.SECURITY_ERR
      msg = 'SECURITY_ERR'
    when FileError.INVALID_MODIFICATION_ERR
      msg = 'INVALID_MODIFICATION_ERR'
    when FileError.INVALID_STATE_ERR
      msg = 'INVALID_STATE_ERR'
    else
      msg = 'Unknown Error'

  console.log('Error: ' + msg)

objects2csv = (objects, attributes) ->
  csvData = new Array()
  csvData.push '"' + attributes.join('","') + '"'
  for object in objects
    row = []
    for attribute in attributes
      row.push ("" + object[attribute]).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
    csvData.push '"' + row.join('","') + '"'
  return csvData.join('\n') + '\n'


persistToFile = (filename, csv) ->
  onInitFs = (fs) ->
    fs.root.getFile(filename, {create:true}, (fileEntry) ->
      fileEntry.createWriter( (writer) ->
        blob = new Blob([csv], {type: 'text/csv'});
        writer.seek(writer.length)
        writer.write(blob)
      , errorHandler)
    , errorHandler)
  window.webkitRequestFileSystem(window.PERSISTENT, 50*1024*1024, onInitFs, errorHandler);

window.TabInfo = (() ->
  obj = {}
  obj.db = TAFFY()
  #Lets us track which running version of this file is actually updating the DB
  updateID = generateUUID()
  updateFunction = null
  settings =
    template: {}
    onDBChange: () ->
      size = TabInfo.db().get().length
      if size >= 1250
        console.log 'persisting to file'
        old = TabInfo.db().order('time asec').limit(250).get()

        tabs = _.filter(old, (e) -> e.type == 'tab')
        if tabs.length > 0
          attributes = ['snapshotId', 'windowId', 'id', 'openerTabId', 'index', 'status', 'snapshotAction', 'domain', 'url', 'domainHash', 'urlHash', 'favIconUrl', 'time']
          tabCsv = objects2csv(tabs, attributes)
          persistToFile('_tabLogs.csv', tabCsv)

        focuses = _.filter(old, (e) -> e.type == 'focus')
        if focuses.length > 0
          attributes = ['action', 'windowId', 'tabId', 'time']
          focusCsv = objects2csv(focuses, attributes)
          persistToFile('_focusLogs.csv', focusCsv)

        TabInfo.db(old).remove()

      chrome.storage.local.set {'tabs': {db: this, updateId: updateID}}
  
  #Grab the info from localStorage and lets update it
  chrome.storage.onChanged.addListener (changes, areaName) ->
    if changes.tabs? 
      if !changes.tabs.newValue?
        obj.db = TAFFY()
        obj.db.settings(settings)
        updateFunction() if updateFunction?
      else if changes.tabs.newValue.updateid != updateID
        obj.db = TAFFY(changes.tabs.newValue.db, false)
        obj.db.settings(settings)
        updateFunction() if updateFunction?
        
  chrome.storage.local.get 'tabs', (retVal) ->
    if retVal.tabs?
      obj.db = TAFFY(retVal.tabs.db)
    obj.db.settings(settings)
    updateFunction() if updateFunction?
      
  obj.clearDB = () ->
    chrome.storage.local.remove('tabs')
    obj.db = TAFFY()
    console.log 'deleting spill files'
    window.webkitRequestFileSystem(window.PERSISTENT, 50*1024*1024, (fs) ->

      fs.root.getFile('_tabLogs.csv', {create: false}, (fileEntry) ->
        fileEntry.remove(() -> 
          console.log('File removed.')
        , errorHandler)
      , errorHandler)

      fs.root.getFile('_focusLogs.csv', {create: false}, (fileEntry) ->
        fileEntry.remove(() ->
          console.log('File removed.')
        , errorHandler)
      , errorHandler)

    , errorHandler)
      
  obj.db.settings(settings)
  obj.updateFunction = (fn) -> updateFunction = fn

  return obj
)()


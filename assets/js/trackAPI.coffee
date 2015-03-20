###
#
# API used for parsing the information stored in chrome.storage for searches
#
###

window.TabInfo = (() ->
  obj = {}
  obj.db = TAFFY()
  #Lets us track which running version of this file is actually updating the DB
  updateID = generateUUID()
  updateFunction = null
  settings =
    template: {}
    onDBChange: () ->
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
      
  obj.db.settings(settings)
  obj.updateFunction = (fn) -> updateFunction = fn

  return obj
)()

window.FocusInfo = (() ->
  obj = {}
  obj.db = TAFFY()
  #Lets us track which running version of this file is actually updating the DB
  updateID = generateUUID()
  updateFunction = null
  settings =
    template: {}
    onDBChange: () ->
      chrome.storage.local.set {'focus': {db: this, updateId: updateID}}
  
  #Grab the info from localStorage and lets update it
  chrome.storage.onChanged.addListener (changes, areaName) ->
    if changes.focus? 
      if !changes.focus.newValue?
        obj.db = TAFFY()
        obj.db.settings(settings)
        updateFunction() if updateFunction?
      else if changes.focus.newValue.updateid != updateID
        obj.db = TAFFY(changes.focus.newValue.db, false)
        obj.db.settings(settings)
        updateFunction() if updateFunction?
        
  chrome.storage.local.get 'focus', (retVal) ->
    if retVal.focus?
      obj.db = TAFFY(retVal.focus.db)
    obj.db.settings(settings)
    updateFunction() if updateFunction?
      
  obj.clearDB = () ->
    chrome.storage.local.remove('focus')
    obj.db = TAFFY()
      
  obj.db.settings(settings)
  obj.updateFunction = (fn) -> updateFunction = fn

  return obj
)()


###
#
# API used for parsing the information stored in chrome.storage for searches
#
###


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

window.db = new Dexie('tabTrack')
db.version(1).stores({
  TabInfo: '++id,action,snapshotId,time'
  FocusInfo: '++id,tabId,time'
  NavInfo: '++id,time'
})

window.TabInfo = (params) ->  
  properties = _.extend({
    windowId: -1
    openerTabId: null
    snapshotId: ''
    tabId: -1
    index: null
    status: ''
    pinned: false
    favIconUrl: ''
    active: false
    globalIndex: -1
    action: ''
    domain: ''
    url: ''
    domainHash: ''
    urlHash: ''
    time: Date.now()
  }, params)
  this.windowId = properties.windowId
  this.openerTabId = properties.openerTabId
  this.snapshotId = properties.snapshotId
  this.tabId = properties.tabId
  this.index = properties.index
  this.status = properties.status
  this.pinned = properties.pinned
  this.favIconUrl = properties.favIconUrl
  this.active = properties.active
  this.globalIndex = properties.globalIndex
  this.action = properties.action
  this.domain = properties.domain
  this.url = properties.url
  this.domainHash = properties.domainHash
  this.urlHash = properties.urlHash
  this.time = properties.time
  
TabInfo.prototype.save = () ->
  self = this
  db.TabInfo.put(this).then (id) ->
    self.id = id
    return self
  
window.FocusInfo = (params) ->  
  properties = _.extend({
    action: ''
    windowId: -1
    tabId: -1
    time: Date.now()
  }, params)
  this.action = properties.action
  this.windowId = properties.windowId
  this.tabId = properties.tabId
  this.time = properties.time
  
FocusInfo.prototype.save = () ->
  self = this
  db.FocusInfo.put(this).then (id) ->
    self.id = id
    return self

window.NavInfo = (params) ->  
  properties = _.extend({
    from: -1
    to: -1
    time: Date.now()
  }, params)
  this.from = properties.from
  this.to = properties.to
  this.time = properties.time

NavInfo.prototype.save = () ->
  self = this
  db.NavInfo.put(this).then (id) ->
    self.id = id
    return self

db.NavInfo.mapToClass(window.NavInfo)
db.FocusInfo.mapToClass(window.FocusInfo)
db.TabInfo.mapToClass(window.TabInfo)
db.clearDB = () ->
  Promise.all([
    db.TabInfo.clear()
    db.FocusInfo.clear()
    db.NavInfo.clear()
  ])

db.open()

Dexie.Promise.on 'error', (err) ->
  console.log(err)

###
throttle = null

window.TabInfo = (() ->
  obj = {}
  obj.db = TAFFY()
  #Lets us track which running version of this file is actually updating the DB
  updateID = generateUUID()
  updateFunction = null

  _onDBChange = (_this) ->
    console.log 'onDBChange exec'
    size = TabInfo.db().get().length
    console.log '  dbSize ' + size
    if size > 1500
      console.log 'persisting to file'
      spillCount = size - 1500 + 250
      console.log 'spilling ' + spillCount + ' records'
      old = TabInfo.db().order('time asec').limit(spillCount).get()

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


      navs = _.filter(old, (e) -> e.type == 'nav')
      if navs.length > 0
        attributes = ['from', 'to', 'time']
        navCsv = objects2csv(navs, attributes)
        persistToFile('_navLogs.csv', navCsv)

      TabInfo.db(old).remove()

    chrome.storage.local.set {'tabs': {db: _this, updateId: updateID}}

  settings =
    cacheSize: 0
    template: {}
    onDBChange: () ->
      console.log 'onDBChange throttle'
      clearTimeout(throttle)
      _this = this
      _exec = () -> _onDBChange(_this)
      throttle = setTimeout(_exec, 1500)

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

      fs.root.getFile('_navLogs.csv', {create: false}, (fileEntry) ->
        fileEntry.remove(() ->
          console.log('File removed.')
        , errorHandler)
      , errorHandler)


    , errorHandler)

  obj.db.settings(settings)
  obj.updateFunction = (fn) -> updateFunction = fn

  return obj
)()
###

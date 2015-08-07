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
    query: null
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
  this.query = properties.query
  
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
#
# Global Application settings hash (that auto-updates in the backend and refreshes stuff elsewhere)
#
# AppSettings.on (setting..., func()) : 
#   * Takes and array of settings, and a function. Will call the function when the setting is updated.
#   * Note the special "setting", 'ready', that will be called when it has finished fetching the settings
#   from chrome storage. 
#
# AppSettings.listSettings :
#   * Returns an array of all of the different setting types 
#
# To add a new setting -- create a new entry in the 'settings' array, and then it will become available for use
###
window.AppSettings = (() ->
  obj = {}
  settings = ['userID', 'trackURL', 'trackDomain', 'logLevel', 'autoSync'] #Add a setting name here to make it available for use
  handlers = {}
  get_val = _.map settings, (itm) ->
    return 'setting-'+itm

  chrome.storage.local.get get_val, (items) ->
    for own key, val of items
      obj[key] = val
    for handler in handlers.ready
      handler.call(obj)


  for setting in settings
    ((setting) ->
      Object.defineProperty obj, setting, {
        set: (value) ->
          hsh = {}
          hsh['setting-'+setting] = value
          obj['setting-'+setting] = value
          chrome.storage.local.set hsh, () ->
            if handlers[setting]
              for handler in handlers[setting]
                handler.call()

        get: () ->
          return obj['setting-'+setting]
      }
    )(setting)

  obj.on = (types..., func) ->
    for type in types
      console.log ("Invalid Event!") if settings.indexOf(type) < 0 && ['ready'].indexOf(type) < 0
      if handlers[type]
        handlers[type].push(func)
      else
        handlers[type] = [func]

  obj.listSettings = () ->
    return settings

  chrome.storage.onChanged.addListener (changes, areaName) ->
    for own key, val of changes
      if obj.hasOwnProperty(key)
        obj[key] = val.newValue

  return obj
)()

#If we are using the Logger extension -- make sure we grab its level from the settings, and set it up

if Logger
  Logger.useDefaults()
  AppSettings.on 'logLevel', 'ready', (settings) ->
    Logger.setLevel(AppSettings.logLevel)

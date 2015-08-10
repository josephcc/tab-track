###
#
# API used for parsing the information stored in chrome.storage for searches
#
###
root = exports ? this

persistToFile = (filename, csv) ->
  onInitFs = (fs) ->
    fs.root.getFile(filename, {create:true}, (fileEntry) ->
      fileEntry.createWriter( (writer) ->
        blob = new Blob([csv], {type: 'text/csv'})
        writer.seek(writer.length)
        writer.write(blob)
      , errorHandler)
    , errorHandler)
  window.webkitRequestFileSystem(window.PERSISTENT, 50*1024*1024, onInitFs, errorHandler)

root.db = new Dexie('tabTrack')
db.version(1).stores({
  TabInfo: '++id,action,snapshotId,time'
  FocusInfo: '++id,tabId,time'
  NavInfo: '++id,time'
})

root.TabInfo = (params) ->
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
    checkSync(self)
    return self
  
root.FocusInfo = (params) ->
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
    checkSync(self)
    return self

root.NavInfo = (params) ->  
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
    checkSync(self)
    return self

db.NavInfo.mapToClass(root.NavInfo)
db.FocusInfo.mapToClass(root.FocusInfo)
db.TabInfo.mapToClass(root.TabInfo)
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
root.AppSettings = (() ->
  #Define any defaults here
  obj =
    'setting-syncInterval': 7200000
    'setting-autoSync': false
    'setting-trackDomain': true
    'setting-trackURL': true
    'setting-retryInterval': 1200000
  #Global settings
  settings = ['userID', 'userSecret', 'trackURL', 'trackDomain', 'logLevel', 'autoSync', 'syncInterval', 'lastSync', 'syncProgress', 'retryInterval']
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

# If AppSettings.autoSync is set, we will autmatically sync the information in our DB with our backend
# in 2hr intervals (usually)
checkSync = (item) ->
  if AppSettings.autoSync and item.time - AppSettings.lastSync > AppSettings.syncInterval and chrome.extension.getBackgroundPage() == window
    lastSync = AppSettings.lastSync
    AppSettings.lastSync = Date.now()
    worker = new Worker('/js/syncer.js')
    getToken = null
    if !AppSettings.userID
      AppSettings.userSecret = generateUUID()
      getToken = Promise.resolve($.ajax({
        url: 'https://report-tabs.cmusocial.com/auth/newClient'
        data: {secret: AppSettings.userSecret}
        method: "POST"
        contentType: 'application/json'
        dataType: 'json'
      })).then (res) ->
        AppSettings.userID = res.user
        return res
    else
      getToken = Promise.resolve($.ajax({
        url: 'https://report-tabs.cmusocial.com/auth/getToken'
        data: {secret: AppSettings.userSecret, user: AppSettings.userID}
        method: "POST"
        contentType: 'application/json'
        dataType: 'json'
      }))
    getToken.then (res) ->
      worker.postMessage({cmd: 'sync', token: res.token})
      worker.addEventListener 'message', (msg) ->
        switch msg.data.cmd
          when 'syncFailed'
            AppSettings.syncProgress = {status: 'failed', err: msg.data.err, lastSuccess: lastSync}
            AppSetting.lastSync = Date.now() - AppSettings.syncInterval + AppSettings.retryInterval
          when 'syncStatus'
            AppSettings.syncProgress = {status: 'syncing', total: msg.data.total, stored: msg.data.stored}
          when 'syncComplete'
            AppSettings.syncProgress = {status: 'complete', time: Date.now()}
    .catch (err) ->
      worker.terminate()
      Logger.error(err)
        
#If we are using the Logger extension -- make sure we grab its level from the settings, and set it up

if Logger?
  Logger.useDefaults()
  AppSettings.on 'logLevel', 'ready', (settings) ->
    Logger.setLevel(AppSettings.logLevel)

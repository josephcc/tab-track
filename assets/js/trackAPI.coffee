###
#
# API used for parsing the information stored in chrome.storage for searches
#
###
root = exports ? this
TABSERVER = "http://localhost:8080" # "http://report-tabs.cmusocial.com" TODO set me to the right URL

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
    url: ''
    domain: ''
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
  return if !chrome?
  #Define any defaults here
  obj =
    'setting-syncInterval': 7200000
    'setting-autoSync': false
    'setting-trackDomain': true
    'setting-trackURL': true
    'setting-retryInterval': 10 #1200000 TODO reset me to the right retry interval
    'setting-syncStop': new Date(0)
    'setting-nextSync': Date.now()
    'setting-syncProgress': {}
  #Global settings
  settings = ['userID', 'userSecret', 'trackURL', 'trackDomain', 'logLevel', 'autoSync', 'syncInterval', 'syncStop', 'nextSync', 'syncProgress', 'retryInterval', 'encryptionKey']
  handlers = {}
  expandedSettings = _.map settings, (itm) -> 'setting-'+itm
  ready = false #Let us know if we are ready yet -- if we already are, go ahead and call any new ready handlers

  chrome.storage.local.get expandedSettings, (items) ->
    for own key, val of items
      obj[key] = val
    ready = true
    for handler in handlers.ready
      handler.call(obj)


  for setting in settings
    ((setting) ->
      Object.defineProperty obj, setting, {
        set: (value) ->
          if value instanceof Date
            value = value.getTime()
          hsh = {}
          hsh['setting-'+setting] = value
          obj['setting-'+setting] = value
          chrome.storage.local.set hsh, () ->

        get: () ->
          return obj['setting-'+setting]
      }
    )(setting)

  obj.on = (types..., func) ->
    for type in types
      console.log ("Invalid Event!") if settings.indexOf(type) < 0 && ['ready'].indexOf(type) < 0
      return func(this) if type == "ready" and ready #If we have already loaded everything, just call the ready event already
      if handlers[type]
        handlers[type].push(func)
      else
        handlers[type] = [func]

  obj.listSettings = () ->
    return settings

  chrome.storage.onChanged.addListener (changes, areaName) ->
    for own key, val of changes
      if expandedSettings.indexOf(key) >= 0
        obj[key] = val.newValue
        if handlers[key.substring(8)]
          for handler in handlers[key.substring(8)]
            handler.call()

  return obj
)()

# If AppSettings.autoSync is set, we will autmatically sync the information in our DB with our backend
# in 2hr intervals (usually)
checkSync = (item) ->
  if AppSettings.autoSync and item.time > AppSettings.nextSync and chrome.extension.getBackgroundPage() == window
    Logger.info "Starting Sync"
    nextSync = AppSettings.nextSync
    AppSettings.nextSync = Date.now() + AppSettings.syncInterval
    worker = new Worker('/js/syncer.js')
    getToken = null
    if !AppSettings.userID
      AppSettings.userSecret = generateUUID()
      getToken = Promise.resolve($.ajax({
        url: "#{TABSERVER}/auth/newClient"
        data: {secret: AppSettings.userSecret}
        jsonp: false,
        method: "POST"
        dataType: 'json'
      })).then (res) ->
        AppSettings.userID = res.user
        return res
    else
      getToken = Promise.resolve($.ajax({
        url: "#{TABSERVER}/auth/getToken"
        data: {secret: AppSettings.userSecret, user: AppSettings.userID}
        jsonp: false,
        method: "POST"
        dataType: 'json'
      }))
    getToken.then (res) ->
      Logger.debug "Token retreival successful"
      worker.postMessage({cmd: 'sync', token: res.token, syncStop: res.lastSync})
      worker.addEventListener 'message', (msg) ->
        switch msg.data.cmd
          when 'syncFailed'
            Logger.error "Sync failure #{msg.data.err}"
            AppSettings.syncProgress = {status: 'failed', err: msg.data.err, lastSuccess: AppSettings.syncStop}
            AppSettings.nextSync = Date.now() + AppSettings.retryInterval
          when 'syncStatus'
            AppSettings.syncProgress = {status: 'syncing', total: msg.data.total, stored: msg.data.stored}
            AppSettings.syncStop = msg.data.stoppedPoint
            Logger.info "Sync progress #{Math.floor((msg.data.stored / msg.data.total) * 100)} %"
          when 'syncComplete'
            Logger.info "Sync Complete"
            AppSettings.syncProgress = {status: 'complete', time: Date.now()}
            AppSettings.syncStop = msg.data.stoppedPoint
            AppSettings.nextSync = Date.now() + AppSettings.syncInterval
    .catch (err) ->
      AppSettings.syncProgress = {status: 'failed', err: err, lastSuccess: AppSettings.syncStop}
      AppSettings.nextSync = Date.now() + AppSettings.retryInterval
      worker.terminate()
      Logger.error(err)
        
#If we are using the Logger extension -- make sure we grab its level from the settings, and set it up

if Logger?
  Logger.useDefaults()
  AppSettings.on 'logLevel', 'ready', (settings) ->
    Logger.setLevel(AppSettings.logLevel)

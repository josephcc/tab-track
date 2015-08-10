####
#
# File that performs background sync of Tab DB to remote server
#
####

importScripts('/vendor/underscore/underscore-min.js')
importScripts('/vendor/bluebird/js/browser/bluebird.min.js')
importScripts('/vendor/dexie/dist/latest/Dexie.min.js')
importScripts('/js/trackAPI.js')
importScripts('/vendor/socket.io/socket.io.js')

self.onmessage = (msg) ->
  #Messages from the initial scope
  switch message.data.cmd
    when 'sync'
      performSync(message.data.token)

performSync = (token) ->
  socket = io('https://report-tabs.cmusocial.com:8080/sync', {
    'query': 'token=' + token
    reconnectionAttempts: 5
    timeout: 10
  })
  ### Do we need these?
  socket.on 'reconnect_failed', (err) ->
    reportErr(err)
  socket.on 'reconnect_error', (err) ->
    reportErr(err)
  socket.on 'connect_error', (err) ->
    reportErr(err)
  socket.on 'connect_timeout', (err) ->
    reportErr(err)
  ###
  socket.on 'error', (err) ->
    reportErr(err)
 
  query1 = db.TabInfo.where('time').aboveOrEqual('AppSettings.lastSync')
  query2 = db.FocusInfo.where('time').aboveOrEqual('AppSettings.lastSync')
  query3 = db.NavInfo.where('time').aboveOrEqual('AppSettings.lastSync')
  Promise.all([query1.count(), query2.count(), query3.count()]).spread (tabCnt, focusCnt, navCnt) ->
    stored1 = stored2 = stored3 = 0
    socket.on 'stored', (res) ->
      switch res.type
        when 'TabInfo' then stored1 = res.packet
        when 'FocusInfo' then stored2 = res.packet
        when 'NavInfo' then stored3 = res.packet
    
    #Every 5 seconds, post a message, updating our sync status
    statusUpdateTimeout = setTimeout( () ->
      self.postMessage({cmd: 'syncStatus', total: tabCnt+focusCnt+navCnt, stored: stored1+stored2+stored3})
    , 5000)

    socket.on 'syncErr', (err) ->
      reportErr(err)

    navComplete = tabComplete = focusComplete = false
    socket.on 'complete', (res) ->
      switch res.type
        when 'TabInfo' then tabComplete = true
        when 'FocusInfo' then focusComplete = true
        when 'NavInfo' then navComplete = true
      if tabComplete and navComplete and focusComplete
        socket.disconnect()
        clearInterval(statusUpdateTimeout)
        self.postMessage({cmd: 'syncComplete'})
        self.close()

    num1 = num2 = num3 = 0
    query1.each (record) ->
      socket.emit 'TabInfoSync', {packet: ++num1, data: record}
    .then () ->
      socket.emit 'TabInfoSync', {action: 'complete'}
    query2.each (record) ->
      socket.emit 'FocusInfoSync', {packet: ++num2, data: record}
    .then () ->
      socket.emit 'FocusInfoSync', {action: 'complete'}
    query3.each (record) ->
      socket.emit 'NavInfoSync', {packet: ++num3, data: record}
    .then () ->
      socket.emit 'NavInfoSync', {action: 'complete'}

reportErr = (err) ->
  self.postMessage({cmd: 'syncFailed', err: err})
  self.close()

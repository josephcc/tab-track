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
  switch msg.data.cmd
    when 'sync'
      performSync(msg.data.token, msg.data.lastSync)

performSync = (token, lastSync) ->
  #socket = io('https://report-tabs.cmusocial.com:8080/sync', { TODO set me to the right server
  socket = io('http://localhost:8080/sync', {
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
 
  tables = ['TabInfo', 'FocusInfo', 'NavInfo']
  queries = []
  for table in tables
    queries.push(db[table].where('time').aboveOrEqual(lastSync))
  Promise.all(_.map(queries, (q) -> q.count())).then (counts) ->
    stored = _.object(_.map(tables, (t) -> [t, 0]))
    
    socket.on 'stored', (res) ->
      stored[res.type] = res.packet
      console.log("Stored #{res.type} #{res.packet}")

    #Every 5 seconds, post a message, updating our sync status
    statusUpdateTimeout = setTimeout( () ->
      self.postMessage({cmd: 'syncStatus', total: _.reduce(counts, ((m, n) -> m + n), 0), stored: _.reduce(counts, ((m, v) -> m + v), 0)})
    , 5000)

    socket.on 'syncErr', (err) ->
      reportErr(err)

    complete = _.object(_.map(tables, (t) -> [t, false]))
    socket.on 'complete', (res) ->
      complete[res.type] = true
      console.log(res)
      if _.reduce(complete, ((m, v) -> m and v), true) 
        socket.disconnect()
        clearInterval(statusUpdateTimeout)
        self.postMessage({cmd: 'syncComplete'})
        self.close()

    Promise.all(_.map(queries, (q) ->
      cnt = 0
      q.each (record) ->
        socket.emit q._ctx.table.name+'Sync', {packet: ++cnt, data: record}
      .then () ->
        socket.emit q._ctx.table.name+'Sync', {action: 'complete'}
    )).then () ->
      console.log("Send complete!")
  .catch (err) ->
    reportErr(err)

reportErr = (err) ->
  self.postMessage({cmd: 'syncFailed', err: err})
  self.close()

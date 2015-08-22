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

msgHandlers = []

self.onmessage = (msg) ->
  #Messages from the initial scope
  for handler in msgHandlers
    handler(msg.data)
  switch msg.data.cmd
    when 'sync'
      performSync(msg.data.token, msg.data.syncStop, msg.data.external)

performSync = (token, lastStop, external) ->
  #socket = io('https://report-tabs.cmusocial.com:8080/sync', { TODO set me to the right server
  unless external
    socket = io('http://localhost:8080/sync', {
      'query': 'token=' + token
      reconnectionAttempts: 5
      timeout: 10
    })
    socket.on 'error', (err) ->
      reportErr(err)
 
  sendMessage = (dest, message) ->
    if external
      self.postMessage(_.assign(message, {table: dest, cmd: 'send'}))
    else
      socket.emit(dest, message)

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
  
  tables = ['TabInfo', 'FocusInfo', 'NavInfo']
  queries = []
  for table in tables
    queries.push(db[table].where('time').aboveOrEqual(lastStop))
  Promise.all(_.map(queries, (q) -> q.count())).then (counts) ->
    stored = _.object(_.map(tables, (t) -> [t, 0]))
    complete = _.object(_.map(tables, (t) -> [t, false]))
    stoppedPoint = lastStop
    
    storeUpdate = (msg) ->
      stored[msg.type] = msg.packet
      stoppedPoint = if msg.time > stoppedPoint then msg.time else stoppedPoint

    completeCheck = (msg) ->
      complete[msg.type] = true
      if _.reduce(complete, ((m, v) -> m and v), true)
        socket.disconnect() unless external
        clearInterval(statusUpdateTimeout)
        self.postMessage({cmd: 'syncComplete', stoppedPoint: msg.time})
        self.close()

    if external
      msgHandlers.push((msg) ->
        switch msg.cmd
          when 'stored' then storeUpdate(msg)
          when 'complete' then completeCheck(msg)
      )
    else
      socket.on 'stored', storeUpdate
      socket.on 'complete', completeCheck
      socket.on 'syncErr', (err) ->
        reportErr(err)

    #Every 5 seconds, post a message, updating our sync status
    statusUpdateTimeout = setInterval( () ->
      self.postMessage({cmd: 'syncStatus', total: _.reduce(counts, ((m, n) -> m + n), 0), stored: _.reduce(stored, ((m, v) -> m + v), 0), stoppedPoint: stoppedPoint})
    , 3000)

    currentStop = Date.now()
    Promise.all(_.map(queries, (q) ->
      cnt = 0
      q.each (record) ->
        delete record.url
        delete record.domain
        sendMessage(q._ctx.table.name+'Sync', {packet: ++cnt, data: record})
      .then () ->
        sendMessage(q._ctx.table.name+'Sync', {action: 'complete', time: currentStop})
    )).then () ->
      console.log("Send complete!")
  .catch (err) ->
    reportErr(err)

reportErr = (err) ->
  self.postMessage({cmd: 'syncFailed', err: err.message})
  self.close()

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
      performSync(msg.data.token, msg.data.stopPoints, msg.data.external)

performSync = (token, stopPoints, external) ->
  unless external
    #socket = io('http://localhost:8080/sync', {
    socket = io('wss://report-tabs.cmusocial.com:8443/sync', {
      transports: ['websocket']
      'query': 'token=' + token
      reconnectionAttempts: 5
    })
    socket.on 'error', (err) ->
      reportErr(err)
 
  sendMessage = (dest, message) ->
    if external
      self.postMessage(_.assign(message, {table: dest, cmd: 'send'}))
    else
      socket.emit(dest, message)

  #Do we need these?
  socket.on 'reconnect_failed', (err) -> reportErr({message: "Socket.io reconnect failure"})

  tables = ['TabInfo', 'FocusInfo', 'NavInfo']
  queries = []
  console.log(stopPoints)
  for table in tables
    queries.push(db[table].where('id').above(stopPoints[table]))
  Promise.all(_.map(queries, (q) -> q.count())).then (counts) ->
    stored = _.object(_.map(tables, (t) -> [t, 0]))
    complete = _.object(_.map(tables, (t) -> [t, false]))
    
    storeUpdate = (msg) ->
      stored[msg.type] = msg.packet
      stopPoints[msg.type] = msg.id

    completeCheck = (msg) ->
      complete[msg.type] = true
      if _.reduce(complete, ((m, v) -> m and v), true)
        socket.disconnect() unless external
        clearInterval(statusUpdateTimeout)
        self.postMessage({cmd: 'syncComplete', stoppedPoint: stopPoints})
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
      self.postMessage({cmd: 'syncStatus', total: _.reduce(counts, ((m, n) -> m + n), 0), stored: _.reduce(stored, ((m, v) -> m + v), 0), stoppedPoint: stopPoints})
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

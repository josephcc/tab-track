#Longer lived interactions we want here
chrome.runtime.onConnectExternal.addListener (port) ->
  switch port.name
    when "sync" then syncConnection(port)
    when "decryption" then decryptionConnection(port)

#For short requests.. use just a simple one-time request
chrome.runtime.onMessageExternal.addListener (request, sender, sendResponse) ->
  #TODO authenticate the sender??
  console.log("Recieved externalMessage")
  switch request.cmd
    when "auth"
      if AppSettings.userID
        sendResponse({cmd: 'getToken', user: AppSettings.userID, secret: AppSettings.userSecret})
      else
        AppSettings.userSecret = generateUUID()
        sendResponse({cmd: 'newClient', secret: AppSettings.userSecret})
    when "saveID" then AppSettings.userID = request.user

syncConnection = (port, syncStop) ->
  worker = new Worker('/js/syncer.js')
  worker.addEventListener 'message', (msg) ->
    switch msg.data.cmd
      when 'syncFailed'
        Logger.error "Sync failure #{msg.data.err}"
        AppSettings.syncProgress = {status: 'failed', err: msg.data.err, lastSuccess: AppSettings.syncStop}
        AppSettings.nextSync = Date.now() + AppSettings.retryInterval
        port.postMessage({cmd: 'failure', time: AppSettings.syncProgress.time})
        port.disconnect()
      when 'syncStatus'
        AppSettings.syncProgress = {status: 'syncing', total: msg.data.total, stored: msg.data.stored}
        AppSettings.syncStop = msg.data.stoppedPoint
        port.postMessage(_.extend({cmd: 'update'}, AppSettings.syncProgress))
        Logger.info "Sync progress #{Math.floor((msg.data.stored / msg.data.total) * 100)} %"
      when 'syncComplete'
        Logger.info "Sync Complete"
        AppSettings.syncProgress = {status: 'complete', time: Date.now()}
        AppSettings.syncStop = msg.data.stoppedPoint
        AppSettings.nextSync = Date.now() + AppSettings.syncInterval
        port.postMessage({cmd: 'complete', time: AppSettings.syncProgress.time})
      else
        port.postMessage(msg.data)
 
  port.onMessage.addListener (msg) ->
    switch msg.cmd
      when 'start'
        worker.postMessage({cmd: 'sync', syncStop: msg.lastSync, external: true})
      when 'syncErr'
        worker.terminate()
        Logger.error(err)
      else
        worker.postMessage(msg)

  port.onDisconnect.addListener () ->
    worker.terminate()


decryptionConnection = (port) ->
  port.onMessage.addListener (msg) ->
    decrypted = CryptoJS.AES.decrypt(msg.encrypted, AppSettings.encryptionKey).toString()
    port.postMessage({decrypted: decrypted})

chrome.runtime.onInstalled.addListener (details) ->
  switch details.reason
    when "install"
      chrome.tabs.create {'url': chrome.extension.getURL('/html/interface.html?reason=installed')}, (tab) ->
        Logger.info("Extension installed!")
    when "update"
      thisVersion = chrome.runtime.getManifest().version
      console.log("Updated from " + details.previousVersion + " to " + thisVersion + "!")
    when "chrome_update" then Logger.info("Extension Updated")

  AppSettings.on 'ready', () ->
    if !AppSettings.encryptionKey
      AppSettings.encryptionKey = generateUUID()


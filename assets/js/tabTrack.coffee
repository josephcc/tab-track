###
# This file keeps track of the Google searches a person performs in the background. It saves them
# in the local storage in the "queries" variable
###

console.log 'start'
takeSnapshot = (action) ->
  chrome.tabs.query {windowType: 'normal'}, (tabs) ->
    chrome.windows.getCurrent null, (window) ->
        console.log '========== BEGIN SNAPSHOT =========='
        console.log 'track - ' + action
        console.log window
        saveTabs = []
        snapshotId = generateUUID()
        console.log tabs
        time = Date.now()
        for tab in tabs
          tab.inActiveWindow = tab.windowId == window.id
          tab.snapshotAction = action
          tab.domain = URI(tab.url).domain()
          tab.urlHash = CryptoJS.MD5(tab.url).toString()
          tab.domainHash = CryptoJS.MD5(tab.domain).toString()
          tab.snapshotId = snapshotId
          tab.time = time
          
          delete tab.width
          delete tab.height
          delete tab.selected
          delete tab.highlighted
          delete tab.incognito

          console.log tab
          saveTabs.push tab

        TabInfo.db.insert(saveTabs)
        console.log '========== END   SNAPSHOT =========='

trackFocus = (windowId, tabId) ->
  console.log 'activated - ' + windowId + ':' + tabId

trackRepalce = (removedTabId, addedTabId) ->
  console.log 'replaced - ' + addedTabId + ':' + removedTabId

chrome.tabs.onUpdated.addListener (tabId, changeInfo, tab) ->
  if not changeInfo.status?
    console.log changeInfo
    return
  takeSnapshot('updated:' + changeInfo.status)

chrome.tabs.onAttached.addListener (tabId, attachInfo) ->
  takeSnapshot('attached')

chrome.tabs.onRemoved.addListener (tabId, removeInfo) ->
  takeSnapshot('removed')

chrome.tabs.onActivated.addListener (activeInfo) ->
  trackFocus(activeInfo.windowId, activeInfo.tabId)

chrome.windows.onFocusChanged.addListener (windowId) ->
    chrome.tabs.query {active: true, windowId: windowId, currentWindow: true}, (tabs) ->
      if tabs.length > 0
        tab = tabs[0]
        trackFocus(windowId, tab.id)

chrome.tabs.onReplaced.addListener (addedTabId, removedTabId) ->
  trackReplace(removedTabId, addedTabId)


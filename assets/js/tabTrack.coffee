
console.log 'start'
takeSnapshot = (action) ->
  snapshotId = generateUUID()
  time = Date.now()
  chrome.tabs.query {windowType: 'normal'}, (tabs) ->
    console.log '========== BEGIN SNAPSHOT =========='
    console.log 'track - ' + action
    saveTabs = []
    for tab in tabs
      tabInfo = new TabInfo(_.extend({
        action: action
        domain: URI(tab.url).domain()
        urlHash: CryptoJS.MD5(tab.url).toString(CryptoJS.enc.Base64)
        domainHash: CryptoJS.MD5(tab.domain).toString(CryptoJS.enc.Base64)
        tabId: tab.id
        snapshotId: snapshotId
      }, tab))
      
      saveTabs.push tabInfo

    compare = (x, y) ->
      if (x == y)
        return 0
      return x > y ? 1 : -1;
    saveTabs.sort (x, y) ->
      if x.windowId == y.windowId
        return compare x.index, y.index
      return compare x.windowId, y.windowId
    globalIndex = 0
    for tab in saveTabs
      tab.globalIndex = globalIndex++
    console.log saveTabs

    tab.save() for tab in saveTabs
    console.log saveTabs
    console.log '========== END   SNAPSHOT =========='

trackFocus = (action, windowId, tabId) ->
  console.log 'activated - ' + windowId + ':' + tabId
  data = new FocusInfo({windowId: windowId, tabId: tabId, action: action, time: Date.now()})
  data.save()

trackReplace = (removedTabId, addedTabId) ->
  console.log 'replaced - ' + addedTabId + ':' + removedTabId
#  data = {type: 'replace', from: removedTabId, to: addedTabId, time: Date.now()}
#  TabInfo.db.insert(data)

chrome.tabs.onUpdated.addListener (tabId, changeInfo, tab) ->
  if not changeInfo.status?
    console.log changeInfo
    return
  # TODO: google doc pages will never finish loading
  if not changeInfo.url? and tab.url.match(/https:\/\/docs.google.com\/.*\/edit.*/)?
    return

  takeSnapshot('updated:' + changeInfo.status)

chrome.tabs.onAttached.addListener (tabId, attachInfo) ->
  takeSnapshot('attached:' + attachInfo.newWindowId + ':' + attachInfo.newPosition)

chrome.tabs.onMoved.addListener (tabId, moveInfo) ->
  takeSnapshot('moved:' + moveInfo.windowId + ':' + moveInfo.fromIndex + ':' + moveInfo.toIndex)

chrome.tabs.onRemoved.addListener (tabId, removeInfo) ->
  takeSnapshot('removed:' + removeInfo.windowId + ':' + removeInfo.isWindowClosing)

chrome.tabs.onActivated.addListener (activeInfo) ->
  trackFocus('tabChange', activeInfo.windowId, activeInfo.tabId)

chrome.windows.onFocusChanged.addListener (windowId) ->
    chrome.tabs.query {active: true, windowId: windowId, currentWindow: true}, (tabs) ->
      if tabs.length > 0
        tab = tabs[0]
        trackFocus('windowChange', windowId, tab.id)

chrome.tabs.onReplaced.addListener (addedTabId, removedTabId) ->
  trackReplace(removedTabId, addedTabId)

chrome.webNavigation.onCreatedNavigationTarget.addListener (details) ->
  console.log 'nav: ' + details.sourceTabId + ' -> ' + details.tabId
  data = new NavInfo({from: details.sourceTabId, to: details.tabId, time: Date.now()})
  data.save()

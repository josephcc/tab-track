
console.log 'start'
compare = (x, y) ->
  if (x == y)
    return 0
  return x > y ? 1 : -1

takeSnapshot = (action) ->
  snapshotId = generateUUID()
  time = Date.now()
  chrome.tabs.query {windowType: 'normal'}, (tabs) ->
    Logger.debug '========== BEGIN SNAPSHOT =========='
    Logger.debug 'track - ' + action
    AppSettings.on 'ready', () ->
      saveTabs = []
      for tab in tabs
        domain = URI(tab.url).domain()
        matches = tab.url.match(/www\.google\.com\/.*q=(.*?)($|&)/)
        if matches?
          query = decodeURIComponent(matches[1].replace(/\+/g, ' '))
          query = query.split(' ')
          query = _.map query, (kw) ->
            return CryptoJS.AES.encrypt(kw, AppSettings.encryptionKey).toString()
          query = query.join(' ')
        else
          query = null
        tabInfo = new TabInfo(_.extend({
          action: action
          domain: domain
          url: tab.url
          urlHash: CryptoJS.AES.encrypt(tab.url, AppSettings.encryptionKey).toString()
          domainHash: CryptoJS.AES.encrypt(domain, AppSettings.encryptionKey).toString()
          tabId: tab.id
          snapshotId: snapshotId
          query: query
          time: time
        }, tab))
        saveTabs.push tabInfo

      saveTabs.sort (x, y) ->
        if x.windowId == y.windowId
          return compare x.index, y.index
        return compare x.windowId, y.windowId
      globalIndex = 0
      for tab in saveTabs
        tab.globalIndex = globalIndex++
      Logger.debug saveTabs

      tab.save() for tab in saveTabs
      Logger.debug saveTabs
      Logger.debug '========== END   SNAPSHOT =========='

trackFocus = (action, windowId, tabId) ->
  Logger.debug 'activated - ' + windowId + ':' + tabId
  data = new FocusInfo({windowId: windowId, tabId: tabId, action: action, time: Date.now()})
  data.save()

trackReplace = (removedTabId, addedTabId) ->
  Logger.debug 'replaced - ' + addedTabId + ':' + removedTabId
#  data = {type: 'replace', from: removedTabId, to: addedTabId, time: Date.now()}
#  TabInfo.db.insert(data)

chrome.tabs.onUpdated.addListener (tabId, changeInfo, tab) ->
  if not changeInfo.status?
    Logger.debug changeInfo
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
  try
    Logger.debug 'nav: ' + details.sourceTabId + ' -> ' + details.tabId
    data = new NavInfo({from: details.sourceTabId, to: details.tabId, time: Date.now()})
    data.save()
  catch err
    console.info(err)

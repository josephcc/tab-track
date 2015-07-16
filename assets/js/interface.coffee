chrome.browserAction.onClicked.addListener (callback) ->
  chrome.tabs.create {'url': chrome.extension.getURL('/html/interface.html')}, (tab) ->
    # Tab opened.

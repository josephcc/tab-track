
objects2csv = (objects, attributes) ->
  csvData = new Array()
  csvData.push '"' + attributes.join('","') + '"'
  for object in objects
    row = []
    for attribute in attributes
      row.push ("" + object[attribute]).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
    csvData.push '"' + row.join('","') + '"'
  return csvData.join('\n') + '\n'

downloadCsv = (filename, csv, spillfile) ->
  onInitFs = (fs) ->
    console.log('Opened file system: ' + fs.name)
    fsFilename = generateUUID() + '.csv'
    fs.root.getFile(spillfile, {create: true}, (spillFileEntry) ->

      spillFileEntry.copyTo fs.root, fsFilename, () ->

        fs.root.getFile(fsFilename, {create: false}, (fileEntry) ->
          fileEntry.createWriter (writer) ->
            writer.onwriteend = (e) ->
              console.log('write done')
              console.log fileEntry.toURL()
              a = document.createElement('a')
              a.href = fileEntry.toURL()
              a.target ='_blank'
              a.download = filename
              a.click()
            blob = new Blob([csv], {type: 'text/csv'})
            writer.seek(writer.length)
            writer.write(blob)

            setTimeout( () ->
              console.log 'removing tmp download file'
              fs.root.getFile(fsFilename, {create: false}, (fileEntry) ->
                fileEntry.remove(() ->
                  console.log('File removed.')
                , errorHandler)
              , errorHandler)
            , 10000)

          , errorHandler)

      , errorHandler)
  window.webkitRequestFileSystem(window.PERSISTENT, 50*1024*1024, onInitFs, errorHandler);


errorHandler = (e) ->
  msg = ''

  switch (e.code)
    when FileError.QUOTA_EXCEEDED_ERR
      msg = 'QUOTA_EXCEEDED_ERR'
    when FileError.NOT_FOUND_ERR
      msg = 'NOT_FOUND_ERR'
    when FileError.SECURITY_ERR
      msg = 'SECURITY_ERR'
    when FileError.INVALID_MODIFICATION_ERR
      msg = 'INVALID_MODIFICATION_ERR'
    when FileError.INVALID_STATE_ERR
      msg = 'INVALID_STATE_ERR'
    else
      msg = 'Unknown Error'

  console.log('Error: ' + msg)

$('.download.all').click () ->
  tabs = TabInfo.db({type: 'tab'}).get()
  attributes = ['snapshotId', 'windowId', 'id', 'openerTabId', 'index', 'status', 'snapshotAction', 'domain', 'url', 'domainHash', 'urlHash', 'favIconUrl', 'time']
  csv = objects2csv(tabs, attributes)
  downloadCsv('tabLogs.csv', csv, '_tabLogs.csv')

  focuses = TabInfo.db({type: 'focus'}).get()
  attributes = ['action', 'windowId', 'tabId', 'time']
  csv = objects2csv(focuses, attributes)
  downloadCsv('focusLogs.csv', csv, '_focusLogs.csv')

  navs = TabInfo.db({type: 'nav'}).get()
  attributes = ['from', 'to', 'time']
  csv = objects2csv(navs, attributes)
  downloadCsv('navLogs.csv', csv, '_navLogs.csv')

$('.render').click () ->
  render()

$('.database.kill').click () ->
  console.log "KILL DB"
  TabInfo.clearDB()
  alert 'database deleted'


lighten = (c, d) ->
  c = c * (1-d) + (255 * d)
  return Math.round(c)

hashStringToColor = (str) ->
  hash = CryptoJS.MD5("" + str)
  r = (hash.words[0] & 0xFF0000) >> 16
  g = (hash.words[0] & 0x00FF00) >> 8
  b = hash.words[0] & 0x0000FF
  r = lighten(r, 0.4)
  g = lighten(g, 0.4)
  b = lighten(b, 0.4)
  return 'rgba(' + r + ", " + g + ", " + b + ', 1.0)'
#  return "#" + ("0" + r.toString(16)).substr(-2) + ("0" + g.toString(16)).substr(-2) + ("0" + b.toString(16)).substr(-2);

pleaseColors = Please.make_color({
    saturation: 1.0,
    colors_returned: 100,
    format: 'hex',
    full_random: true
})

please = (id) ->
  hash = CryptoJS.MD5("" + id)
  id = Math.abs(hash.words[0])
  pleaseColors[id%100]

plot =
    height: 750
    tabHeight: 30
    timelineHeight: 35
    timelineMargin: 4
    timeTickWidth: 100
    seamWidth: 0.05
#    color: d3.scale.category20()
#    color: please
    color: hashStringToColor
    scaleX: 1.0
    scaleMin: 0.01
    scaleMax: 100
    translateX: 0.0
    inFocusColor: '#fafafa'
    outFocusColor: 'black'
    tabLoadingColor: 'black'
    branchMinWidth: 5
    branchColor: 'red'
    branchStrokeWidth: 1.2
    focusPathWidth: 1.1
    focusBubbleRadius: 2.0

plot.focusLineFunction = d3.svg.line()
   .x((d) -> (d.x * plot.scaleX) + plot.translateX)
   .y((d) -> d.y)
   .interpolate("step-after")

_render_timeline = () ->
  ticks = (tick for tick in [plot.timeTickWidth..(plot.width - plot.timeTickWidth)] by plot.timeTickWidth)
  plot.svg.selectAll('line.timeline')
    .data([0])
    .enter()
    .append('line')
    .attr('class', 'timeline')
    .attr('x1', (tick, index) -> return 0)
    .attr('y1', (tick, index) -> plot.timelineHeight)
    .attr('x2', (tick, index) -> return plot.width - 5)
    .attr('y2', (tick, index) -> plot.timelineHeight)
    .attr('stroke', 'black')
    .attr('marker-start', 'url(#marker_stub)')
    .attr('marker-end', 'url(#marker_arrow)')

  plot.svg.selectAll('line.timeTick')
    .data(ticks)
    .enter()
    .append('line')
    .attr('class', 'timeTick')
    .attr('x1', (tick, index) -> return tick)
    .attr('y1', (tick, index) -> 0)
    .attr('x2', (tick, index) -> return tick)
    .attr('y2', (tick, index) -> plot.timelineHeight)
    .attr('stroke', 'black')

  plot._svg.selectAll('text.dateTick')
    .data(ticks)
    .enter()
    .append('text')
    .attr('class', 'dateTick')
    .text((tick, index) ->
      unixtime = getTimeForX(parseInt(tick))
      date = new Date()
      date.setTime(unixtime)
      dateString = date.toLocaleDateString("en-US")
      return dateString
    )
    .attr('x', (tick, index) -> return tick + 4)
    .attr('y', (tick, index) -> return plot.timelineHeight/2 - 2)
    .attr('font-size', plot.timelineHeight * 0.9 / 2)

  plot.svg.selectAll('line.timeTick')
    .data(ticks)
    .enter()
    .append('line')
    .attr('class', 'timeTick')
    .attr('x1', (tick, index) -> return tick)
    .attr('y1', (tick, index) -> 0)
    .attr('x2', (tick, index) -> return tick)
    .attr('y2', (tick, index) -> plot.timelineHeight)
    .attr('stroke', 'black')
  plot._svg.selectAll('text.timeTick')
    .data(ticks)
    .enter()
    .append('text')
    .attr('class', 'timeTick')
    .text((tick, index) ->
      unixtime = getTimeForX(parseInt(tick))
      date = new Date()
      date.setTime(unixtime)
      dateString = date.getHours() + ":" + date.getMinutes() + ":" + date.getSeconds()
      return dateString
    )
    .attr('x', (tick, index) -> return tick + 4)
    .attr('y', (tick, index) -> return plot.timelineHeight - 2)
    .attr('font-size', plot.timelineHeight * 0.9 / 2)

_render_branches = () ->
  _branches = TabInfo.db({type: 'nav'}).get()
  branches = []
  for branch in _branches
    fromTab = getTabForIdTime(branch.from, branch.time)
    toTab = getTabForIdTime(branch.to, branch.time)
    branches.push [toTab, fromTab]

  plot._svg.selectAll('line.branch_down')
    .data(branches)
    .enter()
    .append('line')
    .attr('class', 'branch_down')
    .attr('stroke-width', plot.branchStrokeWidth)
    .attr('x1', (branch, index) ->
      [tab, from] = branch
      getXForTime(tab.time) - plot.seamWidth -  Math.max(plot.branchMinWidth, getWidthForTimeRange(from.endTime, tab.time))
    )
    .attr('y1', (branch, index) ->
      [tab, from] = branch
      getYForIndex(from.index) + plot.tabHeight
    )
    .attr('x2', (branch, index) ->
      [tab, from] = branch
      getXForTime(tab.time) - plot.seamWidth -  Math.max(plot.branchMinWidth, getWidthForTimeRange(from.endTime, tab.time))
    )
    .attr('y2', (branch, index) ->
      [tab, from] = branch
      plot.tabHeight * (tab.index - from.index + 1) + getYForIndex(from.index) - (plot.tabHeight/2)
    )
    .attr('stroke', plot.branchColor)
  plot._svg.selectAll('line.branch_right')
    .data(branches)
    .enter()
    .append('line')
    .attr('class', 'branch_right')
    .attr('stroke-width', plot.branchStrokeWidth)
    .attr('x1', (branch, index) ->
      [tab, from] = branch
      getXForTime(tab.time) - plot.seamWidth -  Math.max(plot.branchMinWidth, getWidthForTimeRange(from.endTime, tab.time))
    )
    .attr('y1', (branch, index) ->
      [tab, from] = branch
      plot.tabHeight * (tab.index - from.index + 1) + getYForIndex(from.index) - (plot.tabHeight/2)
    )
    .attr('x2', (branch, index) ->
      [tab, from] = branch
      getXForTime(tab.time) - plot.seamWidth - 1
    )
    .attr('y2', (branch, index) ->
      [tab, from] = branch
      plot.tabHeight * (tab.index - from.index + 1) + getYForIndex(from.index) - (plot.tabHeight/2)
    )
    .attr('marker-end', 'url(#branch_marker_arrow)')
    .attr('stroke', plot.branchColor)


_render_tabs = () ->
  tabs = TabInfo.db({type: 'tab'}).get()
  snapshots = _.groupBy(tabs, (tab) -> tab.snapshotId)
  snapshots = _.values(snapshots)
  _.sortBy(snapshots, (snapshot) -> snapshot.time)

  tabs = []
  transitions = ([snapshot, snapshots[idx+1]] for snapshot, idx in snapshots)
  transitions.pop()
  for transition in transitions
    from = transition[0]
    to = transition[1]
    endTime = to[0].time
    for tab in from
      tab.endTime = endTime
      tabs.push tab

  plot.svg.selectAll('rect.tab')
      .data(tabs)
      .enter()
      .append('rect')
      .attr('class', 'tab')
      .attr('height', plot.tabHeight)
      .attr('stroke-width', 0)
      .attr('width', (tab, index) -> 
        getWidthForTimeRange(tab.time, tab.endTime) + (plot.seamWidth * 2)
      )
      .attr('x', (tab, index) ->
        getXForTime(tab.time) - plot.seamWidth
      )
      .attr('y', (tab, index) ->
        getYForIndex(tab.index)
      )
      .attr('fill', (tab, index) ->
        if tab.status == 'loading'
          return plot.tabLoadingColor
        return plot.color(tab.id)
      )

  searches = _.filter(tabs, (tab) -> tab.url.indexOf('www.google.com') >= 0 and tab.url.indexOf('q=') >= 0)
  plot.svg.selectAll('rect.search')
      .data(searches)
      .enter()
      .append('rect')
      .attr('class', 'search')
      .attr('height', plot.tabHeight)
      .attr('stroke-width', 0)
      .attr('width', (tab, index) -> 
        getWidthForTimeRange(tab.time, tab.endTime) + (plot.seamWidth * 2)
      )
      .attr('x', (tab, index) ->
        getXForTime(tab.time) - plot.seamWidth
      )
      .attr('y', (tab, index) ->
        getYForIndex(tab.index)
      )
      .attr('fill', (tab, index) ->
        return 'url(#diagonalHatch)'
      )

  $('svg rect.tab, svg rect.search').tipsy( 
    gravity: 'n', 
    html: false, 
    title: () ->
      return "[" + this.__data__.id + "] " + this.__data__.url
  )

getTabForIdTime = (tabId, time) ->
  tabs = TabInfo.db({type: 'tab', id: tabId}).get()
  for tab in tabs
    tab.diff = Math.abs(time - tab.time)

  #_tabs = _.filter(tabs, (tab) -> tab.diff >= 500)
  tabs = _.sortBy(tabs, 'diff')
  if tabs.length > 0
    return tabs[0]
  return null

orderTimeRange = (time1, time2) ->
  return [Math.min(time1, time2), Math.max(time1, time2)]

getTabsForIdTimeRange = (tabId, time1, time2) ->
  [time1, time2] = orderTimeRange(time1, time2)
  tab1 = getTabForIdTime(tabId, time1)
  tab2 = getTabForIdTime(tabId, time2)
  if tab1? and tab2?
    tabs = TabInfo.db({type: 'tab', id: tabId, time: {'>=': tab1.time, '<=': tab2.time}}).get()
    return tabs
  return []

getXForTime = (time) ->
  (time - plot.start) * plot.timeScale

getTimeForX = (x) ->
  (x / plot.timeScale) + plot.start

getYForIndex = (index) ->
  index * plot.tabHeight + plot.timelineHeight + plot.timelineMargin 

getWidthForTimeRange = (time1, time2) ->
  [time1, time2] = orderTimeRange(time1, time2)
  return getXForTime(time2) - getXForTime(time1)

_render_focus = () ->
  focuses = TabInfo.db({type: 'focus'}).get()
  focuses = _.sortBy(focuses, 'time')
  _focuses = []
  for focus in focuses
    tab = getTabForIdTime(focus.tabId, focus.time)
    if tab
      focus.cy = getYForIndex(tab.index) + (plot.tabHeight / 2)
      focus.cx = getXForTime(focus.time)
      _focuses.push focus
  focuses = _focuses

  transitions = ([focus, focuses[idx+1]] for focus, idx in focuses)
  transitions.pop()
  paths = []
  for transition in transitions
    focus1 = transition[0]
    focus2 = transition[1]
    tabs = getTabsForIdTimeRange(focus1.tabId, focus1.time, focus2.time)
    if tabs.length == 1
      tabs = [$.extend(true, {},tabs[0]), $.extend(true, {},tabs[0])]
    if tabs.length >= 2
      tabs[0].time = focus1.time
      tabs[tabs.length-1].time = focus2.time
    for tab in tabs
      cy = getYForIndex(tab.index) + (plot.tabHeight / 2)
      cx = getXForTime(tab.time)
      paths.push {x: cx, y: cy, active: focus1.windowId >= 0}

  paths = ([path, paths[idx+1]] for path, idx in paths)
  paths.pop()

  plot._svg.selectAll('path.focus')
    .data(paths)
    .enter()
    .append('path')
    .attr('class', 'focus')
    .attr('d', (path) -> plot.focusLineFunction(path))
    .attr('stroke', (path) -> 
      if path[0].active
        return plot.inFocusColor
      return plot.outFocusColor
    )
    .attr('stroke-width', plot.focusPathWidth)
    .attr('fill', 'none')
    .attr('stroke-dasharray', '2,1')

  plot._svg.selectAll('circle.focus')
      .data(focuses)
      .enter()
      .append('circle')
      .attr('class', 'focus')
      .attr('stroke-width', 1)
      .attr('r', plot.focusBubbleRadius)
      .attr('cx', (focus, index) ->
        return focus.cx
      )
      .attr('cy', (focus, index) ->
        return focus.cy
      )
      .attr('stroke', (focus, index) -> 
        if focus.windowId == -1
          return plot.outFocusColor
        return plot.inFocusColor
      )
      .attr('fill', (focus, index) ->
        return 'rgba(0,0,0,0.0)'
      )

  $('svg circle.focus').tipsy( 
    gravity: 'n', 
    html: false, 
    title: () -> "[" + this.__data__.windowId + ':' + this.__data__.tabId + "]"
  )

scaleX = (x) ->
  (x * plot.scaleX) + plot.translateX 

tick = () ->
  plot._svg.selectAll('circle.focus')
    .attr('cx', (focus, index) ->
      return scaleX(focus.cx)
    )
  plot.svg.selectAll('line.timeTick')
    .attr('stroke-width', 1.0 / plot.scaleX)
  plot._svg.selectAll('text.dateTick')
    .attr('x', (tick, index) -> return scaleX(tick) + 4)
  plot._svg.selectAll('text.timeTick')
    .attr('x', (tick, index) -> return scaleX(tick) + 4)
  if plot.scaleX < 1.0
    plot._svg.selectAll('text.dateTick')
      .attr('font-size', plot.scaleX * plot.timelineHeight * 0.9 / 2)
    plot._svg.selectAll('text.timeTick')
      .attr('font-size', plot.scaleX * plot.timelineHeight * 0.9 / 2)

  plot._svg.selectAll('path.focus')
    .attr('d', (path) -> plot.focusLineFunction(path))

  plot._svg.selectAll('line.branch_down')
    .attr('x1', (branch, index) ->
      [tab, from] = branch
      scaleX(getXForTime(tab.time) - plot.seamWidth) - Math.max(plot.branchMinWidth, getWidthForTimeRange(from.endTime, tab.time))
    )
    .attr('x2', (branch, index) ->
      [tab, from] = branch
      scaleX(getXForTime(tab.time) - plot.seamWidth) - Math.max(plot.branchMinWidth, getWidthForTimeRange(from.endTime, tab.time))
    )

  plot._svg.selectAll('line.branch_right')
    .attr('x1', (branch, index) ->
      [tab, from] = branch
      scaleX(getXForTime(tab.time) - plot.seamWidth) - Math.max(plot.branchMinWidth, getWidthForTimeRange(from.endTime, tab.time))
    )
    .attr('x2', (branch, index) ->
      [tab, from] = branch
      scaleX(getXForTime(tab.time) - plot.seamWidth) - 1
    )

_setup_svg = () ->
  d3.select('svg').remove()
  plot._svg = d3.select(".render_container")
      .append("svg")
      .attr('width', plot.width)
      .attr('height', plot.height)

  plot.scaleX = 1.0
  plot.translateX = 0.0
  plot.svg = plot._svg.append("g")
  zoomed = () ->
    plot.scaleX = d3.event.scale
    plot.translateX = d3.event.translate[0]
    plot.svg.attr("transform", "translate(" + d3.event.translate[0] + ", 0 )scale(" + d3.event.scale + ", 1)")
    tick()

  zoom = d3.behavior.zoom()
    .scaleExtent([plot.scaleMin, plot.scaleMax])
    .on("zoom", zoomed)
  plot._svg.call(zoom)

  plot.defs = plot.svg.append('svg:defs')
  markers = [
    { id: 0, name: 'circle', path: 'M 0, 0  m -10, 0  a 10,10 0 1,0 20,0  a 10,10 0 1,0 -20,0', viewbox: '-6 -6 12 12' },
    { id: 1, name: 'square', path: 'M 0,0 m -10,-10 L 10,-10 L 10,10 L -10,10 Z', viewbox: '-10 -10 20 20' },
    { id: 2, name: 'arrow', path: 'M 0,0 m -10,-10 L 10,0 L -10,10 Z', viewbox: '-10 -10 20 20' },
    { id: 2, name: 'stub', path: 'M 0,0 m -1,-10 L 1,-10 L 1,10 L -1,10 Z', viewbox: '-1 -10 2 20' },
  ]
  marker = plot.defs.selectAll('marker')
      .data(markers)
      .enter()
      .append('svg:marker')
        .attr('id', (d) -> 'marker_' + d.name)
        .attr('markerHeight', 5)
        .attr('markerWidth', 5)
        .attr('markerUnits', 'strokeWidth')
        .attr('orient', 'auto')
        .attr('refX', 0)
        .attr('refY', 0)
        .attr('viewBox', (d) -> d.viewbox )
        .append('svg:path')
          .attr('d', (d) -> d.path )
          .attr('fill', (d) -> 'black')
  marker = plot.defs.selectAll('marker.branch')
      .data(markers)
      .enter()
      .append('svg:marker')
        .attr('id', (d) -> 'branch_marker_' + d.name)
        .attr('class', plot.branchColor)
        .attr('markerHeight', 5)
        .attr('markerWidth', 5)
        .attr('markerUnits', 'strokeWidth')
        .attr('orient', 'auto')
        .attr('refX', 0)
        .attr('refY', 0)
        .attr('viewBox', (d) -> d.viewbox )
        .append('svg:path')
          .attr('d', (d) -> d.path )
          .attr('fill', plot.branchColor)
  
  plot.defs.append('defs')
  .append('pattern')
    .attr('id', 'diagonalHatch')
    .attr('patternUnits', 'userSpaceOnUse')
    .attr('width', 4)
    .attr('height', 4)
  .append('path')
    .attr('d', 'M-1,1 l2,-2 M0,4 l4,-4 M3,5 l2,-2')
    .attr('fill', 'red')
    .attr('stroke', 'hotpink')
    .attr('stroke-width', 1);

render = () ->
  tabs = TabInfo.db({type: 'tab'}).get()
  plot.start = tabs[0].time
  plot.end = tabs[tabs.length - 1].time
  plot.width = Math.max((plot.end - plot.start) / 5000, $('.render_container').width())
  plot.timeScale = plot.width / (plot.end - plot.start)

  console.log ' -- BEGIN RENDER -- '

  _setup_svg()
  _render_timeline()
  _render_tabs()
  _render_focus()
  _render_branches()

  console.log ' -- END   RENDER -- '

  $('.render_container').scrollLeft(plot.width)


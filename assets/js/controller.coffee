
objects2csv = (objects, attributes) ->
  csvData = new Array()
  csvData.push '"' + attributes.join('","') + '"'
  for object in objects
    row = []
    for attribute in attributes
      row.push ("" + object[attribute]).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
    csvData.push '"' + row.join('","') + '"'
  return csvData.join('\n')

downloadCsv = (filename, csv) ->
  a = document.createElement('a')
  a.href = 'data:attachment/csv,' + encodeURI(csv)
  a.target ='_blank'
  a.download = filename + '.csv'
  a.click()

$('.download.tabs').click () ->
  #domain url urlHash domainHash index id windowId status snapshotAction time
  tabs = TabInfo.db({type: 'tab'}).get()
  attributes = ['snapshotId', 'windowId', 'id', 'openerTabId', 'index', 'status', 'snapshotAction', 'domain', 'url', 'domainHash', 'urlHash', 'favIconUrl', 'time']
  csv = objects2csv(tabs, attributes)
  downloadCsv('tabLogs', csv)

$('.download.focuses').click () ->
  #tabId time windowId
  focuses = TabInfo.db({type: 'focus'}).get()
  attributes = ['action', 'windowId', 'tabId', 'time']
  csv = objects2csv(focuses, attributes)
  downloadCsv('focusLogs', csv)

$('.render').click () ->
  render()


$('.database.kill').click () ->
  console.log "KILL DB"
  #TabInfo.clearDB()
  alert 'database deleted'

plot =
    height: 750
    tabHeight: 25
    timelineHeight: 30
    timelineMargin: 4
    timeTickWidth: 100
    seamWidth: 0.15
    color: d3.scale.category20()
    scaleX: 1.0
    translateX: 0.0


_render_timeline = () ->
  ticks = (tick for tick in [plot.timeTickWidth..(plot.width - plot.timeTickWidth)] by plot.timeTickWidth)
  plot.svg.selectAll('line.timeline')
    .data([0])
    .enter()
    .append('line')
    .attr('class', 'timeline')
    .attr('x1', (tick, index) -> return 0)
    .attr('y1', (tick, index) -> plot.timelineHeight)
    .attr('x2', (tick, index) -> return plot.width)
    .attr('y2', (tick, index) -> plot.timelineHeight)
    .attr('stroke', 'black')

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
      unixtime = (parseInt(tick) / plot.timeScale) + plot.start
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
      unixtime = (parseInt(tick) / plot.timeScale) + plot.start
      date = new Date()
      date.setTime(unixtime)
      dateString = date.getHours() + ":" + date.getMinutes() + ":" + date.getSeconds()
      return dateString
    )
    .attr('x', (tick, index) -> return tick + 4)
    .attr('y', (tick, index) -> return plot.timelineHeight - 2)
    .attr('font-size', plot.timelineHeight * 0.9 / 2)

_render_tabs = (snapshots) ->
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
          return (tab.endTime - tab.time) * plot.timeScale + (plot.seamWidth*2)
      )
      .attr('x', (tab, index) ->
          return (tab.time - plot.start) * plot.timeScale - plot.seamWidth
      )
      .attr('y', (tab, index) ->
          return tab.index * plot.tabHeight + plot.timelineHeight + plot.timelineMargin
      )
      .attr('fill', (tab, index) ->
        if tab.status == 'loading'
          return 'black'
        return plot.color(tab.id)
      )

  $('svg rect.tab').tipsy( 
    gravity: 'n', 
    html: false, 
    title: () ->
      return "[" + this.__data__.id + "] " + this.__data__.url
  )

_render_focus_bubbles = () ->
  focuses = TabInfo.db({type: 'focus'}).get()
  _focuses = []
  for focus in focuses
    tabs = TabInfo.db({type: 'tab', id: focus.tabId}).get()
    for tab in tabs
      tab.diff = Math.abs(focus.time - tab.time)
    tabs = _.sortBy(tabs, 'diff')
    if tabs.length > 0
      tab = tabs[0]
      focus.tab = tab
      focus.cy = tab.index * plot.tabHeight + plot.timelineHeight + plot.timelineMargin + plot.tabHeight/2
      focus.cx = (focus.time - plot.start) * plot.timeScale - plot.seamWidth
      _focuses.push focus
  focuses = _focuses

  plot._svg.selectAll('circle.focus')
      .data(focuses)
      .enter()
      .append('circle')
      .attr('class', 'focus')
      .attr('stroke-width', 1)
      .attr('r', (focus, index) ->
        if focus.windowId == -1
          return 0.25
        return plot.tabHeight/16
      )
      .attr('cx', (focus, index) ->
        return (focus.cx * plot.scaleX) + plot.translateX
      )
      .attr('cy', (focus, index) ->
        return focus.cy
      )
      .attr('stroke', (focus, index) -> 
        if focus.windowId == -1
          return 'black'
        return 'white'
      )
      .attr('fill', (focus, index) ->
        return 'rgba(0,0,0,0.0)'
      )

  return focuses

_render_focus_path = (focuses) ->
  1 == 1

tick = () ->
  plot._svg.selectAll('circle.focus')
      .attr('cx', (focus, index) ->
        return (focus.cx * plot.scaleX) + plot.translateX
      )
  plot.svg.selectAll('line.timeTick')
    .attr('stroke-width', 1.0 / plot.scaleX)
  plot._svg.selectAll('text.dateTick')
    .attr('x', (tick, index) -> return (tick * plot.scaleX) + plot.translateX + 4)
  plot._svg.selectAll('text.timeTick')
    .attr('x', (tick, index) -> return (tick * plot.scaleX) + plot.translateX + 4)
  if plot.scaleX < 1.0
    plot._svg.selectAll('text.dateTick')
      .attr('font-size', plot.scaleX * plot.timelineHeight * 0.9 / 2)
    plot._svg.selectAll('text.timeTick')
      .attr('font-size', plot.scaleX * plot.timelineHeight * 0.9 / 2)

render = () ->
  tabs = TabInfo.db({type: 'tab'}).get()
  snapshots = _.groupBy(tabs, (tab) -> tab.snapshotId)
  snapshots = _.values(snapshots)
  _.sortBy(snapshots, (snapshot) -> snapshot.time)

  plot.start = tabs[0].time
  plot.end = tabs[tabs.length - 1].time
  plot.width = (plot.end - plot.start) / 5000
  plot.timeScale = plot.width / (plot.end - plot.start)

  console.log ' -- BEGIN RENDER -- '


  d3.select('svg').remove()
  plot._svg = d3.select(".render_container")
      .append("svg")
      .attr('width', plot.width)
      .attr('height', plot.height)

  plot.svg = plot._svg.append("g")
  zoomed = () ->
    plot.scaleX = d3.event.scale
    plot.translateX = d3.event.translate[0]
    plot.svg.attr("transform", "translate(" + d3.event.translate[0] + ", 0 )scale(" + d3.event.scale + ", 1)")
    tick()

  
  _render_timeline()
  _render_tabs(snapshots)
  focuses = _render_focus_bubbles()
  _render_focus_path(focuses)



  zoom = d3.behavior.zoom()
    .scaleExtent([0.01, 25])
    .on("zoom", zoomed)
  plot._svg.call(zoom)


  console.log ' -- END   RENDER -- '

  $('.render_container').scrollLeft(plot.width)


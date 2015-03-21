
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

$('.database.kill').click () ->
  #console.log "KILL DB"
  #TabInfo.clearDB()
  #alert 'database deleted'
  render()

plot =
    height: 750
    tabHeight: 25
    timelineHeight: 30
    timelineMargin: 4
    timeTickWidth: 100
    seamWidth: 0.1
    color: d3.scale.category20()

render = () ->
  console.log ' -- BEGIN RENDER -- '

  tabs = TabInfo.db({type: 'tab'}).get()
  snapshots = _.groupBy(tabs, (tab) -> tab.snapshotId)
  snapshots = _.values(snapshots)
  _.sortBy(snapshots, (snapshot) -> snapshot.time)
  transitions = ([snapshot, snapshots[idx+1]] for snapshot, idx in snapshots)
  transitions.pop()

  plot.start = tabs[0].time
  plot.end = tabs[tabs.length - 1].time
  plot.width = (plot.end - plot.start) / 5000
  plot.timeScale = plot.width / (plot.end - plot.start)

  d3.select('svg').remove()
  plot.svg = d3.select(".render_container")
      .append("svg")
      .attr('width', plot.width)
      .attr('height', plot.height)


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

  plot.svg.selectAll('text.dateTick')
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
  plot.svg.selectAll('text.timeTick')
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

  tabs = []
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
      return this.__data__.url
  )

  tabs = TabInfo.db({type: 'tab'}).get()
  tabs = _.groupBy(tabs, (tab) -> tab.id)

  focuses = TabInfo.db({type: 'focus'}).get()
  transitions = ([focus, focuses[idx+1]] for focus, idx in focuses)
  transitions.pop()

  console.log ' -- END   RENDER -- '


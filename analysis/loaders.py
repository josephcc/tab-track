import sys
import csv
from itertools import *
from bisect import *
from operator import *
from containers import *
from collections import defaultdict

def loadSnapshot(fn):
    snapshots = []
    with open(fn, 'rb') as csvfile:
        snapshotRows = defaultdict(list)
        csvreader = csv.reader(csvfile)
        for row in csvreader:
            if row[0] == 'snapshotId' or len(row) != 13:
                continue
            snapshotRows[row[0]].append(row)

        for _, rows in snapshotRows.items():
            snapshots.append(Snapshot(rows))

    snapshots.sort(key=attrgetter('time'))
    for tab in snapshots[0].tabs:
        tab.init = True
    snapshots[0].windows = list(set(map(attrgetter('windowId'), snapshots[0].tabs)))
    for idx in range(len(snapshots) - 1):
        fr = snapshots[idx]
        to = snapshots[idx+1]
        to.windows = list(set(map(attrgetter('windowId'), to.tabs)))
        for tab in to.tabs:
            tab.init = False
            if tab.status == 'complete':
                prevTab = fr.findTab(tab.id)
                if prevTab != None and prevTab.status in ('complete', 'done'):
                    tab.status = 'done'
            if tab.status == 'loading':
                if (not fr.hasTab(tab.id)) or fr.findTab(tab.id).urlHash != tab.urlHash:
                    tab.init = True
        fr.endTime = to.time
    # skip last record because it has no endTime
    snapshots.pop()
    return snapshots

def loadFocus(fn):
    focuses = []
    with open(fn, 'rb') as csvfile:
        csvreader = csv.reader(csvfile)
        for row in csvreader:
            if row[0] == 'action' or len(row) != 4:
                continue
            focus = Focus(row)
            focuses.append(focus)

    focuses.sort(key=attrgetter('time'))
    return focuses

def loadNav(fn):
    navs = []
    with open(fn, 'rb') as csvfile:
        csvreader = csv.reader(csvfile)
        for row in csvreader:
            if row[0] == 'from' or len(row) != 3:
                continue
            nav = Nav(row)
            navs.append(nav)

    navs.sort(key=attrgetter('time'))
    return navs

def _trimByTime(a, s, e):
    while a[0].time < s:
        del a[0]
    while a[-1].time > e:
        del a[-1]
    return a

def _getSnapshotForTime(snapshots, focus):
    index = bisect_left(snapshots, focus)
    snapshots = snapshots[max(0, index-5) : min(len(snapshots)-1, index+5)]
    snapshots = filter(lambda snapshot: snapshot.hasTab(focus.id), snapshots)

    diffs = []
    for snapshot in snapshots:
        diffs.append( abs(focus.time - snapshot.time) )
    
    diffs = list(enumerate(diffs))
    diffs.sort(key=itemgetter(1))
    #_tabs = _.filter(tabs, (tab) -> tab.diff >= 500)

    if len(diffs) > 0:
        snapshots[diffs[0][0]].focuses.append(focus)

def addFocusToSnapshots(snapshots, focuses):
    snapshots.sort(key=attrgetter('time'))
    focuses.sort(key=attrgetter('time'))
    snapshots = _trimByTime(snapshots, focuses[0].time, focuses[-1].time)
    focuses = _trimByTime(focuses, snapshots[0].time, snapshots[-1].time)

    for snapshot in snapshots:
        snapshot.focuses = []
    for focus in focuses:
        _getSnapshotForTime(snapshots, focus)

    lastFocus = None
    for snapshot in snapshots:
        snapshot.lastFocus = lastFocus
        # fix race condition
        for focus in snapshot.focuses:
            focus.time = max(snapshot.time, focus.time)
            focus.time = min(snapshot.endTime, focus.time)
        if len(snapshot.focuses) > 0:
            lastFocus = snapshot.focuses[-1]

    return snapshots


def _getIdxForSnapshot(snapshot, snapshots):
    index = bisect_left(snapshots, time)
    start = max(0, index-25) 
    end = min(len(snapshots)-1, index+25)
    snapshots = snapshots[start:end]
    _snapshotIdx = next(ifilter(lambda x: x[1].snapshotId == snapshot.snapshotId, enumerate(snapshots)))[0]
    return _snapshotIdx + start

def _getTabForIdTime(frTabId, toTabId, time, snapshots):
    index = bisect_left(snapshots, time)
    start = max(0, index-25) 
    end = min(len(snapshots)-1, index+25)
    snapshots = snapshots[start:end]
    snapshots = filter(lambda snapshot: snapshot.hasTab(toTabId) and snapshot.hasTab(frTabId) and snapshot.findTab(toTabId).init, snapshots)

    diffs = []
    for snapshot in snapshots:
        diffs.append( abs(time - snapshot.time) )

    diffs = list(enumerate(diffs))
    diffs.sort(key=itemgetter(1))

    if len(diffs) > 0:
        snapshot = snapshots[diffs[0][0]]
        return snapshot, snapshot.findTab(frTabId), snapshot.findTab(toTabId)
    return None, None, None
    
def addNavToSnapshots(snapshots, navs):
    for nav in navs:
        snapshot, fr, to  = _getTabForIdTime(nav.source, nav.target, nav.time, snapshots)
        if to != None and fr != None:
            to.source = fr
            # propagate source info to future snapshots
            snapshotIdx = next(ifilter(lambda x: x[1].snapshotId == snapshot.snapshotId, enumerate(snapshots)))[0]
            for idx in range(snapshotIdx, len(snapshots)):
                snapshot = snapshots[idx]
                # this will fail to propagate on redirection, as init will be set in that case
                #if (not snapshot.hasTab(nav.target)) or snapshot.findTab(nav.target).init:
                if (not snapshot.hasTab(nav.target)):
                    break
                snapshot.findTab(nav.target).tabSource = fr

def loadEverything(snapshotFn, focusFn, navFn):
    print >> sys.stderr, 'Loading tab logs...',
    snapshots = loadSnapshot(snapshotFn)
    print >> sys.stderr, ' Done\nLoading focus logs...',
    focuses = loadFocus(focusFn)
    print >> sys.stderr, ' Done\nLoading nav logs...',
    navs = loadNav(navFn)
    print >> sys.stderr, ' Done'

    print >> sys.stderr, 'Mapping focus to snapshots...',
    addFocusToSnapshots(snapshots, focuses)
    print >> sys.stderr, ' Done\nMapping nav to snapshots...',
    addNavToSnapshots(snapshots, navs)
    print >> sys.stderr, ' Done'

    return snapshots, focuses, navs


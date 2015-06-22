import sys
import csv
from bisect import *
from operator import *
from containers import *
from collections import defaultdict

def loadSnapshot(fn):
    snapshots = []
    with open(fn, 'rb') as csvfile:
        snapshotRows = defaultdict(list)
        spamreader = csv.reader(csvfile)
        for row in spamreader:
            if row[0] == 'snapshotId' or len(row) != 13:
                continue
            snapshotRows[row[0]].append(row)

        for _, rows in snapshotRows.items():
            snapshots.append(Snapshot(rows))

    snapshots.sort(key=attrgetter('time'))
    for idx in range(len(snapshots) - 1):
        fr = snapshots[idx]
        to = snapshots[idx+1]
        fr.endTime = to.time
    # skip last record because it has no endTime
    snapshots.pop()
    return snapshots

def loadFocus(fn):
    focuses = []
    with open(fn, 'rb') as csvfile:
        spamreader = csv.reader(csvfile)
        for row in spamreader:
            if row[0] == 'action' or len(row) != 4:
                continue
            focus = Focus(row)
            focuses.append(focus)

    focuses.sort(key=attrgetter('time'))
    return focuses

def loadNav(fn):
    navs = defaultdict(list)
    with open(fn, 'rb') as csvfile:
        spamreader = csv.reader(csvfile)
        for row in spamreader:
            if row[0] == 'from' or len(row) != 3:
                continue
            nav = Nav(row)
            navs[nav.target].append(nav)

    for target, a in navs.items():
        a.sort(key=attrgetter('time'))
    return navs

def _trimByTime(a, s, e):
    while a[0].time < s:
        del a[0]
    while a[-1].time > e:
        del a[-1]
    return a

def _getSnapshotForTime(snapshots, focus):
    snapshots = filter(lambda snapshot: snapshot.hasTab(focus.id), snapshots)

    diffs = []
    for snapshot in snapshots:
        diffs.append( abs(focus.time - snapshot.time) )
    
    diffs = list(enumerate(diffs))
    diffs.sort(key=itemgetter(1))
    #_tabs = _.filter(tabs, (tab) -> tab.diff >= 500)

    if len(diffs) > 0:
        snapshots[diffs[0][0]].focuses.append(focus)

# TODO TODO TODO
# this really needs to be optimized
# do a heuristic slice before doing diff
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

allTabs = None
allTabTimeIndex = None
snapshotsReference = None
def _findTabForNav(nav, snapshots):
    global allTabs
    global allTabTimeIndex
    global snapshotsReference
    if allTabs == None or not (snapshotsReference is snapshots):
        snapshotsReference = snapshots
        allTabs = []
        for snapshot in snapshots:
            allTabs += filter(lambda tab: tab.status == 'complete', snapshot.tabs)
        allTabTimeIndex = map(attrgetter('time'), allTabs)
    index = bisect_left(allTabTimeIndex, nav.time) - 1
    if index < 0:
        return None

    while allTabs[index].id != nav.source:
        index -= 1
        # set a time constraint?
        if index < 0:
            return None

    tab = allTabs[index]
    return tab

def addNavToSnapshots(snapshots, navs):
    for snapshot in snapshots:
        for tab in snapshot.tabs:
            if not navs.has_key(tab.id):
                tab.source = None
                continue
            sources = navs[tab.id][:] # dup
            sources = filter(lambda source: source.time < snapshot.time, sources)
            if len(sources) == 0:
                tab.source = None
                continue
            source = sources[-1]
            tab.source = _findTabForNav(source, snapshots)

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


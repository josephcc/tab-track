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

def addFocusToSnapshots(snapshots, focuses):
    snapshots.sort(key=attrgetter('time'))
    focuses.sort(key=attrgetter('time'))
    snapshots = _trimByTime(snapshots, focuses[0].time, focuses[-1].time)
    focuses = _trimByTime(focuses, snapshots[0].time, snapshots[-1].time)

    # this moves all none existing head / tail focuses to the prev / next snapshot,
    # BUT!! they might not be consecutive, it could be exi exi exi non exi exi
    # in that case you want to either
    # 1) move the last 3 to the next snapshot 
    # 2) move the first 4 to the prev snapshot
    # ... need to re-write the entire logic orz
    for idx in range(len(snapshots)):
        prevSnapshot = idx > 0 and snapshots[idx-1] or None
        snapshot = snapshots[idx]
        nextSnapshot = idx + 1 < len(snapshots) and snapshots[idx+1] or None

        if not hasattr(snapshot, 'focuses'):
            snapshot.focuses = []
        if prevSnapshot != None and not hasattr(prevSnapshot, 'focuses'):
            prevSnapshot.focuses = []
        if nextSnapshot != None and not hasattr(nextSnapshot, 'focuses'):
            nextSnapshot.focuses = []

        while len(focuses) > 0 and focuses[0].time < snapshot.endTime:
            snapshot.focuses.append(focuses[0])
            del focuses[0]

        if prevSnapshot != None:
            for idx in range(len(snapshot.focuses)):
                if snapshot.hasTab(snapshot.focuses[idx].id):
                    break
                elif prevSnapshot.hasTab(snapshot.focuses[idx].id):
                    prevSnapshot.focuses.append(snapshot.focuses[idx])
                    prevSnapshot.focuses[-1].time = prevSnapshot.endTime
                    snapshot.focuses[idx] = None
        snapshot.focuses = filter(lambda x: x != None, snapshot.focuses)

        if nextSnapshot != None:
            for idx in reversed(range(len(snapshot.focuses))):
                if snapshot.hasTab(snapshot.focuses[idx].id):
                    break
                elif nextSnapshot.hasTab(snapshot.focuses[idx].id):
                    nextSnapshot.focuses.insert(0, snapshot.focuses[idx])
                    nextSnapshot.focuses[0].time = nextSnapshot.time
                    snapshot.focuses[idx] = None
        snapshot.focuses = filter(lambda x: x != None, snapshot.focuses)

    for focus in snapshot.focuses:
        if not snapshot.hasTab(focus.id):
            print '=' * 33
            print focus
            print 'PREV'
            print prevSnapshot
            print 'CURR'
            print snapshot
            print 'NEXT'
            print nextSnapshot
            print '=' * 33
            break

    lastFocus = None
    for snapshot in snapshots:
        snapshot.lastFocus = lastFocus
        lastFocus = len(snapshot.focuses) > 0 and snapshot.focuses[-1] or snapshot.lastFocus


    print '# of out of range focuses %d' % len(focuses)
    print focuses
    print

    return snapshots

allTabs = None
allTabTimeIndex = None
snapshotsReference = None
def _findTabForNav(nav, snapshots):
    global allTabs
    global allTabTimeIndex
    global snapshotsReference
    if allTabs == None or not (snapshotsReference is snapshots):
        print 'rebuilding allTabIndex...'
        snapshotsReference = snapshots
        allTabs = []
        for snapshot in snapshots:
            allTabs += filter(lambda tab: tab.status == 'complete', snapshot.tabs)
        allTabTimeIndex = map(attrgetter('time'), allTabs)
        print 'done'
        print
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
    snapshots = loadSnapshot(snapshotFn)
    focuses = loadFocus(focusFn)
    navs = loadNav(navFn)

    addFocusToSnapshots(snapshots, focuses)
    addNavToSnapshots(snapshots, navs)

    return snapshots, focuses, navs


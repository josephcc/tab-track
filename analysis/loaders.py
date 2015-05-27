import csv
from bisect import *
from operator import *
from containers import *
from collections import defaultdict

def equalOrSmaller(a, x):
    a = map(attrgetter('time'), a)
    idx = bisect_left(a, x)
    if idx < len(a) and a[idx] == x:
        return idx
    return idx - 1

def equalOrLarger(a, x):
    a = map(attrgetter('time'), a)
    return bisect_right(a, x)

def loadTabSnapshots(fn):
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

    for idx in range(len(snapshots)):
        if len(focuses) == 0:
            del snapshots[idx]
            idx -= 1
            continue
        snapshot = snapshots[idx]
        startIdx = equalOrSmaller(focuses, snapshot.time)
        endIdx = equalOrLarger(focuses, snapshot.endTime)
        snapshot.focuses = focuses[startIdx : endIdx + 1]
        focuses = focuses[endIdx - 1 :]

    return snapshots



import sys
import cPickle as pickle
from itertools import *

from ascii_graph import Pyasciigraph
from bokeh.plotting import figure, show, output_file, vplot

from loaders import *
from containers import *


def init():
    print >> sys.stderr, sys.argv[1]
    if len(sys.argv) in (2,3):
        snapshots, focuses, navs = loadEverything(sys.argv[1])
        if len(sys.argv) == 3:
            print >> sys.stderr, 'Writing snapshot to file...',
            fp = open(sys.argv[2], 'wb')
            pickle.dump(snapshots, fp, -1)
            fp.close()
            print >> sys.stderr, ' Done'
    elif len(sys.argv) == 2:
        print >> sys.stderr, 'Loading pickled snapshots...',
        fp = open(sys.argv[1], 'rb')
        snapshots = pickle.load(fp)
        fp.close()
        print >> sys.stderr, ' Done'
    else:
        raise
    return snapshots

def tabHours(snapshots):
    tabTime = datetime.timedelta()
    active = datetime.timedelta()
    maxCount = 0
    maxWinCount = 0
    tabHisto = defaultdict(datetime.timedelta)
    windowHisto = defaultdict(datetime.timedelta)
    domainTime = defaultdict(datetime.timedelta)
    directBranching = defaultdict(lambda: 0)
    indirectBranching = defaultdict(lambda: 0)

    for snapshot in snapshots:
        maxCount = max(maxCount, len(snapshot.tabs))
        maxWinCount = max(maxWinCount, len(snapshot.windows))
        snapshot_active = datetime.timedelta()
        for this, next in izip(snapshot.focuses[:-1], snapshot.focuses[1:]):
            if this.windowId <= 0:
                continue
            duration = next.time - this.time
            # TODO detect idle here: duration too long within one snapshot -> no action
            active += duration
            tab = snapshot.findTab(this.id)
            domainTime[tab.getDomain()] += duration
            snapshot_active += duration
            tabTime += duration * len(snapshot.tabs)
        tabHisto[len(snapshot.tabs)] += snapshot_active
        windowHisto[len(snapshot.windows)] += snapshot_active

        tabs = filter(lambda tab: tab.init, snapshot.tabs)
        tabs = filter(lambda tab: tab.directSource() != None, tabs)
        for tab in tabs:
            directBranching[tab.directSource().getDomain()] += 1
            for source in tab.indirectSources():
                indirectBranching[source.getDomain()] += 1
            
    return active, tabTime, maxCount, tabHisto, domainTime, directBranching, indirectBranching, maxWinCount, windowHisto

def searches(snapshots):
    count = 0
    for snapshot in snapshots:
        tabs = filter(lambda tab: tab.init, snapshot.tabs)
        tabs = filter(lambda tab: tab.query != None, tabs)
        count += len(tabs)

        snapshot.searchInit = len(tabs) > 0

    return count

def printDeltaHisto(histo, label):
    histo = [(count, float('%.2f' % minutes)) for count, minutes in histo]
    for line in Pyasciigraph().graph(label, histo):
        print line.encode('utf8')

def main():
    snapshots = init()
    try:
        pass
    except Exception as e:
        print '\nUsage:'
        print '\tpython analysis.py userId'
        print '\tpython analysis.py userId userId.pickle'
        print '\tpython analysis.py userId.pickle\n'
        t, v, tb = sys.exc_info()
        raise t, v, tb
        sys.exit()

    print >> sys.stderr, 'Checking snapshot integrity...',
    for snapshot in snapshots:
        snapshot.fsck()
    print >> sys.stderr, ' Done'

    print '-' * 44

    total = snapshots[-1].endTime - snapshots[0].time
    active, tab, maxCount, tabHisto, domainHisto, directBr, indirectBr, maxWinCount, windowHisto = tabHours(snapshots)
    searchCount = searches(snapshots)

    print 'Log duration:\t\t', total, snapshots[-1].endTime, snapshots[0].time
    print 'Active duration:\t', active
    print 'Active ratio:\t\t%.2f%%' % (100 * active.total_seconds() / total.total_seconds())
    print 'Tab duration:\t\t', tab
    print 'Max number of tabs:\t', maxCount
    print 'Max number of windows:\t', maxWinCount
    print 'Average number of tabs:\t', tab.total_seconds() / active.total_seconds()
    print 'Number of searches:\t', searchCount
    if searchCount != 0:
        print '1 search every:\t\t', active.total_seconds() / searchCount, 'seconds'

    print '-' * 44

    tabHisto = tabHisto.items()
    tabHisto.sort(key=itemgetter(0), reverse=True)
    tabHisto = [(count, 100 * delta.total_seconds()/active.total_seconds()) for count, delta in tabHisto]
    printDeltaHisto(tabHisto, 'Active % / Tab count')

    print '-' * 44

    windowHisto = windowHisto.items()
    windowHisto.sort(key=itemgetter(0), reverse=True)
    windowHisto = [(count, 100 * delta.total_seconds()/active.total_seconds()) for count, delta in windowHisto]
    printDeltaHisto(windowHisto, 'Active % / Tab count')

    print '-' * 44

    domainHisto = domainHisto.items()
    domainHisto.sort(key=itemgetter(1), reverse=True)
    domainHisto = [(count, 100 * delta.total_seconds()/active.total_seconds()) for count, delta in domainHisto]
    printDeltaHisto(domainHisto[:11], 'Active % / Domain')

    print '-' * 44

    directBr = directBr.items()
    directBr.sort(key=itemgetter(1), reverse=True)
    printDeltaHisto(directBr[:11], 'Direct branching count / Domain')

    print '-' * 44

    indirectBr = indirectBr.items()
    indirectBr.sort(key=itemgetter(1), reverse=True)
    printDeltaHisto(indirectBr[:11], 'Indirect branching count / Domain')

    print '-' * 44

    output_file("tabsovertime.html", title="# of tabs over time")
    p1 = figure(x_axis_type = "datetime")
    p1.line(map(attrgetter('time'), snapshots), map(lambda snapshot: len(snapshot.tabs), snapshots), legend='# of tabs', color='#00dd00')
    p1.line(map(attrgetter('time'), snapshots), map(lambda snapshot: len(snapshot.windows), snapshots), legend='# of windows', color='#0000dd')
    p1.line(map(attrgetter('time'), snapshots), map(lambda snapshot: snapshot.searchInit and 1 or -1, snapshots), legend='SEARCH', color='#dd0000')

    show(vplot(p1))


main()


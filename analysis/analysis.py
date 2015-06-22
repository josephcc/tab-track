
import sys
import cPickle as pickle
from itertools import *

from ascii_graph import Pyasciigraph

from loaders import *
from containers import *


def init():
    if len(sys.argv) in (4,5):
        snapshots, focuses, navs = loadEverything(*sys.argv[1:4])
        if len(sys.argv) == 5:
            print >> sys.stderr, 'Writing snapshot to file...',
            fp = open(sys.argv[4], 'wb')
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
    tabHisto = defaultdict(datetime.timedelta)
    domainTime = defaultdict(datetime.timedelta)
    directBranching = defaultdict(lambda: 0)
    indirectBranching = defaultdict(lambda: 0)

    for snapshot in snapshots:
        maxCount = max(maxCount, len(snapshot.tabs))
        snapshot_active = datetime.timedelta()
        for this, next in izip(snapshot.focuses[:-1], snapshot.focuses[1:]):
            if this.windowId <= 0:
                continue
            duration = next.time - this.time
            active += duration
            tab = snapshot.findTab(this.id)
            domainTime[tab.domain] += duration
            snapshot_active += duration
            tabTime += duration * len(snapshot.tabs)
        tabHisto[len(snapshot.tabs)] += snapshot_active

        # TODO wrong way to detect creation
        tabs = filter(lambda tab: tab.status == 'loading', snapshot.tabs)
        tabs = filter(lambda tab: tab.directSource() != None, tabs)
        for tab in tabs:
            directBranching[tab.directSource().domain] += 1
            for source in tab.indirectSources():
                indirectBranching[source.domain] += 1
            
    return active, tabTime, maxCount, tabHisto, domainTime, directBranching, indirectBranching

# TODO double check search url patterns
def searches(snapshots, domain='google.com'):
    count = 0
    for snapshot in snapshots:
        # TODO wrong way to detect creation
        tabs = filter(lambda tab: tab.status == 'loading', snapshot.tabs)
        tabs = filter(lambda tab: domain in tab.domain, tabs)
        tabs = filter(lambda tab: 'search' in tab.url, tabs)
        count += len(tabs)

    return count

def printDeltaHisto(histo, label):
    histo = [(count, float('%.2f' % minutes)) for count, minutes in histo]
    for line in Pyasciigraph().graph(label, histo):
        print line

def main():

    try:
        snapshots = init()
    except:
        print '\nUsage:'
        print '\tpython analysis.py tabLogs.csv focusLogs.csv navLogs.csv'
        print '\tpython analysis.py tabLogs.csv focusLogs.csv navLogs.csv snapshots.pickle'
        print '\tpython analysis.py snapshots.pickle\n'
        sys.exit()

    print >> sys.stderr, 'Checking snapshot integrity...',
    for snapshot in snapshots:
        snapshot.fsck()
    print >> sys.stderr, ' Done'

    print '-' * 44

    total = snapshots[-1].endTime - snapshots[0].time
    active, tab, maxCount, tabHisto, domainHisto, directBr, indirectBr = tabHours(snapshots)
    searchCount = searches(snapshots)

    print 'Log duration:\t\t', total
    print 'Active duration:\t', active
    print 'Active ratio:\t\t%.2f%%' % (100 * active.total_seconds() / total.total_seconds())
    print 'Tab duration:\t\t', tab
    print 'Max number of tabs:\t', maxCount
    print 'Average number of tabs:\t', tab.total_seconds() / active.total_seconds()
    print 'Number of searches:\t', searchCount
    print '1 search every:\t\t', active.total_seconds() / searchCount, 'seconds'

    print '-' * 44

    tabHisto = tabHisto.items()
    tabHisto.sort(key=itemgetter(0), reverse=True)
    tabHisto = [(count, 100 * delta.total_seconds()/active.total_seconds()) for count, delta in tabHisto]
    printDeltaHisto(tabHisto, 'Active % / Tab count')

    print '-' * 44

    domainHisto = domainHisto.items()
    domainHisto.sort(key=itemgetter(1), reverse=True)
    domainHisto = [(count, 100 * delta.total_seconds()/active.total_seconds()) for count, delta in domainHisto]
    printDeltaHisto(domainHisto[:20], 'Active % / Domain')

    print '-' * 44

    directBr = directBr.items()
    directBr.sort(key=itemgetter(1), reverse=True)
    printDeltaHisto(directBr[:20], 'Direct branching count / Domain')

    print '-' * 44

    indirectBr = indirectBr.items()
    indirectBr.sort(key=itemgetter(1), reverse=True)
    printDeltaHisto(indirectBr[:20], 'Indirect branching count / Domain')

    print '-' * 44

main()

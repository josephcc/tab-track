
import sys
import cPickle as pickle
from itertools import *

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
    tab = datetime.timedelta(0)
    active = datetime.timedelta(0)
    total = datetime.timedelta(0)
    maxCount = 0
    for snapshot in snapshots:
        total += snapshot.endTime - snapshot.time
        maxCount = max(maxCount, len(snapshot.tabs))
        for this, next in izip(snapshot.focuses[:-1], snapshot.focuses[1:]):
            if this.windowId <= 0:
                continue
            duration = next.time - this.time
            active += duration
            tab += duration * len(snapshot.tabs)
            
    return total, active, tab, maxCount

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

    total, active, tab, maxCount = tabHours(snapshots)
    print 'Log duration:\t\t', total
    print 'Active duration:\t', active
    print 'Active ratio:\t\t%.2f%%' % (100 * active.total_seconds() / total.total_seconds())
    print 'Tab duration:\t\t', tab
    print 'Max number of tabs:\t', maxCount
    print 'Average number of tabs:\t', tab.total_seconds() / active.total_seconds()

    print '-' * 44

main()


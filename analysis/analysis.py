
import sys
import cPickle as pickle

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
        print 'Usage:'
        print '\tpython analysis.py tabLogs.csv focusLogs.csv navLogs.csv'
        print '\tpython analysis.py tabLogs.csv focusLogs.csv navLogs.csv snapshots.pickle'
        print '\tpython analysis.py snapshots.pickle'
        return None
    return snapshots

def main():

    snapshots = init()
    if snapshots == None:
        sys.exit()

    print >> sys.stderr, 'Checking snapshot integrity...',
    for snapshot in snapshots:
        snapshot.fsck()
    print >> sys.stderr, ' Done'

main()


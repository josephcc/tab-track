
import sys
import cPickle as pickle

from loaders import *
from containers import *


def init():
    if len(sys.argv) in (4,5):
        snapshots, focuses, navs = loadEverything(*sys.argv[1:4])
        if len(sys.argv) == 5:
            fp = open(sys.argv[4], 'wb')
            pickle.dump(snapshots, fp, -1)
            fp.close()
    elif len(sys.argv) == 2:
        fp = open(sys.argv[1], 'rb')
        snapshots = pickle.load(fp)
        fp.close()
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

    for snapshot in snapshots:
        print snapshot
        snapshot.fsck()


main()

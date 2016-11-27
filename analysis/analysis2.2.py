import sys
import cPickle as pickle
from operator import *
from itertools import *
from functools import *

from loaders import *
from containers import *
from collections import Counter

from users import users


def isFromSearch(tab):
    if tab.tab.isSearch() or (tab.tab.directSource() != None and tab.tab.directSource().isSearch()):
        return True
    return False

def getTabSessions(user):
    snapshots, focuses, navs = loadEverything(user)
    print >> sys.stderr, 'Checking snapshot integrity...',
    for snapshot in snapshots:
        snapshot.fsck()
    print >> sys.stderr, ' Done'

    tabSessions = extractTabSessions(snapshots)
    tabSessions = filter(lambda tab: tab.duration.total_seconds() > 0, tabSessions)
    searchSessions = filter(isFromSearch, tabSessions)
    otherSessions = filter(lambda tab: not isFromSearch(tab), tabSessions)
    return searchSessions, otherSessions, snapshots

#snapshots, focuses, navs = loadEverything('55f2270a00823a5906ab727f')
def analysis(user):

    searchSessions, otherSessions, snapshots = getTabSessions(user)

    logDuration = snapshots[-1].endTime - snapshots[0].time

    if len(searchSessions) == 0 or len(otherSessions) == 0:
        return

    stats = defaultdict(list)
    for tabSessions in (searchSessions, otherSessions):
        revisitations = map(lambda x: (x.revisitation()+1)/x.duration.total_seconds(), tabSessions)
        duration = reduce(add, map(attrgetter('duration'), tabSessions))
        queueDuration = reduce(add, map(attrgetter('queueDuration'), tabSessions))
        readingDuration = reduce(add, map(attrgetter('readingDuration'), tabSessions))
        backgroundDuration = reduce(add, map(attrgetter('backgroundDuration'), tabSessions))
        obsoleteDuration = reduce(add, map(attrgetter('obsoleteDuration'), tabSessions))

        perc = lambda a, b: '%.2f%%' % (100.0 * a.total_seconds() / b.total_seconds() )
        perc2 = lambda a, b: (100.0 * a.total_seconds() / b.total_seconds() )

        print >> sys.stderr, ''
        print >> sys.stderr, 'Tab time:\t', duration
        print >> sys.stderr, 'Queue time:\t', queueDuration, perc(queueDuration, duration)
        print >> sys.stderr, 'Read time:\t', readingDuration, perc(readingDuration, duration)
        print >> sys.stderr, 'BG time:\t', backgroundDuration, perc(backgroundDuration, duration)
        print >> sys.stderr, 'Obsolte time:\t', obsoleteDuration, perc(obsoleteDuration, duration)
        print >> sys.stderr, 'Average revisitations per "tab":', sum(revisitations) / float(len(revisitations))
        print >> sys.stderr, 'Revisitation dist:\n', Counter(revisitations).most_common()

        stats['queue'].append(perc2(queueDuration, duration))
        stats['read'].append(perc2(readingDuration, duration))
        stats['bg'].append(perc2(backgroundDuration, duration))
        stats['obsolete'].append(perc2(obsoleteDuration, duration))
        stats['revisitation'].append(sum(revisitations) / float(len(revisitations)))
    print >> sys.stderr, '-' * 55

    print user, '\t', 
    print logDuration, '\t', logDuration.total_seconds(), '\t',
    print duration, '\t', duration.total_seconds(), '\t',
    for key in ['queue', 'read', 'bg', 'obsolete', 'revisitation']:
        print stats[key][0] - stats[key][1], '\t',
    print
    sys.stdout.flush()


for user in users:
    analysis(user)

import sys
import cPickle as pickle
from itertools import *
from operator import *

from loaders import *
from containers import *
from collections import Counter

'''
import subprocess
node = subprocess.Popen(['node', 'aes_decrypt.js'])

import zerorpc
c = zerorpc.Client()
c.connect("tcp://127.0.0.1:4242")
key = "bfe9730e-b2ec-45cf-9d8b-a52cf6308b31"
'''

#snapshots, focuses, navs = loadEverything('55f2270a00823a5906ab727f')
snapshots, focuses, navs = loadEverything(sys.argv[1])
print >> sys.stderr, 'Checking snapshot integrity...',
for snapshot in snapshots:
    snapshot.fsck()
print >> sys.stderr, ' Done'

tabSessions = extractTabSessions(snapshots)

'''
tabSessions = filter(lambda ts: c.decrypt(ts.tab.urlHash, key) != 'chrome://newtab/', tabSessions)
node.terminate()
node.kill()
'''

revisitations = map(lambda x: x.revisitation(), tabSessions)
duration = reduce(add, map(attrgetter('duration'), tabSessions))
queueDuration = reduce(add, map(attrgetter('queueDuration'), tabSessions))
readingDuration = reduce(add, map(attrgetter('readingDuration'), tabSessions))
backgroundDuration = reduce(add, map(attrgetter('backgroundDuration'), tabSessions))
obsoleteDuration = reduce(add, map(attrgetter('obsoleteDuration'), tabSessions))

perc = lambda a, b: '%.2f%%' % (100.0 * a.total_seconds() / b.total_seconds() )

print
print 'Time analysis for 55f2270a00823a5906ab727f'
print
print 'Tab time:\t', duration
print 'Queue time:\t', queueDuration, perc(queueDuration, duration)
print 'Read time:\t', readingDuration, perc(readingDuration, duration)
print 'BG time:\t', backgroundDuration, perc(backgroundDuration, duration)
print 'Obsolte time:\t', obsoleteDuration, perc(obsoleteDuration, duration)
print 'Average revisitations per "tab":', sum(revisitations) / float(len(revisitations))
print 'Revisitation dist:\n', Counter(revisitations).most_common()


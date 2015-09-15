
import sys
import cPickle as pickle
from itertools import *

from loaders import *
from containers import *

def main():

    key = "bfe9730e-b2ec-45cf-9d8b-a52cf6308b31"

    import subprocess
    node = subprocess.Popen(['node', 'aes_decrypt.js'])

    import zerorpc
    c = zerorpc.Client()
    c.connect("tcp://127.0.0.1:4242")

    snapshots, focuses, navs = loadEverything('55f2270a00823a5906ab727f')

    print >> sys.stderr, 'Checking snapshot integrity...',
    for snapshot in snapshots:
        snapshot.fsck()
    print >> sys.stderr, ' Done'

    for snapshot in snapshots:
        for tab in snapshot.tabs:
            if not tab.init:
                continue
            if hasattr(tab, 'source') and tab.source != None:
                continue
            if hasattr(tab, 'tabSource') and tab.tabSource != None:
                continue

            print c.decrypt(tab.urlHash, key)
            if tab.query != None and tab.query != []:
                query = [c.decrypt(query, key) for query in tab.query]
                print '  ', '\t'.join(query)
            print tab.toDictionary()

    node.terminate()
    node.kill()

main()


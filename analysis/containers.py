import datetime
from itertools import ifilter
from operator import *
from collections import Counter

class Tab:
    def __init__(self, tab):
        self.snapshotId = tab['snapshotId']
        self.windowId = tab['windowId']
        self.id = tab['tabId']
        self.openerTabId = tab['openerTabId']
        self.index = tab['index']
        self.status = tab['status']
        self.snapshotAction = tab['action']
        self.domain = tab['domainHash']
        self.url = tab['urlHash']
        self.domainHash = tab['domainHash']
        self.urlHash = tab['urlHash']
        self.favIconUrl = tab['favIconUrl']
        self.time = tab['time']
        self.query = tab['query']

        self.windowId = int(self.windowId)
        if self.id == None:
            self.id = -1
        else:
            self.id = int(self.id)
        if self.index == None:
            self.index = -1
        else:
            self.index = int(self.index)
        if self.openerTabId == 'undefined' or self.openerTabId == 'null' or self.openerTabId == None:
            self.openerTabId = -1
        else:
            self.openerTabId = int(self.openerTabId)
        if self.query != None:
            self.query = self.query.split(' ')

    def directSource(self):
        if hasattr(self, 'source') and self.source != None:
            return self.source
        return None

    def indirectSources(self):
        if hasattr(self, 'source') and self.source != None:
            return [self.directSource()] + self.directSource().indirectSources()
        return []

    def __repr__(self):
        source = ''
        if hasattr(self, 'source') and self.source != None:
            source = '\n    from: %s\n  ' % self.source
        if not hasattr(self, 'init'):
            self.init = False
        out = ('<Tab %d:%d %s: %s%s>%s' % (self.windowId, self.id, self.status, self.url, source, self.init and ' (new)' or '')).encode('utf8')
        return out

    def getUrl(self):
        if len(self.url.strip()) == 0:
            url = self.urlHash
        else:
            url = self.url
        return url

    def getDomain(self):
        if len(self.domain.strip()) == 0:
            domain = self.domainHash
        else:
            domain = self.domain
        return domain

class Focus:
    def __init__(self, row):
        self.action = row['action']
        self.windowId = int(row['windowId'])
        self.id = int(row['tabId'])
        self.time = row['time']

    def __repr__(self):
        return ('<Focus %s %d:%d @ %s>' % (self.action, self.windowId, self.id, self.time)).encode('utf8')

class Nav:
    def __init__(self, row):
        self.source = int(row['from'])
        self.target = int(row['to'])
        self.time = row['time']

    def __repr__(self):
        return ('<Nav %d->%d @ %s>' % (self.source, self.target, self.time)).encode('utf8')

class Snapshot:
    def __init__(self, rows):
        self.tabs = map(Tab, rows)
        _idSet = set([])
        # remove dup tabs
        for idx in range(len(self.tabs)):
            if self.tabs[idx].id in _idSet:
                self.tabs[idx] = None
            else:
                _idSet.add(self.tabs[idx].id)
        self.tabs = filter(lambda x: x != None, self.tabs)

        
        self.snapshotId = self.tabs[0].snapshotId
        self.time = self.tabs[0].time

        # hotfix for Nathan's log
        for tab in self.tabs:
            tab.time = self.time

        self.endTime = None
        self.snapshotAction = self.tabs[0].snapshotAction

        self.tabs.sort(key=lambda tab: (tab.windowId, tab.index))

        if len(self.tabs) == 1 and self.snapshotAction == 'allTabClosed':
            self.tabs = []

        self.fsck()

    def __checkUniqueAttribute__(self, attr, objs):
        values = map(attrgetter(attr), objs)
        assert len(set(values)) == 1

    def __lt__(self, other):
        if type(other) == datetime.datetime:
            return self.time.__lt__(other)
        return self.time.__lt__(other.time)

    def fsck(self):
        if len(self.tabs) > 0:
            self.__checkUniqueAttribute__('snapshotId', self.tabs)
            self.__checkUniqueAttribute__('time', self.tabs)
            self.__checkUniqueAttribute__('snapshotAction', self.tabs)
            tabIdCounts = Counter(map(attrgetter('id'), self.tabs))
            assert(tabIdCounts.most_common()[0][1] == 1)

        if hasattr(self, 'focuses'):
            assert(hasattr(self, 'tabs'))
            for focus in self.focuses:
                assert(self.hasTab(focus.id))



    def duration(self):
        if not self.endTime:
            return None
        return self.endTime - self.time

    def hasTab(self, id): #TODO: optimize this
        #return len(filter(lambda tab: tab.id == id, self.tabs)) > 0 # 32.86s for 5 runs
        return next(ifilter(lambda tab: tab.id == id, self.tabs), None) != None # 36.343s for 5 runs

    def findTab(self, id): #TODO: optimize this
        return next(ifilter(lambda tab: tab.id == id, self.tabs), None)

    def __len__(self):
        return self.tabs.__len__()

    def __repr__(self):
        focusstr = ''
        if hasattr(self, 'lastFocus'):
            focusstr += '\n  (last) %s' % self.lastFocus
        if hasattr(self, 'focuses'):
            for focus in self.focuses:
                focusstr += '\n  %s' % focus
        return ('[Snapshot:%s for %s @ %s ~ %s - %s\n  %s%s\n]\n' % (
            self.snapshotAction, self.duration(), self.time, self.endTime, self.snapshotId,
            '\n  '.join(map(str, self.tabs)),
            focusstr
        )).encode('utf8')


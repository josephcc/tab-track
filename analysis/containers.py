import datetime
from itertools import ifilter
from operator import *

class Tab:
    def __init__(self, row):
        self.snapshotId, self.windowId, self.id, self.openerTabId, self.index, self.status, self.snapshotAction, self.domain, self.url, self.domainHash, self.urlHash, self.favIconUrl, self.time = row

        self.time = datetime.datetime.fromtimestamp(int(self.time)/1000.0)
        self.windowId = int(self.windowId)
        self.id = int(self.id)
        self.index = int(self.index)
        if self.openerTabId == 'undefined':
            self.openerTabId = -1
        else:
            self.openerTabId = int(self.openerTabId)

    def __repr__(self):
        source = ''
        if hasattr(self, 'source') and self.source != None:
            source = '\n    from: %s\n  ' % self.source
        out = ('<Tab %d:%d %s: %s%s>' % (self.windowId, self.id, self.status, self.url, source)).encode('utf8')
        return out

class Focus:
    def __init__(self, row):
        row[1] = int(row[1])
        row[2] = int(row[2])
        row[3] = datetime.datetime.fromtimestamp(int(row[3])/1000.0)
        self.action, self.windowId, self.id, self.time = row

    def __repr__(self):
        return ('<Focus %s %d:%d @ %s>' % (self.action, self.windowId, self.id, self.time)).encode('utf8')

class Nav:
    def __init__(self, row):
        row[0] = int(row[0])
        row[1] = int(row[1])
        row[2] = datetime.datetime.fromtimestamp(int(row[2])/1000.0)
        self.source, self.target, self.time = row

    def __repr__(self):
        return ('<Nav %d->%d @ %s>' % (self.source, self.target, self.time)).encode('utf8')


class Snapshot:
    def __init__(self, rows):
        self.tabs = map(Tab, rows)
        self.fsck()
        
        self.snapshotId = self.tabs[0].snapshotId
        self.time = self.tabs[0].time
        self.endTime = None
        self.snapshotAction = self.tabs[0].snapshotAction

        self.tabs.sort(key=lambda tab: (tab.windowId, tab.index))

    def __checkUniqueAttribute__(self, attr, objs):
        values = map(attrgetter(attr), objs)
        assert len(set(values)) == 1

    def fsck(self):
        self.__checkUniqueAttribute__('snapshotId', self.tabs)
        self.__checkUniqueAttribute__('time', self.tabs)
        self.__checkUniqueAttribute__('snapshotAction', self.tabs)

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


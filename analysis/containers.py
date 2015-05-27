import datetime
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
        out = ('<Tab %d:%d %s: %s>' % (self.windowId, self.index, self.status, self.url)).encode('utf8')
        return out

class Focus:
    def __init__(self, row):
        row[1] = int(row[1])
        row[2] = int(row[2])
        row[3] = datetime.datetime.fromtimestamp(int(row[3])/1000.0)
        self.action, self.windowId, self.id, self.time = row

    def __repr__(self):
        return ('<Focus %s %d:%d @ %s>' % (self.action, self.windowId, self.id, self.time)).encode('utf8')


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

    def duration(self):
        if not self.endTime:
            return None
        return self.endTime - self.time

    def __len__(self):
        return self.tabs.__len__()

    def __repr__(self):
        focus = ''
        if hasattr(self, 'focuses'):
            focus += '\n  %s' % self.focuses[0]
            focus += '\n  %s' % self.focuses[-1]
        return ('[Snapshot:%s for %s @ %s - %s\n  %s%s\n]\n' % (
            self.snapshotAction, self.duration(), self.time, self.snapshotId,
            '\n  '.join(map(str, self.tabs)),
            focus
        )).encode('utf8')




if __name__ == '__main__':
    import sys
    from loaders import *
    snapshots = loadTabSnapshots(sys.argv[1])
    focuses = loadFocus(sys.argv[2])

    addFocusToSnapshots(snapshots, focuses)

    for snapshot in snapshots:
        print snapshot






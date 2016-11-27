from pymongo import MongoClient

DB = MongoClient('localhost', 27017).test

users = set(DB.tabinfos.distinct('user')) & set(DB.navinfos.distinct('user')) & set(DB.focusinfos.distinct('user'))
users = map(str, list(users))

if __name__ == '__main__':
    print '\n'.join(users)


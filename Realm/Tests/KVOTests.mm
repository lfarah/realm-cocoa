////////////////////////////////////////////////////////////////////////////
//
// Copyright 2015 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import "RLMTestCase.h"
#import "RLMPredicateUtil.h"

#import <memory>

@interface KVOTests : RLMTestCase
@end

struct KVOHelper {
    id observer;
    id obj;
    NSString *keyPath;
    bool called = false;
    void (^block)(NSString *, id, NSDictionary *);

    KVOHelper(id observer, id obj, NSString *keyPath)
    : observer(observer), obj(obj), keyPath(keyPath)
    {
        [obj addObserver:observer forKeyPath:keyPath options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:this];
    }

    ~KVOHelper() {
        [obj removeObserver:observer forKeyPath:keyPath context:this];
        id self = observer;
        XCTAssertTrue(called);
    }

    void operator()(NSString *key, id obj, NSDictionary *changeDictionary) {
        called = true;
        block(key, obj, changeDictionary);
    }
};

@implementation KVOTests
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    (*static_cast<KVOHelper *>(context))(keyPath, object, change);
}

- (std::unique_ptr<KVOHelper>)expectChangeToProperty:(NSString *)key onObject:(id)obj from:(id)oldValue to:(id)newValue {
    auto h = std::make_unique<KVOHelper>(self, obj, key);
    h->block = ^(NSString *keyPath, id objSeen, NSDictionary *changeDictionary) {
        XCTAssertEqualObjects(keyPath, key);
        XCTAssertEqualObjects(obj, objSeen);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeOldKey], oldValue);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeNewKey], newValue);
    };
    return h;
}

- (std::unique_ptr<KVOHelper>)expectNoChangeToProperty:(NSString *)key onObject:(id)obj {
    auto h = std::make_unique<KVOHelper>(self, obj, key);
    h->called = true;
    h->block = ^(NSString *, id, NSDictionary *) {
        XCTFail(@"Should not have been called");
    };
    return h;
}
@end

@interface KVOObject : NSObject
@property (nonatomic) int16_t int16;
@property (nonatomic) int32_t int32;
@property (nonatomic) int64_t int64;
@end
@implementation KVOObject
@end

@interface KVOSingleObjectTests : KVOTests
@property (nonatomic, strong) RLMRealm *realm;
@end

@implementation KVOSingleObjectTests {
    RLMRealm *_realm;
}
- (void)setUp {
    [super setUp];
    _realm = RLMRealm.defaultRealm;
    [_realm beginWriteTransaction];
    assert(_realm);
}

- (void)tearDown {
    NSLog(@"tearDown %p", self);
    assert(_realm);
    [self.realm cancelWriteTransaction];
    self.realm = nil;
    [super tearDown];
}

- (id)createObject {
    return [AllIntSizesObject createInDefaultRealmWithObject:@[@1, @2, @3]];
}

- (void)testSimple {
    AllIntSizesObject *obj = [self createObject];
    {
        auto h = [self expectChangeToProperty:@"int32" onObject:obj from:@2 to:@10];
        obj.int32 = 10;
    }
    {
        auto h = [self expectChangeToProperty:@"int32" onObject:obj from:@10 to:@1];
        obj.int32 = 1;
    }
    {
        auto h = [self expectChangeToProperty:@"int32" onObject:obj from:@1 to:@1];
        obj.int32 = 1;
    }
}

- (void)testMultipleObservers {
    AllIntSizesObject *obj = [self createObject];
    {
        auto h1 = [self expectChangeToProperty:@"int32" onObject:obj from:@2 to:@10];
        auto h2 = [self expectChangeToProperty:@"int32" onObject:obj from:@2 to:@10];
        auto h3 = [self expectChangeToProperty:@"int32" onObject:obj from:@2 to:@10];
        obj.int32 = 10;
    }
}

- (void)testMultpleProperties {
    assert(_realm);
    AllIntSizesObject *obj = [self createObject];
    {
        auto h1 = [self expectChangeToProperty:@"int16" onObject:obj from:@1 to:@2];
        auto h2 = [self expectNoChangeToProperty:@"int32" onObject:obj];
        auto h3 = [self expectNoChangeToProperty:@"int64" onObject:obj];
        obj.int16 = 2;
    }
    {
        auto h1 = [self expectNoChangeToProperty:@"int16" onObject:obj];
        auto h2 = [self expectChangeToProperty:@"int32" onObject:obj from:@2 to:@4];
        auto h3 = [self expectNoChangeToProperty:@"int64" onObject:obj];
        obj.int32 = 4;
    }
    assert(_realm);
}

- (void)testMultipleObjects {
    AllIntSizesObject *obj1 = [self createObject];
    AllIntSizesObject *obj2 = [self createObject];
    {
        auto h1 = [self expectChangeToProperty:@"int32" onObject:obj1 from:@2 to:@10];
        auto h2 = [self expectNoChangeToProperty:@"int32" onObject:obj2];
        obj1.int32 = 10;
    }
}
@end

@interface KVONSObjectTests : KVOSingleObjectTests
@end
@implementation KVONSObjectTests
- (id)createObject {
    KVOObject *obj = [KVOObject new];
    obj.int16 = 1;
    obj.int32 = 2;
    obj.int64 = 3;
    return obj;
}

#if 0
- (void)testOtherObject {
    RLMRealm *realm = RLMRealm.defaultRealm;
    [realm beginWriteTransaction];

    IntObject *obj1 = [IntObject createInDefaultRealmWithObject:@[@5]];
    IntObject *obj2 = [IntObject allObjects].firstObject;

    __block bool called = false;
    auto h = KVOHelper(self, obj2, @"intCol", ^(NSString *keyPath, id obj, NSDictionary *changeDictionary) {
        XCTAssertEqualObjects(keyPath, @"intCol");
        XCTAssertEqualObjects(obj, obj2);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeOldKey], @5);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeNewKey], @10);
        called = true;
    });
    obj1.intCol = 10;
    XCTAssertTrue(called);
    
    [realm commitWriteTransaction];
}

- (void)testRefresh {
    RLMRealm *realm = RLMRealm.defaultRealm;
    [realm beginWriteTransaction];

    IntObject *obj1 = [IntObject createInDefaultRealmWithObject:@[@5]];
    [realm commitWriteTransaction];

    __block bool called = false;
    auto h = KVOHelper(self, obj1, @"intCol", ^(NSString *keyPath, id obj, NSDictionary *changeDictionary) {
        XCTAssertEqualObjects(keyPath, @"intCol");
        XCTAssertEqualObjects(obj, obj1);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeOldKey], @5);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeNewKey], @10);
        called = true;
    });

    dispatch_queue_t queue = dispatch_queue_create("queue", 0);
    dispatch_async(queue, ^{
        IntObject *obj2 = [IntObject allObjects].firstObject;
        [obj2.realm transactionWithBlock:^{
            obj2.intCol = 10;
        }];
    });
    dispatch_sync(queue, ^{});

    XCTAssertFalse(called);
    [realm refresh];
    XCTAssertTrue(called);
}

- (void)testOnlyCorrectProperty {
    RLMRealm *realm = RLMRealm.defaultRealm;
    [realm beginWriteTransaction];

    AllIntSizesObject *obj1 = [AllIntSizesObject createInDefaultRealmWithObject:@[@1, @2, @3]];

    auto h1 = KVOHelper(self, obj1, @"int16", ^(NSString *, id, NSDictionary *) {
        XCTFail(@"int16 modified");
    });

    __block bool called = false;
    auto h = KVOHelper(self, obj1, @"int32", ^(NSString *keyPath, id obj, NSDictionary *changeDictionary) {
        XCTAssertEqualObjects(keyPath, @"int32");
        XCTAssertEqualObjects(obj, obj1);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeOldKey], @2);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeNewKey], @4);
        called = true;
    });

    obj1.int32 = 4;
    XCTAssertTrue(called);
    [realm commitWriteTransaction];

    called = false;
    dispatch_queue_t queue = dispatch_queue_create("queue", 0);
    dispatch_async(queue, ^{
        AllIntSizesObject *obj2 = [AllIntSizesObject allObjects].firstObject;
        [obj2.realm transactionWithBlock:^{
            obj2.int64 = 6;
        }];
    });
    dispatch_sync(queue, ^{});

    XCTAssertFalse(called);
    [realm refresh];
    XCTAssertFalse(called);
}

- (void)testMultipleProperties {
    RLMRealm *realm = RLMRealm.defaultRealm;
    [realm beginWriteTransaction];

    AllIntSizesObject *obj1 = [AllIntSizesObject createInDefaultRealmWithObject:@[@1, @2, @3]];

    __block bool called1 = false;
    auto h1 = KVOHelper(self, obj1, @"int16", ^(NSString *keyPath, id obj, NSDictionary *changeDictionary) {
        XCTAssertEqualObjects(keyPath, @"int16");
        XCTAssertEqualObjects(obj, obj1);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeOldKey], @1);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeNewKey], @2);
        called1 = true;
    });

    __block bool called2 = false;
    auto h2 = KVOHelper(self, obj1, @"int32", ^(NSString *keyPath, id obj, NSDictionary *changeDictionary) {
        XCTAssertEqualObjects(keyPath, @"int32");
        XCTAssertEqualObjects(obj, obj1);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeOldKey], @2);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeNewKey], @4);
        called2 = true;
    });

    __block bool called3 = false;
    auto h3 = KVOHelper(self, obj1, @"int64", ^(NSString *keyPath, id obj, NSDictionary *changeDictionary) {
        XCTAssertEqualObjects(keyPath, @"int64");
        XCTAssertEqualObjects(obj, obj1);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeOldKey], @3);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeNewKey], @6);
        called3 = true;
    });

    obj1.int16 = 2;
    XCTAssertTrue(called1);
    obj1.int32 = 4;
    XCTAssertTrue(called2);
    obj1.int64 = 6;
    XCTAssertTrue(called3);
    [realm commitWriteTransaction];
}

- (void)testMultiplePropertiesRefresh {
    RLMRealm *realm = RLMRealm.defaultRealm;
    [realm beginWriteTransaction];

    AllIntSizesObject *obj1 = [AllIntSizesObject createInDefaultRealmWithObject:@[@1, @2, @3]];
    [realm commitWriteTransaction];

    __block bool called1 = false;
    auto h1 = KVOHelper(self, obj1, @"int16", ^(NSString *keyPath, id obj, NSDictionary *changeDictionary) {
        XCTAssertEqualObjects(keyPath, @"int16");
        XCTAssertEqualObjects(obj, obj1);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeOldKey], @1);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeNewKey], @2);
        called1 = true;
    });

    __block bool called2 = false;
    auto h2 = KVOHelper(self, obj1, @"int32", ^(NSString *keyPath, id obj, NSDictionary *changeDictionary) {
        XCTAssertEqualObjects(keyPath, @"int32");
        XCTAssertEqualObjects(obj, obj1);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeOldKey], @2);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeNewKey], @4);
        called2 = true;
    });

    __block bool called3 = false;
    auto h3 = KVOHelper(self, obj1, @"int64", ^(NSString *keyPath, id obj, NSDictionary *changeDictionary) {
        XCTAssertEqualObjects(keyPath, @"int64");
        XCTAssertEqualObjects(obj, obj1);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeOldKey], @3);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeNewKey], @6);
        called3 = true;
    });

    dispatch_queue_t queue = dispatch_queue_create("queue", 0);
    dispatch_async(queue, ^{
        AllIntSizesObject *obj2 = [AllIntSizesObject allObjects].firstObject;
        [obj2.realm transactionWithBlock:^{
            obj2.int16 = 2;
        }];
    });
    dispatch_sync(queue, ^{});
    [realm refresh];
    XCTAssertTrue(called1);

    XCTAssertFalse(called2);
    dispatch_async(queue, ^{
        AllIntSizesObject *obj2 = [AllIntSizesObject allObjects].firstObject;
        [obj2.realm transactionWithBlock:^{
            obj2.int32 = 4;
        }];
    });
    dispatch_sync(queue, ^{});
    [realm refresh];
    XCTAssertTrue(called2);

    XCTAssertFalse(called3);
    dispatch_async(queue, ^{
        AllIntSizesObject *obj2 = [AllIntSizesObject allObjects].firstObject;
        [obj2.realm transactionWithBlock:^{
            obj2.int64 = 6;
        }];
    });
    dispatch_sync(queue, ^{});
    [realm refresh];
    XCTAssertTrue(called3);
}

- (void)testUnrelatedObjects {
    RLMRealm *realm = RLMRealm.defaultRealm;
    [realm beginWriteTransaction];

    AllIntSizesObject *obj1 = [AllIntSizesObject createInDefaultRealmWithObject:@[@1, @2, @3]];
    AllIntSizesObject *obj2 = [AllIntSizesObject createInDefaultRealmWithObject:@[@1, @2, @3]];

    auto h1 = KVOHelper(self, obj1, @"int16", ^(NSString *, id, NSDictionary *) {
        XCTFail(@"obj1 modified");
    });
    auto h2 = KVOHelper(self, obj1, @"int32", ^(NSString *, id, NSDictionary *) {
        XCTFail(@"obj1 modified");
    });
    __block bool called = false;
    auto h3 = KVOHelper(self, obj2, @"int32", ^(NSString *keyPath, id obj, NSDictionary *changeDictionary) {
        XCTAssertEqualObjects(keyPath, @"int32");
        XCTAssertEqualObjects(obj, obj2);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeOldKey], @2);
        XCTAssertEqualObjects(changeDictionary[NSKeyValueChangeNewKey], @4);
        called = true;
    });

    obj2.int32 = 4;
    XCTAssertTrue(called);
    [realm commitWriteTransaction];

    dispatch_queue_t queue = dispatch_queue_create("queue", 0);
    dispatch_async(queue, ^{
        AllIntSizesObject *obj2 = [AllIntSizesObject allObjects].firstObject;
        [obj2.realm transactionWithBlock:^{
            obj2.int16 = 0;
        }];
    });
    dispatch_sync(queue, ^{});
}
#endif

@end

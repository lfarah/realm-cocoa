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

#import "TestUtils.h"

#import <Realm/Realm.h>
#import <Realm/RLMRealmUtil.h>
#import <XCTest/XCTestCase.h>

void RLMAssertThrows(XCTestCase *self, dispatch_block_t block, NSString *message, NSString *fileName, NSUInteger lineNumber) {
    BOOL didThrow = NO;
    @try {
        block();
    }
    @catch (...) {
        didThrow = YES;
    }
    if (!didThrow) {
        NSString *prefix = @"The given expression failed to throw an exception";
        message = message ? [NSString stringWithFormat:@"%@ (%@)",  prefix, message] : prefix;
        [self recordFailureWithDescription:message inFile:fileName atLine:lineNumber expected:NO];
    }
}

void RLMDeallocateRealm(NSString *path) {
    __weak RLMRealm *realm;

    @autoreleasepool {
        realm = RLMGetThreadLocalCachedRealmForPath(path);
    }

    while (true) {
        @autoreleasepool {
            if (!realm) {
                return;
            }
        }
        CFRelease((__bridge void *)realm);
    }
}

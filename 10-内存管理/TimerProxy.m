//
//  TimerProxy.m
//  10-内存管理
//
//  Created by 刘光强 on 2020/2/13.
//  Copyright © 2020 guangqiang.liu. All rights reserved.
//

#import "TimerProxy.h"

@implementation TimerProxy

+ (instancetype)proxyWithTarget:(id)target {
    TimerProxy *proxy = [[TimerProxy alloc] init];
    proxy.target = target;
    return proxy;
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    return self.target;
}

- (void)dealloc {
    NSLog(@"%s", __func__);
}
@end

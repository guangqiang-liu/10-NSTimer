//
//  TimerProxy2.m
//  10-内存管理
//
//  Created by 刘光强 on 2020/2/13.
//  Copyright © 2020 guangqiang.liu. All rights reserved.
//

#import "TimerProxy2.h"

@implementation TimerProxy2

+ (instancetype)proxyWithTarget:(id)target {
    // 初始化proxy，NSProxy没有init方法
    TimerProxy2 *proxy = [TimerProxy2 alloc];
    proxy.target = target;
    return proxy;
}

// NSProxy调用方法直接找对应的方法，没有通过isa一层层查找
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    return [self.target methodSignatureForSelector:sel];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:self.target];
}
@end

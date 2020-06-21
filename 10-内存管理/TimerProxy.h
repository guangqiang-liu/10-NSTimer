//
//  TimerProxy.h
//  10-内存管理
//
//  Created by 刘光强 on 2020/2/13.
//  Copyright © 2020 guangqiang.liu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TimerProxy : NSObject

@property (nonatomic, weak) id target;

+ (instancetype)proxyWithTarget:(id)target;
@end

NS_ASSUME_NONNULL_END

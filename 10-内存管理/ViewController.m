//
//  ViewController.m
//  10-内存管理
//
//  Created by 刘光强 on 2020/2/13.
//  Copyright © 2020 guangqiang.liu. All rights reserved.
//

#import "ViewController.h"
#import "TimerProxy.h"
#import "TimerProxy2.h"

@interface ViewController ()

@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) NSTimer *timer;

@property (nonatomic, strong) dispatch_source_t gcdTimer;
@end

@implementation ViewController

// 解决循环引用问题
- (void)displayLinkTest {
    self.displayLink = [CADisplayLink displayLinkWithTarget:[TimerProxy proxyWithTarget:self] selector:@selector(doTask)];
    // 将displayLink添加到runloop中
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

    self.timer = [NSTimer timerWithTimeInterval:1 target:[TimerProxy2 proxyWithTarget:self] selector:@selector(doTask2) userInfo:nil repeats:YES];
    // 将timer添加到runloop中
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
}

- (void)timerTest {
    __weak typeof(self) weakSelf = self;
    
    self.timer = [NSTimer timerWithTimeInterval:1 target:weakSelf selector:@selector(doTask) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
}

- (void)timerWithTimeInterval {
    NSTimer *timer1 = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(doTask) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer1 forMode:NSDefaultRunLoopMode];
    
    NSTimer *timer2 = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        NSLog(@"2222");
    }];
    [[NSRunLoop currentRunLoop] addTimer:timer2 forMode:NSDefaultRunLoopMode];
    
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:"];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = self;
    invocation.selector = @selector(doTask2);
    NSTimer *timer3 =  [NSTimer timerWithTimeInterval:1 invocation:invocation repeats:YES];
    
    [[NSRunLoop currentRunLoop] addTimer:timer3 forMode:NSDefaultRunLoopMode];
}

- (void)scheduledTimerWithTimeInterval {
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(doTask) userInfo:nil repeats:YES];
    
    [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        NSLog(@"444");
    }];
    
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:"];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = self;
    invocation.selector = @selector(doTask2);
    [NSTimer scheduledTimerWithTimeInterval:1 invocation:invocation repeats:YES];
}

- (void)asyncTimerTest {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(doTask) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
        [[NSRunLoop currentRunLoop] run];
    });
}

- (void)gcdTimerTest {
    // 创建一个队列，如果是`dispatch_get_main_queue`那么定时器就会在主线程中执行，如果我们需要定时器在子线程中执行，我们可以创建一个队列`dispatch_queue_create("queun", DISPATCH_QUEUE_SERIAL)`
    dispatch_queue_t queue = dispatch_get_main_queue();
    
    // 创建定时器
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    
    // 设置几秒开始定时
    uint64_t startTime = 0;
    
    // 设置定时器的时间间隔
    uint64_t interval = 1;
    
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, startTime * NSEC_PER_SEC), interval * NSEC_PER_SEC, 0);
    
    // 设置定时器执行任务
    dispatch_source_set_event_handler(timer, ^{
        NSLog(@"1111");
    });
    
    // 启动定时器
    dispatch_resume(timer);
    
    // 这里需要主要，创建完gcd的定时器，我们需要使用一个强指针指向这个定时器
    self.gcdTimer = timer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)doTask {
    NSLog(@"111");
}

- (void)doTask2 {
    NSLog(@"333");
}

- (void)dealloc {
    [self.displayLink invalidate];
    [self.timer invalidate];
    
    NSLog(@"%s", __func__);
}
@end

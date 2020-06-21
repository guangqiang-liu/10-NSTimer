# 10-内存管理中NSTimer常见问题

我们在平时的项目开发过程中，经常会使用到`NSTimer`来创建定时器，但是在使用过程中有时我们又会遇到以下几个问题：

* 主线程中NSTimer创建的定时器不工作
* 异步子线程中创建的timer不工作
* 滚动列表时，NSTimer失效不工作，停止滚动timer恢复工作
* NSTimer创建的定时器，当前控制器对象销毁了，但是此时Timer还在工作，没有销毁，造成了循环引用
* NSTimer创建的定时器不准，例如设置的是1秒执行一次，最终发现有时不是一秒执行1次

我们先来了解下iOS中`NSTimer`常用的API有哪些：

```
+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)ti invocation:(NSInvocation *)invocation repeats:(BOOL)yesOrNo;
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)ti invocation:(NSInvocation *)invocation repeats:(BOOL)yesOrNo;

+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)ti target:(id)aTarget selector:(SEL)aSelector userInfo:(nullable id)userInfo repeats:(BOOL)yesOrNo;
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)ti target:(id)aTarget selector:(SEL)aSelector userInfo:(nullable id)userInfo repeats:(BOOL)yesOrNo;

+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(NSTimer *timer))block API_AVAILABLE(macosx(10.12), ios(10.0), watchos(3.0), tvos(10.0));
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(NSTimer *timer))block API_AVAILABLE(macosx(10.12), ios(10.0), watchos(3.0), tvos(10.0));
```

我们在平时的开发过程中，常用到的`NSTimer`类方法就上面这6个函数

下面我们先来探究下`NSTimer`不工作的问题，示例代码如下：

```
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    NSTimer *timer1 = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(doTask) userInfo:nil repeats:YES];

    NSTimer *timer2 = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        NSLog(@"2222");
    }];
    
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:"];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = self;
    invocation.selector = @selector(doTask);
    NSTimer *timer3 =  [NSTimer timerWithTimeInterval:1 invocation:invocation repeats:YES];
}

- (void)doTask {
    NSLog(@"1111");
}
```

从上面创建的3个timer的运行结果来看，这三个timer都没有工作，这又是为何尼，我们从`timerWithTimeInterval:`开头的函数注释可以得知，初始化出来的timer需要添加到`runloop`中才能正常使用

> Creates and returns a new NSTimer object initialized with the specified block object. This timer needs to be scheduled on a run loop (via -[NSRunLoop addTimer:]) before it will fire.

我们将timer添加到`runloop`中，修改代码如下：

```
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    NSTimer *timer1 = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(doTask) userInfo:nil repeats:YES];
    // 将timer添加到runloop
    [[NSRunLoop currentRunLoop] addTimer:timer1 forMode:NSDefaultRunLoopMode];
    
    NSTimer *timer2 = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        NSLog(@"2222");
    }];
    // 将timer添加到runloop
    [[NSRunLoop currentRunLoop] addTimer:timer2 forMode:NSDefaultRunLoopMode];
    
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:"];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = self;
    invocation.selector = @selector(doTask2);
    NSTimer *timer3 =  [NSTimer timerWithTimeInterval:1 invocation:invocation repeats:YES];
    
    // 将timer添加到runloop
    [[NSRunLoop currentRunLoop] addTimer:timer3 forMode:NSDefaultRunLoopMode];
}

- (void)doTask {
    NSLog(@"1111");
}

- (void)doTask2 {
    NSLog(@"333");
}
```

将timer添加到runloop中后，这三个timer就能正常打印工作了

接下来我们将`timerWithTimeInterval:`替换成`scheduledTimerWithTimeInterval:`，这时我们发现不将timer添加到runloop中，这时timer也都能正常工作，这又是为何尼？，我们看下`scheduledTimerWithTimeInterval:`开头的函数的注释可知，`scheduledTimerWithTimeInterval:`开头的函数创建的timer，底层已近将此timer添加到当前runloop中，不需要我们重复添加

> Creates and returns a new NSTimer object initialized with the specified block object and schedules it on the current run loop in the default mode.

```
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
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

- (void)doTask {
    NSLog(@"111");
}

- (void)doTask2 {
    NSLog(@"333");
}
```

我们从`GNU`中的源码也可以看到，`scheduledTimerWithTimeInterval:`内部确实将timer添加到runloop，源码如下：

```
/**
 * Create a timer which will fire after ti seconds and, if f is YES,
 * every ti seconds thereafter. On firing, the target object will be
 * sent a message specified by selector and with the timer as its
 * argument.<br />
 * This timer will automatically be added to the current run loop and
 * will fire in the default run loop mode.
 */
+ (NSTimer*) scheduledTimerWithTimeInterval: (NSTimeInterval)ti
				     target: (id)object
				   selector: (SEL)selector
				   userInfo: (id)info
				    repeats: (BOOL)f
{
  id t = [[self alloc] initWithFireDate: nil
			       interval: ti
				 target: object
			       selector: selector
			       userInfo: info
				repeats: f];
				
	// 将timer添加到runloop中
  [[NSRunLoop currentRunLoop] addTimer: t forMode: NSDefaultRunLoopMode];
  RELEASE(t);
  return t;
}
```

---

接下来我们再来看看在异步子线程中创建的timer不工作的问题，示例代码如下：

```
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{        
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(doTask) userInfo:nil repeats:YES];
    });
}

- (void)doTask {
    NSLog(@"111");
}
```

我们运行项目发现没有执行打印语句，timer没有工作，这是因为在异步子线程中默认是没有`runloop`的，不能将timer添加到runloop中，所以我们需要在子线程中创建一个runloop，修改代码如下：

```
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(doTask) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    });
}

- (void)doTask {
    NSLog(@"111");
}
```

我们在异步线程中创建好runloop后，运行项目，发现还是没有打印，这又是为啥尼，这是因为在子线程中创建的runloop，我们必须手动调用`run`方法来启动这个runloop，所以我们修改代码如下：

```
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(doTask) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
        // 启动runloop
        [[NSRunLoop currentRunLoop] run];
    });
}

- (void)doTask {
    NSLog(@"111"); // 111
}
```

---

滚动列表(继承自UIScrollView的控件)导致NSTimer失效的问题，前几个章节讲解runloop的应用时有讲解

---

接下来我们再来看看`NSTimer`造成的循环引用问题，示例代码如下：

```
@interface ViewController ()

@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) NSTimer *timer;
@end

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
        
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(doTask)];
    // 将displayLink添加到runloop中
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    self.timer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(doTask2) userInfo:nil repeats:YES];
    // 将timer添加到runloop中
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
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
```

`CADisplayLink`

> CADisplayLink也是一种定时器，定时器平均每秒刷新60次（60FPS为屏幕刷帧频率）

这里我们拿`CADisplayLink`和`NSTimer`一块分析，因为它们都会产生循环引用，并且原因也一样

当我们返回当前控制器时，我们发现当前控制器已经销毁，但是定时器任然在工作，这是因为当前控制器`self`强引用着`timer`，然而`timer`内部的实现又将传递进去的`target`参数对象进行了持有(retain操作)，这样就导致了循环引用

timer内部对`target`对象进行了持有，也就是进行了`retain`操作，使`target`对象的引用计数器+1，这个我们可以通过`timerWithTimeInterval:target:selector:userInfo:repeats:`对应的`GNU`源码查看了解到，`GNU`源码如下：

```
- (id) initWithFireDate: (NSDate*)fd
	       interval: (NSTimeInterval)ti
		 target: (id)object
	       selector: (SEL)selector
	       userInfo: (id)info
		repeats: (BOOL)f
{
  if (ti <= 0.0)
    {
      ti = 0.0001;
    }
  if (fd == nil)
    {
      _date = [[NSDate_class allocWithZone: NSDefaultMallocZone()]
        initWithTimeIntervalSinceNow: ti];
    }
  else
    {
      _date = [fd copyWithZone: NSDefaultMallocZone()];
    }
    
     // 从这里可以看到，在timer内部，对传递进来的`target`对象进行了retain操作，也就是在timer内部对`target`对象进行了强引用
  _target = RETAIN(object);
  
  _selector = selector;
  _info = RETAIN(info);
  if (f == YES)
    {
      _repeats = YES;
      _interval = ti;
    }
  else
    {
      _repeats = NO;
      _interval = 0.0;
    }
  return self;
}


/**
 * Create a timer which will fire after ti seconds and, if f is YES,
 * every ti seconds thereafter. On firing, the target object will be
 * sent a message specified by selector and with the timer as its
 * argument.<br />
 * NB. To make the timer operate, you must add it to a run loop.
 */
+ (NSTimer*) timerWithTimeInterval: (NSTimeInterval)ti
			    target: (id)object
			  selector: (SEL)selector
			  userInfo: (id)info
			   repeats: (BOOL)f
{
  return AUTORELEASE([[self alloc] initWithFireDate: nil
					   interval: ti
					     target: object
					   selector: selector
					   userInfo: info
					    repeats: f]);
}
```

查看`GNU`源码，我们可以知道，`timerWithTimeInterval:target:selector:userInfo:repeats:`函数底层最终会调用`initWithFireDate:interval:target:selector:userInfo:repeats:`函数，在这个函数内部有执行`_target = RETAIN(object);`，所以会产生循环引用

那么怎么解决这个循环引用问题尼，我们将`Target`参数的self强指针改为弱指针`__weak typeof(self) weakSelf = self`是否可以尼，示例代码如下：

```
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    __weak typeof(self) weakSelf = self;
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:weakSelf selector:@selector(doTask)];
    // 将displayLink添加到runloop中
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    self.timer = [NSTimer timerWithTimeInterval:1 target:weakSelf selector:@selector(doTask2) userInfo:nil repeats:YES];
    // 将timer添加到runloop中
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
}
```

我们发现将`self`改为`weakSelf`并不能解决循环引用问题，这是因为`__weak`是用来解决`block`代码块内部的循环引用问题的，用在此处并没有作用，那我们该怎么解决这种循环引用尼？

对于`NSTimer`来说，我们可以选择使用`timerWithTimeInterval:repeats:block:`，这时就可以在block内部使用`weakSelf`来解决循环引用

```
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    __weak typeof(self) weakSelf = self;
    
    self.timer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [weakSelf doTask2];
    }];
    
    // 将timer添加到runloop中
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
}
```

但是`CADisplayLink`定时器没有带`block`的这种用法，那还是得想办法解决`target:selector:`这种用法的循环引用，这时我们可以使用代理的方式来解决，我们创建一个`target`的代理对象，将实现`doTask`方法的目标对象转移给`TimerProxy`代理对象，测试代码如下：

`TimerProxy`类

```
@interface TimerProxy : NSObject

// 弱引用
@property (nonatomic, weak) id target;

+ (instancetype)proxyWithTarget:(id)target;
@end

@implementation TimerProxy

+ (instancetype)proxyWithTarget:(id)target {
    TimerProxy *proxy = [[TimerProxy alloc] init];
    proxy.target = target;
    return proxy;
}

// 消息转发
- (id)forwardingTargetForSelector:(SEL)aSelector {
	 // 将aSelector的实现转发给self.target对象实现
    return self.target;
}

- (void)dealloc {
    NSLog(@"%s", __func__);
}
@end
```

```
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
        
    self.displayLink = [CADisplayLink displayLinkWithTarget:[TimerProxy proxyWithTarget:self] selector:@selector(doTask)];
    // 将displayLink添加到runloop中
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

    self.timer = [NSTimer timerWithTimeInterval:1 target:[TimerProxy proxyWithTarget:self] selector:@selector(doTask2) userInfo:nil repeats:YES];
    // 将timer添加到runloop中
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
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
```

我们再次运行程序，退出当前控制器，发现定时器和控制器都能正常的销毁了，这里使用弱引用的`target`就解决了循环引用问题

---

接下来我们再来看下`NSTimer`和`CADisplayLink`创建的定时器存在不准确的问题。`NSTimer`和`CADisplayLink`定时器不准是因为timer需要在runloop环境下工作，然而runloop的运行循环并不能保证每一个循环所用的时间都是相同的，可能某一个循环所用时间0.2s，或者0.2s，或者0.3s，或者0.5s，这时如果timer定时器的时间间隔是1s，但是此时runloop需要循环0.2s+0.2s+0.3s+0.5s才能执行一次定时器任务，但是这时的时间就是1.2s了，与定时器的1s就有一些误差了，所以说导致了timer不准

我们可以选择使用`GCD`来创建一个定时器，`GCD`创建的定时器不依赖与runloop的运行环境，所以就更加准确一些，示例代码如下：

```
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
        
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
```


讲解示例Demo地址：[https://github.com/guangqiang-liu/10-NSTimer]()


## 更多文章
* ReactNative开源项目OneM(1200+star)：**[https://github.com/guangqiang-liu/OneM](https://github.com/guangqiang-liu/OneM)**：欢迎小伙伴们 **star**
* iOS组件化开发实战项目(500+star)：**[https://github.com/guangqiang-liu/iOS-Component-Pro]()**：欢迎小伙伴们 **star**
* 简书主页：包含多篇iOS和RN开发相关的技术文章[http://www.jianshu.com/u/023338566ca5](http://www.jianshu.com/u/023338566ca5) 欢迎小伙伴们：**多多关注，点赞**
* ReactNative QQ技术交流群(2000人)：**620792950** 欢迎小伙伴进群交流学习
* iOS QQ技术交流群：**678441305** 欢迎小伙伴进群交流学习
# GooglyPuff
這是一個講解**Grand Centeral Dispatch**的<a href="https://www.raywenderlich.com/60749/grand-central-dispatch-in-depth-part-1">Tutorial</a>，裡面提到的點都蠻細的，像是在多執行緒下所產生問題，如<a href="https://en.wikipedia.org/wiki/Readers–writers_problem">Readers–writers problem</a>或<a href="https://zh.wikipedia.org/wiki/競爭危害">race condition</a>等等，總之這是一個中英夾雜的GCD重點整理．

<br></br>
## **What is GCD?**  
* GCD can improve your app’s responsiveness by helping you defer computationally expensive task and run them in the background.  
* GCD provides an easier concurrency model than locks and threads and helps to avoid concurrency bugs.  
* GCD can potentially optimize your code with higher performance primitives for common pattern such as singletons.  
<br></br>
## **GCD Terminology**  
* **Serial**: Tasks executed serially are always executed on at a time.  
* **Concurrent**: Tasks executed concurrently might be executed at the same time.  
* **Asynchronous**: An asynchronous function, on the other hand, returns immediately, ordering the task to be done but does not wait for it. Thus, an asynchronous function does not block the current thread of execution from proceeding on to the next function.   
```short explan
  GCD提供dispatch_async:這個function讓我們可以選擇要在哪個指定的thread上，用非同步的方式執行一個block
```
* **Synchronous**: A synchronous function returns only after the completion of a task that it orders.  
```code
不同於dispatch_async會做平行處理，呼叫dispatch_sync的時候，則是先把dispatch_sync的這個block做完之後，
才繼續執行到程式的下一行．呼叫的時候要特別小心．  
如果已經在main thread這一條thread上了，但我們卻又呼叫目前所在的main thread，就會造成死結：  
```
```code
dispatch_sync(dispatch_get_main_queue(), ^{
  [someObject doSomething];
});
```  

* **Critical Section**: This is a piece of code that must **not be executed concurrently**, that is, from two threads at once. This is usually because the code manipulates a shared resource such as a variable that can become corrupt if it’s accessed by concur- rent processes.
```code
dispatch_once() executes a block once and only once in a thread safe manner. 
Different threads that try to access the critical section — the code passed to dispatch_once — while a thread is already in this section are blocked until the critical section completes.
```  
* **Deadlock**: Two(or sometimes more) items — in most cases, threads—are said to be deadlocked if they all get stuck waiting for each other to complete or perform another action. 
e.g, The first thread can’t finish because it’s waiting for the second thread to finish.But the second thread can’t finish because it’s waiting for the first to finish.

* **Thread Safe**: Thread safe code can be safely called from multiple threads or concurrent tasks without causing any problems (data corruption, crashing, etc). Code that is not thread safe must only be run in one context at a time. An example of thread safe code is NSDictionary. You can use it from multiple threads at the same time without issue. On the other hand, NSMutableDictionary is not thread safe and should only be accessed from one thread at a time.

* **Race Condition**: 在設計Singleton模式時，可能會犯的一種錯誤情況，如下程式；
```code
+ (instancetype)sharedManager
{
    static PhotoManager *sharedPhotoManager = nil;
    if (!sharedPhotoManager) {
        sharedPhotoManager = [[PhotoManager alloc] init];
        sharedPhotoManager->_photosArray = [NSMutableArray array];
    }
    return sharedPhotoManager;
}

The if condition branch is not thread safe; 
if you invoke the method multiple times, there’s a possibility that one thread(called Thread-A) could enter the if block and a context switch could occur before sharePhotoManager is allocated. 
Then another thread(Thread-B) could enter the if, allocate an instance of the singleton, then exit.  

When the system context switch back to Thread-A, you’ll then allocate another instance of the singleton, then exit.  
At that point you have two instances of a singleton.
```
```code
可以用dispatch_once來設計Singleton，dispatch_once保證某個block只會被執行一次．
能有效解決同時可能有Thread-A和Thread-B進入if條件後產生兩個instance的情況，如下程式；

+ (instancetype)sharedManager
{
    static PhotoManager *sharedPhotoManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPhotoManager = [[PhotoManager alloc] init];
        sharedPhotoManager->_photosArray = [NSMutableArray array];
    });
    return sharedPhotoManager;
}
```  

* **Readers–writers problem**: In computer science, the readers-writers problems are examples of a common computing problem in concurrency. There are at least three variations of the problems, which deal with situations in which many threads try to access the same shared resource at one time. Some threads may read and some may write, with the constraint that no process may access the shared resource for either reading or writing while another process is in the act of writing to it. **GCD provides an elegant solution of creating a Readers-writer lock using dispatch barriers.**

<br></br>
## **Concurrency vs Parallelism**
Concurrency and parallelism are often mentioned together. Multi-core devices execute multiple threads at the same time via parallelism;
In order for single-cored devices to achieve parallelism, they must run a thread, perform a context switch, then run another thread or process. This usually happens quickly enough as to give the illusion of parallel execution.
<div align="center">
  <img src="https://github.com/jhsiao21/GooglyPuff/blob/master/concurrencyVSparallelism.jpg"> 
  </div>
  
## **Queue**
GCD provides dispatch queues to handle blocks of code, these queues manage the tasks you provide to GCD and execute those tasks in FIFO(First-In-First-Out) order. 

* **Serial queues** : Serial queues is one of the kind of dispatch queues that GCD provides. Tasks in serial execute one at a time, each task starting only after the preceding task has finished.
```short explan
如果我們想讓好幾件工作(Block)都在背景執行，而每件工作並非平行執行，而是一件工作做完之後，再繼續下一件工作，便可使用Serial queue.
```
<div align="center">
  <img src="https://github.com/jhsiao21/GooglyPuff/blob/master/serialqueue.jpg"> 
</div>
<br></br>

* **Concurrent queues** : Tasks in concurrent queues are guarantee to start in the order they were added.
<div align="center">
  <img src="https://github.com/jhsiao21/GooglyPuff/blob/master/concurrent.jpg"> 
</div>

* **Barrier** : barrier就像是serial queue與concurrent queue的合體，可以解決Readers–writers problem!
Notice how in normal operation the queue acts just like a normal concurrent queue. But when the barrier is executing, it essentially acts like a serial queue. That is, the barrier is the only thing executing. After the barrier finishes, the queue goes back to being a normal concurrent queue.
<div align="center">
  <img src="https://github.com/jhsiao21/GooglyPuff/blob/master/dispatch_barrier.jpg"> 
</div>

## **Queue Types**
* **Main queue**: Like any serial queue, tasks in the queue execute one at a time.It’s guaranteed that all tasks will execute on the main thread, which is the only thread allowed to update your UI. This queue is the one to use for sending messages to UIViews or posting notifications.
```short explan
dispatch_get_main_queue()，這個function可以把在背景完成的工作回到main thread
```
  
* **Global dispatch queue** : The system also provides you with several concurrent queues. Global dispatch queues are currently four queues of different priority: background, low, default, and high.
```short explan
dispatch_get_global_queue(0 , 0)這個function會讓系統根據目前的狀況，在適當時機建立一條thread,
第一個參數是這條thread執行工作的優先程度，從2(最重要)~-2(最不重要)，第二個參數是保留參數，目前沒有作用，直接填0即可． 
我們經常會讓某個time-consuming task在背景執行，執行完成後，在繼續於main thread更新UI，所以組合方式就是：
```

```code
dispatch_async(concurrentQueue, ^{
        [someObject doSomethingInBackground]; //time-consuming task
        dispatch_async(dispatch_get_main_queue(), ^{
            [someObject doSomethingOnMainThread]; //update UI
        });
    });
```

<br></br>
For more detail, you can see the website:  
https://www.raywenderlich.com/60749/grand-central-dispatch-in-depth-part-1


 

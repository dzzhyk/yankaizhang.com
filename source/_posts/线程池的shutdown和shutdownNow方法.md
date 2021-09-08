---
title: 线程池的shutdown和shutdownNow方法
date: 2021-09-08 20:29:54
categories:
- Java
tags:
- 面试
- Java并发编程
- 线程池
---

使用Java的线程池ThreadPoolExecutor类时候发现了两个不同的关闭线程池的方法：shutdown和shutdownNow方法，具体这两个方法有啥区别呢？这次一起来探讨一下：

## 线程池的状态runState

阅读ThreadPoolExecutor类的源码不难看出，线程池实现类中定义了线程池具有几个状态：

```java
/** The runState provides the main lifecycle control, taking on values:
*   RUNNING:  Accept new tasks and process queued tasks
*   SHUTDOWN: Don't accept new tasks, but process queued tasks
*   STOP:     Don't accept new tasks, don't process queued tasks,
*             and interrupt in-progress tasks
*   TIDYING:  All tasks have terminated, workerCount is zero,
*             the thread transitioning to state TIDYING
*             will run the terminated() hook method
*   TERMINATED: terminated() has completed
*/

private static final int RUNNING    = -1 << COUNT_BITS;
private static final int SHUTDOWN   =  0 << COUNT_BITS;
private static final int STOP       =  1 << COUNT_BITS;
private static final int TIDYING    =  2 << COUNT_BITS;
private static final int TERMINATED =  3 << COUNT_BITS;
```

同时，类源码中也解释了上面五个状态之间是如何切换的，这里笔者整理成一个状态转换图好了：

![线程池状态转换图](https://gitee.com/dzzhyk/MarkdownPics/raw/master/image-20210908203537430.png)

从上面的图中可以看到，这次要讨论的shutdown和shutdownNow方法是和SHUTDOWN、STOP状态相关联的



## shutdown()方法

线程池内部主要存在两个部分：保存工作线程的HashSet集合Workers，保存待执行任务的BlockingQueue集合taskQueue，线程池释放的时候，主要需要处理并且释放的资源内容也就是这两块。

对于shutdown方法，这个方法返回值为void。

-   执行了shutdown方法之后，线程池的状态切换为SHUTDOWN状态
-   对于taskQueue，线程池不再接受新的任务提交请求，但是会等待队列中已存在的任务全部执行完成



## shutdownNow()方法

对于shutdownNow方法，这个方法返回List\<Runnable>，尚未开始执行的任务列表

-   执行了shutdownNow方法之后，线程池的状态切换为STOP状态
-   对于taskQueue，线程池不再接受新的任务提交请求，并且尝试interrupt中断开始执行的任务（不一定中断成功），队列中尚未执行的任务全部以列表形式返回



## 何时进入TERMINATED状态

从线程池的状态转换图中可以看到，从调用了shutdown或者shutdownNow方法到最终线程池结束工作的TERMINATED状态仍然有一段距离，因为可能执行的任务还需要执行完成。

一般来说，因为调用shutdown或shutdownNow方法是立即返回的，并不会阻塞等待所有任务完成，所以线程池提供了额外的awaitTermination函数来实现阻塞等待所有工作完成，并且到达了TERMINATED状态。

```java
public boolean awaitTermination(long timeout, TimeUnit unit);
```

方法内部借助一个condition变量实现了阻塞等待，并且在所有任务结束时唤醒返回true


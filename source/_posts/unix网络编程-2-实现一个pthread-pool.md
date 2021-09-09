---
title: unix网络编程-2-实现一个pthread_pool
date: 2021-09-09 17:52:59
categories:
- 网络编程
tags:
- 网络编程
- 线程池
- Linux
- pthread
---

这次使用C语言，设计一个基于pthread的线程池吧。

想要设计线程池的原因有三个：

1.   想要重新锻炼下C语言的编码能力
2.   面试经常出现一些线程池的内容，笔者比较反感这些八股文，所以就简单实现一个线程池好了
3.   线程池所谓服务端必不可少的组件，后面继续学习unix网络编程的时候会用到

在开始之前按照惯例介绍一下环境：

-   macOS 10.15
-   gcc工具链（clang）
-   gdb调试（brew install gdb）



## 开始设计线程池结构

笔者参考了Java提供的ThreadPoolExecutor类，也就是线程池类，当然也顺便研究了一下源码，发现略有点复杂，我们这次就实现一个Fixed_Pool，也就是核心线程就等于工作线程数好了。

给出线程池pthread_pool的设计图如下：

<img src="https://gitee.com/dzzhyk/MarkdownPics/raw/master/image-20210909182922612.png" alt="pthread_pool设计" style="zoom:50%;" />

单看图的话还是比较简单的，因为这次写一个固定核心线程数的线程池，比如上图，核心线程数为2，等待队列长度为4，某一时刻，这个线程池能负载的最大任务数为6个（2个正在执行，4个等待执行）

如果等待队列已满，此时再尝试提交任务的话就会返回-1，代表提交失败。



## 定义核心结构体

从上面的设计图中看到，需要设计的结构有两个：pthread_pool类型和task任务类型

于是给出下面的设计：

```c
/**
 * pthread_pool
 * 实现一个基于pthread的Fixed线程池，创建初期就初始化n个线程，n个核心线程全部活跃
 * 线程池真正可以负载的任务数量t = 线程数量w + 等待队列长度n
 * 例如：一个3核心线程，队列长度为2的线程池，其负载能力最大为5
 */

typedef enum _pthread_pool_state {
    RUNNING,   // 运行
    TERMINATED // 结束
} pthread_pool_state;

typedef struct _pthread_pool_task_t {
    void *(*func)(void *); // 任务函数
    void *args;            // 函数参数
} pthread_pool_task_t;

struct pthread_pool_t {
    pthread_mutex_t mutex; // 内部锁
    pthread_cond_t cond;   // 同步条件

    pthread_t *threads; // 线程数组
    int thread_count;   // 核心线程数量

    pthread_pool_task_t *task_queue; // 任务队列
    int task_head;                   // 头部指针
    int task_tail;                   // 尾部指针
    int task_queue_size;             // 最大任务队列长度
    int task_count;                  // 当前任务数量
    pthread_pool_state pool_state;   // 线程池状态
};

#define SPP struct pthread_pool_t
```

笔者这里额外加了一个state枚举类型来表示线程池当前的执行状态，当然执行状态很简单只有两种：运行中和终止



## 设计线程池的关键函数

对于一个线程池，不难想到有几个核心方法需要设计并且实现：创建、提交任务、核心线程工作函数、关闭、释放资源

下面给出笔者设计的这5个函数的定义：

```c
void *pthread_pool_worker(void *);
void pthread_pool_release(SPP *);
int pthread_pool_submit(SPP *, void *(*)(void *), void *);
void pthread_pool_shutdown(SPP *);
SPP *pthread_pool_create(int, int);
```



### pthread_pool_create函数实现

创建一个线程池，即定义一个结构体对象，然后分配相应的内存，同时初始化其中的一些参数即可。

因为是核心线程全部运行，所以创建的时候就初始化核心线程数量的工作线程数组

```c
// 新建一个线程池
SPP *pthread_pool_create(int thread_count, int queue_size) {
    assert(thread_count > 0 && queue_size > 0);

    SPP *tmp = (SPP *)malloc(sizeof(SPP));

    if (pthread_mutex_init(&tmp->mutex, NULL) != 0) return NULL;
    if (pthread_cond_init(&tmp->cond, NULL) != 0) return NULL;

    pthread_attr_t tmp_attr;
    if (pthread_attr_init(&tmp_attr) != 0) return NULL;

    tmp->thread_count = thread_count;
    tmp->threads = (pthread_t *)malloc(thread_count * sizeof(pthread_t));
    tmp->task_queue_size = queue_size;
    tmp->task_queue = (pthread_pool_task_t *)malloc(queue_size * sizeof(pthread_pool_task_t));
    tmp->task_head = 0;
    tmp->task_tail = 0;
    tmp->task_count = 0;
    tmp->pool_state = RUNNING;

    // 设置线程退出时自动回收资源
    pthread_attr_setdetachstate(&tmp_attr, PTHREAD_CREATE_DETACHED);

    int flag = 1;
    for (int i = 0; i < tmp->thread_count; ++i) {
        // printf("创建%d号线程\n", i);
        int ret = pthread_create(&(tmp->threads[i]), &tmp_attr, pthread_pool_worker, tmp);
        if (ret != 0) {
            flag = 0;
            break;
        }
    }
    if (!flag) {
        pthread_pool_shutdown(tmp);
        return NULL;
    }

    return tmp;
}
```



### pthread_pool_worker函数实现

worker函数是线程池每个内置工作线程不断运行的一个方法，在这个方法里线程不断检查任务队列是否有任务需要完成，否则就阻塞等待被唤醒；如何唤醒呢？当提交任务的时候会通过condition唤醒阻塞的线程检查任务队列执行。

-   当确认存在任务需要完成的时候，线程会获取这个任务并且将任务队列头指针后移一位，然后执行这个任务

-   如果线程池需要关闭，那么worker函数会break退出，同时回收工作线程资源

```c
// 线程池内置线程处理函数
void *pthread_pool_worker(void *args) {
    SPP *pool = (SPP *)args;
    pthread_pool_task_t task;

    while (1) {
        pthread_mutex_lock(&(pool->mutex));
        // 尝试循环获取任务，没有任务就阻塞等待
        while (pool->task_count == 0 && pool->pool_state == RUNNING) {
            pthread_cond_wait(&(pool->cond), &(pool->mutex));
        }

        if (pool->pool_state != RUNNING) break;
        task.func = pool->task_queue[pool->task_head].func;
        task.args = pool->task_queue[pool->task_head].args;

        pool->task_head++;
        if (pool->task_head == pool->task_queue_size) pool->task_head = 0;
        pool->task_count--;
        pthread_mutex_unlock(&(pool->mutex));
	
        // 执行任务
        task.func(task.args);
    }

    pthread_mutex_unlock(&(pool->mutex));
    pthread_exit(NULL);
    return NULL;
}
```



### pthread_pool_submit函数实现

向线程池中提交一个任务，然后尝试唤醒阻塞等待的工作线程，移动tail指针

```c

// 提交一个任务
int pthread_pool_submit(SPP *pool, void *(*func)(void *), void *args) {
    if (!pool || !func) return -1;
    pthread_mutex_lock(&(pool->mutex));

    int flag = -1;
    do {
        // 判断下一个tail位置
        int pos = pool->task_tail + 1;
        pos = ((pos == pool->task_queue_size) ? 0 : pos);

        if (pool->task_queue_size == pool->task_count) break;
        if (pool->pool_state != RUNNING) break;

        pool->task_queue[pool->task_tail].func = func;
        pool->task_queue[pool->task_tail].args = args;

        pool->task_tail = pos;
        pool->task_count++;
        pthread_cond_signal(&(pool->cond));
        flag = 0;
    } while (0);
    pthread_mutex_unlock(&(pool->mutex));
    return flag;
}
```



### 剩余函数实现

关闭和回收线程池资源，C语言的动态内存操作需要小心一点

```c
// 关闭线程池
void pthread_pool_shutdown(SPP *pool) {
    pthread_mutex_lock(&(pool->mutex));

    while (pool->pool_state == RUNNING) {
        pool->pool_state = TERMINATED;
    }

    // 唤醒所有可能等待的核心线程
    pthread_cond_signal(&(pool->cond));

    // 尝试取消所有正在运行的线程
    for (int i = 0; i < pool->thread_count; i++) {
        printf("尝试取消线程%d...\n", i);
        pthread_cancel(pool->threads[i]);
    }

    pthread_mutex_unlock(&(pool->mutex));
    pthread_pool_release(pool);
}

// 释放线程池资源
void pthread_pool_release(SPP *pool) {
    if (pool->threads) free(pool->threads);
    if (pool->task_queue) free(pool->task_queue);
    pthread_mutex_destroy(&(pool->mutex));
    pthread_cond_destroy(&(pool->cond));
    free(pool);
}
```

关闭线程池的方法这里是非阻塞的，调用了之后不一定会结束所有正在工作的线程。

关闭线程池的时候尝试取消正在运行的线程，如果运行线程内部是个死循环并且没有监听取消事件，会造成程序无法结束。



## 验证线程池功能

简单写一个程序验证线程池的功能

首先给出上面线程池必须依赖的头文件内容：

```c
#ifndef _COMMONS_H_
#define _COMMONS_H_

#include <arpa/inet.h>
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <memory.h>
#include <netinet/in.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/msg.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>

#endif
```

然后简单写一个main.c来测试线程池的功能：

```c
#include "pool.h"
#include "time.h"

void *task(void *args) {
    time_t t = time(NULL);
    printf("[Thread-%d]: %s", pthread_self(), ctime(&t));
    sleep(1);
    return NULL;
}

int main(int argc, char const *argv[]) {
    // 新建一个线程池
    SPP *pool = pthread_pool_create(3, 50);

    int cnt = 0;
    for (int i = 1; i <= 100; i++) {
        int ret = pthread_pool_submit(pool, task, NULL);
        if (ret != 0) {
            printf("%d 号任务提交失败...\n", i);
        } else {
            printf("%d 号任务提交成功!!!\n", i);
            cnt++;
        }
    }
    printf("成功提交任务数量：%d\n", cnt);

    // 主线程阻塞不退出
    pthread_exit(NULL);

    // 尝试关闭线程池
    pthread_pool_shutdown(pool);
    return 0;
}
```

这里创建了一个核心数量为3，等待队列大小为50的线程池，所以可以得到同一时刻可以提交的最大任务数量是53个任务，其余的任务会提交失败。

因为核心数量是3，所以同一时刻运行会有3个不同线程执行任务，并且打出当前时间，这里直接给出一部分的输出吧：

```shell
$ cc -g pool.c main.c -lpthread
$ ./a.out
```

输出如下：

```shell
1 号任务提交成功!!!
2 号任务提交成功!!!
3 号任务提交成功!!!
4 号任务提交成功!!!
5 号任务提交成功!!!
6 号任务提交成功!!!
7 号任务提交成功!!!
8 号任务提交成功!!!
9 号任务提交成功!!!
10 号任务提交成功!!!
11 号任务提交成功!!!
12 号任务提交成功!!!
13 号任务提交成功!!!
14 号任务提交成功!!!
15 号任务提交成功!!!
16 号任务提交成功!!!
17 号任务提交成功!!!
18 号任务提交成功!!!
19 号任务提交成功!!!
20 号任务提交成功!!!
21 号任务提交成功!!!
22 号任务提交成功!!!
23 号任务提交成功!!!
24 号任务提交成功!!!
25 号任务提交成功!!!
26 号任务提交成功!!!
27 号任务提交成功!!!
28 号任务提交成功!!!
29 号任务提交成功!!!
30 号任务提交成功!!!
31 号任务提交成功!!!
32 号任务提交成功!!!
33 号任务提交成功!!!
34 号任务提交成功!!!
35 号任务提交成功!!!
36 号任务提交成功!!!
37 号任务提交成功!!!
38 号任务提交成功!!!
39 号任务提交成功!!!
40 号任务提交成功!!!
41 号任务提交成功!!!
42 号任务提交成功!!!
43 号任务提交成功!!!
44 号任务提交成功!!!
45 号任务提交成功!!!
46 号任务提交成功!!!
47 号任务提交成功!!!
48 号任务提交成功!!!
49 号任务提交成功!!!
50 号任务提交成功!!!
51 号任务提交成功!!!
52 号任务提交成功!!!
53 号任务提交成功!!!
54 号任务提交失败...
55 号任务提交失败...
56 号任务提交失败...
57 号任务提交失败...
58 号任务提交失败...
59 号任务提交失败...
60 号任务提交失败...
61 号任务提交失败...
62 号任务提交失败...
63 号任务提交失败...
64 号任务提交失败...
65 号任务提交失败...
66 号任务提交失败...
67 号任务提交失败...
68 号任务提交失败...
69 号任务提交失败...
70 号任务提交失败...
71 号任务提交失败...
72 号任务提交失败...
73 号任务提交失败...
74 号任务提交失败...
75 号任务提交失败...
76 号任务提交失败...
77 号任务提交失败...
78 号任务提交失败...
79 号任务提交失败...
80 号任务提交失败...
81 号任务提交失败...
82 号任务提交失败...
83 号任务提交失败...
84 号任务提交失败...
85 号任务提交失败...
86 号任务提交失败...
87 号任务提交失败...
88 号任务提交失败...
89 号任务提交失败...
90 号任务提交失败...
91 号任务提交失败...
92 号任务提交失败...
93 号任务提交失败...
94 号任务提交失败...
95 号任务提交失败...
96 号任务提交失败...
97 号任务提交失败...
98 号任务提交失败...
99 号任务提交失败...
100 号任务提交失败...
成功提交任务数量：53
[Thread-27713536]: Thu Sep  9 18:40:49 2021
[Thread-28250112]: Thu Sep  9 18:40:49 2021
[Thread-28786688]: Thu Sep  9 18:40:49 2021
[Thread-28786688]: Thu Sep  9 18:40:50 2021
[Thread-28250112]: Thu Sep  9 18:40:50 2021
[Thread-27713536]: Thu Sep  9 18:40:50 2021
[Thread-28786688]: Thu Sep  9 18:40:51 2021
[Thread-28250112]: Thu Sep  9 18:40:51 2021
[Thread-27713536]: Thu Sep  9 18:40:51 2021
[Thread-28786688]: Thu Sep  9 18:40:52 2021
[Thread-28250112]: Thu Sep  9 18:40:52 2021
[Thread-27713536]: Thu Sep  9 18:40:52 2021
[Thread-28786688]: Thu Sep  9 18:40:53 2021
[Thread-28250112]: Thu Sep  9 18:40:53 2021
[Thread-27713536]: Thu Sep  9 18:40:53 2021
[Thread-28250112]: Thu Sep  9 18:40:54 2021
[Thread-27713536]: Thu Sep  9 18:40:54 2021
[Thread-28786688]: Thu Sep  9 18:40:54 2021
[Thread-28250112]: Thu Sep  9 18:40:55 2021
[Thread-27713536]: Thu Sep  9 18:40:55 2021
[Thread-28786688]: Thu Sep  9 18:40:55 2021
[Thread-28250112]: Thu Sep  9 18:40:56 2021
[Thread-27713536]: Thu Sep  9 18:40:56 2021
[Thread-28786688]: Thu Sep  9 18:40:56 2021
[Thread-28786688]: Thu Sep  9 18:40:57 2021
[Thread-28250112]: Thu Sep  9 18:40:57 2021
[Thread-27713536]: Thu Sep  9 18:40:57 2021
[Thread-28786688]: Thu Sep  9 18:40:58 2021
[Thread-28250112]: Thu Sep  9 18:40:58 2021
[Thread-27713536]: Thu Sep  9 18:40:58 2021
[Thread-28786688]: Thu Sep  9 18:41:00 2021
[Thread-28250112]: Thu Sep  9 18:41:00 2021
[Thread-27713536]: Thu Sep  9 18:41:00 2021
[Thread-28786688]: Thu Sep  9 18:41:01 2021
[Thread-28250112]: Thu Sep  9 18:41:01 2021
[Thread-27713536]: Thu Sep  9 18:41:01 2021
[Thread-27713536]: Thu Sep  9 18:41:02 2021
[Thread-28250112]: Thu Sep  9 18:41:02 2021
[Thread-28786688]: Thu Sep  9 18:41:02 2021
[Thread-27713536]: Thu Sep  9 18:41:03 2021
[Thread-28786688]: Thu Sep  9 18:41:03 2021
[Thread-28250112]: Thu Sep  9 18:41:03 2021
[Thread-28250112]: Thu Sep  9 18:41:04 2021
[Thread-27713536]: Thu Sep  9 18:41:04 2021
[Thread-28786688]: Thu Sep  9 18:41:04 2021
[Thread-28250112]: Thu Sep  9 18:41:05 2021
[Thread-28786688]: Thu Sep  9 18:41:05 2021
[Thread-27713536]: Thu Sep  9 18:41:05 2021
[Thread-28250112]: Thu Sep  9 18:41:06 2021
[Thread-27713536]: Thu Sep  9 18:41:06 2021
[Thread-28786688]: Thu Sep  9 18:41:06 2021
[Thread-28786688]: Thu Sep  9 18:41:07 2021
[Thread-28250112]: Thu Sep  9 18:41:07 2021

$ ^C
```



## 其他内容

vscode配置的调试debug只能调试单文件，这次调试就是用的gdb来调试的

编译的时候加入-g参数生成debug信息，然后gdb a.out就可以调试程序了

对于多线程的调试，gdb也是很方便的，具体参考：https://www.cnblogs.com/xuxm2007/archive/2011/04/01/2002162.html

<img src="https://gitee.com/dzzhyk/MarkdownPics/raw/master/image-20210909184526181.png" alt="使用gdb调试" style="zoom:50%;" />

<img src="https://gitee.com/dzzhyk/MarkdownPics/raw/master/image-20210909184608119.png" alt="gdb显示所有线程" style="zoom:50%;" />

---
title: 双向链表与LRU、LFU的实现
date: 2021-09-13 22:11:06
categories:
- 面试
tags:
- 数据结构
- 双向链表
- LRU缓存策略
- LFU缓存策略
---

可以说LRU、LFU两种缓存淘汰策略是最近面试中常见的问题了，这次笔者就准备采用双向链表来实现一个LRU和LFU。

## 缓存淘汰策略

缓存淘汰策略：一个缓存系统如果缓存大小达到了上限，如果有新的缓存内容存入时，需要淘汰掉一部分旧的缓存内容，这样才有空间存放缓存数据，同时要保证缓存替换的频率尽量低。

-   FIFO淘汰策略：队列式缓存，前出后进
-   LRU淘汰策略：空间不足会淘汰掉最近最少使用的缓存
-   LFU淘汰策略：根据缓存请求次数排序，空间不足会淘汰掉请求次数最少的缓存



## 实现LRU

实现LRU是经典的题目，这里采用哈希表+双向链表来实现LRU，具体的设计图如下：

![LRU缓存（哈希表+双向链表）](https://gitee.com/dzzhyk/MarkdownPics/raw/master/image-20210913223510931.png)

1.   map中存放(key, 节点指针)，指针指向具体的双线链表节点
2.   维护一个双向链表，其头部是最近最多使用的缓存，尾部是最近最少使用缓存，如果缓存空间不足，淘汰掉尾部
3.   每次访问、存入新的缓存，将其放置在双向链表头部，表示刚刚使用

### 定义结构体

哈希表借助STL中的map，定义一个LRU结构体和双向链表节点Node

```c++
/**
 * LRU缓存，"最近最少使用"缓存淘汰策略
 */

struct Node {
    int k;
    int v;
    Node *prev;
    Node *next;
};

struct LRU {
    int cap;	// 总容量
    int len;	// 当前容量
    Node *head;
    Node *tail;
    map<int, Node *> cache;
};

LRU *lru_create(int);
void lru_put(LRU *, int, int);
int lru_get(LRU *, int);
void lru_destroy(LRU *);
void lru_print(LRU *);

Node *lru_remove_node(LRU *, Node *);
void lru_push_first(LRU *, Node *);
void lru_pop_last(LRU *);
```

**对于LRU，笔者这里核心实现了下面三个方法：**

1.   **lru_remove_node：移除任意一个节点**
2.   **lru_push_first：向双向链表首部添加节点**
3.   **lru_pop_last：移除双向链表最后一个节点**



### 具体实现

```c++
LRU *lru_create(int size) {
    LRU *tmp = (LRU *)malloc(sizeof(LRU));
    tmp->cache = map<int, Node *>();
    tmp->cap = size;
    tmp->len = 0;
    tmp->head = (Node *)malloc(sizeof(Node));
    tmp->tail = (Node *)malloc(sizeof(Node));
    tmp->head->next = tmp->tail;
    tmp->tail->prev = tmp->head;
    return tmp;
}

void lru_destroy(LRU *lru) {
    if (!lru) return;
    Node *tmp = lru->head;
    while (tmp) {
        Node *t = tmp;
        tmp = tmp->next;
        free(t);
    }
}

void lru_put(LRU *lru, int key, int val) {
    if (!lru) return;
    if (lru->len >= lru->cap) lru_pop_last(lru);
    if (lru->cache.find(key) != lru->cache.end()) {
        Node *tmp = lru->cache[key];
        tmp = lru_remove_node(lru, tmp);
        tmp->v = val;
        lru_push_first(lru, tmp);
    } else {
        Node *tmp = (Node *)malloc(sizeof(Node));
        tmp->k = key;
        tmp->v = val;
        lru_push_first(lru, tmp);
    }
}

int lru_get(LRU *lru, int key) {
    if (!lru) return -1;
    if (lru->cache.find(key) != lru->cache.end()) {
        Node *tmp = lru_remove_node(lru, lru->cache[key]);
        lru_push_first(lru, tmp);
        return tmp->v;
    }
    return -1;
}

// 从双向链表中移除一个节点
Node *lru_remove_node(LRU *lru, Node *node) {
    Node *tmp = node->next;
    node->prev->next = tmp;
    tmp->prev = node->prev;
    node->next = NULL;
    node->prev = NULL;
    lru->len--;
    lru->cache.erase(node->k);
    return node;
}

// 将节点插入到双向链表头部
void lru_push_first(LRU *lru, Node *node) {
    if (!lru || !node) return;
    if (lru->len >= lru->cap) lru_pop_last(lru);
    Node *tmp = lru->head->next;
    node->next = tmp;
    tmp->prev = node;
    lru->head->next = node;
    node->prev = lru->head;
    lru->len++;
    lru->cache[node->k] = node;
}

// 移除双向链表的尾部节点
void lru_pop_last(LRU *lru) {
    if (lru->len <= 0) return;
    Node *tmp = lru->tail->prev;
    Node *t = tmp->prev;
    t->next = lru->tail;
    lru->tail->prev = t;
    lru->cache.erase(tmp->k);
    lru->len--;
    free(tmp);
}

// 即时打印缓存内容
void lru_print(LRU *lru) {
    cout << "----------\n";
    Node *tmp = lru->head->next;
    while (tmp != lru->tail) {
        cout << "(" << tmp->k << ", " << tmp->v << ") ";
        tmp = tmp->next;
    }
    cout << "\n";
}
```



### 验证LRU效果

补充main函数：

```c++
int main() {
    LRU *lru = lru_create(3);

    lru_put(lru, 1, 1);
    lru_print(lru);

    lru_put(lru, 2, 2);
    lru_print(lru);

    cout << lru_get(lru, 3) << endl;
    lru_print(lru);

    lru_put(lru, 3, 3);
    lru_print(lru);

    cout << lru_get(lru, 2) << endl;
    lru_print(lru);

    cout << lru_get(lru, 2) << endl;
    lru_print(lru);

    lru_put(lru, 4, 4);
    lru_print(lru);

    cout << lru_get(lru, 1) << endl;
    lru_print(lru);

    lru_destroy(lru);

    return 0;
}
```

验证一下效果，从左到右是双向链表首至尾的内容：

<img src="https://gitee.com/dzzhyk/MarkdownPics/raw/master/image-20210913224007315.png" alt="LRU执行结果" style="zoom: 67%;" />



## 实现LFU

对于LFU，虽然比较好理解，但是实现起来笔者还是需要仔细思考一会的，如果是面试场景下问到LRU之后，很容易连坐扯出LFU，所以这里也思考了一下LFU的实现方式，并且给出的具体实现。

![LFU缓存（哈希表+双向链表）](https://gitee.com/dzzhyk/MarkdownPics/raw/master/image-20210913224436981.png)

这里笔者继续采用一种基于双向链表的实现方式，不同的是每个双向链表节点Node里面需要多出cnt属性来记录访问该Node节点的次数。除此之外，双向链表的头部是急需淘汰的元素，反而尾部是使用次数cnt最多，不需要淘汰的元素

对于哈希表，这里依然采用STL中的map来实现。



### 定义结构体

和LRU的结构体几乎相同，除了节点多出了cnt属性

```c++
/**
 * LFU缓存，"最不经常使用"缓存淘汰策略
 */

struct Node {
    int k;
    int v;
    int cnt;	// 访问次数
    Node *prev;
    Node *next;
};

struct LFU {
    int cap;
    int len;
    Node *head;
    Node *tail;
    map<int, Node *> cache;
};

LFU *lfu_create(int);
void lfu_put(LFU *, int, int);
int lfu_get(LFU *, int);
void lfu_destroy(LFU *);
void lfu_print(LFU *);

Node *lfu_insert_node(LFU *, Node *);
Node *lfu_remove_node(LFU *, Node *);
```

**对于LFU，笔者这里核心实现了下面两个方法：**

1.   **lru_remove_node：移除任意一个节点**
2.   **lfu_insert_node：将一个节点插入到双向链表中的合适位置（大于node节点cnt数的第一个节点的左边）**

<img src="https://gitee.com/dzzhyk/MarkdownPics/raw/master/image-20210913225834248.png" alt="LFU双向链表-插入一个节点" style="zoom:50%;" />



### 具体实现

```c++
LFU *lfu_create(int size) {
    LFU *tmp = (LFU *)malloc(sizeof(LFU));
    tmp->head = (Node *)malloc(sizeof(Node));
    tmp->tail = (Node *)malloc(sizeof(Node));
    tmp->head->cnt = 0;
    tmp->tail->cnt = 0;
    tmp->cap = size;
    tmp->len = 0;
    tmp->head->next = tmp->tail;
    tmp->tail->prev = tmp->head;
    tmp->cache = map<int, Node *>();
    return tmp;
}

void lfu_destroy(LFU *lfu) {
    lfu->cache.clear();
    Node *tmp = lfu->head;
    while (tmp) {
        Node *t = tmp;
        tmp = tmp->next;
        free(t);
    }
}

// 将一个节点插入到双向链表中的合适位置(大于node节点cnt数的第一个节点的左边)
Node *lfu_insert_node(LFU *lfu, Node *node) {
    if (lfu->cap <= lfu->len) {
        Node *t = lfu_remove_node(lfu, lfu->head->next);
        free(t);
    }
    Node *tmp = lfu->head;
    while (tmp != lfu->tail && tmp->cnt <= node->cnt) tmp = tmp->next;

    tmp->prev->next = node;
    node->prev = tmp->prev;
    node->next = tmp;
    tmp->prev = node;

    lfu->cache[node->k] = node;
    lfu->len++;
    return node;
}

// 将一个节点从原有双向链表上移除，返回这个移除的节点
Node *lfu_remove_node(LFU *lfu, Node *node) {
    if (lfu->len <= 0 || !node) return NULL;
    node->prev->next = node->next;
    node->next->prev = node->prev;
    node->prev = NULL;
    node->next = NULL;
    lfu->len--;
    lfu->cache.erase(node->k);
    return node;
}

void lfu_put(LFU *lfu, int key, int val) {
    if (!lfu) return;
    map<int, Node *> mp = lfu->cache;
    if (mp.find(key) != mp.end()) {
        Node *tmp = mp[key];
        tmp = lfu_remove_node(lfu, tmp);
        tmp->cnt++;
        tmp->v = val;
        lfu_insert_node(lfu, tmp);
    } else {
        Node *tmp = (Node *)malloc(sizeof(Node));
        tmp->cnt = 1;
        tmp->k = key;
        tmp->v = val;
        lfu_insert_node(lfu, tmp);
    }
}

int lfu_get(LFU *lfu, int key) {
    if (!lfu) return -1;
    if (lfu->cache.find(key) != lfu->cache.end()) {
        Node *tmp = lfu->cache[key];
        tmp = lfu_remove_node(lfu, tmp);
        tmp->cnt++;
        tmp = lfu_insert_node(lfu, tmp);
        return tmp->v;
    }
    return -1;
}

void lfu_print(LFU *lfu) {
    cout << "----------\n";
    Node *tmp = lfu->head->next;
    while (tmp != lfu->tail) {
        cout << "(" << tmp->k << ", " << tmp->v << ") -> cnt: " << tmp->cnt << "\n";
        tmp = tmp->next;
    }
}
```





### 验证LFU效果

定义一个main函数同时调用LFU即可：

```c++
int main() {
    LFU *lfu = lfu_create(3);

    lfu_put(lfu, 1, 1);
    lfu_print(lfu);

    lfu_put(lfu, 2, 2);
    lfu_print(lfu);

    cout << lfu_get(lfu, 3) << endl;
    lfu_print(lfu);

    lfu_put(lfu, 3, 3);
    lfu_print(lfu);

    cout << lfu_get(lfu, 2) << endl;
    lfu_print(lfu);

    cout << lfu_get(lfu, 2) << endl;
    lfu_print(lfu);

    lfu_put(lfu, 4, 4);
    lfu_print(lfu);

    cout << lfu_get(lfu, 1) << endl;
    lfu_print(lfu);

    lfu_destroy(lfu);

    return 0;
}
```

可以看到双向链表内部是根据cnt从小到大排列缓存k-v的：

<img src="https://gitee.com/dzzhyk/MarkdownPics/raw/master/image-20210913225229277.png" alt="LFU效果" style="zoom: 67%;" />



## LFU的其他实现方式

上面实现LFU使用的是map+双向链表的方法，每次淘汰双向链表头部的元素。

除此之外，还可以使用优先队列priority_queue来代替双向链表，因为优先队列内部维护了一个二叉队，如果按照cnt元素从小到大维护一个优先队列，每次pop队首元素也是可以的。

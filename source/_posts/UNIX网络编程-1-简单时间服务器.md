---
title: unix网络编程-1-简单时间服务器
date: 2021-09-06 17:48:09
categories:
    - 网络编程
tags:
    - Linux
    - 网络编程
    - socket
---

根据书上内容，编写一个简单的获取时间的客户端、服务器如下：

## time client

```c
#include "commons.h"

/**
 * time check client
 */
int main(int argc, char const *argv[]) {
    // fd socket描述符
    int fd;
    // 目标服务器socket包装体
    struct sockaddr_in svraddr;

    if (argc < 2) {
        perror("usage: client <ip>\n");
    }

    fd = common_socket(AF_INET, SOCK_STREAM, 0);

    // 初始化目标服务器信息
    memset(&svraddr, 0, sizeof(svraddr));
    svraddr.sin_family = AF_INET;
    svraddr.sin_port = htons(13); // 时间服务器，端口13

    // 将ip地址串转换为in_addr(整数)，然后赋值给svraddr
    if (inet_pton(AF_INET, argv[1], &svraddr.sin_addr) <= 0) {
        perror("inet_pton error\n");
    }

    // 尝试连接服务器
    common_connect(fd, (SA *)&svraddr, sizeof(svraddr));

    // 读取服务器发送的信息，写入buf中并且打印
    int len;
    char recvbuf[MAXLINE + 1];
    while ((len = common_read(fd, recvbuf, MAXLINE)) > 0) {
        recvbuf[len] = '\0';
        printf("%s", recvbuf);
    }

    return EXIT_SUCCESS;
}
```

## time server

```c
#include "commons.h"

#define LISTEN_NUMBER 1024

int main(int argc, char const *argv[]) {
    // 监听socket描述符，连接socket描述符
    int listenfd, connfd;
    struct sockaddr_in svraddr;
    char wrtbuf[MAXLINE];
    time_t ticks;

    listenfd = common_socket(AF_INET, SOCK_STREAM, 0);

    // 初始化服务器信息
    memset(&svraddr, 0, sizeof(svraddr));
    svraddr.sin_family = AF_INET;
    svraddr.sin_port = htons(13);
    svraddr.sin_addr.s_addr = htonl(INADDR_ANY);

    // 绑定监听socket和服务器socket信息
    common_bind(listenfd, (SA *)&svraddr, sizeof(svraddr));

    // 最多同时监听1024个连接
    common_listen(listenfd, LISTEN_NUMBER);

    // 接收客户端连接socket
    while (1) {
        connfd = accept(listenfd, NULL, NULL);
        ticks = time(NULL);
        snprintf(wrtbuf, sizeof(wrtbuf), "%.24s\r\n", ctime(&ticks));
        common_write(connfd, wrtbuf, strlen(wrtbuf));
        common_close(connfd);
    }

    exit(EXIT_SUCCESS);
}
```

## commons.h 公共头文件

```c
/**
 * 公共头文件
 */
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>

#define MAXLINE 1024

typedef struct sockaddr SA;

// 新建socket
int common_socket(int family, int sock_type, int protocol) {
    int fd;
    if ((fd = (socket(family, sock_type, protocol))) < 0) {
        perror("common_socket error\n");
        exit(EXIT_FAILURE);
    }
    return fd;
}

// 连接socket
void common_connect(int sockfd, const SA *svraddr, socklen_t socklen) {
    if (connect(sockfd, svraddr, socklen) < 0) {
        perror("common_connect error\n");
        exit(EXIT_FAILURE);
    }
}

// 绑定socket
void common_bind(int listenfd, const SA *svraddr, socklen_t socklen) {
    if (bind(listenfd, svraddr, socklen) < 0) {
        perror("common_bind error\n");
        exit(EXIT_FAILURE);
    }
}

// 监听socket
void common_listen(int listenfd, int conn_number) {
    if (listen(listenfd, conn_number) < 0) {
        perror("common_listen error\n");
        exit(EXIT_FAILURE);
    }
}

// 读取socket
int common_read(int sockfd, void *recvbuf, size_t recvlen) {
    int len;
    if ((len = read(sockfd, recvbuf, recvlen)) < 0) {
        perror("common_read error\n");
        exit(EXIT_FAILURE);
    }
    return len;
}

// 写入socket
void common_write(int connfd, const void *buf, size_t nbytes) {
    if (write(connfd, buf, nbytes) < 0) {
        perror("common_write error\n");
        exit(EXIT_FAILURE);
    }
}

// 关闭socket
void common_close(int connfd) {
    if (close(connfd) < 0) {
        perror("common_close error\n");
        exit(EXIT_FAILURE);
    }
}
```

## 运行效果

<img src="https://gitee.com/dzzhyk/MarkdownPics/raw/master/image-20210906175210048.png" alt="运行截图" style="zoom:50%;" />

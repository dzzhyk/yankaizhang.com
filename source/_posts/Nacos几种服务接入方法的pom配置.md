---
title: Nacos几种服务接入方法的pom配置
date: 2021-10-29 00:02:56
categories:
    - Spring Cloud
tags:
    - Spring Cloud
    - Nacos
    - Dubbo
---

最近在进一步学习Spring Cloud Alibaba微服务技术栈，使用Nacos的时候配置依赖总是配置不好，这里笔者总结保存一下，使用的是目前最新的版本，避免以后再次踩坑。



## 前言

Nacos注册中心支持多种服务协议的注册，这里使用了rest服务和dubbo服务两种

对于服务的远程调用，有三种方式：

1.   使用原始的restTemplate远程调用服务
2.   使用openfeign远程调用服务
3.   使用dubbo框架提供的远程调用

具体的使用方式很容易，下面记录一下pom.xml文件配置





## 项目根pom.xml

项目总的pom.xml，配置了SpringBoot、SpringCloud、SpringCloudAlibaba三个依赖

根据官网的版本要求来修改即可

| Spring Cloud Version    | Spring Cloud Alibaba Version | Spring Boot Version |
| ----------------------- | ---------------------------- | ------------------- |
| Spring Cloud Hoxton.SR9 | 2.2.6.RELEASE                | 2.3.2.RELEASE       |

```xml
<properties>
    <java.version>1.8</java.version>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
    
    <!-- 版本需要对应正确 -->
    <spring-boot.version>2.3.2.RELEASE</spring-boot.version>
    <spring-cloud.version>Hoxton.SR9</spring-cloud.version>
    <spring-cloud-alibaba.version>2.2.6.RELEASE</spring-cloud-alibaba.version>
</properties>

<dependencyManagement>
    <dependencies>
        <!-- Spring Boot 全局依赖 -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-dependencies</artifactId>
            <version>${spring-boot.version}</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
        <!-- Spring Cloud Alibaba 全局依赖 -->
        <dependency>
            <groupId>com.alibaba.cloud</groupId>
            <artifactId>spring-cloud-alibaba-dependencies</artifactId>
            <version>${spring-cloud-alibaba.version}</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
        <!-- Spring Cloud 全局依赖 -->
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-dependencies</artifactId>
            <version>${spring-cloud.version}</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

后面所有的子项目全部继承与该父项目即可



## 创建和消费rest服务

```xml
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
        <groupId>com.alibaba.cloud</groupId>
        <artifactId>spring-cloud-starter-alibaba-nacos-discovery</artifactId>
    </dependency>
</dependencies>
```



## 使用openfeign消费rest服务

```xml
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
        <groupId>com.alibaba.cloud</groupId>
        <artifactId>spring-cloud-starter-alibaba-nacos-discovery</artifactId>
    </dependency>
    <!-- openfeign 远程调用 -->
    <dependency>
        <groupId>org.springframework.cloud</groupId>
        <artifactId>spring-cloud-starter-openfeign</artifactId>
    </dependency>
</dependencies>
```



## dubbo服务注册和消费

dubbo的依赖配置有点复杂，这里暂且总结一下：

1.   dubbo服务一般会单独定义一个api模块供提供方和消费方使用，这种设计个人认为很不错
2.   dubbo服务提供方和消费方需要的依赖相同，额外需要api依赖

dubbo作为一个RPC框架比较灵活，可以和多种不同的注册中心组合（比如zk）

这里记录使用的是dubbo+nacos注册中心的组合

```xml
<dependencies>
    <!-- 引入自定义的api，准备实现 -->
    <dependency>
        <groupId>com.yankaizhang</groupId>
        <artifactId>dubbo-api</artifactId>
        <version>0.0.1-SNAPSHOT</version>
    </dependency>

    <!-- nacos注册服务 -->
    <dependency>
        <groupId>com.alibaba.cloud</groupId>
        <artifactId>spring-cloud-starter-alibaba-nacos-discovery</artifactId>
    </dependency>

    <!-- 引入dubbo需要以下内容 -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-actuator</artifactId>
    </dependency>
    <dependency>
        <groupId>com.alibaba.cloud</groupId>
        <artifactId>spring-cloud-starter-dubbo</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.cloud</groupId>
        <artifactId>spring-cloud-starter-netflix-ribbon</artifactId>
    </dependency>
    <dependency>
        <groupId>org.apache.commons</groupId>
        <artifactId>commons-lang3</artifactId>
    </dependency>

</dependencies>
```



## 附录

![image-20211005235803405](https://gitee.com/dzzhyk/MarkdownPics/raw/master/image-20211005235803405.png)


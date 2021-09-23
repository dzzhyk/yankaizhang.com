---
title: Windows 10 修改Office2016安装路径
date: 2021-09-23 21:01:14
categories:
- 杂项
tags:
- Windows
- Office
---

一件头痛的事：给家里电脑重做系统，发现正版Office脱机安装文件不能指定安装位置，默认安装到C盘，笔者作为软件必须装到D盘的强迫症为此头痛了半个小时，使用创建软连接的方式解决这个问题。

安装之前打开cmd：

```shell
md D:\Program Files\Microsoft Office
md D:\Program Files (x86)\Microsoft Office
mklink /j "C:\Program Files\Microsoft Office" "D:\Program Files\Microsoft Office"
mklink /j "C:\Program Files (x86)\Microsoft Office" "D:\Program Files (x86)\Microsoft Office"
```

随后执行安装即可。

参考：

https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/mklink

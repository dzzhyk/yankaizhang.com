---
title: DNS协议相关问题整理
date: 2021-08-27 20:47:35
categories:
- 面试
tags:
- 面试
- 计算机网络
- DNS协议
---

# DNS协议

域名解析协议DNS (Domain Name System)将域名和 IP 地址相互映射，方便人使用便于记忆的域名而不是 IP 地址。

将域名映射成 IP 地址称为**正向解析**，将 IP 地址映射成域名称为**反向解析**



# DNS使用到的协议和端口

DNS同时占用UDP和TCP的53号端口；DNS在进行区域传输的时候使用TCP协议，其它时候则使用UDP协议； 

DNS的规范规定了2种类型的DNS服务器，一个叫主DNS服务器，一个叫辅助DNS服务器。在一个区域中主DNS服务器从自己本机的数据文件中读取该区的DNS数据信息，而辅助DNS服务器则从区的主DNS服务器中读取该区的DNS数据信息。当一个辅助DNS服务器启动时，它需要与主DNS服务器通信，并加载数据信息，这就叫做区域传送（zone transfer）。 



**区域传送**时使用TCP：

1.   辅域名服务器会定时（一般时3小时）向主域名服务器进行查询以便了解数据是否有变动。如有变动，则会执行一次区域传送，进行数据同步。区域传送将使用TCP而不是UDP，因为数据同步传送的数据量比一个请求和应答的数据量要多得多。 
2.   TCP是一种可靠的连接，保证了数据的准确性。 

**域名解析**时使用UDP： 

客户端向DNS服务器查询域名，一般返回的内容都不超过512字节，用UDP传输即可。不用经过TCP三次握手，这样DNS服务器负载更低，响应更快。虽然从理论上说，客户端也可以指定向DNS服务器查询的时候使用TCP，但事实上，很多DNS服务器进行配置的时候，仅支持UDP查询包。



# DNS服务器分类

1. 根域名服务器
2. 顶级域名服务器
3. 权限域名服务器
4. 本地域名服务器



# DNS记录类型

笔者从阿里云截图得到的：

<img src="https://gitee.com/dzzhyk/MarkdownPics/raw/master/image-20210827225505585.png" align="middle" alt="DNS记录类型" style="zoom:50%;" />



# DNS协议解析方式

1. **递归查询**：主机向本地域名服务器器的查询

如果主机所询问的本地域名服务器不知道被查询的域名的 IP 地址，那么本地域名服务器就以 DNS 客户的身份，向根域名服务器继续发出查询请求报⽂(代替主机继续查询)。
最终的查询结果有两种，要么找到了 IP 地址，要么返回错误。

2. **迭代查询**：本地域名服务器器向根域名服务器器的查询

当根域名服务器收到本地域名服务器发出的迭代查询请求报⽂时，要么给出所要查询的 IP 地址，要么告诉本地服务器下一步应当向哪一个DNS服务器进⾏查询，然后让本地服务器进行后续的查询。

根域名服务器器常是把⾃己知道的顶级域名服务器的 IP 地址告诉本地域名服务器，让本地域名服务器再向顶级域名服务器查询。顶级域名服务器在收到本地域名服务器的查询请求后，要么给出所要查询的 IP 地址，要么告诉本地服务器下⼀步应当向哪⼀个权限域名服务器进⾏查询。最后，本地域名服务器得到了所要解析的 IP 地址或报错，然后把这个结果返回给发起查询的主机。



# DNS解析过程

1）首先搜索**浏览器的 DNS 缓存**，缓存中维护一张域名与 IP 地址的对应表；

2）若没有命中，则继续搜索**操作系统的 DNS 缓存**；

3）若仍然没有命中，则操作系统将域名发送至**本地域名服务器**，本地域名服务器查询自己的 DNS 缓存，查找成功则返回结果（注意：主机和本地域名服务器之间的查询方式是**递归查询**）；

4）若本地域名服务器的 DNS 缓存没有命中，则本地域名服务器向上级域名服务器进行查询，通过以下方式进行**迭代查询**（注意：本地域名服务器和其他域名服务器之间的查询方式是迭代查询，防止根域名服务器压力过大）：

-   首先本地域名服务器向**根域名服务器**发起请求，根域名服务器是最高层次的，它并不会直接指明这个域名对应的 IP 地址，而是返回顶级域名服务器的地址，也就是说给本地域名服务器指明一条道路，让他去这里寻找答案
-   本地域名服务器拿到这个**顶级域名服务器**的地址后，就向其发起请求，获取**权限域名服务器**的地址
-   本地域名服务器根据权限域名服务器的地址向其发起请求，最终得到该域名对应的 IP 地址

4）本地域名服务器将得到的 IP 地址返回给操作系统，同时自己将 IP 地址缓存起来

5）操作系统将 IP 地址返回给浏览器，同时自己也将 IP 地址缓存起来

6）至此，浏览器就得到了域名对应的 IP 地址，并将 IP 地址缓存起来

![DNS解析过程](https://gitee.com/dzzhyk/MarkdownPics/raw/master/1460000039039286.png)



# DNS域名缓存

为了提高DNS查询效率，并减少因特网上的DNS查询保存数量，在DNS域名服务器中使用了高速缓存，用来存放最近查询过的域名以及从何处获得域名映射信息的记录。

计算机中 DNS 记录在本地有两种缓存方式：浏览器缓存和操作系统缓存。

1. **浏览器缓存**：浏览器在获取网站域名的实际 IP 地址后会对其进行缓存，减少网络请求的损耗。每种浏览器都有一个固定的 DNS 缓存时间，如 Chrome 的过期时间是 1 分钟，在这个期限内不会重新请求 DNS
2. **操作系统缓存**：操作系统的缓存其实是用户自己配置的 hosts 文件。



# DNS协议故障原因

- DNS服务器自身出现问题
- 域名受到DNS攻击
- DNS解析配置错误，如：域名解析目标IP设置错误
- 客户机或者服务器本地的hosts文件配置不当



# 常用的DNS协议工具

## nslookup

nslookup全称是"query Internet name server interactively"，主要用来查询DNS。

mac下自带了这个工具：

<img src="https://gitee.com/dzzhyk/MarkdownPics/raw/master/image-20210827223648429.png" alt="nslookup工具" style="zoom:50%;" />

### 直接查询域名ip

```shell
$ nslookup
> google.com
Server:		192.168.1.1
Address:	192.168.1.1#53

Non-authoritative answer:
Name:	google.com
Address: 46.82.174.69
```



### 连接指定DNS服务器查询域名ip

```shell
$ nslookup
# 连接到8.8.8.8域名服务器
> server 8.8.8.8
Default server: 8.8.8.8
Address: 8.8.8.8#53

> google.com
Server:		8.8.8.8
Address:	8.8.8.8#53

Name:	google.com
Address: 59.24.3.174
```



### 查看DNS配置信息

```shell
$ nslookup
> set all
Default server: 192.168.1.1
Address: 192.168.1.1#53
Default server: 192.168.0.1
Address: 192.168.0.1#53

Set options:
  novc			nodebug		nod2
  search		recurse
  timeout = 0		retry = 3	port = 53	ndots = 1
  querytype = A     class = IN
  srchlist =
```



man nslookup找到的可用的set字段：

**IN**
the Internet class

**CH**
the Chaos class

**HS**
the Hesiod class

**ANY**
wildcard

The class specifies the protocol group of the information.

(Default = IN; abbreviation = cl)

**[no]debug**
Turn on or off the display of the full response packet and any intermediate response packets when searching.

(Default = nodebug; abbreviation = [no]deb)

**[no]d2**
Turn debugging mode on or off. This displays more about what nslookup is doing.

(Default = nod2)

**domain=name**
Sets the search list to name.

**[no]search**
If the lookup request contains at least one period but doesn't end with a trailing period, append the domain names in the domain
search list to the request until an answer is received.

(Default = search)

**port=value**
Change the default TCP/UDP name server port to value.

(Default = 53; abbreviation = po)

**querytype=value**

**type=value**
Change the type of the information query.

(Default = A; abbreviations = q, ty)

**[no]recurse**
Tell the name server to query other servers if it does not have the information.

(Default = recurse; abbreviation = [no]rec)

**ndots=number**
Set the number of dots (label separators) in a domain that will disable searching. Absolute names always stop searching.

**retry=number**
Set the number of retries to number.

**timeout=number**
Change the initial timeout interval for waiting for a reply to number seconds.

**[no]vc**
Always use a virtual circuit when sending requests to the server.

(Default = novc)

**[no]fail**
Try the next nameserver if a nameserver responds with SERVFAIL or a referral (nofail) or terminate query (fail) on such a
response.

(Default = nofail)



## dig

dig工具是用于查询DNS记录的工具，功能比nslookup更加强大，mac下自带了这个工具：

<img src="https://gitee.com/dzzhyk/MarkdownPics/raw/master/image-20210827225040112.png" alt="dig工具" style="zoom:50%;" />



dig有意思的玩法：

1.   查看某个域名的DNS解析过程

     ```shell
     $ dig yankaizhang.com +trace
     
     ; <<>> DiG 9.10.6 <<>> yankaizhang.com +trace
     
     # 先找到本地域名服务器
     ;; global options: +cmd
     .			3153	IN	NS	m.root-servers.net.
     .			3153	IN	NS	h.root-servers.net.
     .			3153	IN	NS	a.root-servers.net.
     .			3153	IN	NS	b.root-servers.net.
     .			3153	IN	NS	k.root-servers.net.
     .			3153	IN	NS	l.root-servers.net.
     .			3153	IN	NS	i.root-servers.net.
     .			3153	IN	NS	f.root-servers.net.
     .			3153	IN	NS	j.root-servers.net.
     .			3153	IN	NS	e.root-servers.net.
     .			3153	IN	NS	c.root-servers.net.
     .			3153	IN	NS	g.root-servers.net.
     .			3153	IN	NS	d.root-servers.net.
     ;; Received 239 bytes from 192.168.1.1#53(192.168.1.1) in 36 ms
     
     # 本地域名服务器请求根域名服务器（递归查询）
     com.			172800	IN	NS	a.gtld-servers.net.
     com.			172800	IN	NS	b.gtld-servers.net.
     com.			172800	IN	NS	c.gtld-servers.net.
     com.			172800	IN	NS	d.gtld-servers.net.
     com.			172800	IN	NS	e.gtld-servers.net.
     com.			172800	IN	NS	f.gtld-servers.net.
     com.			172800	IN	NS	g.gtld-servers.net.
     com.			172800	IN	NS	h.gtld-servers.net.
     com.			172800	IN	NS	i.gtld-servers.net.
     com.			172800	IN	NS	j.gtld-servers.net.
     com.			172800	IN	NS	k.gtld-servers.net.
     com.			172800	IN	NS	l.gtld-servers.net.
     com.			172800	IN	NS	m.gtld-servers.net.
     com.			86400	IN	DS	30909 8 2 E2D3C916F6DEEAC73294E8268FB5885044A833FC5459588F4A9184CF C41A5766
     com.			86400	IN	RRSIG	DS 8 1 86400 20210909050000 20210827040000 26838 . ZLTCRLor3hezbp3CvYQbJCE+4XLPCvLOPlWx+cXru6A0snY2Dkv44JX8 hMpgiueL+Jp1rem/CqAZbLfacGe3cpJJpEkxK5Xob8BKRj4bQE+wH6Et gLy97rFKvCmpf80q29GEgxD5XwRFZoMSqnoNRGMUjPe8yTBoCiGPo+RF UBm0oQ0L2YmNeBEy0KSe+EI4ySUw3BLPSRAu2R/CkpISY2JFmnuG6jSE uM7T9Y5tgFYS7Kvba1NiMsBIiLy3KrijjwczSVCWl+9IKCqaQpCmVqES npK7x9Y0uzlTgNwo8IC1nKzKqvBz7S1UibvTQNxaKK/+Kd8R2lixbO8Y 4ErY0Q==
     ;; Received 1175 bytes from 193.0.14.129#53(k.root-servers.net) in 47 ms
     
     # 根域名服务器通知本地域名服务器去yankaizhang.com.顶级域名服务器（迭代查询）
     yankaizhang.com.	172800	IN	NS	dns2.hichina.com.
     yankaizhang.com.	172800	IN	NS	dns1.hichina.com.
     CK0POJMG874LJREF7EFN8430QVIT8BSM.com. 86400 IN NSEC3 1 1 0 - CK0Q1GIN43N1ARRC9OSM6QPQR81H5M9A  NS SOA RRSIG DNSKEY NSEC3PARAM
     CK0POJMG874LJREF7EFN8430QVIT8BSM.com. 86400 IN RRSIG NSEC3 8 2 86400 20210901042504 20210825031504 39343 com. UjMhvFuOAHV8bbjokUqcBsgJe3Bf2xtTLT2JLkt5wXb40qu6XWzZArOl jTO3BwtnAj7D/KQIqNsBRq0P/Djh8GGgSUhMFCbcel9G6CVESLYq6/E1 SKhGl72pxNtYDHEB5RYnBxsg55rh+gZWZMlhS5h+EjTkz692t8U8lB2C OmIyJpCUsldl7ciWmxMRHwennzbemMT5rhfDSe/SRT4WsQ==
     RTC0V9MOFGVV5RQ2BV3FMVPS9972PM35.com. 86400 IN NSEC3 1 1 0 - RTC22ASFHJHTLN9NCAREUK0D41R9BA1B  NS DS RRSIG
     RTC0V9MOFGVV5RQ2BV3FMVPS9972PM35.com. 86400 IN RRSIG NSEC3 8 2 86400 20210831051456 20210824040456 39343 com. lmTGKCex0R26RXHbTQbyUcWejz0KIeJtpYhHNs2lyGWV8rY3E9vf+moL Kwqk3Fkk5YU8DEiMLCzkyWxGeqmnlxZVtGqmxDLnkrt83frflR2piT9k uWnJXlocN6XNvrlsEk+eGyzFGRPRMMdnu2JlWx6RYVS1b0PqmJJTLOPL EHqUYaZshDNhE2Bo9JMPtZMDRQoI+/GlTc+4htFDFxT9Iw==
     ;; Received 951 bytes from 192.41.162.30#53(l.gtld-servers.net) in 281 ms
     
     # 查询结束，得到记录值（这里是CNAME）
     yankaizhang.com.	600	IN	CNAME	yankaizhang.com.cdn.dnsv1.com.
     ;; Received 87 bytes from 106.11.211.64#53(dns2.hichina.com) in 27 ms
     ```

     

2.   查找一个域名的授权DNS服务器

     ```shell
     $ dig  yankaizhang.com +nssearch
     SOA dns1.hichina.com. hostmaster.hichina.com. 2020071211 3600 1200 86400 360 from server 140.205.81.24 in 26 ms.
     SOA dns1.hichina.com. hostmaster.hichina.com. 2020071211 3600 1200 86400 360 from server 106.11.211.63 in 27 ms.
     SOA dns1.hichina.com. hostmaster.hichina.com. 2020071211 3600 1200 86400 360 from server 106.11.211.64 in 27 ms.
     SOA dns1.hichina.com. hostmaster.hichina.com. 2020071211 3600 1200 86400 360 from server 140.205.41.23 in 28 ms.
     SOA dns1.hichina.com. hostmaster.hichina.com. 2020071211 3600 1200 86400 360 from server 140.205.81.13 in 31 ms.
     SOA dns1.hichina.com. hostmaster.hichina.com. 2020071211 3600 1200 86400 360 from server 106.11.211.53 in 31 ms.
     SOA dns1.hichina.com. hostmaster.hichina.com. 2020071211 3600 1200 86400 360 from server 106.11.211.54 in 31 ms.
     SOA dns1.hichina.com. hostmaster.hichina.com. 2020071211 3600 1200 86400 360 from server 140.205.81.23 in 31 ms.
     SOA dns1.hichina.com. hostmaster.hichina.com. 2020071211 3600 1200 86400 360 from server 140.205.81.14 in 31 ms.
     SOA dns1.hichina.com. hostmaster.hichina.com. 2020071211 3600 1200 86400 360 from server 140.205.41.14 in 37 ms.
     SOA dns1.hichina.com. hostmaster.hichina.com. 2020071211 3600 1200 86400 360 from server 140.205.41.13 in 37 ms.
     SOA dns1.hichina.com. hostmaster.hichina.com. 2020071211 3600 1200 86400 360 from server 140.205.41.24 in 37 ms.
     SOA dns1.hichina.com. hostmaster.hichina.com. 2020071211 3600 1200 86400 360 from server 106.11.141.123 in 47 ms.
     SOA dns1.hichina.com. hostmaster.hichina.com. 2020071211 3600 1200 86400 360 from server 106.11.141.114 in 48 ms.
     SOA dns1.hichina.com. hostmaster.hichina.com. 2020071211 3600 1200 86400 360 from server 106.11.141.124 in 49 ms.
     SOA dns1.hichina.com. hostmaster.hichina.com. 2020071211 3600 1200 86400 360 from server 106.11.141.113 in 62 ms
     ```

3.   查看域名的正向解析和反向解析

     ```shell
     $ dig yankaizhang.com
     $ dig -x yankaizhang.com
     ```



## host

host工具也是mac自带的一个DNS查询工具，其功能和输入输出和dig差不多，参数操作方式有所不同

<img src="https://gitee.com/dzzhyk/MarkdownPics/raw/master/image-20210827231223945.png" alt="host工具" style="zoom:50%;" />

个人使用：

```shell
$ host -a yankaizhang.com

Trying "yankaizhang.com"
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 64983
;; flags: qr rd ra; QUERY: 1, ANSWER: 3, AUTHORITY: 0, ADDITIONAL: 0

;; QUESTION SECTION:
;yankaizhang.com.		IN	ANY

;; ANSWER SECTION:
yankaizhang.com.	600	IN	CNAME	yankaizhang.com.cdn.dnsv1.com.
yankaizhang.com.	3600	IN	NS	dns1.hichina.com.
yankaizhang.com.	3600	IN	NS	dns2.hichina.com.

Received 119 bytes from 192.168.1.1#53 in 207 ms
```




# 文章参考
[https://segmentfault.com/a/1190000039039275](https://segmentfault.com/a/1190000039039275)

[https://www.cnblogs.com/549294286/p/5172435.html](https://www.cnblogs.com/549294286/p/5172435.html)

[https://cloud.tencent.com/developer/article/1083201](https://cloud.tencent.com/developer/article/1083201)

[https://www.cnblogs.com/machangwei-8/p/10353216.html](https://www.cnblogs.com/machangwei-8/p/10353216.html)

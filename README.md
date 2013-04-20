PomeloClient iOS WebSocket
==========================

_自己写写, 练习一下_

之前一直写 PHP, 偶尔接触 JavaScript 写前端.

好吧, 这是我第一次写 Objective-C 的代码, 所以质量欠佳. 但勇气可嘉呀.

代码方面, 基于 JavaScript 版本的 [pomelo-jsclient-websocket](https://github.com/pomelonode/pomelo-jsclient-websocket) 和 [pomelo-protobuf](https://github.com/pomelonode/pomelo-protobuf) 一行一行的抄写. 结构, 逻辑全都 COPY 过来.

API 写法完全使用了 0.2 版本的 [pomelo-iosclient](https://github.com/netease/pomelo-iosclient). 目的是为了无痛升级. 使用已经写好了的兼容文件, import 一下便可以无需修改你程序的代码直接用了.

这是我用老版 [ioschat](https://github.com/NetEase/pomelo-ioschat) 改的 [https://github.com/ETiV/pomelo-ioschat-websocket](https://github.com/ETiV/pomelo-ioschat-websocket) 程序基本代码没改过.

现在唯一的缺憾是缺少测试, 因为我对 protobuf 也是第一次接触. 通过 iosChat 测试, 只能测一个 onChat 事件…不过发中英文的消息都没有问题.

感谢Hatsune Miku, 各种演唱会陪我熬夜.

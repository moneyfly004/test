<div>

[**English**](README.md)

</div>

## MoneyFly

[![License](https://img.shields.io/github/license/moneyfly004/test?style=flat-square)](LICENSE)
[![Release](https://img.shields.io/github/release/moneyfly004/test/all.svg?style=flat-square)](https://github.com/moneyfly004/test/releases/)

多平台代理客户端，内置订阅管理、设备管理和应用内套餐购买。

## 功能特性

✈️ **多平台支持**：Android、Windows、macOS 和 Linux

🔐 **账户系统**：登录、注册、邮箱验证找回密码

📦 **订阅管理**：登录后自动同步代理配置

💳 **应用内购买**：浏览套餐、支付宝/扫码支付，支付成功自动更新配置

📱 **设备管理**：查看绑定设备、编辑备注、远程删除设备

📊 **仪表盘**：订阅到期时间、设备使用情况、实时速率、节点选择器

🌙 **Material You 设计**：深色模式、自适应屏幕、多种主题颜色

☁️ **WebDAV 同步**：备份和恢复配置

## 下载

<a href="https://github.com/moneyfly004/test/releases"><img alt="从 GitHub 下载" src="snapshots/get-it-on-github.svg" width="200px"/></a>

## 使用说明

### Linux

使用前安装依赖：

```bash
sudo apt-get install libayatana-appindicator3-dev
sudo apt-get install libkeybinder-3.0-dev
```

### Android

支持以下广播操作：

```
com.moneyfly.proxy.action.START
com.moneyfly.proxy.action.STOP
com.moneyfly.proxy.action.TOGGLE
```

## 构建

1. 更新子模块
   ```bash
   git submodule update --init --recursive
   ```

2. 安装 `Flutter` 和 `Golang` 环境

3. 构建

   ```bash
   dart setup.dart android   # 安卓
   dart setup.dart windows   # Windows
   dart setup.dart linux     # Linux
   dart setup.dart macos     # macOS
   ```

## 致谢

基于 [FlClash](https://github.com/chen08209/FlClash) 开发，感谢原作者 chen08209 的优秀开源工作。

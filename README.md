<div>

[**简体中文**](README_zh_CN.md)

</div>

## MoneyFly

[![License](https://img.shields.io/github/license/moneyfly004/test?style=flat-square)](LICENSE)
[![Release](https://img.shields.io/github/release/moneyfly004/test/all.svg?style=flat-square)](https://github.com/moneyfly004/test/releases/)

A multi-platform proxy client with built-in subscription management, device management, and in-app package purchasing.

## Features

✈️ **Multi-platform**: Android, Windows, macOS and Linux

🔐 **Account system**: Login, register, forgot password with email verification

📦 **Subscription management**: Auto-sync proxy config after login

💳 **In-app purchase**: Browse packages, pay via Alipay / QR payment, auto-update config on success

📱 **Device management**: View bound devices, edit remarks, remove devices remotely

📊 **Dashboard**: Subscription expiry, device usage, real-time speed, node selector

🌙 **Material You design**: Dark mode, adaptive screen sizes, multiple color themes

☁️ **WebDAV sync**: Backup and restore configuration

## Download

<a href="https://github.com/moneyfly004/test/releases"><img alt="Get it on GitHub" src="snapshots/get-it-on-github.svg" width="200px"/></a>

## Usage

### Linux

Install dependencies before use:

```bash
sudo apt-get install libayatana-appindicator3-dev
sudo apt-get install libkeybinder-3.0-dev
```

### Android

Supports the following broadcast actions:

```
com.moneyfly.proxy.action.START
com.moneyfly.proxy.action.STOP
com.moneyfly.proxy.action.TOGGLE
```

## Build

1. Update submodules
   ```bash
   git submodule update --init --recursive
   ```

2. Install `Flutter` and `Golang` environment

3. Build

   ```bash
   dart setup.dart android   # Android
   dart setup.dart windows   # Windows
   dart setup.dart linux     # Linux
   dart setup.dart macos     # macOS
   ```

## Acknowledgements

Based on [FlClash](https://github.com/chen08209/FlClash) by chen08209. Thanks to the original author for the excellent open-source work.

# fhs-install-singbox

> 欲查阅以简体中文撰写的介绍，请访问：[README.zh-Hans-CN.md](README.zh-Hans-CN.md) **NOT YET**

> Unofficial Bash script for installing sing-box in operating systems such as Debian / CentOS / Fedora / openSUSE that support systemd

The files installed by this script compatible with [Filesystem Hierarchy Standard (FHS)](https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard)：

```
installed: /usr/local/bin/sing-box
installed: /usr/local/etc/sing-box/geoip.dat
installed: /usr/local/etc/sing-box/geosite.dat
installed: /usr/local/etc/sing-box/config.json
installed: /var/log/sing-box/
installed: /var/log/sing-box/access.log
installed: /var/log/sing-box/error.log
installed: /etc/systemd/system/sing-box.service
installed: /etc/systemd/system/sing-box@.service
```

## NOTE
 

This project **DOES NOT AUTOMATICCALY GENERATE CONFIGURATION FILE** for you; This project **ONLY HELP USER DURING INSTALLATION**. Other questions cannot be helped here. Please refer to [Documentaion](https://sing-box.sagernet.org/) Understand the configuration file syntax and complete the configuration file that suits you. During the process, you can refer to [Examples](https://sing-box.sagernet.org/examples/)  
（**Please note that these templates need to be modified and adjusted by yourself after copying, and cannot be used directly**）

## HOW TO USE

* The script will provide information such as `info` and `error` when it is executed, please read it carefully.

### Install and Update sing-box

```
// Install binary and .db files
# bash <(curl -L https://raw.githubusercontent.com/NextGenOP/fhs-install-singbox/master/install-release.sh)
```

### Install(or update) geoip.db & geosite.db to the latest release

```
// Only update .db data files
# bash <(curl -L https://raw.githubusercontent.com/NextGenOP/fhs-install-singbox/master/install-dat-release.sh)
```

### Uninstall sing-box

```
# bash <(curl -L https://raw.githubusercontent.com/NextGenOP/fhs-install-singbox/master/install-release.sh) --remove
```

### Other Resource

* 「[Do not install or update geoip and geosite](https://github.com/v2fly/fhs-install-v2ray/wiki/Do-not-install-or-update-geoip.dat-and-geosite.dat)」。
* 「[Insufficient permissions when using certificate](https://github.com/v2fly/fhs-install-v2ray/wiki/Insufficient-permissions-when-using-certificates)」。

> If your you have another question please 

**Please read before asking questions [Issue #63](https://github.com/v2fly/fhs-install-v2ray/issues/63)**



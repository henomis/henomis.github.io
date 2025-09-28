---
title: "NetBSD on a ROCK64 Board"
date: 2024-11-09T22:00:32+01:00
tags: ["freebsd", "netbsd", "iot", "rock64", "gateway", "experiment"]
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
disableHLJS: true # to disable highlightjs
disableShare: false
disableHLJS: false
hideSummary: false
searchHidden: true
ShowReadingTime: true
ShowBreadCrumbs: true
ShowPostNavLinks: true
featuredImage: "/images/rock64-008.jpg"
aliases: 
    - "/blog/netbsd-on-a-rock64-board/"
cover:
    image: "/images/rock64-008.jpg" # image path/url
    alt: "<alt text>" # alt text
    caption: "<text>" # display caption under cover
    relative: false # when using page bundles set this to true
    hidden: false # only hide on current single page
---

This is the sequel to the previous post [FreeBSD on a ROCK64 Board](https://simonevellei.com/blog/posts/freebsd-on-a-rock64-board/). Long story short, I had the chance to resurrect 4 single-board computers that were collecting dust in my office. I decided to install FreeBSD on one of them and it was a success. This time I will show you how and why I installed NetBSD on a second ROCK64 board.

## Let's add connectivity to the FreeBSD board
The process I described in the previous post was fun and I learned a lot. However, I used a USB-to-serial adapter to connect to the board, and even though it was fine to complete the installation, I wanted to have a more comfortable way to connect to the board. 

> Did I tell you I have a lot of dust-collecting devices in my office?

I remembered I had a USB wifi dongle that I bought a few years ago. This adapter is based on the Atheros AR9271 chipset, I knew it was supported by Linux at the time, but I wasn't sure about FreeBSD. After a quick search, I found the FreeBSD wiki page dedicated to [Atheros wireless driver support](https://wiki.freebsd.org/dev/ath(4)). And you know what? The AR9271 chipset  is not yet well supported along with the related USB HAL.

> Mmm, ok let's buy a cheap USB wifi dongle that is supported by FreeBSD.

That was my first thought, and I started looking at the list of devices and then searching for the FreeBSD driver support. It was at that moment that a weird idea came to my mind: if this device is not supported by FreeBSD, why not try it with NetBSD?

![rock64](/images/rock64-006.jpg)

## NetBSD to the rescue

As I did with FreeBSD, I went to the Rock64 software release page to the [NetBSD section](https://wiki.pine64.org/wiki/ROCK64_Software_Releases#NetBSD). It was very interesting dicover that the NetBSD image for my board was ready to [download](https://nycdn.netbsd.org/pub/arm/) and use. A few minutes later I had the image on my computer and I was ready to flash it on the SD card.

```bash
$ sudo dd if=NetBSD-10-aarch64--rock64.img of=/dev/sda bs=1M status=progress
```

It worked like a charm, unlike FreeBSD, NetBSD has the support for the eMMC boot, so it was very straightforward. Cool, next step was to connect the wifi dongle and see if it was recognized by the system.

```bash
$ dmesg

[     2.755663] : Atheros AR9271
[     2.755663] athn0: rev 1 (1T1R), ROM rev 15, address 00:c0:ca:--:--:--
```

The device was recognized and the driver was loaded. The `ifconfig` command showed the new interface `athn0`. The plan was clear, I had to configure the NetBSD system as gateway and connect it to the FreeBSD board via ethernet cable.

### Configuring the wifi interface
NetBSD has a dedicated web page to explain how to [configure the wifi interface](https://www.netbsd.org/docs/guide/en/chap-net-practice.html#chap-net-practice-lan-setup-wlan), so I followed the instructions and configured the `athn0` interface.  

```bash
$ cat /etc/ifconfig.athn0

inet 192.168.1.2 netmask 255.255.255.0
```

NetBSD uses WPA supplicant to manage the wifi connection, so I had to create a configuration file for the wifi network.

```bash
$ cat /etc/wpa_supplicant.conf

ctrl_interface=/var/run/wpa_supplicant
ctrl_interface_group=wheel
update_config=1
network={
	ssid="my-wifi-ssid"
	psk=--------------------------------
}
```

After configuring the wifi interface I had to modify the `/etc/rc.conf` file to enable the `wpa_supplicant` service and set the `defaultroute` to the gateway IP address.

```bash
$ cat /etc/rc.conf

...
wpa_supplicant=YES
wpa_supplicant_flags="-B -D bsd -i athn0 -c /etc/wpa_supplicant.conf"
defaultroute="192.168.1.1"
```

Lastly, I had to set the `nameserver` in the `/etc/resolv.conf` file.

```bash
$ cat /etc/resolv.conf

nameserver 192.168.1.1
```

The system was ready to connect to the wifi network and was able to reach the internet. The next step was to configure the ethernet interface to connect to the FreeBSD board.

### Configuring the ethernet interface
Following the same steps as before, I configured the `awge0` interface with the IP address

```bash
$ cat /etc/ifconfig.awge0

inet 10.0.0.1 netmask 255.255.255.0
```

After configuring the ethernet interface I had to instruct the system to forward ip packets enabling the ip forwarding in the `/etc/sysctl.conf` file.

```bash
$ cat /etc/sysctl.conf

...
net.inet.ip.forwarding=1
```

The last step was to configure the `npf` firewall to enable NAT and forward the packets from the `awge0` interface to the `athn0` interface. I created the `/etc/npf.conf` file with the following rules.

```bash
$ext_if = { inet4(athn0) }
$int_if = { inet4(awge0) }

$services_tcp = { 2222 }
$localnet = { 10.0.0.0/24 }

alg "icmp"

map $ext_if dynamic 10.0.0.0/24 -> ifaddrs($ext_if)
map $ext_if dynamic proto tcp 10.0.0.2 port 22 <- ifaddrs($ext_if) port 2222

procedure "log" {        
        log: npflog0
}

group "external" on $ext_if {
        pass stateful out final all
        pass stateful in final family inet4 proto tcp to $ext_if \
                port ssh apply "log"
        pass stateful in final proto tcp to $ext_if \
                port $services_tcp
}

group "internal" on $int_if {
        block in all
        pass in final from $localnet
        pass out final all
}

group default {
        pass final on lo0 all
        block all
}
```

The firewall rules allow connections to the FreeBSD board via ssh on port `2222`.
The `man npf.conf` page was very helpful to understand the syntax and the rules and it contains a good example to start with. After creating the `npf.conf` file I had to enable the `npf` service in the `/etc/rc.conf` file.

```bash
$ cat /etc/rc.conf

...
npf=YES
```

That was it, the NetBSD system was ready to act as a gateway and connect to the FreeBSD board.

## Configuring the FreeBSD board

The last step was to configure the FreeBSD board to connect to the NetBSD gateway. I configured the `dwc0` interface with a static IP address and set the `defaultrouter` to the NetBSD gateway IP address.

```bash

$ cat /etc/rc.conf

...
ifconfig_dwc0="inet 10.0.0.2 netmask 255.255.255.0"
defaultrouter="10.0.0.1"
```

![rock64](/images/rock64-007.jpg)

And... it worked! I was able to connect to the FreeBSD board via ssh on port `2222` using the NetBSD gateway!

I had a lot of fun configuring the NetBSD system as a gateway and connecting it to the FreeBSD board. I learned a lot about the NetBSD system and I was impressed by the simplicity and the clarity of the documentation. I will definitely use NetBSD in the future for other projects!
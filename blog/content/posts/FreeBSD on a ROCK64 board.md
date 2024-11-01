---
title: "FreeBSD on a ROCK64 Board"
date: 2024-11-01T16:37:37+01:00
tags: ["freebsd", "linux", "iot", "embedded", "experiment"]
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
cover:
    image: "/blog/images/rock64-004.png" # image path/url
    alt: "<alt text>" # alt text
    caption: "<text>" # display caption under cover
    relative: false # when using page bundles set this to true
    hidden: false # only hide on current single page
---
This is a story about an embedded board and a BSD system. The title could have been "How to resurrect a forgotten board and fall in love with BSD operating systems, again".
It all started 6 years ago when I bought 4 Pine Rock64 boards, with a well planned project in my mind. Each board was equipped with a Rockchip RK3328 quad-core ARM Cortex A53 64-Bit processor, 4GB of RAM, 32GB of eMMC storage, and a Gigabit Ethernet port.

![image](/blog/images/rock64-001.png)

 The project was to build a cluster of 4 boards to experiment with Kubernetes and Docker. I was very excited about the project, but unfortunately, I never had the time to go through it. The only thing I did was to build a rack to hold the 4 boards together, including a small 5-port switch and a power supply. The rack was placed in a corner of my office and forgotten after some preliminary tests.

![image](/blog/images/rock64-003.png)

## The resurrection
Some days ago I was cleaning my office and I found the rack with the 4 boards. I decided to give it a try and see if I could make them work. I connected the power supply and the switch, and I powered on the boards. The boards were booting, I tried to connect to them using the serial console, but I couldn't remember the root password. I took that as a **sign**, let's start from scratch, again. I still had the original eMMC USB adapter to flash an OS image and more or less 20 years of IoT experience on my shoulders. Ready, set, go!

![image](/blog/images/rock64-002.png)

## Documentation
First thing first, let's check the documentation. I went to the Pine64 website and I found the [Rock64 device](https://pine64.org/devices/rock64/) page and the [Rock64 wiki](https://wiki.pine64.org/wiki/Rock64). Time flies, and I remember a different website, but I'm happy to see the [Release](https://pine64.org/documentation/ROCK64/Software/Releases/) page with the latest supported OS images. There are many Linux distributions, Debian, the derived Armbian, and a plethora of Android versions. Hey, am I getting so old? Then my heart calmed down when I saw the FreeBSD, NetBSD, and OpenBSD support. 

> "They are still there", I thought.

However, just to understand if the boards were still working, I decided to flash the latest Armbian image. I downloaded the image, flashed it on the eMMC, and powered on a board. The board booted, and I managed to connect to it using the serial console.

> Cool! But wait...look at the `ps aux` output!

Sorry guys, I'm old school, I can't stand `systemd`. Yes, I must confess to have been lazy last years and to have been using Ubuntu for my desktop PC, but come on, it's an embedded board, I would have liked to squeeze the maximum performance out of it and full control of the system. My heart turned suddenly less happy.

## The BSD way
I'll make it short, but it could deserve an additional post. My first experience with a BSD OS was with OpenBSD at the University in 2003 to pass the Security and Cryptography exam. I had to research and write a paper about the security and cryptography features of OpenBSD. I started installing OpenBSD on my desktop PC to put my hands on it, and I fell in love with it. But, again, that's another story.

I decided to install FreeBSD on the Rock64 boards. I went to the FreeBSD website and discovered that there were pre-built ROCK64 arm images. 

> "Wow, that's amazing!", I thought.

I downloaded the image, flashed it on the eMMC, and powered on a board. All seemed to work fine, but at some point the board froze. I tried to understand what was happening, but I couldn't find the root cause. From this point on, I started to investigate the issue, and I found that the issue was related to eMMC boot support.

> Ah-ah it would have been too easy!

## Never give up
The issue was that the FreeBSD kernel included into the ROCK64 image didn't support the eMMC boot. However, after some research, I found a [blog post](https://www.idatum.net/ads-b-on-a-rock64-with-freebsd-stable14.html) that explained how to build a custom kernel and fix the issue for that board.

> Nice! But...did I tell you that I became a lazy Linux Ubuntu user? 

The post's author explains how to build the kernel on a FreeBSD system, and my next question was: "Is it possible to build a FreeBSD kernel on a Linux system?". Back to Google search and this time I landed on a FreeBSD [wiki page](https://wiki.freebsd.org/BuildingOnNonFreeBSD) that explains how to build a FreeBSD kernel on a Linux system. I'm used to build Linux embedded systems from scratch starting from cross-compiling the kernel, so I felt at home.

## Attempt #1: Building the FreeBSD kernel on a Linux system
I followed the instructions and downloaded the FreeBSD source code.

```bash
$ git clone https://git.FreeBSD.org/src.git
```

I then installed the required packages on my Ubuntu system

```bash
$ sudo apt install clang libarchive-dev libbz2-dev
```

Since Linux doesn't include a version of bmake by default, building should be done using the script `tools/build/make.py` which will bootstrap bmake before attempting to build. 

```bash
$ export MAKEOBJDIRPREFIX=~/freebsd

$ tools/build/make.py buildkernel TARGET=arm64 TARGET_ARCH=aarch64 KERNCONF=ROCK64
```

However, the build failed with an error related to the missing `config` command. I'm still not sure I haven't missed something, but I decided to try another approach.

## Attempt #2: Building the FreeBSD kernel on a FreeBSD system
I realized I needed a FreeBSD system to compile the kernel.

> _What's the fastest way to have a FreeBSD system up and running? A virtual machine somewhere in the cloud, or...a virtual machine on my PC! Where are you, QEMU, my old friend?_

The next surprise would have been finding precompiled FreeBSD qcow2 images in the [official repository](https://download.freebsd.org/releases/VM-IMAGES/14.1-RELEASE/amd64/Latest/). It seemed that I was lucky, and I downloaded the image and started a virtual machine with QEMU. However to have enough space to build the kernel I had to resize the disk image. From this point on, this story will become more nerdy.


### Booting the FreeBSD virtual machine
Let's resize the disk image and boot the virtual machine.

```bash
$ qemu-img resize ~/FreeBSD-14.1-RELEASE-amd64-zfs.qcow2 +10G

$ qemu-system-x86_64 -hda ~/FreeBSD-14.1-RELEASE-amd64-zfs.qcow2 -m 2048 -enable-kvm  -netdev user,id=mynet0,hostfwd=tcp:127.0.0.1:7722-:22 -device e1000,netdev=0
```

I connected to the virtual machine and then expanded the last partition on the virtual disk to make use of this new space.

```bash
$ gpart show ada0

$ gpart resize -i 4 -a 4k ada0
```

Once the partition has been resized, I instructed ZFS to expand the pool to use the additional space.

```bash
$ zpool list

$ zpool online -e zroot ada0p4
```

### Building the FreeBSD kernel
After cloning the FreeBSD source code, I installed the required packages.

```bash
$ pkg update

$ pkg install git gcc gmake python pkgconf pixman bison glib 
```

and finally I built the kernel.

```bash
make buildkernel TARGET=arm64 KERNCONF=ROCK64
```

Cool! It worked! I was very close to the final goal. I only needed to copy the kernel to the ROCK64 image and then flash it on the eMMC.

### Copying the kernel to the ROCK64 image
I downloaded the ROCK64 image from the [FreeBSD website](https://download.freebsd.org/ftp/snapshots/ISO-IMAGES/14.1/) and uncompressed it.

```bash
$ wget https://download.freebsd.org/ftp/snapshots/ISO-IMAGES/14.1/FreeBSD-14.1-STABLE-arm64-aarch64-ROCK64-20241017-d36ba3989ca9-269125.img.xz

$ unxz FreeBSD-14.1-STABLE-arm64-aarch64-ROCK64-20241017-d36ba3989ca9-269125.img.xz
```

Then I mounted the boot partition of the image

```bash
$ mdconfig -a -t vnode -f /root/FreeBSD-14.1-STABLE-arm64-aarch64-ROCK64-20241017-d36ba3989ca9-269125.img

$ mdconfig -l

$ gpart show md0

$ mount -t ufs /dev/md0p2 /mnt
```

Ok, back to the kernel build directory, I copied the kernel to the boot partition of the ROCK64 image and unmounted it.

```bash
$ make installkernel TARGET=arm64 KERNCONF=ROCK64 DESTDIR=/mnt

$ umount /mnt

$ mdconfig -d -u md0
```

### Flashing the eMMC

I connected the eMMC USB adapter to my PC and I flashed the ROCK64 image on the eMMC.

```bash
$ scp -P 7722 root@localhost:/root/FreeBSD-14.1-STABLE-arm64-aarch64-ROCK64-20241017-d36ba3989ca9-269125.img ~/

$ sudo dd if=FreeBSD-13.4-STABLE-arm64-aarch64-ROCK64-20241024-9db8fd4c2adc-258557.img of=/dev/sda bs=1M status=progress
```

## The moment of truth
I powered on the board, and it booted successfully. I connected to the board using the serial console and could see the FreeBSD boot messages. I was very happy, and I felt like a child with a new toy. I started to explore the system, and I found that the board was working fine. I could connect to the board using SSH, and I could install packages using the package manager.

> "I did it!", I thought.

![image](/blog/images/rock64-005.png)

## Conclusion and questions
I'm very happy to have resurrected the Rock64 boards and to have installed FreeBSD on them. However, I have some questions that I would like to share with you.

1. Nice story, but was it worth it? I mean, was it worth spending so much time to install FreeBSD on a Rock64 board when I could have used QEMU to run a FreeBSD virtual machine on my PC? **Yes, it was worth it. I learned a lot of things, and I had fun. The feeling of having a physical board running FreeBSD is priceless.**

2. Nice try, could there be other, simpler ways to achieve the same result? **I'm pretty sure there are different ways to achieve the same result as well as I'm also sure that I might have missed something in the process. But, again, I had fun.**

3. What was the first shell command I typed into the FreeBSD system? **Did I tell you I can't stand `systemd`? I wanted to be sure to have the init system I like, so I typed `ls /etc/rc.d/`.**
 

3. Why did I choose FreeBSD instead of OpenBSD or NetBSD? **Oh, well...this story could have a sequel 😉.**


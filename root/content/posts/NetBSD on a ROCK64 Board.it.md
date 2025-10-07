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
    - "/blog/posts/netbsd-on-a-rock64-board/"
cover:
    image: "/images/rock64-008.jpg" # image path/url
    alt: "<alt text>" # alt text
    caption: "<text>" # display caption under cover
    relative: false # when using page bundles set this to true
    hidden: false # only hide on current single page
---
{{< admonition type=info open=true >}}
Questo post è stato originariamente scritto in inglese e tradotto in italiano tramite AI. Se noti errori di traduzione o passaggi poco chiari, segnalamelo pure.

🇬🇧 [Leggi il post originale in inglese](/en/netbsd-on-a-rock64-board/)
{{< /admonition >}}

Questo è il seguito del post precedente [FreeBSD su una scheda ROCK64](https://simonevellei.com/blog/posts/freebsd-on-a-rock64-board/). Per farla breve, ho avuto la possibilità di resuscitare 4 single-board computer che stavano raccogliendo polvere nel mio ufficio. Ho deciso di installare FreeBSD su uno di essi ed è stato un successo. Questa volta ti mostrerò come e perché ho installato NetBSD su una seconda scheda ROCK64.

## Aggiungiamo la connettività alla scheda FreeBSD

Il processo che ho descritto nel post precedente è stato divertente e istruttivo. Tuttavia, ho usato un adattatore USB-seriale per collegarmi alla scheda e, anche se andava bene per completare l’installazione, volevo un modo più comodo per connettermi alla scheda.

> Ti ho detto che ho un sacco di dispositivi che raccolgono polvere nel mio ufficio?

Mi sono ricordato di avere una chiavetta wifi USB che avevo comprato qualche anno fa. Questo adattatore si basa sul chipset Atheros AR9271, sapevo che era supportato da Linux all’epoca, ma non ero sicuro riguardo FreeBSD. Dopo una rapida ricerca, ho trovato la pagina wiki di FreeBSD dedicata al [supporto dei driver wireless Atheros](https://wiki.freebsd.org/dev/ath%284%29). E sai una cosa? Il chipset AR9271 non è ancora ben supportato insieme all’HAL USB correlato.

> Mmm, ok, compriamo una chiavetta wifi USB economica che sia supportata da FreeBSD.

Questa è stata la mia prima idea, e ho iniziato a guardare la lista dei dispositivi e poi a cercare il supporto driver su FreeBSD. È stato in quel momento che mi è venuta in mente un’idea strana: se questo dispositivo non è supportato da FreeBSD, perché non provarlo con NetBSD?

![rock64](/images/rock64-006.jpg)

## NetBSD in soccorso

Come avevo fatto con FreeBSD, sono andato alla pagina delle release software di Rock64 nella sezione [NetBSD](https://wiki.pine64.org/wiki/ROCK64_Software_Releases#NetBSD). È stato molto interessante scoprire che l’immagine NetBSD per la mia scheda era pronta per essere [scaricata](https://nycdn.netbsd.org/pub/arm/) e usata. Pochi minuti dopo avevo l’immagine sul mio computer e ero pronto a scriverla sulla scheda SD.

```bash
$ sudo dd if=NetBSD-10-aarch64--rock64.img of=/dev/sda bs=1M status=progress
```

Ha funzionato alla perfezione, a differenza di FreeBSD, NetBSD supporta l’avvio da eMMC, quindi è stato tutto molto semplice. Ottimo, il passo successivo era collegare la chiavetta wifi e vedere se veniva riconosciuta dal sistema.

```bash
$ dmesg

[     2.755663] : Atheros AR9271
[     2.755663] athn0: rev 1 (1T1R), ROM rev 15, address 00:c0:ca:--:--:--
```

Il dispositivo è stato riconosciuto e il driver è stato caricato. Il comando `ifconfig` mostrava la nuova interfaccia `athn0`. Il piano era chiaro: dovevo configurare il sistema NetBSD come gateway e collegarlo alla scheda FreeBSD tramite cavo ethernet.

### Configurare l’interfaccia wifi

NetBSD ha una pagina web dedicata che spiega come [configurare l’interfaccia wifi](https://www.netbsd.org/docs/guide/en/chap-net-practice.html#chap-net-practice-lan-setup-wlan), quindi ho seguito le istruzioni e configurato l’interfaccia `athn0`.

```bash
$ cat /etc/ifconfig.athn0

inet 192.168.1.2 netmask 255.255.255.0
```

NetBSD usa WPA supplicant per gestire la connessione wifi, quindi ho dovuto creare un file di configurazione per la rete wifi.

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

Dopo aver configurato l’interfaccia wifi, ho dovuto modificare il file `/etc/rc.conf` per abilitare il servizio `wpa_supplicant` e impostare il `defaultroute` con l’indirizzo IP del gateway.

```bash
$ cat /etc/rc.conf

...
wpa_supplicant=YES
wpa_supplicant_flags="-B -D bsd -i athn0 -c /etc/wpa_supplicant.conf"
defaultroute="192.168.1.1"
```

Infine, ho dovuto impostare il `nameserver` nel file `/etc/resolv.conf`.

```bash
$ cat /etc/resolv.conf

nameserver 192.168.1.1
```

Il sistema era pronto a connettersi alla rete wifi ed era in grado di raggiungere Internet. Il passo successivo era configurare l’interfaccia ethernet per collegarsi alla scheda FreeBSD.

### Configurare l’interfaccia ethernet

Seguendo gli stessi passaggi di prima, ho configurato l’interfaccia `awge0` con l’indirizzo IP

```bash
$ cat /etc/ifconfig.awge0

inet 10.0.0.1 netmask 255.255.255.0
```

Dopo aver configurato l’interfaccia ethernet, ho dovuto istruire il sistema a inoltrare i pacchetti IP abilitando l’IP forwarding nel file `/etc/sysctl.conf`.

```bash
$ cat /etc/sysctl.conf

...
net.inet.ip.forwarding=1
```

L’ultimo passo era configurare il firewall `npf` per abilitare il NAT e inoltrare i pacchetti dall’interfaccia `awge0` all’interfaccia `athn0`. Ho creato il file `/etc/npf.conf` con le seguenti regole.

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

Le regole del firewall permettono connessioni alla scheda FreeBSD via ssh sulla porta `2222`.
La pagina `man npf.conf` è stata molto utile per capire la sintassi e le regole, e contiene un buon esempio da cui partire. Dopo aver creato il file `npf.conf`, ho dovuto abilitare il servizio `npf` nel file `/etc/rc.conf`.

```bash
$ cat /etc/rc.conf

...
npf=YES
```

E questo era tutto, il sistema NetBSD era pronto ad agire come gateway e connettersi alla scheda FreeBSD.

## Configurare la scheda FreeBSD

L’ultimo passo era configurare la scheda FreeBSD per connettersi al gateway NetBSD. Ho configurato l’interfaccia `dwc0` con un indirizzo IP statico e impostato il `defaultrouter` con l’indirizzo IP del gateway NetBSD.

```bash

$ cat /etc/rc.conf

...
ifconfig_dwc0="inet 10.0.0.2 netmask 255.255.255.0"
defaultrouter="10.0.0.1"
```

![rock64](/images/rock64-007.jpg)

E… ha funzionato! Sono riuscito a connettermi alla scheda FreeBSD via ssh sulla porta `2222` utilizzando il gateway NetBSD!

Mi sono divertito molto a configurare il sistema NetBSD come gateway e a collegarlo alla scheda FreeBSD. Ho imparato molto su NetBSD e sono rimasto colpito dalla semplicità e chiarezza della documentazione. Userò sicuramente NetBSD in futuro per altri progetti!

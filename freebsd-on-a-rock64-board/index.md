# FreeBSD on a ROCK64 Board


{{< admonition type=info open=true >}}
Questo post è stato originariamente scritto in inglese e tradotto in italiano tramite AI. Se noti errori di traduzione o passaggi poco chiari, segnalamelo pure.

[🇬🇧 Leggi l'articolo originale in inglese](/en/freebsd-on-a-rock64-board/)
{{< /admonition >}}



Questa è la storia di una scheda embedded e di un sistema BSD. Il titolo avrebbe potuto essere "Come resuscitare una scheda dimenticata e innamorarsi di nuovo dei sistemi operativi BSD".
Tutto è iniziato 6 anni fa quando ho comprato 4 schede Pine Rock64, con un progetto ben pianificato in mente. Ogni scheda era equipaggiata con un processore Rockchip RK3328 quad-core ARM Cortex A53 a 64 bit, 4 GB di RAM, 32 GB di memoria eMMC e una porta Ethernet Gigabit.

![image](/images/rock64-001.png)

Il progetto era costruire un cluster di 4 schede per sperimentare con Kubernetes e Docker. Ero molto entusiasta del progetto, ma purtroppo non ho mai avuto il tempo di portarlo avanti. L’unica cosa che ho fatto è stata costruire un rack per tenere insieme le 4 schede, incluso un piccolo switch a 5 porte e un alimentatore. Il rack è stato messo in un angolo del mio ufficio e dimenticato dopo alcuni test preliminari.

![image](/images/rock64-003.png)

## La resurrezione

Qualche giorno fa stavo pulendo il mio ufficio e ho trovato il rack con le 4 schede. Ho deciso di fare un tentativo e vedere se potevo farle funzionare. Ho collegato l’alimentatore e lo switch, e ho acceso le schede. Le schede si avviavano, ho provato a connettermi tramite la console seriale, ma non ricordavo la password di root. Ho preso questo come un **segno**, ricominciamo da zero. Avevo ancora l’adattatore USB per eMMC originale per flashare un’immagine OS e più o meno 20 anni di esperienza IoT sulle spalle. Pronti, via!

![image](/images/rock64-002.png)

## Documentazione

Prima cosa, controlliamo la documentazione. Sono andato sul sito Pine64 e ho trovato la pagina [Rock64 device](https://pine64.org/devices/rock64/) e la [wiki Rock64](https://wiki.pine64.org/wiki/Rock64). Il tempo vola, e ricordo un sito diverso, ma sono stato felice di vedere la pagina [Release](https://pine64.org/documentation/ROCK64/Software/Releases/) con le ultime immagini OS supportate. Ci sono molte distribuzioni Linux, Debian, l’Armbian derivata, e una miriade di versioni Android. Ehi, sto diventando così vecchio? Poi il cuore mi si è calmato quando ho visto il supporto a FreeBSD, NetBSD e OpenBSD.

> "Sono ancora lì", ho pensato.

Tuttavia, solo per capire se le schede funzionavano ancora, ho deciso di flashare l’ultima immagine Armbian. Ho scaricato l’immagine, l’ho flashata sulla eMMC e ho acceso una scheda. La scheda si è avviata e sono riuscito a connettermi tramite console seriale.

> Fantastico! Ma aspetta... guarda l’output di `ps aux`!

Scusate ragazzi, sono della vecchia scuola, non sopporto `systemd`. Sì, devo confessare di essere stato pigro negli ultimi anni e di aver usato Ubuntu per il mio PC desktop, ma dai, è una scheda embedded, avrei voluto spremere il massimo delle prestazioni e avere il pieno controllo del sistema. Il mio cuore è diventato improvvisamente meno felice.

## La via BSD

La faccio breve, ma meriterebbe un altro post. La mia prima esperienza con un OS BSD fu con OpenBSD all’università nel 2003 per superare l’esame di Sicurezza e Crittografia. Dovevo fare una ricerca e scrivere un paper sulle funzionalità di sicurezza e crittografia di OpenBSD. Ho iniziato installando OpenBSD sul mio PC desktop per metterci le mani, e me ne sono innamorato. Ma, ancora una volta, questa è un’altra storia.

Ho deciso di installare FreeBSD sulle schede Rock64. Sono andato sul sito FreeBSD e ho scoperto che c’erano immagini precompilate per ROCK64 arm.

> "Wow, incredibile!", ho pensato.

Ho scaricato l’immagine, l’ho flashata sulla eMMC e ho acceso una scheda. Sembrava funzionare tutto bene, ma a un certo punto la scheda si è bloccata. Ho provato a capire cosa stava succedendo, ma non riuscivo a trovare la causa. Da lì ho iniziato a indagare, e ho scoperto che il problema era legato al supporto di boot su eMMC.

> Ah-ah, sarebbe stato troppo facile!

## Mai arrendersi

Il problema era che il kernel FreeBSD incluso nell’immagine ROCK64 non supportava il boot da eMMC. Tuttavia, dopo alcune ricerche, ho trovato un [post sul blog](https://www.idatum.net/ads-b-on-a-rock64-with-freebsd-stable14.html) che spiegava come compilare un kernel personalizzato e risolvere il problema per quella scheda.

> Bello! Ma...vi ho detto che sono diventato un pigro utente Linux Ubuntu?

L’autore del post spiegava come compilare il kernel su un sistema FreeBSD, e la mia domanda successiva è stata: "È possibile compilare un kernel FreeBSD su un sistema Linux?". Torno su Google e stavolta atterro su una [pagina wiki di FreeBSD](https://wiki.freebsd.org/BuildingOnNonFreeBSD) che spiega come compilare un kernel FreeBSD su un sistema Linux. Sono abituato a costruire sistemi embedded Linux da zero a partire dal cross-compiling del kernel, quindi mi sentivo a casa.

## Tentativo #1: Compilare il kernel FreeBSD su un sistema Linux

Ho seguito le istruzioni e scaricato il codice sorgente di FreeBSD.

```bash
$ git clone https://git.FreeBSD.org/src.git
```

Ho poi installato i pacchetti richiesti sul mio sistema Ubuntu

```bash
$ sudo apt install clang libarchive-dev libbz2-dev
```

Poiché Linux non include di default una versione di bmake, la compilazione deve essere fatta usando lo script `tools/build/make.py` che farà il bootstrap di bmake prima di tentare la build.

```bash
$ export MAKEOBJDIRPREFIX=~/freebsd

$ tools/build/make.py buildkernel TARGET=arm64 TARGET_ARCH=aarch64 KERNCONF=ROCK64
```

Tuttavia, la compilazione è fallita con un errore legato al comando `config` mancante. Non sono ancora sicuro di non aver dimenticato qualcosa, ma ho deciso di provare un altro approccio.

## Tentativo #2: Compilare il kernel FreeBSD su un sistema FreeBSD

Mi sono reso conto che avevo bisogno di un sistema FreeBSD per compilare il kernel.

> *Qual è il modo più veloce per avere un sistema FreeBSD funzionante? Una macchina virtuale nel cloud, oppure...una macchina virtuale sul mio PC! Dove sei, QEMU, vecchio amico?*

La sorpresa successiva è stata trovare immagini qcow2 precompilate di FreeBSD nel [repository ufficiale](https://download.freebsd.org/releases/VM-IMAGES/14.1-RELEASE/amd64/Latest/). Sembrava che fossi fortunato, ho scaricato l’immagine e avviato una macchina virtuale con QEMU. Tuttavia, per avere abbastanza spazio per compilare il kernel, ho dovuto ridimensionare l’immagine disco. Da questo punto in poi, la storia diventerà più nerd.

### Avviare la macchina virtuale FreeBSD

Ridimensioniamo l’immagine disco e avviamo la macchina virtuale.

```bash
$ qemu-img resize ~/FreeBSD-14.1-RELEASE-amd64-zfs.qcow2 +10G

$ qemu-system-x86_64 -hda ~/FreeBSD-14.1-RELEASE-amd64-zfs.qcow2 -m 2048 -enable-kvm  -netdev user,id=mynet0,hostfwd=tcp:127.0.0.1:7722-:22 -device e1000,netdev=mynet0
```

Mi sono connesso alla VM e ho esteso l’ultima partizione del disco virtuale per usare lo spazio aggiunto.

```bash
$ gpart show ada0

$ gpart resize -i 4 -a 4k ada0
```

Una volta ridimensionata la partizione, ho istruito ZFS a espandere il pool per usare lo spazio extra.

```bash
$ zpool list

$ zpool online -e zroot ada0p4
```

### Compilare il kernel FreeBSD

Dopo aver clonato il codice sorgente di FreeBSD, ho installato i pacchetti richiesti.

```bash
$ pkg update

$ pkg install git gcc gmake python pkgconf pixman bison glib 
```

e finalmente ho compilato il kernel.

```bash
make buildkernel TARGET=arm64 KERNCONF=ROCK64
```

Fantastico! Ha funzionato! Ero molto vicino all’obiettivo finale. Dovevo solo copiare il kernel nell’immagine ROCK64 e poi flasharlo sulla eMMC.

### Copiare il kernel nell’immagine ROCK64

Ho scaricato l’immagine ROCK64 dal [sito FreeBSD](https://download.freebsd.org/ftp/snapshots/ISO-IMAGES/14.1/) e l’ho decompressa.

```bash
$ wget https://download.freebsd.org/ftp/snapshots/ISO-IMAGES/14.1/FreeBSD-14.1-STABLE-arm64-aarch64-ROCK64-20241017-d36ba3989ca9-269125.img.xz

$ unxz FreeBSD-14.1-STABLE-arm64-aarch64-ROCK64-20241017-d36ba3989ca9-269125.img.xz
```

Poi ho montato la partizione di boot dell’immagine.

```bash
$ mdconfig -a -t vnode -f /root/FreeBSD-14.1-STABLE-arm64-aarch64-ROCK64-20241017-d36ba3989ca9-269125.img

$ mdconfig -l

$ gpart show md0

$ mount -t ufs /dev/md0p2 /mnt
```

Ok, tornando alla directory di compilazione del kernel, ho copiato il kernel nella partizione di boot dell’immagine ROCK64 e poi l’ho smontata.

```bash
$ make installkernel TARGET=arm64 KERNCONF=ROCK64 DESTDIR=/mnt

$ umount /mnt

$ mdconfig -d -u md0
```

### Flashare la eMMC

Ho collegato l’adattatore USB per eMMC al mio PC e ho flashato l’immagine ROCK64 sulla eMMC.

```bash
$ scp -P 7722 root@localhost:/root/FreeBSD-14.1-STABLE-arm64-aarch64-ROCK64-20241017-d36ba3989ca9-269125.img ~/

$ sudo dd if=FreeBSD-13.4-STABLE-arm64-aarch64-ROCK64-20241024-9db8fd4c2adc-258557.img of=/dev/sda bs=1M status=progress
```

## Il momento della verità

Ho acceso la scheda, e si è avviata correttamente. Mi sono connesso tramite console seriale e ho potuto vedere i messaggi di avvio di FreeBSD. Ero molto felice, e mi sentivo come un bambino con un nuovo giocattolo. Ho iniziato a esplorare il sistema e ho scoperto che la scheda funzionava bene. Potevo connettermi via SSH e installare pacchetti con il package manager.

> "Ce l’ho fatta!", ho pensato.

![image](/images/rock64-005.png)

## Conclusione e domande

Sono molto felice di aver resuscitato le schede Rock64 e di aver installato FreeBSD su di esse. Tuttavia, ho alcune domande che vorrei condividere con voi.

1. Bella storia, ma ne è valsa la pena? Voglio dire, è valsa la pena passare così tanto tempo per installare FreeBSD su una scheda Rock64 quando avrei potuto usare QEMU per eseguire una macchina virtuale FreeBSD sul mio PC? **Sì, ne è valsa la pena. Ho imparato molte cose e mi sono divertito. La sensazione di avere una scheda fisica che esegue FreeBSD non ha prezzo.**

2. Bel tentativo, ma potrebbero esserci altri modi, più semplici, per ottenere lo stesso risultato? **Sono abbastanza sicuro che ci siano modi diversi per ottenere lo stesso risultato così come sono sicuro di essermi perso qualcosa nel processo. Ma, di nuovo, mi sono divertito.**

3. Qual è stato il primo comando shell che ho digitato nel sistema FreeBSD? **Vi ho detto che non sopporto `systemd`? Volevo essere sicuro di avere il sistema di init che mi piace, quindi ho digitato `ls /etc/rc.d/`.**

4. Perché ho scelto FreeBSD invece di OpenBSD o NetBSD? **Oh, beh...questa storia potrebbe avere un seguito 😉.**



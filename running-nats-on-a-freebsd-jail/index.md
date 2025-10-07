# Running NATS on a FreeBSD Jail

{{< admonition type=info open=true >}}
Questo post è stato originariamente scritto in inglese e tradotto in italiano tramite AI. Se noti errori di traduzione o passaggi poco chiari, segnalamelo pure.

🇬🇧 [Leggi il post originale in inglese](/en/running-nats-on-a-freebsd-jail/)
{{< /admonition >}}

Negli ultimi mesi ho giocato con FreeBSD e le mie schede embedded Rock64 [[1](https://simonevellei.com/blog/posts/freebsd-on-a-rock64-board/)] [[2](https://simonevellei.com/blog/posts/netbsd-on-a-rock64-board/)]. Mi sono davvero divertito con l’esperienza e ho voluto passare al livello successivo sperimentando con le *FreeBSD jails*. Sono rimasto sorpreso da quanto fosse facile (e logico) creare e gestire un ambiente isolato. Ho anche notato che i comandi di basso livello sono stati incapsulati in interfacce più user-friendly (come `bastille`), rendendo l’esperienza complessiva molto più piacevole. Per avere un vero esempio di un microservizio in esecuzione in una jail, ho deciso di provare con [NATS](https://nats.io).

## Cos’è NATS?

[NATS](https://nats.io) è un sistema di messaggistica open-source progettato per applicazioni *cloud-native*, messaggistica IoT e architetture a microservizi. Fornisce un meccanismo di comunicazione leggero, ad alte prestazioni e sicuro, che supporta sia i modelli *publish-subscribe* che *request-reply*. NATS è noto per la sua semplicità, facilità d’uso e capacità di scalare orizzontalmente, rendendolo una scelta ideale per sistemi distribuiti.

Una delle caratteristiche principali di NATS è la capacità di gestire messaggi ad alto throughput e bassa latenza. Questo è possibile grazie a una combinazione di un protocollo efficiente, strutture dati in memoria e comunicazione di rete ottimizzata. NATS supporta anche il *clustering*, che consente a più server NATS di lavorare insieme per fornire tolleranza ai guasti e bilanciamento del carico.

Oltre alle sue funzionalità di messaggistica di base, NATS dispone di un ricco ecosistema di client e librerie per vari linguaggi di programmazione, rendendo facile l’integrazione con diverse applicazioni e servizi. Offre anche funzionalità avanzate come *streaming*, persistenza e sicurezza, che possono essere sfruttate per costruire soluzioni di messaggistica robuste e affidabili.

## Cos’è una FreeBSD jail?

Le *FreeBSD jails* sono una caratteristica potente e flessibile del sistema operativo FreeBSD che consente di creare ambienti isolati e sicuri all’interno di una singola istanza FreeBSD. Introdotte in FreeBSD 4.0, le jails offrono un’alternativa leggera alla virtualizzazione completa, permettendo di eseguire più applicazioni o servizi in spazi separati e confinati senza il sovraccarico di una macchina virtuale completa.

Una jail FreeBSD funziona come un ambiente *chroot* con funzionalità aggiuntive di sicurezza e gestione delle risorse. Ogni jail ha il proprio filesystem, le proprie interfacce di rete e lo spazio dei processi, garantendo che i processi in esecuzione all’interno di una jail non possano interferire con quelli di altre jails o del sistema host. Questo isolamento rende le jails una scelta eccellente per ospitare in modo sicuro più applicazioni su un singolo server, testare software in un ambiente controllato o gestire ambienti multi-tenant.

Le jails sono altamente configurabili, consentendo di regolare il livello di isolamento e allocazione delle risorse per ciascuna jail. È possibile assegnare indirizzi IP specifici, limitare l’uso della CPU e della memoria e controllare l’accesso alle risorse di sistema. Questa flessibilità, combinata con la natura leggera delle jails, le rende una scelta popolare sia per ambienti di sviluppo che di produzione.

## Cos’è Bastille?

[Bastille](https://bastillebsd.org/) è un’utilità da linea di comando per la gestione delle *FreeBSD jails*. Semplifica il processo di creazione, configurazione e manutenzione delle jails, che sono ambienti leggeri e isolati simili ai container. Bastille fornisce un’interfaccia facile da usare per la gestione delle jails, permettendo agli utenti di distribuire e gestire rapidamente applicazioni in modo sicuro ed efficiente.

Con Bastille puoi creare nuove jails, avviarle e arrestarle, e gestirne la configurazione con comandi semplici. Supporta anche i *template*, che possono essere utilizzati per automatizzare la distribuzione di ambienti preconfigurati. Questo lo rende uno strumento eccellente sia per lo sviluppo che per la produzione, dove coerenza e ripetibilità sono importanti.

Bastille si integra anche con ZFS, un file system robusto che offre funzionalità avanzate come snapshot e clonazione. Questa integrazione consente una gestione efficiente dello storage e un facile rollback delle modifiche, migliorando ulteriormente la flessibilità e l’affidabilità degli ambienti jail.

### Implementare un template Bastille per NATS

I *template* Bastille sono ambienti preconfigurati che possono essere utilizzati per distribuire rapidamente nuove jails. Contengono un’installazione base di FreeBSD insieme a eventuali pacchetti o configurazioni aggiuntive. I template sono una funzionalità potente di Bastille che può aiutare a semplificare il flusso di lavoro e garantire coerenza tra gli ambienti.

L’idea è quella di essere indipendenti dall’architettura, così il template può essere utilizzato in qualsiasi sistema FreeBSD. NATS verrà compilato dai sorgenti, quindi il template conterrà i pacchetti necessari per costruirlo.

```shell
# installa i pacchetti richiesti
PKG git
PKG go
```

Poi possiamo creare un utente e un gruppo specifici per NATS:

```shell
# crea il gruppo predefinito
CMD pw groupadd "${NATS_GROUP}"
# crea l’utente predefinito
CMD pw useradd -n "${NATS_USER}" -g "${NATS_GROUP}" -s /usr/sbin/nologin -w no
```

Accetteremo i nomi di gruppo e utente come variabili d’ambiente, così potremo personalizzarli quando creeremo la jail dal template.

Ora è il momento di clonare il repository di NATS e compilarlo:

```shell
# scarica e installa il server nats
CMD "${GO}" install "github.com/nats-io/nats-server/v2@${NATS_VERSION}"
CMD "${INSTALL}" -o "${NATS_USER}" -g "${NATS_GROUP}" "${GOPATH}/bin/nats-server" /usr/local/bin/nats-server
```

Utilizzeremo `go install` per scaricare e compilare il server NATS, quindi lo installeremo nella directory `/usr/local/bin`. Imposteremo anche proprietario e gruppo del binario all’utente e al gruppo creati in precedenza.

Una volta installato il server NATS, possiamo creare un file di configurazione e uno script di avvio per esso:

```shell
CP usr /
CMD chmod a+x /usr/local/etc/rc.d/nats
```

La directory `usr` contiene il file di configurazione e lo script di avvio per il server NATS. Li copieremo nella directory root della jail e renderemo eseguibile lo script di avvio.

Infine, imposteremo il server NATS per avviarsi automaticamente all’avvio della jail:

```shell
SYSRC nats_enable=YES
SYSRC nats_user="${NATS_USER}"
SYSRC nats_group="${NATS_GROUP}"
SERVICE nats start
```

> Non preoccuparti troppo del template; troverai un link al repository con il codice completo alla fine dell’articolo.

## Creare una jail NATS

Per consentire a Bastille di creare una jail da un template, dobbiamo prima eseguire il bootstrap:

```shell
bastille bootstrap https://github.com/henomis/nats-jail-template
```

Questo comando scaricherà il template dal repository; lo troverai nella directory `/usr/local/bastille/templates/`.

Ora possiamo creare la jail:

```shell
bastille create nats-jail 14.2-RELEASE 10.0.0.1
```

Questo comando creerà una nuova jail chiamata `nats-jail`. La jail sarà basata su FreeBSD 14.2-RELEASE e avrà l’indirizzo IP `10.0.0.1`. È ora di applicare il template:

```shell
bastille template nats-jail henomis/nats-jail-template
```

Questo comando applicherà il template alla jail, installando tutti i pacchetti e le configurazioni necessari. Una volta applicato il template, avrai un server NATS pienamente funzionante in esecuzione nella jail.

## Testare la jail NATS

Per testare la jail NATS, puoi connetterti ad essa usando lo strumento CLI di NATS. Ma, dato che ci siamo già divertiti con le jails, possiamo crearne una nuova ed eseguire il tool NATS CLI al suo interno. Imposteremo un *publisher* e un *subscriber* in due jails diverse, e useremo il server NATS per inviare messaggi tra di loro.

Creiamo una nuova jail per il publisher:

```shell
bastille create pub-jail 14.2-RELEASE 10.0.0.2
```

Poi installeremo i pacchetti necessari e lo strumento CLI di NATS:

```shell
bastille pkg pub-jail install -y git go
bastille cmd pub-jail go install github.com/nats-io/natscli/nats@latest
```

Grazie a `bastille clone` possiamo creare una nuova jail da una esistente, quindi possiamo clonare la jail del publisher e creare una jail per il subscriber:

```shell
bastille clone pub-jail sub-jail 10.0.0.3
bastille start sub-jail
```

Siamo quasi alla fine, dobbiamo solo avviare il subscriber e il publisher in due jails diverse:

```shell
bastille cmd sub-jail /root/go/bin/nats --server 10.0.0.1 sub my.topic
```

Usando un altro terminale:

```shell
bastille cmd pub-jail /root/go/bin/nats --server 10.0.0.1 pub my.topic "message {{.Count}} - {{.TimeStamp}}" --count 5
```

Dovresti vedere i messaggi inviati dal publisher nel terminale del subscriber.

```shell
[#1] Received on "my.topic"
message 1 - 2025-01-01T16:20:16+01:00


[#2] Received on "my.topic"
message 2 - 2025-01-01T16:20:16+01:00


[#3] Received on "my.topic"
message 3 - 2025-01-01T16:20:16+01:00


[#4] Received on "my.topic"
message 4 - 2025-01-01T16:20:16+01:00


[#5] Received on "my.topic"
message 5 - 2025-01-01T16:20:16+01:00
```

E… questo è tutto! Hai un server NATS in esecuzione in una jail FreeBSD, e puoi inviare messaggi tra diverse jails usando lo strumento CLI di NATS. Puoi sperimentare con configurazioni diverse, aggiungere altre jails ed esplorare ulteriormente le potenzialità di NATS e delle FreeBSD jails.

## Conclusione

In questo articolo abbiamo visto come creare una jail FreeBSD con Bastille ed eseguire al suo interno un server NATS. Abbiamo anche visto come creare due jails aggiuntive e usare lo strumento CLI di NATS per inviare messaggi tra di esse. Questo esempio dimostra la potenza e la flessibilità delle FreeBSD jails e come possano essere utilizzate per creare ambienti isolati e sicuri per l’esecuzione di applicazioni e servizi.

Troverai il codice completo nel repository [https://github.com/henomis/nats-jail-template](https://github.com/henomis/nats-jail-template). Sentiti libero di fare un fork e sperimentare sul tuo sistema FreeBSD. Spero che questo articolo ti abbia ispirato a esplorare il mondo delle FreeBSD jails e a sperimentare con diverse applicazioni e servizi. Buon hacking!


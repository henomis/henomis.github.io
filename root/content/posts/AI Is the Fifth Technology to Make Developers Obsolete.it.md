---
date: '2026-05-24T20:02:47+02:00'
title: "L'AI è la quinta tecnologia che renderà obsoleti gli sviluppatori"
tags: ["ai", "developers", "software", "productivity"]
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
featuredImage: "/images/ai002.png"
images: ["/images/ai002.png"]
code:
  maxShownLines: -1
cover:
    image: "/images/ai002.png" # image path/url
    alt: "<alt text>" # alt text
    caption: "<text>" # display caption under cover
    relative: false # when using page bundles set this to true
    hidden: false # only hide on current single page
---

Ogni decennio, puntuale come un orologio svizzero, qualcuno annuncia che gli sviluppatori sono finiti. Il rito è sempre lo stesso: una nuova tecnologia promette di rendere superflua la figura del programmatore, qualcuno scrive un articolo trionfale, i decision maker si sentono autorizzati a sognare margini più alti.

## Quattro precedenti

### Anni '80: i linguaggi di quarta generazione

I 4GL promettevano la fine della programmazione tradizionale: il responsabile del controllo di gestione avrebbe scritto da solo i suoi report, l'analista commerciale avrebbe disegnato il suo gestionale. Per qualche tempo è andata bene, finché i sistemi sono rimasti piccoli. Poi il dato è cresciuto, i requisiti si sono fatti articolati, le performance hanno iniziato a degradare. Alla fine sono arrivati i programmatori a riscrivere tutto in linguaggi general-purpose.

### Anni '90: CASE Tools e UML

L'idea era seducente: si disegna il diagramma, la macchina genera il codice. Per quasi un decennio sembrava la strada giusta. Poi è emerso il problema strutturale: il codice generato era praticamente illeggibile, e quando dovevi correggere un bug complesso non potevi sperare di farlo ridisegnando il diagramma. Il round-trip engineering, in teoria perfetto, in pratica si rompeva al primo tentativo serio. Chi aveva investito si è ritrovato con due codebase da gestire: il modello e il codice, sempre disallineati.

### Anni 2000: i CMS

Qui c'è stato un successo vero, ma confinato. I CMS hanno effettivamente reso possibile a chiunque costruire un sito vetrina o un blog. Il problema è arrivato quando le aziende hanno preteso di estendere l'idea: e-commerce con regole di business specifiche, integrazione con il gestionale interno, scalabilità per traffico serio, sicurezza degna di questo nome. A quel punto sono arrivati i plugin che si pestavano i piedi, le vulnerabilità da gestire, gli sviluppatori chiamati a sistemare quello che doveva essere "tre clic".

### Anni 2010: low-code e no-code

Il "citizen developer" avrebbe portato lo sviluppo dentro le linee di business trascinando blocchi. In parte è successo: per prototipi, flussi interni, app di piccole dimensioni, queste piattaforme sono ottime. Poi però c'è il muro: requisiti di sicurezza che la piattaforma non copre, integrazione con sistemi legacy che richiede comunque codice, costi di licenza che esplodono quando l'utilizzo cresce, vendor lock-in che blocca le evoluzioni. Quando l'app diventa critica, di nuovo si chiama uno sviluppatore. Spesso per riscriverla altrove.

---

Quattro promesse, quattro delusioni, quattro ondate di sviluppatori richiamati a sistemare il disastro.

E ora siamo al quinto giro.

## Ma questa volta è davvero diverso

Qui voglio fermarmi, perché sarebbe disonesto liquidare l'AI come "l'ennesima moda". Non lo è.

I quattro tentativi precedenti erano astrazioni rigide: schemi predefiniti, blocchi configurabili, generatori basati su regole. Erano strumenti, non intelligenza. Vincolavano lo sviluppo a percorsi prevedibili e fuori da quei percorsi crollavano. Funzionavano nello spazio piccolo che i loro progettisti avevano immaginato, e niente di più.

L'AI generativa è un'altra cosa. È la prima tecnologia in sessant'anni di informatica capace di scrivere codice originale, ragionare su un problema in linguaggio naturale, debuggare un errore che non ha mai visto prima, intervenire in un codebase che non è stato pensato per lei. Un buon agent, oggi, fa in venti minuti cose che a uno sviluppatore esperto richiedono ore. Sta cambiando come si lavora, cosa significa essere produttivi, dove si concentra il valore. Chi non lo vede, non sta guardando.

Quindi sì, questa volta la tecnologia è di un altro ordine di grandezza. Profondamente. Ma la **conclusione** che molti ne stanno traendo ("non ci servono più gli sviluppatori") è la stessa di quarant'anni fa. Ed è qui che il copione torna identico.

## La conclusione sbagliata da una premessa giusta

Lo schema è questo. Una persona del team prodotto, magari un PM brillante o un designer curioso, apre Claude Code e in un pomeriggio mette in piedi qualcosa che funziona. Lo demo al team, lo demo al capo. Sembra magia, e in parte lo è davvero. La conclusione, però, fa un salto logico: "Vedete? Possiamo farne a meno."

Entra in scena Dunning-Kruger, fedele compagno di tutte le rivoluzioni tecnologiche. Più una tecnologia abbatte la barriera d'ingresso, più amplifica l'illusione di competenza in chi non vede ciò che sta sotto. L'AI è particolarmente insidiosa proprio perché funziona davvero: produce codice sintatticamente perfetto, spesso anche concettualmente solido. Sembra il codice di un senior. A volte lo è. A volte è una trappola travestita da senior, e la differenza, da fuori, è invisibile.

## Il problema non è mai stato scrivere il codice

Qui sta il fraintendimento che si tramanda da quarant'anni, intatto. Tutte queste tecnologie (4GL, CASE, CMS, low-code, e ora l'AI) si concentrano o si sono concentrate sulla parte facile del lavoro: scrivere il codice.

Solo che scrivere il codice, applicando Pareto, è il 20% del problema. Il vero lavoro è il restante 80%:

- Capire davvero cosa serve, non cosa il committente dice di volere.
- Modellare il dominio in modo che regga ai cambiamenti dei prossimi cinque anni.
- Pensare ai casi limite che non sono nelle specifiche perché nessuno ci ha pensato.
- Sicurezza: autenticazione, autorizzazioni, validazione degli input, threat modeling.
- Performance sotto carico reale, non quello del demo con tre utenti.
- Consistenza dei dati quando le cose vanno male (e prima o poi vanno male).
- Osservabilità, debugging, recupero da errori.
- Manutenibilità: il codice viene letto cento volte più di quanto venga scritto.
- Integrazione con sistemi che hanno regole non scritte e API documentate peggio.

Questa è la parte subdola. Non emerge nel demo. Non emerge nemmeno nei primi giorni di produzione. Emerge dopo due mesi, quando un cliente importante segnala un bug intermittente che nessuno riesce a riprodurre. O dopo un anno, quando bisogna aggiungere una funzionalità che spacca a metà il modello dati. O un sabato sera, quando il sistema si pianta perché qualcuno ha caricato un CSV con un carattere non previsto.

Lo sviluppatore esperto non è pagato per scrivere `if/else`. È pagato per aver visto cosa succede dopo l'`if/else`. È pagato per quel sopracciglio che si solleva quando legge una specifica e qualcosa non torna. È pagato per dire "fermi un attimo" prima che il treno deragli.

## L'AI moltiplica chi sa, espone chi non sa

E proprio perché l'AI è diversa dai precedenti, questa volta il fraintendimento costa di più. I tentativi precedenti fallivano in fretta: dopo qualche mese era evidente che il sistema non scalava, e si chiamava lo sviluppatore. L'AI no. L'AI ti porta molto più avanti prima che le crepe diventino visibili. Costruisci, deployi, vai in produzione, acquisisci utenti. E poi, quando emergono i problemi veri, sei dentro un sistema che nessuno ha mai realmente progettato.

Il problema non è la qualità del codice generato. È che il codice generato risponde alla domanda che hai posto. E formulare la domanda giusta (riconoscere i requisiti impliciti che nessuno ti dirà) è esattamente la competenza che si sta cercando di rimpiazzare.

Un buon sviluppatore con un buon agent è oggi enormemente più produttivo di sei mesi fa, e questo è straordinario. Ma la produttività moltiplica chi sa cosa sta facendo. A chi non sa cosa sta facendo, l'AI offre la possibilità di produrre disastri più velocemente, su scala più grande, con maggiore confidenza.

## Il finale, già scritto

Nei prossimi 12-24 mesi vedremo lo stesso epilogo di sempre, ma più caro. Aziende che si sono entusiasmate avranno in produzione applicazioni costruite "senza sviluppatori" che ora vanno mantenute, evolute, messe in sicurezza, integrate con il resto del sistema informativo. Cercheranno sviluppatori. Cercheranno gli stessi sviluppatori che avevano dichiarato obsoleti. E pagheranno molto più di quanto avrebbero pagato all'inizio per fare le cose bene.

Non perché l'AI non funzioni. Funziona, e funziona magnificamente. Ma perché il software, da sessant'anni a questa parte, non è mai stato un problema di scrivere righe di codice. È un problema di capire un dominio, prevedere i fallimenti, tenere insieme un sistema vivo nel tempo. E quelle competenze, almeno per ora, l'AI non le sostituisce. Le amplifica in chi le possiede già, e le rende dolorosamente assenti in chi non le ha.

Quindi sì, celebriamo pure il funerale degli sviluppatori. Ne abbiamo già celebrati quattro. Questo quinto è diverso dagli altri: la tecnologia è reale, potente, trasformativa. Ma finirà come gli altri, con i parenti del defunto che chiamano qualcuno per sistemare la situazione. E lui, lo sviluppatore, arriverà. Solo, questa volta, con un agent in mano.


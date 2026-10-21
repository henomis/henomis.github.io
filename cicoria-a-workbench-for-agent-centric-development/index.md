# Cicoria: un banco di lavoro per lo sviluppo agent-centric


Ormai la maggior parte del mio codice non la scrivo io. Io scrivo la specifica, gli agenti scrivono il codice, e la review è mia.

Questo cambia quello che ti serve dagli strumenti. Così ho costruito un nuovo banco di lavoro. Si chiama **cicoria**, ed esce oggi.

## Dal codice al centro agli agenti al centro

Per anni eravamo abituati a lavorare intorno al codice. Al centro c'era l'editor, e tutto il resto (il terminale, git, la review) gli stava intorno, perché il lavoro era scrivere codice nei file.

Lo sviluppo AI-first sposta il centro. L'unità di lavoro non è più un file, è una sessione di un agente. Passo il tempo a descrivere cosa voglio, a leggere cosa ha cambiato un agente, a indicare le righe sbagliate e a rimandarlo al lavoro. Il codice c'è ancora, ma lo incontro come un diff da rivedere, non come un buffer in cui scrivere.

Nella pagina della mia [dark factory](https://simonevellei.com/darkfactory/) racconto come scrivo software in questo modo: il codice lo scrivono gli agenti, io tengo la specifica e i gate. cicoria è il banco di lavoro da cui tutto questo parte.

## Più progetti insieme

C'è un secondo cambiamento, e non è meno grande. Con gli agenti lavori su più progetti insieme.

Un agente rifà un'API, un altro corregge un bug in un altro repository, un terzo scrive la documentazione di un progetto secondario. Nessuno ha bisogno di me tutto il tempo, quindi non resto su uno solo. Mi sposto tra loro: ne guido uno, rivedo il lavoro di un altro, metto in coda la prossima istruzione per un terzo.

Le tab del terminale si prestano poco a questo. Ogni tab ha lo stesso aspetto, qualunque cosa stia facendo l'agente dietro, e cosa ha cambiato ognuno resta nascosto finché non vai a guardare.

L'idea di fondo di cicoria è semplice: non sostituisce i tuoi agenti e non li avvolge in qualcosa di nuovo. Claude Code, Copilot CLI e Codex CLI girano così come sono, ognuno con la sua interfaccia in un vero terminale. cicoria è il banco intorno a loro. Ti mostra cosa sta facendo ogni sessione, cosa ha cambiato, e ti fa rimandare la tua review.

Gli agenti fanno il lavoro, e tu resti nel giro. Ogni messaggio che un agente riceve l'hai scritto o messo in coda tu.

## Nata dagli attriti

L'idea è arrivata alle 5:15 di domenica 11 ottobre. A fine mattinata era un piano che un agente potesse seguire, e un agente ha cominciato a costruirla.

Da lì cicoria è stata costruita nel modo in cui va usata: gli agenti a implementare, io a tenere la specifica e la review, nove giorni dalla prima idea a oggi. E siccome usavo agenti per costruire uno strumento per usare agenti, ogni spigolo saltava fuori subito.

Più che un changelog, la storia dei commit sembra un diario di quegli spigoli.

La primissima cosa costruita dopo il commit iniziale è stata una coda di messaggi per ogni sessione. La prossima cosa da dire a un agente arriva spesso mentre è ancora a metà del suo turno. Adesso aspetta in fila, e cicoria la manda quando il turno finisce.

A metà pomeriggio è arrivata la review. Gli agenti fanno commit da soli, quindi un semplice `git diff` è spesso vuoto proprio quando vuoi vedere cosa è successo. Per questo cicoria conta le modifiche dal commit da cui la sessione è partita. Poi serviva indicare righe precise durante la review, e sono arrivate le note sulle righe, rimandate all'agente in un solo messaggio.

Nei giorni dopo sono arrivati Copilot CLI e Codex CLI, WSL2, il branch git nel titolo, e un git worktree tutto suo per la sessione che condividerebbe la cartella con un'altra. Poi le modifiche di una sessione molto attiva hanno cominciato a confondersi tra loro, e adesso un pannello dei commit elenca cosa ha committato la sessione e ti fa guardare un commit alla volta. Le sessioni hanno anche cominciato ad accumularsi in altre finestre, e adesso il titolo del terminale nomina quelle che hanno bisogno di te.

L'ultima è nata lontano dalla scrivania. Il lavoro non si ferma quando mi alzo, e volevo continuare a guidarlo. Così adesso cicoria ha un web cockpit: dal telefono vedi le sessioni che condividi, e puoi seguirle e rispondere da lì.

Ogni funzione è una piccola risposta a un momento in cui lo strumento si metteva in mezzo.

## Cosa c'è sul banco di lavoro

Prima dell'elenco, un minuto di una sessione vera. Claude Code scrive un piccolo server HTTP in Go mentre un README aspetta in coda, una seconda sessione nel pannello diviso conta le righe di `main.go`, e una nota sul diff chiede alla prima un nuovo endpoint.

<video controls muted playsinline preload="metadata" poster="https://henomis.github.io/cicoria/demo.jpg" style="width:100%;height:auto;">
  <source src="https://henomis.github.io/cicoria/demo.mp4" type="video/mp4">
  <a href="https://henomis.github.io/cicoria/demo.mp4">Guarda la demo di cicoria</a>
</video>

Ecco cosa c'è oggi, una riga per voce. I dettagli sono nella [documentazione](https://henomis.github.io/cicoria/).

- **Tutti i progetti su un solo banco.** Una sessione è un agente in una cartella, quindi uno spazio di lavoro tiene sessioni di più progetti.
- **Vedi cosa sta facendo ogni sessione.** Se lavora, se ti aspetta, se ha finito mentre guardavi altrove, se è inattiva o è terminata, e da quanto.
- **Ci vai dritto.** Un tasto ti porta alla prossima sessione che ha bisogno di te. Te lo dicono anche una notifica sul desktop e il titolo della finestra, persino da una tab in secondo piano.
- **Il tuo agente, così com'è.** Claude Code, Copilot CLI e Codex CLI con l'integrazione completa degli hook, dati agli agenti che cicoria avvia senza toccare le tue impostazioni. Funziona anche qualunque altro agente da riga di comando, con lo stato dedotto dall'attività del terminale.
- **Rivedi cosa ha fatto, commit compresi.** Un pannello delle modifiche e diff a schermo intero, contati dal commit da cui la sessione è partita.
- **Ripercorri i suoi commit.** Un pannello dei commit elenca cosa ha committato la sessione, e restringe le modifiche a un commit alla volta.
- **Una review come per una pull request.** Le note sulle righe tornano all'agente in un solo messaggio, con file e righe citati.
- **Prepara cosa dire dopo.** Una coda per sessione, inviata quando l'agente finisce il turno. Puoi metterla in pausa, riordinarla, modificarla.
- **Chiedi a una sessione da un'altra.** Fai tu la domanda, e la risposta torna da sola alla sessione da cui l'hai fatta (Claude Code e Codex).
- **Due agenti, un repository, alberi separati.** Un git worktree per sessione, proposto quando serve.
- **Due sessioni sotto gli occhi.** Dividi il pannello.
- **Guida dal telefono.** Un tasto avvia il web cockpit e mostra un QR code. Dal telefono vedi le sessioni che condividi, cosa ha detto per ultimo ogni agente e cosa ha cambiato, e puoi rispondere, mettere in coda un messaggio o premere il tasto che una domanda aspetta.
- **Chiudi, e riprendi domani.** Sessioni, note e code vengono ricordate, e le conversazioni ripartono.

Il pannello delle sessioni è fatto così:

```
1 ● auth-refactor
2 ▲ fix-flaky-test
3 ✓ docs-pass
```

Una lavora, una ha bisogno di me, una ha finito mentre guardavo altrove. Tre progetti, un'occhiata.

## Ancora un po' amara

Il nome viene dalla cicoria che stavo cucinando mentre un agente ne scriveva le prime righe, ed è rimasto. Come l'ortaggio, è ancora un po' amara.

È giovanissima, nata da nove giorni. La sviluppo su Linux, e gira su WSL2. Ci sono i binari per macOS, ma non li ho provati di persona, quindi ogni segnalazione è preziosa. Gli agenti diversi dai tre supportati hanno uno stato dedotto e una coda da mandare a mano. A Copilot, per ora, un'altra sessione non può fare domande. Il web cockpit parla HTTP semplice, quindi su una rete di cui non ti fidi mettilo dietro una VPN o Tailscale. La roadmap ha ancora parecchie voci aperte. L'ho costruita per il mio modo di lavorare: dimmi dove non si adatta al tuo.

## Provala

```sh
curl -fsSL https://henomis.github.io/cicoria/install.sh | sh
```

Oppure `go install github.com/henomis/cicoria@latest`, se preferisci. All'avvio, nel pannello dell'agente cresce un piccolo fiore di cicoria. Ti lascio il piacere di scoprirlo.

La documentazione è sul [sito di cicoria](https://henomis.github.io/cicoria/), il codice su [GitHub](https://github.com/henomis/cicoria).

Come gli altri miei progetti, cicoria è fatta da una persona sola, a una scrivania in Italia, ed è un inizio. Se la provi, mi piacerebbe sapere quale agente vuoi dopo. Gemini CLI è il primo della roadmap: dimmi quale viene dopo, e aprimi una issue quando qualcosa si rompe.

Sul vecchio banco di lavoro al centro c'era l'editor. Su quello nuovo al centro ci sono gli agenti, e il mio lavoro è stargli dietro.


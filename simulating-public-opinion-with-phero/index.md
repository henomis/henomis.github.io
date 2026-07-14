# Simulare l'opinione pubblica con Phero


Una singola risposta di un LLM ha una forma ordinata e sicura. L'opinione pubblica no.

Quando cambia una policy, esce un prodotto o un'azienda annuncia qualcosa di impopolare, la parte interessante raramente è la prima reazione. È quello che succede dopo, quando le persone vedono le reazioni degli altri. Gli argomenti si irrigidiscono. Nascono coalizioni. Un'obiezione pratica diventa la frase che tutti ripetono. Un punto debole sparisce perché nessuno lo raccoglie.

Questa cosa è difficile da studiare con un solo prompt.

L'esempio [social simulation](https://github.com/henomis/phero/tree/main/examples/social-simulation) di Phero esplora una forma diversa: dai al sistema uno scenario iniziale, costruisci un cast di persone fittizie con opinioni in conflitto, lasciale pubblicare in parallelo per alcuni round, poi chiedi a un agente analista di leggere la trascrizione.

Non è magia predittiva. È un modo strutturato per chiedere: *se persone diverse reagissero pubblicamente a questa situazione, quali dinamiche potrebbero emergere?*

## Cosa costruiamo

L'esempio è una CLI ispirata a MiroFish, costruita interamente con [Phero](https://github.com/henomis/phero). Prende uno scenario iniziale e lo attraversa in quattro fasi:

1. Estrae fatti neutrali dal testo di partenza
2. Genera personaggi fittizi diversi, con posizioni in conflitto
3. Esegue diversi round di simulazione, con tutti gli agenti-persona che pubblicano in parallelo
4. Sintetizza un report strutturato dalla trascrizione completa

Opzionalmente, alla fine apre una sessione interattiva di Q&A con l'agente che ha prodotto il report.

Una run inizia così:

```text
multi-agent architecture example: social simulation
- llm: model=gpt-4o
- agents: 8  rounds: 5  topk: 15
- estimated LLM calls: ~43

phase 1/4: extracting world facts...
world facts extracted.

phase 2/4: generating 8 personas...
8 personas generated:
  - Maria Lopez (pragmatic, community-focused)
  - James Okafor (skeptical, data-driven, direct)

phase 3/4: running 5 simulation rounds...
  round 1/5
    [Maria Lopez] This policy is exactly what our city needs to...
    [James Okafor] The timeline is completely unrealistic. Banning...
```

Lo scenario di default è un controverso divieto comunale delle auto private a benzina nel centro città. Puoi sostituirlo con un articolo, una proposta di policy, un annuncio di prodotto o un breve paragrafo scritto direttamente da riga di comando.

## L'architettura

L'architettura è una pipeline con una parte centrale concorrente:

```text
seed text
    |
    v
KnowledgeExtractor  -> world facts
                              |
                              v
                     PersonaOrchestrator -> N persona agents
                                                      |
                                          +-----------+-----------+
                                          |   simulation rounds   |
                                          |  goroutine fan-out    |
                                          |  shared WorldFeed     |
                                          +-----------+-----------+
                                                      |
                                                      v
                                               ReportAgent
                                                      |
                                               optional REPL
```

Nella pipeline ci sono tre ruoli agentici diversi.

Il `KnowledgeExtractor` trasforma materiale arbitrario in fatti neutrali sul mondo. Il `PersonaOrchestrator` trasforma quei fatti in un cast. Ogni persona diventa poi un proprio `agent.Agent`, con memoria e system prompt dedicati. Alla fine il `ReportAgent` legge la trascrizione completa e produce l'analisi.

La simulazione in sé è Go esplicito: goroutine, `sync.WaitGroup`, un feed protetto da mutex e un timeout via context. Phero fornisce l'astrazione di agente, la memoria, l'interfaccia LLM e il loop prompt/tool. L'orchestrazione resta visibile nel codice applicativo.

## Dal testo iniziale ai fatti del mondo

Il primo passaggio è volutamente noioso, ed è proprio questo il punto.

Prima di generare opinioni, l'esempio estrae un riassunto neutrale della situazione:

```go
worldFacts, err := extractWorldFacts(ctx, llmClient, seedText)
if err != nil {
    panic(fmt.Errorf("world facts: %w", err))
}
```

L'estrattore è un normale agente Phero:

```go
knowledgeAgent, err := agent.New(
    llmClient,
    "KnowledgeExtractor",
    `You are a knowledge extraction specialist.

Read the provided source material and produce a concise, neutral
"world facts" summary covering the central situation, key entities,
main tensions, current state, and open questions.

Be factual and neutral. Do not take a stance.`,
)
```

Questo tiene il resto del sistema ancorato. Ogni persona viene generata dagli stessi fatti, non da un'interpretazione diversa dell'articolo originale. Così il disaccordo nasce dai personaggi, non da una deriva accidentale del contesto.

È anche un buon punto di debug. Se la simulazione più avanti sembra strana, guarda prima i world facts. Se i fatti sono sbagliati, tutto il resto sta reagendo al mondo sbagliato.

## Generare il cast

La seconda fase crea persone fittizie che hanno motivi per non essere d'accordo.

Lo schema della persona è intenzionalmente piccolo:

```go
type Persona struct {
    Name        string `json:"name"`
    Background  string `json:"background"`
    Stance      string `json:"stance"`
    Personality string `json:"personality"`
}
```

Il `PersonaOrchestrator` riceve i fatti del mondo e il numero richiesto di persone. Il prompt chiede esattamente quel numero di persone, con posizioni davvero distinte:

```go
prompt := fmt.Sprintf(
    "World facts:\n%s\n\nGenerate exactly %d personas with diverse and conflicting stances.",
    worldFacts, n,
)
```

All'agente viene chiesto di restituire solo JSON. L'esempio poi ripulisce eventuale testo intorno all'oggetto e fa l'unmarshal in struct Go. Non è glamour, ma è un buon design per un esempio: tieni stretto il confine dell'output LLM, validalo, e fallisci chiaramente se la forma non è quella attesa.

Ogni persona diventa poi un agente con un proprio system prompt:

```go
systemPrompt := fmt.Sprintf(`You are %s in a social simulation.

Background: %s
Your stance: %s
Personality: %s

Stay fully in character. React authentically to what others say.
Do not break character or refer to yourself as an AI.
Keep your posts concise (3-5 sentences).`,
    p.Name, p.Background, p.Stance, p.Personality,
)
```

La memoria della persona è limitata:

```go
memCapacity := uint(roundsHint*2 + 10)
a.SetMemory(simplemem.New(memCapacity))
```

Questo conta perché la persona deve ricordare i propri turni precedenti, ma la simulazione deve mantenere costi e contesto prevedibili.

## Il world feed

Lo stato condiviso dell'esempio non è un grafo sociale. È una trascrizione pubblica.

```go
type FeedEntry struct {
    Round  int
    Author string
    Post   string
}

type WorldFeed struct {
    mu      sync.Mutex
    entries []FeedEntry
}
```

Ogni post viene aggiunto al feed. Prima di ogni round, gli agenti ricevono gli ultimi `topk` elementi:

```go
snapshot := s.feed.TopK(s.topk)
```

È molto più semplice di un social network reale. Non c'è grafo dei follower, non c'è algoritmo di ranking, non ci sono quote post, non ci sono messaggi privati. Tutti vedono la stessa piazza pubblica recente.

Questa semplicità è un compromesso. Perdi realismo, ma guadagni ispezionabilità. Tutta la simulazione è una trascrizione leggibile dall'inizio alla fine, e il report agent può citare direttamente round e nomi degli agenti.

## Eseguire round concorrenti

Il cuore dell'esempio è `Simulation.RunRound`.

Per ogni round, la simulazione prende uno snapshot del feed prima di far partire gli agenti-persona:

```go
snapshot := s.feed.TopK(s.topk)
results := make([]roundResult, len(s.agents))
```

Poi esegue il fan-out verso tutti gli agenti usando goroutine:

```go
for i, pa := range s.agents {
    wg.Add(1)

    go func(idx int, pa *personaAgent) {
        defer wg.Done()

        prompt := buildRoundPrompt(round, totalRounds, snapshot)
        out, err := pa.agent.Run(ctx, llm.Text(prompt))
        if err != nil {
            results[idx] = roundResult{err: fmt.Errorf("agent %q: %w", pa.name, err)}
            return
        }

        results[idx] = roundResult{
            entry: FeedEntry{
                Round:  round,
                Author: pa.name,
                Post:   strings.TrimSpace(out.TextContent()),
            },
        }
    }(i, pa)
}

wg.Wait()
```

Il dettaglio dello snapshot è importante. Se gli agenti leggessero il feed mentre altri agenti lo stanno scrivendo, l'ordine di scheduling delle goroutine cambierebbe ciò che ogni persona vede. Invece, ogni agente nello stesso round vede lo stesso stato pre-round. I post vengono raccolti dopo, in ordine deterministico rispetto alla lista degli agenti.

Così la concorrenza migliora la latenza senza trasformare la simulazione in qualcosa che dipende dalle race del runtime.

## Trasformare la trascrizione in un report

Dopo l'ultimo round, l'intero feed diventa una trascrizione:

```go
transcript := sim.Transcript()
```

L'esempio la scrive in `transcript.txt`, poi la invia al report agent insieme ai world facts:

```go
reportPrompt := fmt.Sprintf(
    "World facts:\n%s\n\nSimulation transcript:\n%s\n\nAnalyze this simulation and produce the report.",
    worldFacts, transcript,
)
```

Il report agent ha una struttura analitica fissa:

```text
## Opinion Evolution
## Coalitions & Dynamics
## Key Inflection Points
## Final Outlook
```

Qui la trascrizione diventa utile. Al report agent non viene chiesto di riassumere sensazioni generiche. Gli viene chiesto di citare agenti, round, spostamenti, coalizioni e momenti in cui la conversazione ha cambiato direzione.

Il flag opzionale `--interact` apre una REPL con lo stesso report agent. Poiché l'agente ha memoria, le domande successive possono riferirsi al report e alla trascrizione senza incollare tutto di nuovo.

## Costi e limiti

L'esempio stampa una stima dei costi prima di iniziare:

```go
estimatedCalls := numAgents*numRounds + 3
```

Le impostazioni di default sono 8 agenti e 5 round, quindi la run fa circa 43 chiamate LLM: una per i world facts, una per le persone, 40 post delle persone e un report.

Questo significa che le manopole contano:

```bash
go run . --agents 4 --rounds 3
go run . --agents 12 --rounds 8
```

Parti piccolo. Quando prompt e scenario producono comportamenti utili, aumenta la scala.

Il README è esplicito sui compromessi rispetto a MiroFish. Questo esempio Phero non implementa GraphRAG, memoria cloud di lungo periodo, un milione di agenti o un social graph dual-platform. Usa world facts piatti, memoria in-process limitata, fan-out con goroutine e un feed condiviso.

Ed è proprio per questo che è un buon esempio. I pezzi in movimento stanno in pochi file, e l'idea architetturale resta visibile.

## Provalo

Dalla directory dell'esempio:

```bash
cd examples/social-simulation
go run .
```

Con uno scenario custom inline:

```bash
go run . --seed "A city announces a pilot program converting downtown parking spaces into bike lanes, trees, and outdoor seating."
```

Da un file:

```bash
go run . --seed ./article.txt --agents 12 --rounds 8
```

Con Q&A interattivo dopo il report:

```bash
go run . --interact
```

Il client OpenAI-compatible si configura tramite variabili d'ambiente:

```bash
export OPENAI_API_KEY="..."
export OPENAI_MODEL="gpt-4o"
export OPENAI_BASE_URL="https://api.openai.com/v1"
```

Se non imposti né chiave né base URL, l'esempio usa di default un endpoint compatibile con Ollama in locale.

La cosa interessante di questo esempio non è che preveda il futuro. Fa qualcosa di più modesto e più utile: ti dà un modo ripetibile per esplorare come il disaccordo può muoversi dentro un piccolo pubblico artificiale.

Per lanci di prodotto, bozze di policy, comunicazioni di incidente, community management o semplice curiosità, spesso basta questo per far emergere la domanda che avresti dovuto porti prima.

Se vuoi provarlo, parti da [examples/social-simulation](https://github.com/henomis/phero/tree/main/examples/social-simulation).

Se ti ha incuriosito, **[metti una stella a Phero su GitHub](https://github.com/henomis/phero)**. Aiuta davvero il progetto a crescere, e richiede tre secondi.

*Phero è open source sotto licenza Apache 2.0. Contributi, issue e discussioni sono benvenuti.*

*[GitHub](https://github.com/henomis/phero) · [pkg.go.dev](https://pkg.go.dev/github.com/henomis/phero) · [Examples](https://github.com/henomis/phero/tree/main/examples)*

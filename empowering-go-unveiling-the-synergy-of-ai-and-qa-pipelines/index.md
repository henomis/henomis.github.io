# Empowering Go: unveiling the synergy of AI and Q&A pipelines

{{< admonition type=info open=true >}}
Questo post è stato originariamente scritto in inglese e tradotto in italiano tramite AI. Se noti errori di traduzione o passaggi poco chiari, segnalamelo pure.

[🇬🇧 Leggi l'articolo originale in inglese](/en/empowering-go-unveiling-the-synergy-of-ai-and-qa-pipelines/)
{{< /admonition >}}


Nel regno dell’intelligenza artificiale e del machine learning, la ricerca efficiente di similarità è un componente critico per compiti che vanno dai sistemi di raccomandazione al riconoscimento delle immagini. In questo post, esploreremo l’implementazione della ricerca di similarità vettoriale in Go, utilizzando il framework [LinGoose](https://github.com/henomis/lingoose) per indicizzare e interrogare vettori in un database [Qdrant](https://qdrant.tech/).

## Comprendere la Ricerca di Similarità Vettoriale

La ricerca di similarità vettoriale consiste nel trovare vettori in un dataset che siano più simili a un vettore di query. Questo è fondamentale in varie applicazioni di IA in cui è necessario abbinare o classificare elementi simili. Qdrant, un database vettoriale, fornisce una soluzione robusta per tali ricerche.

## Vantaggi di Qdrant e Approfondimenti Pratici

* **Scalabilità**: Qdrant è progettato per la scalabilità, rendendolo adatto alla gestione di grandi dataset e applicazioni in tempo reale.

* **Configurabilità**: Il codice consente la personalizzazione di parametri come la dimensione dei vettori e la metrica di distanza, offrendo flessibilità per diversi casi d’uso.

* **Applicabilità Reale**: La ricerca di similarità vettoriale è essenziale in applicazioni come raccomandazioni di contenuti, similarità di immagini e elaborazione del linguaggio naturale.

## Iniziare con Qdrant

Lo snippet di codice fornito dimostra una configurazione di base di Qdrant per l’indicizzazione e l’interrogazione dei vettori. Analizziamo i componenti chiave del codice.

```go
// Importa i pacchetti necessari
import (
	"context"
	"fmt"

	"github.com/henomis/lingoose/index"
	"github.com/henomis/lingoose/index/option"
	"github.com/henomis/lingoose/index/vectordb/qdrant"
)

func main() {
	// Crea un nuovo indice vettoriale qdrant
	qdrantIndex := qdrant.New(
		qdrant.Options{
			CollectionName: "test",
			CreateCollection: &qdrant.CreateCollectionOptions{
				Dimension: 4,
				Distance:  qdrant.DistanceCosine,
			},
		},
	).WithAPIKeyAndEdpoint("", "http://localhost:6333")

	// Inserisci un vettore
	err := qdrantIndex.Insert(
		context.Background(),
		[]index.Data{
			{
				ID:     "1",
				Values: []float64{0.1, 0.2, 0.3, 0.4},
			},
			{
				ID:     "2",
				Values: []float64{0.5, 0.6, 0.7, 0.8},
			},
		})
	if err != nil {
		panic(err)
	}

	// Interroga l’indice
	similarities, err := qdrantIndex.Search(
		context.Background(),
		[]float64{0.1, 0.8, 0.2, 0.5},
		&option.Options{
			TopK: 2,
		},
	)
	if err != nil {
		panic(err)
	}

	// Stampa i risultati
	for _, similarity := range similarities {
		fmt.Printf("ID: %s, Punteggio: %f\n", similarity.ID, similarity.Score)
	}
}
```

### Analisi del Codice

* **Inizializzazione di Qdrant**: Il codice inizializza un indice vettoriale Qdrant con opzioni specificate, come il nome della collezione, la dimensione del vettore e la metrica di distanza (in questo caso, distanza coseno).

* **Inserimento dei Vettori**: I vettori con ID associati vengono inseriti nell’indice Qdrant. Questo è un passaggio cruciale per costruire il dataset da utilizzare nelle ricerche di similarità.

* **Interrogazione dell’Indice**: Viene fornito un vettore di query all’indice, e Qdrant restituisce i vettori più simili in base alla metrica di distanza specificata. L’opzione TopK determina il numero di vicini più prossimi da recuperare.

* **Visualizzazione dei Risultati**: I risultati, compresi ID e punteggi di similarità, vengono stampati per ulteriori analisi.

## Pipeline Domanda e Risposta

In questa sezione, esploreremo un’implementazione pratica dell’IA in Go, focalizzandoci sulle pipeline di Domanda-Risposta (Q&A) e sull’indicizzazione vettoriale. Questa implementazione sfrutta la potenza del linguaggio Go per integrare senza soluzione di continuità le capacità di IA nelle applicazioni. Utilizzeremo il framework [LinGoose](https://github.com/henomis/lingoose) per costruire una pipeline Q&A che utilizza Qdrant per l’indicizzazione e l’interrogazione dei vettori.

### Comprendere il Codice

Analizziamo lo snippet di codice Go fornito passo dopo passo per comprenderne la funzionalità e come sfrutta l’IA per un recupero efficiente delle informazioni.

```go
// Carica documenti PDF da una directory e dividili in blocchi di 2000 caratteri
docs, _ := loader.NewPDFToTextLoader("./kb").
	WithTextSplitter(textsplitter.NewRecursiveCharacterTextSplitter(2000, 200)).
	Load(context.Background())
```

Qui, il codice carica documenti PDF da una directory specificata ("./kb") e li divide in blocchi di 2000 caratteri. Il preprocessing dei documenti è un passaggio cruciale per preparare i dati alle applicazioni di IA, assicurando che l’input sia adeguatamente strutturato e gestibile.

```go
// Crea un nuovo indice vettoriale qdrant
qdrantIndex := index.New(
	qdrant.New(
		qdrant.Options{
			CollectionName: "test",
			CreateCollection: &qdrant.CreateCollectionOptions{
				Dimension: 1536,
				Distance:  qdrant.DistanceCosine,
			},
		},
	).WithAPIKeyAndEdpoint("", "http://localhost:6333"),
	openaiembedder.New(openaiembedder.AdaEmbeddingV2),
).WithIncludeContents(true)
```

In questo codice, viene creato un nuovo indice vettoriale utilizzando la libreria [LinGoose](https://github.com/henomis/lingoose). L’indice impiega il database vettoriale Qdrant con opzioni specificate, come nome della collezione, dimensionalità e metrica di distanza (in questo caso, distanza coseno). Inoltre, incorpora il modello OpenAI Ada Embedding per la rappresentazione testuale.

```go
// Carica i documenti nell’indice
qdrantIndex.LoadFromDocuments(context.Background(), docs)
```

I documenti caricati vengono poi indicizzati, popolando l’indice vettoriale con informazioni rilevanti. Questo passaggio è cruciale per abilitare un recupero delle informazioni rapido ed efficiente durante le query.

```go
// Crea una pipeline Q&A e interroga l’indice
qapipeline.New(openai.NewChat().WithVerbose(true)).
	WithIndex(qdrantIndex).
	Query(context.Background(), "Qual è lo scopo della NATO?", option.WithTopK(1))
```

Infine, viene creata una pipeline Q&A utilizzando il modello OpenAI Chat. La pipeline è configurata con l’indice creato, e viene eseguita una query di esempio per recuperare informazioni rilevanti sullo scopo della NATO. L’opzione WithTopK(1) limita il risultato alla risposta più pertinente.

## IA in Azione: Vantaggi e Buone Pratiche

Questo codice mostra l’integrazione senza soluzione di continuità delle capacità di IA nelle applicazioni Go, offrendo diversi vantaggi:

* **Recupero Efficiente delle Informazioni**: L’indice vettoriale consente un recupero rapido ed efficiente delle informazioni rilevanti, rendendolo adatto a grandi dataset.

* **Embedding Testuale Flessibile**: L’utilizzo del modello OpenAI Ada Embedding consente una rappresentazione testuale flessibile e contestuale, migliorando l’accuratezza dei risultati Q&A.

* **Scalabilità con Qdrant**: L’uso di Qdrant come database vettoriale garantisce scalabilità e robustezza, rendendolo adatto ad applicazioni con carichi di lavoro variabili.

* **Personalizzazione ed Esperimenti**: Gli sviluppatori possono sperimentare con diversi modelli di embedding, metriche di distanza e opzioni di indicizzazione per adattare la soluzione ai propri casi d’uso.

## Conclusione

Integrare l’IA nelle applicazioni Go apre un mondo di possibilità per gli sviluppatori che vogliono arricchire il loro software con capacità avanzate di elaborazione del linguaggio naturale. Lo snippet di codice fornito funge da punto di partenza, e gli sviluppatori sono incoraggiati a sperimentare, personalizzare ed esplorare ulteriormente per sbloccare tutto il potenziale dell’IA nei loro progetti. Che tu stia costruendo una knowledge base, un chatbot o un sistema di recupero informazioni, combinare la potenza di Go e dell’IA può portare a soluzioni potenti ed efficienti. Abbiamo utilizzato il framework Go [LinGoose](https://github.com/henomis/lingoose), che ho personalmente sviluppato, per fornire un modo semplice ed efficiente di integrare l’IA nei tuoi progetti Go.


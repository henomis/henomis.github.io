# Linear Regression in Go

L'analisi dei **big data** e il parallelo sviluppo dell'**intelligenza artificiale** sono i protagonisti delle innovazioni tecnologiche di quest'ultimo decennio. Chi approccia lo studio della materia, tuttavia, avrà prima o poi a che fare con il linguaggio **Python** che, usato spesso in ambito accademico, rappresenta il punto riferimento grazie alla disponibilità di una serie di librerie, tool e veri e propri framework per la manipolazione dei dati.

Sebbene, in molti casi, l'uso di tali strumenti è inserito all'interno di procedure **batch** o **offline** , non possiamo escludere che alcuni servizi cloud possano necessitare di processi avanzati per la manipolazione dati **on demand**. In questo caso uno dei linguaggi più usati in ambito **backend** Cloud è **Go**.

Compito di questo articolo è la verifica e la validazione di strumenti e librerie **Go** in grado di essere al passo con i più famosi disponibili per **Python**. Come dataset di riferimento ho scelto la lista dei film americani con il relativo budget per la produzione e incasso totale ai botteghini.

## Data gathering
Il primo passo che andremo a considerare è la raccolta di dati. Recuperare un **dataset** in rete è abbastanza semplice, può essere scaricato attraverso una semplice GET http, o ad esempio recuperato grazie ad apposite API di fornitori terzi. I nostri dati, una volta in nostro possesso, dovranno essere inseriti all'interno di un contenitore chiamato **dataframe**. Nel mondo **Python** la libreria di riferimento è [Pandas](https://pandas.pydata.org), nel nostro caso useremo invece **[Gota](https://github.com/go-gota/gota)**.

### pkg/dataminer
Ho sviluppato un package apposito per lo step di **data gathering** usando le funzionalità di `gota/dataframe`. Il metodo che verrà esposto è  `GatherFromFile()`che si occuperà di creare un dataframe a partire da un file CSV usando esclusivamente le colonne di interesse per la manipolazione dati.

```go
func (dm *DataMiner) GatherFromFile(
	filename string,
) (*plottabledataframe.PlottableDataFrame, error) {

	csvFile, err := os.Open(filename)
	if err != nil {
		return nil, err
	}

	dataFrame := dataframe.ReadCSV(csvFile).Select(
		[]string{dm.xDataName, dm.yDataName},
	)

	return plottabledataframe.NewDataFramePlottable(
		dataFrame,
		dm.xDataName,
		dm.yDataName,
	), nil

}
```

Il dato restituito sarà un wrapper al dataframe che ne estenderà le funzionalità per poter essere poi passato al plotter.

## Data cleaning
Il dato grezzo importato non sempre è pronto per l'analisi dei dati. Potrebbe,infatti, presentare **valori non ammessi**, includere **transienti da filtrare** o avere, semplicemente, un **formato non corretto**. Per questa fase sarà ancora utile il dataframe di `gota`.

### pkg/datacleaner
In questo package è presente l'implementazione del metodo `Clean()` che provvederà ad applicare 3 filtri:

* Un filtro che **rimuove caratteri di valuta e formattazione**. Questo step agisce attraverso il metodo `Capply()`che prende in input una funzione filtro da applicare iterativamente a tutte le colonne del dataframe. Internamente alla serie viene, poi, usato il metodo `Map()` che accetta un'ulteriore funzione che elabora iterativamente tutti gli elementi.
* Un filtro che **converte il tipo di dato**. Il metodo `Mutate()` provvede a sostituire entrambe le serie del dataframe applicando la conversione di tipo da `string` a `float64`.
* Un filtro per **rimuovere valori indesiderati**. In questo caso la funzione filtro rimuove i film che hanno avuto un incasso nullo perché, ad esempio, non sono mai usciti nelle sale cinematografiche.

```go
func (dc *DataCleaner) Clean() {

	// remove $ symbol and useless ','
	dc.dataFrame.DataFrame = dc.dataFrame.DataFrame.Capply(func(s series.Series) series.Series {
		return s.Map(
			func(e series.Element) series.Element {
				elementAsString := strings.ReplaceAll(e.String(), "$", "")
				elementAsString = strings.ReplaceAll(elementAsString, ",", "")
				e.Set(elementAsString)

				return e
			},
		)
	})

	// mutate series to float64 type
	dc.dataFrame.DataFrame = dc.dataFrame.DataFrame.Mutate(
		series.New(
			dc.dataFrame.DataFrame.Col(dc.dataFrame.XColumnName).Float(),
			series.Float,
			dc.dataFrame.XColumnName,
		),
	)

	dc.dataFrame.DataFrame = dc.dataFrame.DataFrame.Mutate(
		series.New(
			dc.dataFrame.DataFrame.Col(dc.dataFrame.YColumnName).Float(),
			series.Float,
			dc.dataFrame.YColumnName,
		),
	)

	// remove movies without worldwide gross (value = $0)
	dc.dataFrame.DataFrame = dc.dataFrame.DataFrame.Filter(
		dataframe.F{
			Colname:    dc.dataFrame.YColumnName,
			Comparator: series.Greater,
			Comparando: 0,
		},
	)

}
```

## Data training
I dati sono ora pronti per il **training**. In questo caso sceglieremo una **regressione lineare** per poter graficare una funzione di interpolazione. Ancora una volta sostituiremo il tool [NumPy](https://numpy.org/) di Python con **[Gonum](https://www.gonum.org/)** libreria del linguaggio Go.

### pkg/datatrainer
Questo package espone un metodo `LinearRegression` che lavorando sulle serie di dati dei passaggi precedenti restituisce due variabili `alpha` e `beta` coefficienti della funzione lineare di interpolazione.

```go
func (dt *DataTrainer) LinearRegression() (alpha, beta float64) {
	alpha, beta = stat.LinearRegression(
		dt.xData,
		dt.yData,
		nil,
		false,
	)

	return
}
```

## Data plotting
I dati elaborati possono essere infine graficati per esaminarne il risultato. In Python uno dei principali tool per graficare i dati è [Matplotlib](https://matplotlib.org), per il nostro esempio in Go, invece, useremo sempre **[Gonum](https://www.gonum.org/)** che include delle funzionalità per la generazione di grafici.

### pkg/dataplotter
Il nostro intento è quello di salvare il grafico all'interno di una immagine PNG. Grazie al metodo esposto `PlotToFile()` viene impostato un grafico con uno **scatter** in rosso dei dati grezzi e la funzione di **regressione lineare** in blu.

```go
func (dp *DataPlotter) PlotToFile(filename string) error {

	line := plotter.NewFunction(
		func(x float64) float64 {
			return dp.beta*x + dp.alpha
		},
	)
	line.Color = color.RGBA{R: 0, G: 0, B: 255, A: 255}

	scatter, err := plotter.NewScatter(dp.dataFrame)
	if err != nil {
		return err
	}
	scatter.Color = color.RGBA{R: 255, G: 0, B: 0, A: 255}

	dp.plot.Add(scatter, line)

	if err := dp.plot.Save(8*vg.Inch, 4*vg.Inch, filename); err != nil {
		return err
	}

	return nil
}
```

## Mettiamo tutto insieme
Nella visualizzazione complessiva del file `main.go` è possibile vedere come il processo attraversi in maniera chiara ed ordinata le fasi di 
* **Gathering**
* **Cleaning**
* **Training**
* **Plotting**

```go
func main() {

	// GATHER DATA
	dataminer := dataminer.New(
		"production_budget_usd",
		"worldwide_gross_usd",
	)

	dataFrame, err := dataminer.GatherFromFile(
		"cost_revenue_dirty.csv",
	)
	if err != nil {
		log.Fatal("unable to gather data: ", err)
	}

	// CLEAN DATA
	dataCleaner := datacleaner.New(dataFrame)
	dataCleaner.Clean()

	dataFrame.Dump()

	// TRAIN DATA
	dataTrainer := datatrainer.New(
		dataFrame.X(),
		dataFrame.Y(),
	)

	alpha, beta := dataTrainer.LinearRegression()
	fmt.Println("alpha =", alpha, " beta =", beta)

	// PLOT DATA
	dataPlotter := dataplotter.New(
		dataFrame,
		alpha,
		beta,
	)
	dataPlotter.SetTitles(
		"Movies production budget and gross",
		"Production budget",
		"Worldwide gross",
	)

	err = dataPlotter.PlotToFile("output.png")
	if err != nil {
		log.Fatal("unable to plot data: ", err)
	}

	fmt.Println("plot saved successfully")

}
```

L'esempio può essere eseguito in maniera interpretata "alla python" col comando

`go run ./cmd/`

oppure compilato col comando

`go build -o linear_regression ./cmd/`

## Grafico finale

![output graphic data](/blog/images/linear-regression01.png)

## Conclusioni
Abbiamo dimostrato che, almeno per questo primo esempio di regressione lineare, anche in **Go** esistono gli strumenti adatti per la manipolazione dei dati, per l'elaborazione di funzioni di interpolazione e per la generazione di grafici. Tali strumenti ci permettono di implementare all'interno di servizi Cloud backend realizzati in linguaggio Go un vero e proprio sistema completo per la gestione dei dati **on demand**.

Il codice completo dell'esempio mostrato è disponibile all'interno del repository Github [github.com/henomis/linear-regression.go](https://github.com/henomis/linear-regression-go)


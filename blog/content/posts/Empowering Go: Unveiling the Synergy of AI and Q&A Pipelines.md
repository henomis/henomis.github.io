---
title: "Empowering Go: unveiling the synergy of AI and Q&A pipelines"
date: 2023-11-16T08:24:42+01:00
tags: ["lingoose", "ai", "openai", "rag", "llm", "qdrant"]
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
    image: "/blog/images/lingoose002.png" # image path/url
    alt: "<alt text>" # alt text
    caption: "<text>" # display caption under cover
    relative: false # when using page bundles set this to true
    hidden: false # only hide on current single page
---
In the realm of artificial intelligence and machine learning, efficient similarity search is a critical component for tasks ranging from recommendation systems to image recognition. In this blog post, we'll explore the implementation of vector similarity search in Go, utilizing [LinGoose](https://github.com/henomis/lingoose) framework for indexing and querying vectors in a [Qdrant](https://qdrant.tech/) database.

## Understanding Vector Similarity Search

Vector similarity search involves finding vectors in a dataset that are most similar to a query vector. This is fundamental in various AI applications where matching or ranking similar items is required. Qdrant, a vector database, provides a robust solution for such searches.

## Advantages of Qdrant and Practical Insights
- **Scalability**: Qdrant is designed for scalability, making it suitable for handling large datasets and real-time applications.

- **Configurability**: The code allows customization of parameters such as vector dimension and distance metric, providing flexibility for different use cases.

- **Real-world Applicability**: Vector similarity search is essential in applications like content recommendation, image similarity, and natural language processing.

## Getting Started with Qdrant
The code snippet provided demonstrates a basic setup of Qdrant for vector indexing and querying. Let's break down the key components of the code.

```go
// Import necessary packages
import (
	"context"
	"fmt"

	"github.com/henomis/lingoose/index"
	"github.com/henomis/lingoose/index/option"
	"github.com/henomis/lingoose/index/vectordb/qdrant"
)

func main() {
	// Create a new qdrant vector index
	qdrantIndex := qdrant.New(
		qdrant.Options{
			CollectionName: "test",
			CreateCollection: &qdrant.CreateCollectionOptions{
				Dimension: 4,
				Distance:  qdrant.DistanceCosine,
			},
		},
	).WithAPIKeyAndEdpoint("", "http://localhost:6333")

	// Insert a vector
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

	// Query the index
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

	// Print the results
	for _, similarity := range similarities {
		fmt.Printf("ID: %s, Score: %f\n", similarity.ID, similarity.Score)
	}
}
```

### Breaking Down the Code
- **Qdrant Initialization**: The code initializes a Qdrant vector index with specified options, such as the collection name, vector dimension, and distance metric (in this case, cosine distance).

- **Vector Insertion**: Vectors with associated IDs are inserted into the Qdrant index. This is a crucial step in building the dataset for similarity searches.

- **Querying the Index**: A query vector is provided to the index, and Qdrant returns the most similar vectors based on the specified distance metric. The TopK option determines the number of nearest neighbors to retrieve.

- **Results Display**: The results, including IDs and similarity scores, are printed for further analysis.

## Question and Answer pipeline

In this section, we'll explore a practical implementation of AI in Go, focusing on Question-Answer (Q&A) pipelines and vector indexing. This implementation leverages the power of the Go programming language to seamlessly integrate AI capabilities into your applications. We'll use [LinGoose](https://github.com/henomis/lingoose) framework to build a Q&A pipeline that utilizes Qdrant for vector indexing and querying.

### Understanding the Code
Let's dissect the provided Go code snippet step by step to understand its functionality and how it harnesses AI for efficient information retrieval.

```go
// Load PDF documents from a directory and split them into chunks of 2000 characters
docs, _ := loader.NewPDFToTextLoader("./kb").
	WithTextSplitter(textsplitter.NewRecursiveCharacterTextSplitter(2000, 200)).
	Load(context.Background())
```

Here, the code loads PDF documents from a specified directory ("./kb") and splits them into chunks of 2000 characters. Document preprocessing is a crucial step in preparing data for AI applications, ensuring that the input is appropriately structured and manageable.

```go
// Create a new qdrant vector index
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

In this code, a new vector index is created using the [LinGoose](https://github.com/henomis/lingoose) library. The index employs the Qdrant vector database with specified options, such as collection name, dimensionality, and distance metric (cosine distance in this case). Additionally, it incorporates the OpenAI Ada Embedding model for text representation.


```go
// Load the documents into the index
qdrantIndex.LoadFromDocuments(context.Background(), docs)
```

The loaded documents are then indexed, populating the vector index with relevant information. This step is crucial for enabling efficient and fast retrieval of information during queries.

```go
// Create a Q&A pipeline and query the index
qapipeline.New(openai.NewChat().WithVerbose(true)).
	WithIndex(qdrantIndex).
	Query(context.Background(), "What is the NATO purpose?", option.WithTopK(1))
```

Finally, a Q&A pipeline is established using the OpenAI Chat model. The pipeline is configured with the created index, and a sample query is issued to retrieve relevant information about the NATO purpose. The WithTopK(1) option limits the result to the topmost relevant answer.

## AI in Action: Advantages and Best Practices
This code showcases the seamless integration of AI capabilities into Go applications, providing several advantages:

- **Efficient Information Retrieval**: The vector index allows for fast and efficient retrieval of relevant information, making it suitable for large datasets.

- **Flexible Text Embedding**: The use of OpenAI's Ada Embedding model enables flexible and context-aware text representation, improving the accuracy of Q&A results.

- **Scalability with Qdrant**: Leveraging Qdrant as the vector database ensures scalability and robustness, making it suitable for applications with varying workloads.

- **Customization and Experimentation**: Developers can experiment with different embedding models, distance metrics, and indexing options to tailor the solution to their specific use cases.

## Conclusion
Integrating AI into Go applications opens up a realm of possibilities for developers seeking to enhance their software with advanced natural language processing capabilities. The provided code snippet serves as a starting point, and developers are encouraged to experiment, customize, and explore further to unlock the full potential of AI in their projects. Whether you're building a knowledge base, chatbot, or information retrieval system, combining the strengths of Go and AI can lead to powerful and efficient solutions. We used the [LinGoose](https://github.com/henomis/lingoose) Go framework that I personally developed to provide a simple and efficient way to integrate AI into your Go projects.


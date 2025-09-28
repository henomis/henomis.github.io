---
title: "Leveraging Go and Redis for Efficient Retrieval Augmented Generation"
date: 2023-11-05T17:06:47+01:00
tags: ["lingoose", "ai", "openai", "rag", "llm"]
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
featuredImage: "/images/lingoose001.png"
cover:
    image: "/images/lingoose001.png" # image path/url
    alt: "<alt text>" # alt text
    caption: "<text>" # display caption under cover
    relative: false # when using page bundles set this to true
    hidden: false # only hide on current single page
---
## Introduction

Artificial Intelligence has transformed the way we handle data, and one crucial aspect of AI is similarity search. Whether it's for image recognition, recommendation systems, or natural language processing, finding similar data points quickly and accurately is a common challenge. In this blog post, we will explore a Go code snippet that showcases how to perform efficient vector similarity search using Redis and the [Lingoose](https://github.com/henomis/lingoose) Go framework, catering to tech-savvy readers interested in both Go programming and AI.

## Vector Similarity Search

Vector similarity search is a fundamental AI concept that involves finding items similar to a query vector in a large dataset. It is widely used in recommendation systems (e.g., suggesting products or content similar to what a user likes), image and document retrieval, and more. The code snippet we'll examine demonstrates how to set up a Redis-based vector index and efficiently search for similar vectors.

## Advantages of Redis for Vector Search

Redis, an in-memory key-value store, is a powerful choice for vector similarity search due to its low-latency performance and ability to handle real-time queries. It allows us to store vectors efficiently and perform searches in milliseconds. Redis also offers data persistence and clustering capabilities, making it suitable for large-scale applications.

## Implementing Vector Similarity Search in Go

In our code snippet, we use the [Lingoose](https://github.com/henomis/lingoose) Go framework to create a Redis vector index and perform vector similarity search. 

```go
package main

import (
	"context"
	"fmt"

	"github.com/RediSearch/redisearch-go/v2/redisearch"
	"github.com/henomis/lingoose/index"
	"github.com/henomis/lingoose/index/option"
	"github.com/henomis/lingoose/index/vectordb/redis"
)

func main() {

	// Create a new redis vector index
	redisIndex := redis.New(
		redis.Options{
			RedisearchClient: redisearch.NewClient("localhost:6379", "test"),
			CreateIndex: &redis.CreateIndexOptions{
				Dimension: 4,
				Distance:  redis.DistanceCosine,
			},
		},
	)

	// Insert a vector
	err := redisIndex.Insert(
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
	similarities, err := redisIndex.Search(
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

Here's a breakdown of the code:

1. **Importing Libraries:** We import the necessary Go libraries, including Redisearch and [Lingoose](https://github.com/henomis/lingoose), to build our vector index.

2. **Creating the Redis Vector Index:** We create a new Redis vector index using the [Lingoose](https://github.com/henomis/lingoose) library, specifying options such as the Redis server location, the index name, vector dimension, and the distance metric (cosine similarity in this case).

3. **Inserting Vectors:** We insert two vectors into the index, each with an ID and a set of float values. This simulates the process of adding data points to the index.

4. **Querying the Index:** We perform a vector search by providing a query vector and specifying options such as the number of similar vectors to retrieve (TopK).

5. **Printing the Results:** We print the IDs and similarity scores of the most similar vectors found in the search.

## Retrieval Augmented Generation with Golang and Redis

The above code snippet serves as a starting point for implementing vector similarity search in your Go-based AI projects. You can extend this functionality to create recommendation engines, content-based image retrieval systems, or personalized content filtering. In the next example, we'll use the [Lingoose](https://github.com/henomis/lingoose) Go framework to build a **retrieval augmented generation (RAG)** system that uses Redis to store and search for similar vectors.

### Loading PDF Documents
```go
docs, _ := loader.NewPDFToTextLoader("./kb").
    WithTextSplitter(textsplitter.NewRecursiveCharacterTextSplitter(2000, 200)).
    Load(context.Background())
```

The code begins by loading PDF documents from a directory and splitting their text into smaller chunks of 2000 characters. This is a crucial step because it prepares the documents for indexing and querying. The [Lingoose](https://github.com/henomis/lingoose) `loader`, `textsplitter` packages are used here to facilitate this process.

### Creating a Redis Vector Index
```go
// Create a new Redis vector index
redisIndex := index.New(
    redis.New(
        redis.Options{
            RedisearchClient: redisearch.NewClient("localhost:6379", "test"),
            CreateIndex: &redis.CreateIndexOptions{
                Dimension: 1536,
                Distance:  redis.DistanceCosine,
            },
        },
    ),
    openaiembedder.New(openaiembedder.AdaEmbeddingV2),
).WithIncludeContents(true)
```

Next, we create a Redis vector index. We've specified parameters such as the dimension (1536) and the distance metric (Cosine) in order to be compliant with our AI LLM engine. The [Lingoose](https://github.com/henomis/lingoose) `openaiembedder` package is employed to embed text into vectors, which is essential for AI-based searching. We also set `WithIncludeContents` to true to include the document contents in the index.

### Loading Documents into the Index
```go
redisIndex.LoadFromDocuments(context.Background(), docs)
```

Here, we load the documents we previously prepared into the Redis index. This step is where the AI embedding of document content happens, allowing us to perform vector-based searches later.

### Querying the Index with Q&A
```go
qapipeline.New(openai.NewChat().WithVerbose(true)).
    WithIndex(redisIndex).
    Query(context.Background(), "What is the NATO purpose?", option.WithTopK(1))
```

The final part of the code demonstrates how to use a Q&A pipeline to query the index. We create a Q&A pipeline using OpenAI LLM, and with the help of the `WithInde` method, we associate it with our Redis index. We then ask a question, "What is the NATO purpose?," and specify that we want the top 1 answer (`WithTopK(1)`).


## The AI-Powered Search Engine in Action
So, what does this code snippet achieve? It creates an AI-powered search engine capable of answering questions based on the content of PDF documents. When you pose a question, the search engine scans the indexed documents, computes vector-based similarity, and returns the most relevant answer. This approach is highly versatile and can be used in various real-world scenarios, such as:

- **Document Search**: Build a document search engine that helps users find specific information within a large repository of documents.

- **Chatbots and Virtual Assistants**: Enhance chatbots and virtual assistants by enabling them to answer user questions with accuracy, drawing information from knowledge bases.

- **E-Learning Platforms**: Create intelligent e-learning platforms that can provide instant answers to students' queries from course materials.

- **Customer Support**: Improve customer support systems by automating responses to common questions, providing faster and more accurate support.


## Conclusion
In this blog post, we've explored a Go code that demonstrates the power of combining AI, Redis, and OpenAI to create an intelligent search engine. By embedding document content into vectors and using AI models for querying, you can build a versatile and accurate search engine for a wide range of applications. We used the [Lingoose](https://github.com/henomis/lingoose) Go framework that I personally developed to provide a simple and efficient way to integrate AI into your Go projects.
Experiment with the code and adapt it to your specific needs to unlock the full potential of AI-powered search. AI is constantly evolving, and its applications are limitless, making it an exciting field for tech-savvy Go programmers. Happy coding!
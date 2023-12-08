# About MobileLLM

A locally running Large Language Model (LLM) combined with a vector database designed to assist developers in adding ChatGPT features secure and for free.

This project provides an LLM tool that runs locally, augmenting your application with the capability to understand and use language effectively, driven by deep learning technology.

## Why use MobileLLM

- It runs locally and offline
- It is free
- User data stays within their control
- Augment the knowledge of an LLM with your app's data

## Early prototype

We currently support the [RWKV model](https://github.com/BlinkDL/RWKV-LM) that can run using less than 2GB of RAM. In the roadmap, we plan to incorporate more potent models such as Llama2 and Mistral to provide an even more robust solution.

Furthermore, the following updates will also include smoother integrations. We aim to provide an easier way to connect CoreData and SwiftData with the vector database, thus bridging the gap between your data entities and knowledge enhancement functionalities.

## Demo App

You can try the [demo chat](https://github.com/windwithbirds/MobileLLM-Demo/). The following recording shows how it works:



## Usage

1. Download the model from Huggingface
2. Select the model from the file system
3. Load the model in Memory
4. Send a prompt

```swift
do {
    try model.load(model: "path/to/model", parameters: .default, type: .rwkv)
    let result = try await model.ask(question: "Tell me about the meaning of life")
    print(result)
} catch {
    print(error.localizedDescription)
}
```

## Retrieval-Augmented Generation (RAG)

For more information on what an RAG is, check the [video](https://www.youtube.com/watch?v=T-D1OfcDW1M).

1. Add a string to the vector database
2. Send a prompt specifying the similarity score
3. The LLM will respond based on the local knowledge

```swift
do {
    try model.load(model: url, parameters: .default, type: .rwkv)
    try model.add(document: "The dog is named Max")
    let result = try await model.ask(question: "How is the dog named?", similarityThreshold: 0.5)
    print(result)
} catch {
    print(error.localizedDescription)
}
```

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/windwithbirds/mobilellm.git", .branch("main"))
]
```

## License

MobileLLM is available under the MIT license. See the LICENSE.md file for more info.

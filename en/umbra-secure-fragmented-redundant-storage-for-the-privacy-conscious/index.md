# UMBRA - Secure, fragmented, redundant storage for the privacy conscious


Over the winter holidays, I built Umbra — a command-line tool that takes a different approach to storing sensitive files. The core idea? Use anonymous paste services — the kind typically used for sharing code snippets or logs — as a distributed storage backend for encrypted file fragments.

## The Core Idea

Services like termbin, clbin, and paste.c-net.org are designed for quickly sharing text snippets anonymously — no accounts, no tracking, just paste and get a URL. But what if you could use these ephemeral, anonymous paste bins as a storage layer for sensitive files?

That's exactly what Umbra does. It breaks files into chunks, encrypts each piece, and distributes them across multiple anonymous paste services. These services don't know who you are, what you're storing, or how the pieces fit together. No single service has complete access to your data, and even if one goes down or loses data, redundant copies on other services keep your file recoverable.

In Umbra's terminology, these paste services are called **providers** — a pluggable abstraction that allows treating different services uniformly.

## How It Works

When you upload a file with Umbra, several things happen automatically:

First, the file gets divided into configurable chunks — you can specify either the number of chunks or their exact size. Each chunk is then encrypted using XChaCha20-Poly1305, a modern authenticated encryption algorithm that ensures both confidentiality and integrity. The encryption key is derived from your password using Argon2id, which makes brute-force attacks computationally expensive.

Next, these encrypted chunks are distributed across multiple anonymous paste services. Umbra includes built-in support for termbin, clbin, pipfi, paste.c-net.org, and others — all services that require no authentication and leave no trace of who uploaded the data. You can configure how many redundant copies of each chunk should exist, providing resilience against provider failures or data expiration.

All the information needed to reconstruct your file — chunk locations, hashes, cryptographic parameters — is stored in a manifest file. This manifest is itself encrypted, creating a zero-knowledge architecture where no single party has all the pieces.

## Ghost Modes: Hiding in Plain Sight

One of the more interesting features is "ghost mode," which provides plausible deniability for storing manifests. Instead of keeping the manifest as a binary file, you can hide it inside an ordinary-looking image using steganography, or encode it as a QR code. This makes the manifest indistinguishable from everyday images, adding an extra layer of obscurity.

## Trust No One

The beauty of using anonymous paste services is that they're already designed for privacy. No accounts, no authentication, no logs tying uploads to identities. Layer encrypted file fragments on top of that, and you have a genuinely anonymous storage system.

The security model is straightforward: trust nothing except your password. The paste services only see encrypted blobs with no context about what they contain or how they relate to other chunks. Without your password, the manifest reveals nothing about the file structure, content, or storage locations. The services don't know who you are, and even if they could decrypt the data (which they can't), they'd only have meaningless fragments.

The tool employs SHA-256 hashing throughout to verify data integrity. During download, Umbra checks every chunk and the final reassembled file against their expected hashes. If anything doesn't match — whether due to corruption, tampering, or provider issues — the operation aborts immediately rather than silently delivering corrupted data.

## Practical Usage

The command-line interface keeps things simple. Uploading a file requires just a password, the source file, and a manifest location. You can optionally specify how many chunks to create, how many copies to maintain, and which providers to use.

For even more flexibility, manifests don't have to be stored locally. You can upload them directly to a provider, effectively making the entire storage solution remote. The tool provides you with a reference string that you'll need later for retrieval.

Downloading reverses the process: provide the manifest (or the provider reference), enter your password, and Umbra fetches chunks from the distributed storage, verifies their integrity, and reassembles your original file.

## Design Philosophy

Throughout development, I focused on failing safely rather than quietly. If data integrity checks fail, the tool stops immediately. If a provider is unreachable, it tries redundant copies. The goal was to build something that either succeeds completely or tells you exactly why it couldn't.

The architecture is intentionally modular. Adding new paste service providers is straightforward thanks to a simple provider interface. The separation between cryptographic operations, content handling, and provider interactions makes the codebase maintainable and testable.

## Experimental Territory

It's important to note that Umbra is experimental software. While it uses well-established cryptographic primitives, the implementation hasn't been audited by security professionals. The paste services are free, public utilities with no guarantees about data persistence — many expire content after a certain period. This is a weekend project exploring an unconventional idea, not a production-ready backup solution.

That said, it's been an interesting exploration of distributed storage, modern cryptography, and the tradeoffs involved in building secure systems. The project demonstrates that with relatively simple tools and techniques, you can create meaningful layers of security and redundancy.

## Final Thoughts

Umbra represents an experiment in repurposing existing infrastructure for unintended use cases. Anonymous paste services were never designed as file storage backends, but with the right cryptographic layer, they work surprisingly well. By removing dependence on any single provider and ensuring end-to-end encryption, it gives users a genuinely anonymous way to store sensitive files across the public internet.

Whether you actually need this level of paranoia is debatable, but building it was a fascinating exploration of how simple, existing services can be combined in unexpected ways. The code is open source and available on GitHub. If you're curious about distributed storage, cryptography, or creative uses of paste bins, feel free to check it out.

👉 [GitHub Repository](https://github.com/henomis.com/umbra)

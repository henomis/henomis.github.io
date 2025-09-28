# NATS as broker for my home server

One of my childhood memories is tied to my aunt’s habit of making pizza dough. It was her favorite way to relax. This might seem normal, except that she was a baker by profession. How ironic, isn’t it? The very job that could be a source of stress became her way to unwind. The funny thing is, after becoming a software developer, I found myself in the exact same situation. I love to code, but sometimes I need to do it to relax. And that's exactly what happened when I started to develop my home server.

This article, however, is not strictly about my home server. It’s more about the architecture I chose to implement it, specifically using NATS as a message broker. I will explain why I made this choice and how it has benefited my project.

# The home server
**TLDR;** A mini-pc equipped with a N100 CPU, 16GB of RAM, and a 512GB SSD, running Debian. All the services are containerized using `Docker`, and the entire system is managed with a single docker-compose file. That's only the first approach, as I have different plans for the future. Currently, the server runs a few services, including AdGuard, Nextcloud, and Traefik. But the most interesting part is the custom services I developed myself using Go and NATS.

# The first service: a pollens monitoring system
Did you know that I have allergies? Yes, I do. And I hate them. Every spring, when the pollen count rises, I suffer from sneezing, itchy eyes, and a runny nose. It’s not fun at all. Luckily, it's not so severe, but it’s still annoying. Last year, I found a way to handle it avoiding drugs relying on natural remedies, mostly based on blackcurrant. But to do that effectively, I needed to know the pollen levels in my area with some day's notice. So, I decided to build a pollen monitoring system using data from the [ARPAM Marche](https://pollini.arpa.marche.it/) website, which provides pseudo-real-time pollen data for my region.

## Pollenium
The official website’s user interface is clunky and slow, but fortunately, it exposes a public API. I leveraged this API by writing a lightweight Go program that fetches daily pollen data for my area. The program handles its own scheduling internally, ensuring the data is updated automatically each day and stored in a local SQLite database. On top of this, I developed a simple web interface that presents the latest readings and visualizes historical trends with interactive graphs, making it easy to track pollen levels over time.

![zoom:Pollen monitoring](/images/pollenium01.png)

That's what I called **Pollenium**.

## Pollen alerts
Did I mention that I need to be notified when pollen levels are high? Pollenium is great, but if the pollen count spikes, I want to receive an immediate alert. However, I didn’t want to implement this feature directly in Pollenium. I preferred to keep it simple and focused on its core functionality. So, I decided to create a separate architecture to handle notifications. This is where NATS comes into play.

# Why NATS?
NATS is a high-performance messaging system that is lightweight and easy to deploy. It supports various messaging patterns, including publish/subscribe, request/reply, and queuing. Here are some reasons why I chose NATS for my home server:
- **Simplicity**: NATS has a simple API and is easy to set up. This was crucial for me as I wanted to focus on developing my home server without getting bogged down in complex configurations.
- **Performance**: NATS is designed for high throughput and low latency.
- **Language Support**: NATS has client libraries for many programming languages, including Go, which I used for my home server.

# Notification service

The easiest way to receive a notification is through a Telegram bot. The new service I implemented listens for messages on specific subjects and sends a message to my Telegram bot chat. The service is highly configurable and you can specify different subjects to listen to, as well as the message format and chat IDs to send the notifications to. I called this service **Telenats**. Notifications are NATS JetStream messages, so they are persistent and can be replayed if needed.

![zoom:Pollen monitoring](/images/pollenium02.png)

# User interfaces

The system was working fine, but I wanted to let NATS handle more than just notifications. Then I had a couple of crazy ideas: 
* why not use NATS to listen for keystrokes?
* why not use NATS to dispatch messages for a text-to-speech service?

I bought an USB numeric keypad and an USB speaker as input/output devices for my home server.

## Listen for keystrokes
I implemented a simple Go program that listens for keystrokes. Every keystroke is captured and published to a related NATS subject. This way, I can send "_commands_" to any service listening to that subject. Simple, right? I called this service **Typocast**. I just passed the `/dev/input/eventX` device as a parameter to the container, and it works like a charm.

## Text-to-speech
The text-to-speech feature is a little bit more complex. I needed a couple of things:
* a service that converts text to speech
* a service that listens for tts messages and plays the audio after conversion

For the text-to-speech conversion, I used [Piper](https://github.com/OHF-Voice/piper1-gpl) it has voices in different languages, including Italian. It comes with a simple http server that accepts text and returns an audio file. The second service, which I called **Voicecast**, listens for tts messages on a specific NATS subject. When it receives a message, it sends the text to the Piper server, gets the audio file, and plays it using the classic `ALSA` interface.

# Putting it all together
Now that I had all the components, I needed to connect them. Here’s how currently works:
1. Pollenium every day fetches the pollen data and stores it in the database.
2. If the pollen level exceeds a certain threshold, Pollenium publishes a notification message to a specific NATS subject.
3. Telenats listens for notification messages and sends a message to my Telegram bot chat.
4. If I want to hear the current pollen levels, I can press a specific key on my keyboard.
5. Typocast captures the keystroke and publishes a specific message to the related NATS subject.
6. Pollenium listens for that subject/keystroke and when it receives the message, it gets from the database the current pollens with high levels and publishes a formatted message to the tts NATS subject.
7. Voicecast listens for tts messages, sends the text to the Piper server, gets the audio file, and plays it.

![zoom:Pollen monitoring](/images/pollenium03.png)

# Conclusion
Using NATS as a message broker for my home server has been a great choice. It has allowed me to build a modular architecture that is easy to maintain and extend. I can easily add new services or modify existing ones without affecting the entire system. Plus, it has been a fun and **relaxing** experience to develop my home server using Go and asynchronous messaging.


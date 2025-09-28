# Running NATS on a FreeBSD Jail


Last few months I played with FreeBSD and my Rock64 embedded boards [[1](https://simonevellei.com/blog/posts/freebsd-on-a-rock64-board/)] [[2](https://simonevellei.com/blog/posts/netbsd-on-a-rock64-board/)]. I really enjoyed the experience and I wanted to go to the next level and experiment with FreeBSD jails. I was surprised how easy (and logical) it was to create and manage an isolated environment. I also noticed that the low level commands have been wrapped into a more user friendly interfaces (like `bastille`) making the whole experience more enjoyable. To have a real example of a microservice running on a jail, I decided to try with [NATS](https://nats.io).

## What is NATS?
[NATS](https://nats.io) is an open-source messaging system that is designed for cloud-native applications, IoT messaging, and microservices architectures. It provides a lightweight, high-performance, and secure communication mechanism that supports both publish-subscribe and request-reply patterns. NATS is known for its simplicity, ease of use, and ability to scale horizontally, making it an ideal choice for distributed systems.

One of the key features of NATS is its ability to handle high-throughput and low-latency messaging. It achieves this through a combination of efficient protocol design, in-memory data structures, and optimized network communication. NATS also supports clustering, which allows multiple NATS servers to work together to provide fault tolerance and load balancing.

In addition to its core messaging capabilities, NATS has a rich ecosystem of clients and libraries for various programming languages, making it easy to integrate with different applications and services. It also offers advanced features such as streaming, persistence, and security, which can be leveraged to build robust and reliable messaging solutions.

## What is a FreeBSD jail?
FreeBSD jails are a powerful and flexible feature of the FreeBSD operating system that allow you to create isolated, secure environments within a single FreeBSD instance. Introduced in FreeBSD 4.0, jails provide a lightweight alternative to full virtualization, enabling you to run multiple applications or services in separate, confined spaces without the overhead of a full virtual machine.

A FreeBSD jail operates as a chroot environment with additional security and resource management features. Each jail has its own filesystem, network interfaces, and process space, ensuring that processes running inside a jail cannot interfere with those in other jails or the host system. This isolation makes jails an excellent choice for securely hosting multiple applications on a single server, testing software in a controlled environment, or managing multi-tenant environments.

Jails are highly configurable, allowing you to fine-tune the level of isolation and resource allocation for each jail. You can assign specific IP addresses, limit CPU and memory usage, and control access to system resources. This flexibility, combined with the lightweight nature of jails, makes them a popular choice for both development and production environments.

## What is Bastille?
[Bastille](https://bastillebsd.org/) is a command-line utility for managing FreeBSD jails. It simplifies the process of creating, configuring, and maintaining jails, which are lightweight, isolated environments similar to containers. Bastille provides an easy-to-use interface for jail management, allowing users to quickly deploy and manage applications in a secure and efficient manner.

With Bastille, you can create new jails, start and stop them, and manage their configurations with simple commands. It also supports templates, which can be used to automate the deployment of pre-configured environments. This makes it an excellent tool for both development and production use cases, where consistency and repeatability are important.

Bastille also integrates with ZFS, a robust file system that provides advanced features such as snapshots and cloning. This integration allows for efficient storage management and easy rollback of changes, further enhancing the flexibility and reliability of your jail environments.

### Implementing a Bastille template for NATS
Bastille templates are pre-configured environments that can be used to quickly deploy new jails. They contain a base FreeBSD installation along with any additional packages or configurations that you want to include. Templates are a powerful feature of Bastille that can help you streamline your workflow and ensure consistency across your environments.

The idea is to be architecture agnostic, so the template can be used in any FreeBSD system. NATS will be compiled from source, so the template will contain the necessary packages to build it.

```shell
# install required packages
PKG git
PKG go
```

Then we can create specific user and group for NATS:

```shell
# create default group
CMD pw groupadd "${NATS_GROUP}"
# create default user
CMD pw useradd -n "${NATS_USER}" -g "${NATS_GROUP}" -s /usr/sbin/nologin -w no
```

We'll accept group and user names as environment variables, so we can customize them when creating the jail from the template.

Now it's time to clone the NATS repository and compile it:

```shell
# download and install nats server
CMD "${GO}" install "github.com/nats-io/nats-server/v2@${NATS_VERSION}"
CMD "${INSTALL}" -o "${NATS_USER}" -g "${NATS_GROUP}" "${GOPATH}/bin/nats-server" /usr/local/bin/nats-server
```

We'll use `go install` to download and compile the NATS server, and then we'll install it in the `/usr/local/bin` directory. We'll also set the owner and group of the binary to the user and group we created earlier.

As soon as we have the NATS server installed, we can create a configuration file and an init script for it:

```shell
CP usr /
CMD chmod a+x /usr/local/etc/rc.d/nats
```

The `usr` directory contains the configuration file and the init script for the NATS server. We'll copy them to the root directory of the jail and make the init script executable.

Finally, we'll set the NATS server to start automatically when the jail boots:

```shell
SYSRC nats_enable=YES
SYSRC nats_user="${NATS_USER}"
SYSRC nats_group="${NATS_GROUP}"
SERVICE nats start
```

> Don't worry too much about the template; you'll find a link to the repository with the complete code at the end of the article.

## Creating a NATS jail
In order to let Bastille create a jail from a template we need to bootstrap it first:

```shell
bastille bootstrap https://github.com/henomis/nats-jail-template
```

This command will download the template from the repository, you'll find it into the directory `/usr/local/bastille/templates/`

Now we can create the jail:

```shell
bastille create nats-jail 14.2-RELEASE 10.0.0.1
```

This command will create a new jail named `nats-jail`. The jail will be based on FreeBSD 14.2-RELEASE and will have the IP address `10.0.0.1`. It's time to apply the template:

```shell
bastille template nats-jail henomis/nats-jail-template
```

This command will apply the template to the jail, installing all the necessary packages and configurations. Once the template is applied, you'll have a fully functional NATS server running in the jail.

## Testing the NATS jail
To test the NATS jail, you can connect to it using the NATS CLI tool. But, as we already had fun with jails, we can create a new jails and run the NATS CLI tool in it. We will set up a publisher and a subscriber in two different jails, and we'll use the NATS server to send messages between them.


Let's create a new jail for the publisher:
```shell
bastille create pub-jail 14.2-RELEASE 10.0.0.2
```

Then we'll install the necessary packages and the NATS CLI tool:

```shell
bastille pkg pub-jail install -y git go
bastille cmd pub-jail go install github.com/nats-io/natscli/nats@latest
```

Thanks to `bastille clone` we can create a new jail from an existing one, so we can clone the publisher jail and create a subscriber jail:

```shell
bastille clone pub-jail sub-jail 10.0.0.3
bastille start sub-jail
``` 

We are very close to the end, we just need to start the subscriber and the publisher in two different jails:

```shell
bastille cmd sub-jail /root/go/bin/nats --server 10.0.0.1 sub my.topic
```

Using a different terminal:

```shell
bastille cmd pub-jail /root/go/bin/nats --server 10.0.0.1 pub my.topic "message {{.Count}} - {{.TimeStamp}}" --count 5
```

You should see the messages sent by the publisher in the subscriber terminal.
```shell
[#1] Received on "my.topic"
message 1 - 2025-01-01T16:20:16+01:00


[#2] Received on "my.topic"
message 2 - 2025-01-01T16:20:16+01:00


[#3] Received on "my.topic"
message 3 - 2025-01-01T16:20:16+01:00


[#4] Received on "my.topic"
message 4 - 2025-01-01T16:20:16+01:00


[#5] Received on "my.topic"
message 5 - 2025-01-01T16:20:16+01:00
```

And... that's it! You have a NATS server running in a FreeBSD jail, and you are able to send messages between different jails using the NATS CLI tool. You can experiment with different configurations, add more jails, and explore the capabilities of NATS and FreeBSD jails further.

## Conclusion
In this article, we have seen how to create a FreeBSD jail with Bastille and run a NATS server inside it. We have also seen how to create two additional jails and use the NATS CLI tool to send messages between them. This example demonstrates the power and flexibility of FreeBSD jails and how they can be used to create isolated, secure environments for running applications and services.

You will find the complete code in the [https://github.com/henomis/nats-jail-template](https://github.com/henomis/nats-jail-template) repository. Feel free to fork it and experiment with it on your own FreeBSD system. I hope this article has inspired you to explore the world of FreeBSD jails and experiment with different applications and services. Happy hacking!

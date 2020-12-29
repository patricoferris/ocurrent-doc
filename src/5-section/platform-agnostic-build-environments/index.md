---
title: Platform agnostic build environments
description: A tool for managing build environments across platforms
authors:
- Patrick Ferris
date: 2020-12-29 11:27:59 +00:00
toc: true
resources: []
---

Since it's inception, [Docker](https://www.docker.com/) has taken the developer world by storm. Whether it's mimicking larger complex system interactions like applications talking to servers with docker-compose, CI testing with simple dockerfiles or development environments for websites there are many use cases for docker. Docker relies on something called [BuildKit](https://github.com/moby/buildkit). For OCluster this was too unreliable and not very flexible. 

OBuilder provides a high-level abstraction for build environments by providing an infrastructure centered on two key components: **a snapshotting filesystem and an execution environment**. 

 - Execution environment (sandbox): this is a means by which to take commands and run them in an isolated way. On Linux for example we can reuse the small, standalone execution environment of BuildKit -- [runc](https://github.com/opencontainers/runc). 
 - Snapshotting Filesystem: if you have ever run the `docker build` command you may be familiar with what looks like layering of file-systems on top of each other so if you change something in your dockerfile further down the line, cached snapshots of the filesystem are summoned instead of rebuilding everything from scratch. As of writing, OBuilder supports `zfs` and `btrfs` backends for implementing this. 

## A simplified diagram 

<a style="border-bottom: none; text-align: center;" href="/img/obuilder-v0.png">
  <div><img width="600" alt="OBuilder configuration diagram" src="/img/obuilder-v0.png"/></div>
</a>

In this simplified diagram there are two contexts, a current working directory of the user and OBuilder's context consisting of a sandbox and a store. In reality things are a little more complex than this, but it helps introduce the key concepts. OBuilder's typical execution is: 

 1. After initial setup (creating the various store directories) the OBuilder context receives a `spec` file describing the job. Each operation (`run`, `from` etc.) is executed within the sandbox. Some of these have little actual effect like `env` which sets some environment variables. `run` and `copy` however have to actually be executed.
 2. For these operations, upon success, the state of the environment is stored by taking a snapshot and naming it the hash which is generated from the spec file and current operation.
 3. Sometimes you may be executing operations that have been done for. If this is the case then the `result` directory of the store should contain the associated hash and instead of replaying this, the state of the environment can be restored. 


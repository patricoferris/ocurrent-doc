---
title: A scheduler, some workers and a client
description: An in-depth look at the how the OCluster infrastructure works
authors:
- Patrick Ferris
date: 2020-12-23 18:41:13 +00:00
toc: true
resources: []
---

In this section we'll look at the infrastructure provided out-of-the-box by OCluster to build a distributed system using Capnp to tie all of the pieces together. 

At it's simplest, OCluster provides four main primitives to build a cluster: 

  - Scheduler: the scheduler handles accepting jobs, organising a fair queueing mechanism and dispatching jobs to pools and workers. When it starts up it also generates the `admin.cap` allowing someone to manage the cluster.
  - Worker: a worker belongs to a pool (and will need access to the pool's `.cap` file, see the previous section) and will process jobs given to it. 
  - Admin: a service for managing lots of different aspects of the cluster. 
  - Client: clients can submit jobs to the scheduler, but the admin must first generate a `submission.cap` and add the client. When submitting jobs the client specifies which pool it wants along with other things like a cache hint. We'll look at these more closely soon.

## A Typical Configuration

<a style="border-bottom: none" href="/img/ocluster.svg">
  <img width="800" alt="OCluster configuration diagram" src="/img/ocluster.svg"/>
</a>

Above you can see a depiction of a typical OCluster configuration. There's quite a lot to take in but the main sections are *clients*, *the scheduler*, *the admin* and *workers* organised into *pools*. 



---
title: A scheduler, some workers and a client
description: An indepth look at the how the OCluster infrastructure works
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

<a style="border-bottom: none" href="/img/ocluster-v0.png"><img width="800" alt="" src="/img/ocluster-v0.png"/></a>

Above you can see a depiction of a typical OCluster configuration, following the numbers we explain the process of running jobs given this pre-configured setup.

  1. A client (one of perhaps many) submits a job to the scheduler providing the required details that a job needs.
  2. The scheduler implements some form of fair-queuing mechanism as well as ensuring the job will be sent to the right pool. 
  3. A worker in a pool receives a job to run -- the logs are streamed back to the client. 
  4. An administrative client can watch over all of these different aspects. 

---
title: OCluster
description: Capnp powered distributed CI builds
pages:
- title: Capabilities and protocols or something
  description: A look into Capnp

---


In this section (and the following *OBuilder* section) we'll look at two useful libraries that OCurrent provides to take your pipelines to the next level.  

The first, and topic of this section, is [OCluster](https://github.com/ocurrent/ocluster). OCluster manages builds on worker nodes, implement a scheduling service to accept new jobs and send them to workers based on some algorithm.

The README of the OCluster repository is an excellent place to start; this documentation, however, will assume no prior knowledge except what was explained in the previous three sections.

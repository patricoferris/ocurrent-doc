---
title: Introduction to incrementalism in OCurrent
description: Understanding how the eDSL works and how to use it to start building
  pipelines
pages:
- title: The Domain Specific Language
  description: An introduction to practical uses of the eDSL for OCurrent
- title: A High Level Interface
  description: The high-level OCurrent interface for building pipelines

---


Welcome to the beginning of theses docs on building things with OCurrent -- an OCaml DSL for generating incremental pipelines to build... well almost anything. This introductory chapter will give a solid understanding of the foundation upon which the OCurrent tower stands including: 

 - The core eDSL features and how it achieves incrementalism 
 - The notion of an OCurrent plugin
 - The broad overview of the suite of existing OCurrent features 

## Why be incremental? 

An incremental approach to building is used within and outside software development. Not only does it allow for steady progress to be made, but also responsive and fast rebuilding in the face of changes. If you want to paint a wall yellow, you don't tear down the building and start from scratch! 

Incrementalism nearly always provides: 
 - Faster rebuilds 
 - Less resource-intensive lifetimes of applications 

This provides users with a better experience (almost instant continuous integration from a hot pipeline) and puts the resources to good use!

For an incremental approach to work well, individual commands or steps need to have a good understanding of their dependencies in order to react if they change. This is provided by OCurrent in the eDSL (more on that later). But you can think of it like any process which reacts to a changing dependency -- your heating turning off when the thermometer reaches a certain temperature or your git repository rebuilding when the main `ref` changes. 

With this added reactivity, the incremental process not only has the afore mentioned benefits but now it has a real sense of automation too!
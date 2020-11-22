---
title: Create an OCurrent Plugin
description: Learn how to use the underlying OCurrent primitives to build a new plugin
pages:
- title: Basic OCurrent Primitives
  description: A look at the core components of building OCurrent plugins
- title: Build a Gitlab OCurrent Plugin
  description: Learn to build a simple Gitlab plugin for OCurrent

---


Plugins for OCurrent are useful modules which provide a specific functionality using the underlying OCurrent primitives in order to do things like caching and automatic component generation. 

If you have worked through the other sections may already be familiar with some of the like: 

 - The `Docker` plugin for pulling, building and running docker images. 
 - The `Github` plugin for authenticating and using the Github API (the newer *GraphQL* one). 
 - The `Git` plugin for working with git repositories and being able to `fetch` from them. 

Here we will look at (a) the underlying primitives OCurrent exposes for building plugins and (b) building a [Gitlab](https://about.gitlab.com/) plugin. 


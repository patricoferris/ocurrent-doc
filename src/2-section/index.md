---
title: Build a website deployer with OCurrent
description: Only using OCurrent plugins learn how to do some continuous deployment
pages:
- title: A Gatsby Site Deployer
  description: Setup the entry point of the pipeline to watch Github and pull from
    it to get the latest content
---


This is a tutorial on how to use existing OCurrent plugins to build a continuous deployment service for your website. It will be relatively simple, but the concepts should transfer nicely.

We will learn to: 

 - Monitor and pull in our site content from Github
 - Configure an environment in the pipeline to build the site 
 - Build and deploy the site using Docker (in reality it will be more of a development type server)  

To show the flexibility of this approach the site won't even be in OCaml, it will be a Gatsby website which uses Javascript and Node. But for good measure, we'll use [cohttp-server-lwt](https://github.com/mirage/ocaml-cohttp) as the web-server to run our static site just to show more flexibility.


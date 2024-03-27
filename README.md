# Quick Lookup and Context Suite Deployment

This repo contains configuration for the our clusters and services.
We use Fleet (Rancher) to manage our Kubernetes clusters and Helm to deploy our services.

The Fleet service monitors this repo and deploys all services and applications that are mapped in Ranchder.

### Index

- [Systems involved and their roles](#systems-involved-and-their-roles)
  - [Github](#github)
  - [Rancher](#rancher)
  - [Docker Hub](#docker-hub)
- [Applications included in repo](#applications-included-in-repo)
  - [Context Suite](#context-suite)
    - [The Client Application](#the-client-application)
    - [The Context API](#the-context-api)
  - [Quick Lookup](#quick-lookup)
    - [The Graph API](#the-graph-api)
    - [The Bestlist](#the-bestlist)
  - [Self Services Portal](#self-services-portal)
  - [The GraphQL Playground](#the-graphql-playground)

### IMPORTANT!
**No secrets are stored in this repo. NONE AT ALL!**</br> 
As this is a public repo, all secrets are stored in Rancher and injected into the cluster at deployment time.
Before you commit any changes to this repo, make sure you have removed all secrets from the files you are changing.

Refer to the [Rancher documentation](https://ranchermanager.docs.rancher.com/how-to-guides/new-user-guides/kubernetes-resources-setup/secrets#docusaurus_skipToContent_fallback) for how to add secrets to the cluster.

### Also IMPORTANT!
We separate deployment configuration from application code.</br>
The only CI actions included in code repos are building, dockerizing the code and pushing the image to DockerHub.</br>
All other deployment configuration is stored in this repo.

## Systems involved and their roles
The following systems are involved in deploying Quick Lookup and Context Suite services.

### Github
This repository is stored on Github and contains all configuration for the services and applications.
Whe it changes, Fleet will automatically deploy the changes to the cluster.

Our code is also stored in Github and is automatically build and dockerized by Github Actions.
Docker images are then stored in [DockerHub](#docker-hub).

### Rancher
Wee use Rancher to manage our all of our Kubernetes clusters, independent of the cloud provider.
Fleet is the part of Rancher that is used to monitor and deploy the configuration in this repo.

Our rancher instance is available at [ops.quicklookup.com](https://ops.quicklookup.com)</br>
[Rancher Docs](https://ranchermanager.docs.rancher.com/)</br>
[Fleet Docs](https://fleet.rancher.io/)

### Docker Hub
Whe store container images in DockerHub.
Fleet fetches the images from DockerHub and deploys them to the cluster based on the tags specified in this repo.
We can have Github Actions updated these tags automatically when code is pushed to Github.

[Our DocerHub Repo](https://hub.docker.com/repository/docker/quicklookup/)

# Applications included in repo

## Context Suite

### The Client Application

### The Context API

## Quick Lookup

### The Graph API

### The Bestlist 

## Self Services Portal

## The GraphQL Playground







# ``Automerge``

Automerge helps you build collaborative applications by tracking changes and enabling consistent merging of those changes to your models.

## Overview

Automerge is an implementation of [CRDTs](https://crdt.tech), that enables you define model objects, update them, and share changes between different instances that update that model. 
Automerge provides the serialization for the combined change history for models, but doesn't provide any I/O - saving to disk, or transfering content over a network.

For an overview of Automerge, watch the November 2021 video [Automerge: a new foundation for collaboration software](https://www.youtube.com/watch?v=Qytg0Ibet2E).

## Topics

### Getting Started

- <doc:AutomergeBasics>

### Tracking collaborative changes

- ``Document``
- ``Proxy``
- ``Actor``
- ``Patch``

## Built in data structures

- ``Text``
- ``Counter``
- ``Table``

# ``Automerge``

Automerge helps you build collaborative applications by tracking changes and enabling consistent merging of those changes to your models.

## Overview

Automerge is an implementation of [CRDTs](https://crdt.tech), that enables you define model objects, update them, and share changes between different instances that update that model. Automerge provides the serialization for the combined change history for models, but doesn't provide any I/O - saving to disk, or transfering content over a network.

For some of the details of how Automerge manages the complexities of implementing CRDTs, watch the July 2020 video [CRDTs: The Hard Parts](https://www.youtube.com/watch?v=x7drE24geUw).

## Topics

### Getting Started

- <doc:AutomergeBasics>

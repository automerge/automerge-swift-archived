# Conflicts in the Change History

Expose and highlight conflicting changes within a document.

## Overview

Automerge allows different nodes to independently make arbitrary changes to their respective copies of a document. 
In most cases, those changes can be combined without any trouble. 
For example, if users modify two different objects, or two different properties in the same object, then it is straightforward to combine those changes.

If users concurrently insert or delete items in a list (or characters in a text document), Automerge preserves all the insertions and deletions. 
If two users concurrently insert at the same position, Automerge arbitrarily places one of the insertions first and the other second, while ensuring that the final order is the same on all nodes.

### Conflicting changes

When two collaborators concurrently update the same property in the same object (or, similarly, the same index in the same list), Automerge picks one of the concurrently written values as the "winner". 

```swift
// Define the model.
struct Coordinate: Codable, Equatable {
    var x: Int?
}

// Create the two collaborators
let actor1 = Actor()
let actor2 = Actor()

// Initialize documents with known actor IDs.
var doc1 = Document(Coordinate(), actor: actor1)
var doc2 = Document(Coordinate(), actor: actor2)

// Set values independently.
doc1.change { proxy in
  proxy.x.set(1)
}
doc2.change { doc in
  doc.x.set(2)
}

// Merge the changes in both directions.
doc1.merge(doc2)
doc2.merge(doc1)

// Now, `doc1` might be either {x: 1} or {x: 2}.
// However, `doc2` will be the same, whichever value is 
// chosen as winner.
// doc1.content.x == doc2.content.x
```

Although only one of the concurrently written values shows up in the object, the other value that was set is not lost.
Automerge tracks the actor Id and the value that it didn't pick, and maintains that information as a conflict until that property is updated again.

You can inspect the conflicts through the proxy returned from the document using the ``Document/rootProxy()`` method.
If the winning value of the property `x` is `2`, then Automerge records a conflict on property `x`.
In the following example, `actor-1` is the ID of the actor that "lost" the conflict, and the associated value of the conflict is the value `actor-1`, the Id of the actor that lost the assignment to the property `x`:

```swift
doc1 
// {x: 2}
doc2 
// {x: 2}

doc1.rootProxy().conflicts(dynamicMember: \.x)) 
// ex: Optional([1@40d336cdd6044c2f9886d5240b7ba91c: Optional(1), 1@554560f135b14f18b8fa37ed999624c2: Optional(2)])

doc2.rootProxy().conflicts(dynamicMember: \.x)) 
// ex: Optional([1@554560f135b14f18b8fa37ed999624c2: Optional(2), 1@40d336cdd6044c2f9886d5240b7ba91c: Optional(1)])
```

Use the information from ``Proxy/conflicts(dynamicMember:)`` (or ``Proxy/conflicts(index:)``, used when the model is a list) to hint that the current value over-wrote another value.

The change to a property that is listed in the conflicts, Automerge considers it resolved, and the conflict disappears from the change history.

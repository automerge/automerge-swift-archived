![Build](https://github.com/lightsprint09/automerge-swift/workflows/Build/badge.svg?branch=main)
# automerge-swift
A automerge frontend in Swift using the rs-backend

## Installation

### Swift Package Manager

[SPM](https://swift.org/package-manager/) is integrated with the Swift build system to automate the process of downloading, compiling, and linking dependencies.

Specify the following in your `Package.swift`:

```swift
.package(url: "https://github.com/automerge/automerge-swift", .branch("main")),
```

## Usage

The following code sample gives a quick overview of how to use Automerge
```swift
import Automerge
/// Define your model object, which will be stored in automerge.

/// Do NOT provide custom Codable implementations or custom CodingKeys for now 
struct Cards: Codable {
  var cards: [Card]
}
struct Card: Codable {
  let title: String
  var done: Bool
}

// Let's say doc1 is the application state on device 1.
// Further down we'll simulate a second device.
// We initialize the document to initially contain an empty list of cards.
var doc1 = Automerge.Document(Cards(cards: []))

// The doc1 object is treated as immutable -- you must never change it
// directly. To change it, you need to call .change() with a closure
// in which you can mutate the state. You can also include a human-readable
// description of the change, like a commit message, which is stored in the
// change history (see below).
doc1.change(message: "Add card") { doc in 
    doc.cards.append(Card(title: "Rewrite everything in Obj-C", done: false))
}

// Now the state of doc1 is:
// { cards: [ { title: 'Rewrite everything in Obj-C', done: false } ] }

// You can use all methods provided by `RangeReplaceableCollection`.
doc1.change(message: "Add card") { doc in 
    doc.cards.insert(Card(title: "Rewrite everything in Swift", done: false), at: 0)
}

// Now the state of doc1 is:
// { cards:
//    [ { title: 'Rewrite everything in Swift', done: false },
//      { title: 'Rewrite everything in Obj-C', done: false } ] }

// Now let's simulate another device, whose application state is doc2. doc2 has
// a copy of all the cards in doc1.

var doc2 = Document(changes: doc1.allChanges())

// Now make a change on device 1:
doc1.change(message: "Mark card as done") { doc in 
    doc.cards[0].done.set(true)
}

// { cards:
//    [ { title: 'Rewrite everything in Swift', done: true },
//      { title: 'Rewrite everything in Obj-C', done: false } ] }

// And, unbeknownst to device 1, also make a change on device 2:
doc2.change(message: "Delete card") { doc in 
    doc.cards.remove(at: 1)
}

/ { cards: [ { title: 'Rewrite everything in Swift', done: false } ] }

// Now comes the moment of truth. Let's merge the changes from device 2 back
// into device 1. You can also do the merge the other way round, and you'll get
// the same result. The merged result remembers that 'Rewrite everything in
// Swift' was set to true, and that 'Rewrite everything in Obj-C' was
// deleted:

doc1.merge(doc2)

// { cards: [ { title: 'Rewrite everything in Swift', done: true } ] }

// As our final trick, we can inspect the change history. Automerge
// automatically keeps track of every change, along with the "commit message"
// that you passed to change(). When you query that history, it includes both
// changes you made locally, and also changes that came from other devices. You
// can also see a snapshot of the application state at any moment in time in the
// past. For example, we can count how many cards there were at each point:

History(doc1).map { ($0.change.message, $0.snapshot.cards.count) }
// [ ('Initialization', 0),
//   ('Add card', 1),
//   ('Add another card', 2),
//   ('Mark card as done', 2),
//   ('Delete card', 1)
//  ]

```

## Automerge document lifecycle

### Initializing a document

`Document.init<T>(_ content: T) ` creates a new Automerge document and populates it with the contents of the object. The value passed must always be an object.

```swift
var doc = Automerge.Document(Cards(cards: []))
```
 
 An Automerge document must be treated as immutable. It is never changed directly, only with the `doc.change` function, described below.

### Updating a document

`doc.change` enables you to modify an Automerge document doc.

 The change function you pass to`doc.change` is called with a mutable version of doc, as shown below.

 The optional message argument allows you to attach an arbitrary string to the change, which is not interpreted by Automerge, but saved as part of the change history

```swift

currentDoc.change() { doc in 
    doc.proberty.set("value") // assigns a string value to a property
    doc.proberty.set(nil) // removes a property

    // all primitive datatypes are supported
    doc.stringValue.set("value")
    doc.numberValue.set(1)
    doc.boolValue.set(true)

    doc.nestedObject.set(NestedObject(property: "val")) // creates a nested object
    doc.nestedObject.property.set("value")

    // Arrays are fully supported
    doc.list = [] // creates an empty list object
    doc.list.append(contentsOf: [2, 3])
    doc.list.insert(1, at: 0)
    doc.list[2].set(3)
    // now doc.list is [0, 1, 3]

    // Looping over lists works as you'd expect:
    for (i, value) in doc.liste.enumerated() {
        doc.list[i].set(2 * value)
    }
    // now doc.list is [0, 2, 6]

}
```

### Persisting a document

`doc.save()` serializes the state of Automerge document doc to binary, which you can write to disk. The binary contains an encoding of the full change history of the document (a bit like a git repository).

`Document(data: binary)` unserializes an Automerge document from binary that was produced by `doc.save()`.

Note: Specifying actor

The Document initializer takes an optional `actor` parameter:

```swift
let actor = Actor(actorId: "1234abcd56789qrstuv")
let doc2 = Document(Cards(cards: []), actor: actor)
let doc3 = Document(data: binary, actor: actor)
```

The actor ID is a string that uniquely identifies the current node; if you omit actor ID, a random ID is generated. If you pass in your own actor ID, you must ensure that there can never be two different processes with the same actor ID. Even if you have two different processes running on the same machine, they must have distinct actor IDs.

Unless you know what you are doing, you should stick with the default, and let actor ID be auto-generated.

### Sending and receiving changes

The Automerge library itself is agnostic to the network layer — that is, you can use whatever communication mechanism you like to get changes from one node to another. There are currently a few options, with more under development:

Use `.getChanges()` and  `.apply(changes:)` to manually capture changes on one node and apply them on another.

The .getChanges()/.apply(changes:) API works as follows:

```swift
// On one node
var newDoc = oldDoc
newDoc.change { doc in
  // make arbitrary change to the document
}
let changes = newDoc.getChanges(between: oldDoc)
network.broadcast(changes)

// On another node
let changes = network.receive()
currentDoc.apply(changes: changes)
```
Note that `newDoc.getChanges(between: currentDoc)` takes  an old  document state as argument. It then returns a list of all the changes that were made in newDoc since oldDoc. If you want a list of all the changes ever made in doc, you can call `Document.getAllChanges()`.

The counterpart, `Document.apply(chnages:)` applies the list of changes to the document. Automerge guarantees that whenever any two documents have applied the same set of changes — even if the changes were applied in a different order — then those two documents are equal. That property is called convergence, and it is the essence of what Automerge is all about.

`doc1.merge(doc2)` is a related function that is useful for testing. It looks for any changes that appear in doc2 but not in doc1, and applies them to doc1. This function requires that doc1 and doc2 have different actor IDs (that is, they originated from different calls to Document.init()). See the Usage section above for an example using `Document.merge()`.

### Conflicting changes

Automerge allows different nodes to independently make arbitrary changes to their respective copies of a document. In most cases, those changes can be combined without any trouble. For example, if users modify two different objects, or two different properties in the same object, then it is straightforward to combine those changes.

If users concurrently insert or delete items in a list (or characters in a text document), Automerge preserves all the insertions and deletions. If two users concurrently insert at the same position, Automerge will arbitrarily place one of the insertions first and the other second, while ensuring that the final order is the same on all nodes.

The only case Automerge cannot handle automatically, because there is no well-defined resolution, is when users concurrently update the same property in the same object (or, similarly, the same index in the same list). In this case, Automerge arbitrarily picks one of the concurrently written values as the "winner":

```swift
// Initialize documents with known actor IDs
var doc1 = Document(Coordinate(), Actor(actorId: "actor-1")
var doc2 = Document(Coordinate(), Actor(actorId: "actor-2")
doc1.change { doc in
  doc.x.set(1)
})
doc2.change { doc in
  doc.x.set(2)
})
doc1.merge(doc2)
doc2.merge(doc1)

// Now, doc1 might be either {x: 1} or {x: 2} -- the choice is random.
// However, doc2 will be the same, whichever value is chosen as winner.
doc1.coontent.x == doc2.coontent.x
```
Although only one of the concurrently written values shows up in the object, the other values are not lost. They are merely relegated to a conflicts object. Suppose doc.x = 2 is chosen as the "winning" value:

```swift
doc1 // {x: 2}
doc2 // {x: 2}
doc1.rootProxy().conflicts(dynamicMember: \.x)) // {'actor-1': 1}
doc2.rootProxy().conflicts(dynamicMember: \.x)) // {'actor-1': 1}
```
Here, we've recorded a conflict on property x. The key actor-1 is the actor ID that "lost" the conflict. The associated value is the value actor-1 assigned to the property x. You might use the information in the conflicts object to show the conflict in the user interface.

The next time you assign to a conflicting property, the conflict is automatically considered to be resolved, and the conflict disappears from the object returned by Automerge.getConflicts().

## Generating the Documentation

Using Xcode:

- open the `Package.swift` file using Xcode
- choose Product > Build Documentation

An archive of the documentation can be exported from the Documentation window in Xcode by selecting Automerge under automerge-swift in Workspace Documentation, then clicking on the ... to expose an Export... menu.

![A screenshot of a portion of the Xcode documentation window that displays the Workspace Documentation with a workspace named automerge-swift. The workspace has an enabled disclosure arrow to the left of its name, showing a highlighted documentation set named Automerge with an ellipsis within a circular button to the right of the Automerge.](.img/Xcode_doc_export.png)

Building on the command line:

```bash
mkdir -p .build/symbol-graphs
swift build --target Automerge -Xswiftc -emit-symbol-graph -Xswiftc -emit-symbol-graph-dir -Xswiftc .build/symbol-graphs
xcrun docc preview Source/Automerge.docc --fallback-display-name Automerge --fallback-bundle-identifier org.automerge.Automerge-swift --fallback-bundle-version 0.1.6 --additional-symbol-graph-dir .build/symbol-graphs
```

The documentation is then hosted locally, accessible at [http://localhost:8000/documentation/automerge](http://localhost:8000/documentation/automerge).
When you invoke `xcrun docc preview`, DocC runs a local webserver to temporarily host the documentation and shows you the available URLs, such as:

```
========================================
Starting Local Preview Server
	 Address: http://localhost:8000/documentation/zippyjson
	          http://localhost:8000/documentation/automerge
========================================
```

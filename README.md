![Build](https://github.com/lightsprint09/automerge-swift/workflows/Build/badge.svg?branch=master)
# automerge-swift
A automerge frontend in Swift using the rs-backend

## Usage

The following code sample gives a quick overview of ho to use Automerge
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

History(doc1).map {($0.change.message, $0.snapshot.cards.count) }
Automerge.getHistory(finalDoc).map(state => [state.change.message, state.snapshot.cards.length])
// [ [ 'Initialization', 0 ],
//   [ 'Add card', 1 ],
//   [ 'Add another card', 2 ],
//   [ 'Mark card as done', 2 ],
//   [ 'Delete card', 1 ] ]

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

 The changeFn function you pass to`doc.change` is called with a mutable version of doc, as shown below.

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
    doc.nestedObject.propertyset("value")

    // Arrays are fully supported
    doc.list = [] // creates an empty list object
    doc.list.append(contentsOf: [2, 3]
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
let actor = Actor(actorId: "1234abcd-56789qrstuv")
let doc2 = Document(Cards(cards: []), actor: actor)
let doc3 = Document(data: binary, actor: actor)
```

The actor ID is a string that uniquely identifies the current node; if you omit actor ID, a random UUID is generated. If you pass in your own actor ID, you must ensure that there can never be two different processes with the same actor ID. Even if you have two different processes running on the same machine, they must have distinct actor IDs.

Unless you know what you are doing, you should stick with the default, and let actor ID be auto-generated.


### Undo and redo

Automerge makes it easy to support an undo/redo feature in your application. Note that undo is a somewhat tricky concept in a collaborative application! Here, "undo" is taken as meaning "what the user expects to happen when they hit ctrl+Z/⌘ Z". In particular, the undo feature undoes the most recent change by the local user; it cannot currently be used to revert changes made by other users.

Moreover, undo is not the same as jumping back to a previous version of a document; see the next section on how to examine document history. Undo works by applying the inverse operation of the local user's most recent change, and redo works by applying the inverse of the inverse. Both undo and redo create new changes, so from other users' point of view, an undo or redo looks the same as any other kind of change.

To check whether undo is currently available, use the function `canUndo()`. It returns true if the local user has made any changes since the document was created or loaded. You can then call doc.undo() to perform an undo. The functions canRedo() and redo() do the inverse:

```swift
var doc = Automerge.Document(Birds(birds: []))
doc.change() {
    $0.birds.append("blackbird")
}
doc.change() {
    $0.birds.append("robin")
}
// now doc is {birds: ['blackbird', 'robin']}

doc.canUndo // returns true
doc.undo() // now doc is {birds: ['blackbird']}
doc.undo() // now doc is {birds: []}
doc.redo() // now doc is {birds: ['blackbird']}
doc.redo() // now doc is {birds: ['blackbird', 'robin']}
```
You can pass an optional message as second argument to `.undo(message: String)` and `.redo(doc, message)`. This string is used as "commit message" that describes the undo/redo change, and it appears in the change history.

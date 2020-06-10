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
var doc1 = Automerge.Document(Cards(cards: []))
```
 
 An Automerge document must be treated as immutable. It is never changed directly, only with the `Document.change` function, described below.

### Updating a document

`Document.change` enables you to modify an Automerge document doc.

 The changeFn function you pass to`Document.change` is called with a mutable version of doc, as shown below.

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

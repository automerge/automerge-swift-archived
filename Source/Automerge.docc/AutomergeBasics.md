# Automerge Basics

Getting started using Automerge in your app.

## Overview

The following content walks you through creating a model that collaborators update.
With your model, you create an Automerge document, update that document, and inspect it.
Then you can replicate the document to represent another collaborator, update the two models independently, and merge the results.
The content then shows how to get and display the change history for your model that is encoded into the Automerge document.

### Creating a Model for Automerge

Automerge expects its documents to have a model. 
Make your document's model a codable struct, but do not provide any custom `Codable` protocol implementations or custom `CodingKeys`.

```swift
import Automerge
// Define your model object, which will be stored in 
// automerge.

// Don't provide custom Codable implementations or 
// custom CodingKeys. 
struct Cards: Codable {
  var cards: [Card]
}
struct Card: Codable {
  let title: String
  var done: Bool
}
```

With your model defined, create a document with an initial value for your model.
The following snippet creates a document named `doc1` that contains an empty list of cards:

```swift
var doc1 = Automerge.Document(Cards(cards: []))
```

### Updating your Model through the Automerge Document

Treat your document an an immutable view of your current model's state. 
To change a document, call the ``Document/change(message:_:)`` method with a closure, and update your model's state within that closure.
You can also include a human-readable description of the change, similar to a commit message, which automerge stores in the change history.

The following snippet shows an example of adding a new card into your document:
```swift
doc1.change(message: "Add card") { doc in 
    doc.cards.append(
        Card(title: "Rewrite everything in Obj-C",
             done: false)
    )
}
// Now the state of doc1 is:
// { cards: [ 
//   { 
//     title: 'Rewrite everything in Obj-C', 
//     done: false 
//   }
// ] }
```

When you use a list in your model, you can use all the methods provided by `RangeReplacableCollection` on that list within the closure.
For example, the following code snippet adds an additional card using the `insert(_:at:)` method:

```swift
doc1.change(message: "Add card") { doc in 
    doc.cards.insert(
        Card(title: "Rewrite everything in Swift", 
             done: false), 
        at: 0)
}

// Now the state of doc1 is:
// { cards:
//    [ { title: 'Rewrite everything in Swift', 
//        done: false },
//      { title: 'Rewrite everything in Obj-C', 
//        done: false } ] }
```

### Sharing Automerge Documents between Collaborators

To simulate a collaborator working on the same document, create a new document from your document's change history, as shown in the following snippet:
```swift
var doc2 = Document(changes: doc1.allChanges())
//doc2 has a copy of all the cards in doc1.
```

Now you can make changes in each document indepdendently.
The following code snippet shows updating one of the cards in the first document, and removing that same card in the second document:

```swift
// Now make a change on device 1:
doc1.change(message: "Mark card as done") { doc in 
    doc.cards[0].done.set(true)
}

// doc1 state:
// { cards:
//    [ { title: 'Rewrite everything in Swift', 
//        done: true },
//      { title: 'Rewrite everything in Obj-C', 
//        done: false } ] }

doc2.change(message: "Delete card") { doc in 
    doc.cards.remove(at: 1)
}
// doc2 state:
// { cards: [ { title: 'Rewrite everything in Swift', 
//              done: false } ] }
```

### Merging Changes Between Collaborators

Automerge provides the mechanisms to consistently merge changes, including those changes that would normally appear to conflict.
The following example shows merging the changes from the second document back into the first:
```swift
doc1.merge(doc2)

// doc1 state:
// { cards: [ { title: 'Rewrite everything in Swift', 
//              done: true } ] }
```

You can merge documents in a either direction, and automerge returns the same resulting state.
The merged result includes the history that the card labeled 'Rewrite everything in Swift' was set to true, and the card 'Rewrite everything in Obj-C' was deleted. 

### Displaying the Change History of an Automerge Document

You can also inspect the details of the change history associated with a document.
Automerge keeps track of all changes, along with any messages that included when ``Document/change(message:_:)`` was called. 


When you query that history, it the changes you made locally and any changes that you merged in from collaborators. 
The change history also provides a snapshot of your model's state at any point in the change history.
The following example uses `map` to iterate through the change history and count how many cards existed at each change:

```swift
History(doc1).map { ($0.change.message, $0.snapshot.cards.count) }
// [ ('Initialization', 0),
//   ('Add card', 1),
//   ('Add another card', 2),
//   ('Mark card as done', 2),
//   ('Delete card', 1)
//  ]
```

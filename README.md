![Build](https://github.com/lightsprint09/automerge-swift/workflows/Build/badge.svg?branch=master)
# automerge-swift
A automerge frontend in Swift using the rs-backend

## Usage (⚠️ Highly Experimental)

### 1. Define your types you want to store
⚠️  <b>Default</b> Codable conformance required

⚠️ Do NOT provide custom Codable implementations or custom CodeingKeys

```swift
struct Trip: Codable {
  var name: String
  var stops: [Stop]
}
struct Stop: Codable {
  let name: String
  var nights: Int // Define your types with mutalibilty in mind
}
```

### 2. Create a document

```swift
import Automerge

let trip = Trip(name, "Summer 2020", stops: [])
let document = Automerge.Document(trip)
```

### 3. Mutate a document
⚠️ Here is the ugly part, make sure to copy the static keypath into the dynamic string argument. (Missing dynamic feature of Swift. We should bring up a proposal to fix this)
```swift
var mutableDocument = document
mutableDocument.change { doc
  doc[\.stops, "stops"].append(Stop(name: "Munich", night: 0))
  doc[\.stops, "stops"].append(Stop(name: "Rome", night: 2))
}
mutableDocument.change { doc
  doc[\.name, "name"] = "Summer 2021"
  doc[\.stops[1].nights, "stops[1].nights"] = 3
}
```

### Future 🌈
When the limitation of key paths would be lifted, API could look so much better. This should be the long term goal.
```swift
var mutableDocument = document
mutableDocument.change { doc
  doc.stops.append(Stop(name: "Munich", night: 0))
  doc.stops.append(Stop(name: "Rome", night: 2))
}
mutableDocument.change { doc
  doc.name = "Summer 2021"
  doc.stops[1].nights = 3
}
```

### Other APIs.
Othere API should be really simple and will be added over time.

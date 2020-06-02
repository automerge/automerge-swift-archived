![Build](https://github.com/lightsprint09/automerge-swift/workflows/Build/badge.svg?branch=master)
# automerge-swift
A automerge frontend in Swift using the rs-backend

## Usage (Experimental)

### 1. Define your types you want to store
<b>Default</b> Codable conformance required

⚠️ Do NOT provide custom Codable implementations or custom CodingKeys (I am working on custom CodingKey support)

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
```swift
var mutableDocument = document
mutableDocument.change { doc in
  let stops = doc.stops
  stops.append(Stop(name: "Munich", night: 0))
  stops.append(Stop(name: "Rome", night: 2))
}
mutableDocument.change { doc in
  doc.name.set("Summer 2021")
  doc.stops[1].nights.set(3)
}
```

### Future 🌈
We quite near the API goal. Custom assignment operators are missing for now
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

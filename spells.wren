import "./parcel" for Stateful
class Spell is Stateful {
  construct new(data) {
    super(data)
  }
  cost { 3 }
  target { { "area": true } }
  effect { null }
}

import "./parcel" for Stateful
class Spell is Stateful {
  construct new(data) {
    super(data)
  }
  cost { 1 }
  target { { "area": true } }
  effect { null }
}

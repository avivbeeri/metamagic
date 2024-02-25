class Animation {
  static ease(x) {
    return -((Num.pi * x).cos - 1) / 2
  }
}

module A
  X = "A::X"
end

module B
  X = "B::X"
end

class C
  prepend A
end

class D < C
  prepend B

  p X
end

class C
end

p C::X

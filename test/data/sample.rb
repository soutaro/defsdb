require "tsort"
require_relative "sample2"

class TestSuperClass
end

module TestModule
end

class TestClass < TestSuperClass
  include TestModule

  TestConstant = TestSuperClass.new

  def test_method

  end

  private def test_private_method

  end

  protected def test_protected_method

  end
end

class <<TestClass
  def test_singleton_method

  end

  private def test_private_singleton_method

  end

  protected def test_protected_singleton_method

  end
end

TestConstant = TestClass.new

class A
  X = []
  class B
    X = true
    class C
      X = "string"
      class D
      end
    end
  end
end

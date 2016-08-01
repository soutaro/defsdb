require_relative "test_helper"

class Hello
  def hoge
  end

  def pppp
  end

  private :pppp
end

module MethodsTest
  module M
    def g
    end
  end

  class A
    def self.f()
    end
  end

  class B < A
    extend M
  end
end

describe Object do
  let(:instance) { Hello.new }

  it "instance" do
    p instance.public_methods(false)
    p instance.private_methods(false)
    p instance.singleton_methods(true)
  end

  it "class" do
    p Hello.public_methods(false)
    p Hello.singleton_methods(true)
    p Hello.public_instance_methods
  end

  it "aaa" do
    a = Hello.new

    def a.pppp
    end

    a.pppp

    a.singleton_class.instance_eval do
      private :pppp
    end

    p a.private_methods(false)
    p a.singleton_methods(false)
  end

  it "hoge" do
    MethodsTest::B.f

    p MethodsTest::B.ancestors

    p MethodsTest::B.singleton_methods
    p MethodsTest::B.singleton_methods(false)
  end
end

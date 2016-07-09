require 'defsdb'
require 'minitest/autorun'

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

$dumper = Defsdb::Dumper.new
$dumper.run

module WithDumper
  def self.included(mod)
    mod.instance_eval do
      let(:dumper) { $dumper }
      let(:result) { $dumper.as_json }
    end
  end
end

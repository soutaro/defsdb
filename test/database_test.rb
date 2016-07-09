require 'test_helper'
require "set"

describe Defsdb::Database do
  include WithDumper

  let(:database) { Defsdb::Database.new(dumper.as_json) }

  it "loads database" do
    test_class = database.toplevel["TestClass"]
    refute_nil test_class

    assert_equal "TestSuperClass", test_class.superclass.name
    assert(test_class.included_modules.map(&:name).include?("TestModule"))

    assert(test_class.defined_instance_methods.any? {|method| method.name == "test_method" && method.visibility == :public })
    assert(test_class.defined_instance_methods.any? {|method| method.name == "test_private_method" && method.visibility == :private })
    assert(test_class.defined_instance_methods.any? {|method| method.name == "test_protected_method" && method.visibility == :protected })

    assert(test_class.defined_singleton_methods.any? {|method| method.name == "test_singleton_method" && method.visibility == :public })
    assert(test_class.defined_singleton_methods.any? {|method| method.name == "test_private_singleton_method" && method.visibility == :private })
    assert(test_class.defined_singleton_methods.any? {|method| method.name == "test_protected_singleton_method" && method.visibility == :protected })
  end

  describe "#each_module" do
    it "enumerate modules" do
      modules = Set.new

      database.each_module do |mod|
        modules << mod
      end

      assert(modules.any? {|mod| mod.name == "TestSuperClass" && mod.is_a?(Defsdb::Database::Class) })
      assert(modules.any? {|mod| mod.name == "TestClass" && mod.is_a?(Defsdb::Database::Class) })
      assert(modules.any? {|mod| mod.name == "TestModule" && mod.is_a?(Defsdb::Database::Module) })
    end
  end

  describe "#each_method" do
    it "enumerate methods" do
      methods = Set.new

      database.each_method do |method|
        methods << method
      end

      assert(methods.any? {|method| method.name == "test_method" && method.visibility == :public && method.instance_method? })
      assert(methods.any? {|method| method.name == "test_private_method" && method.visibility == :private && method.instance_method? })
      assert(methods.any? {|method| method.name == "test_protected_method" && method.visibility == :protected && method.instance_method? })

      assert(methods.any? {|method| method.name == "test_singleton_method" && method.visibility == :public && method.singleton_method? })
      assert(methods.any? {|method| method.name == "test_private_singleton_method" && method.visibility == :private && method.singleton_method? })
      assert(methods.any? {|method| method.name == "test_protected_singleton_method" && method.visibility == :protected && method.singleton_method? })
    end
  end
end

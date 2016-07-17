require 'test_helper'
require "set"

describe Defsdb::Database do
  include WithDumper

  let(:json) { dump_data("sample.rb") }
  let(:database) {
    Defsdb::Database.new.tap do |database|
      Defsdb::Database::LoadJSON.new(database, json).run
    end
  }

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
    it "enumerates modules" do
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
    it "enumerates methods" do
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

  describe "#each_method_body" do
    it "enumerates method bodies" do
      database.each_method_body.with_object({}) do |body, _|
        assert_kind_of Defsdb::Database::MethodBody, body
      end
    end
  end

  describe "#resolve_constant" do
    it "lookup constant" do
      constant = database.resolve_constant("TestSuperClass")
      assert_equal(database.toplevel["TestSuperClass"], constant)
    end

    it "returns nil when no constant found" do
      assert_nil database.resolve_constant("NoSuchConstant")
    end

    it "lookup constant relatively" do
      constant = database.resolve_constant("TestSuperClass", ["TestClass"])
      assert_equal(database.toplevel["TestSuperClass"], constant)
    end

    it "lookup constant relatively2" do
      assert_equal "Array", database.resolve_constant("X", ["A"]).klass.name
      assert_equal "TrueClass", database.resolve_constant("X", ["A", "B"]).klass.name
      assert_equal "String", database.resolve_constant("X", ["A", "B", "C"]).klass.name
      assert_equal "String", database.resolve_constant("X", ["A", "B", "C", "D"]).klass.name
    end

    it "raises exception if context cannot be resolved" do
      assert_raises Defsdb::Database::InvalidModuleContextError do
        database.resolve_constant("X", ["ZZZ"])
      end

      assert_raises Defsdb::Database::InvalidModuleContextError do
        database.resolve_constant("X", ["A", "X"])
      end
    end
  end
end

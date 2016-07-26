require_relative 'test_helper'
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

  describe "#lookup_constant_path" do
    it "lookup toplevel constant from toplevel" do
      assert_equal "Fixnum", database.lookup_constant_path(["X"], current_module: nil, module_context: []).klass.name
      assert_equal "Fixnum", database.lookup_constant_path([:root, "X"], current_module: nil, module_context: []).klass.name
    end

    it "lookup nested constant from toplevel" do
      assert_equal "Array", database.lookup_constant_path(["A", "X"], current_module: nil, module_context: []).klass.name
      assert_equal "Array", database.lookup_constant_path(["Y", "X"], current_module: nil, module_context: []).klass.name
    end
  end

  describe "#lookup_constant" do
    it "lookup constant in toplevel" do
      assert_equal "Fixnum", database.lookup_constant("X", database.object_class, []).klass.name
    end

    it "lookup constant from context" do
      z = database.toplevel["Z"]

      a = database.toplevel["A"]
      a_b = a.constants["B"]
      a_b_c = a_b.constants["C"]
      a_b_c_d = a_b_c.constants["D"]

      assert_equal "TrueClass", database.lookup_constant("X", z, [a, a_b]).klass.name
      assert_equal "String", database.lookup_constant("X", z, [a, a_b, a_b_c, a_b_c_d]).klass.name
    end

    it "lookup constant from ancestors" do
      y = database.toplevel["Y"]

      assert_equal "Array", database.lookup_constant("X", y, []).klass.name
    end
  end
end

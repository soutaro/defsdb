require 'test_helper'

describe Defsdb::Dumper do
  include WithDumper

  let (:json) { dump_data("sample.rb") }

  describe "toplevel constant" do
    it "contains constant" do
      entry = json[:toplevel][:TestConstant]

      refute_nil entry
      assert_equal 'value', entry[:type]
    end

    it "records class of constant" do
      entry = json[:toplevel][:TestConstant]

      assert_equal "TestClass", entry[:class][:name]
    end

    it "contains methods" do
      constant = json[:toplevel][:TestConstant]

      assert(constant[:methods][:public].any? {|m| m[:name] == 'test_method' })
      assert(constant[:methods][:private].any? {|m| m[:name] == 'test_private_method' })
      assert(constant[:methods][:protected].any? {|m| m[:name] == 'test_protected_method' })
    end
  end

  describe "classes" do
    it "contains class definition as constant" do
      constant = json[:toplevel][:TestClass]

      refute_nil constant
      assert_equal 'class', constant[:type]
      assert_kind_of String, constant[:id]
      assert_equal "TestClass", constant[:name]
    end

    it "contains class definition" do
      constant = json[:toplevel][:TestClass]
      klass = json[:modules][constant[:id].to_sym]

      refute_nil klass
    end

    it "contains methods" do
      constant = json[:toplevel][:TestClass]
      klass = json[:modules][constant[:id].to_sym]

      assert(klass[:methods][:public].any? {|m| m[:name] == 'test_singleton_method' })
      assert(klass[:methods][:private].any? {|m| m[:name] == 'test_private_singleton_method' })
      assert(klass[:methods][:protected].any? {|m| m[:name] == 'test_protected_singleton_method' })
    end

    it "contains instance methods" do
      constant = json[:toplevel][:TestClass]
      klass = json[:modules][constant[:id].to_sym]

      assert(klass[:instance_methods][:public].any? {|m| m[:name] == 'test_method' })
      assert(klass[:instance_methods][:private].any? {|m| m[:name] == 'test_private_method' })
      assert(klass[:instance_methods][:protected].any? {|m| m[:name] == 'test_protected_method' })
    end

    it "has super class" do
      constant = json[:toplevel][:TestClass]
      klass = json[:modules][constant[:id].to_sym]

      refute_nil klass[:superclass]
      assert_equal "TestSuperClass", klass[:superclass][:name]
    end

    it "has included modules" do
      constant = json[:toplevel][:TestClass]
      klass = json[:modules][constant[:id].to_sym]

      assert(klass[:included_modules].any? {|m| m[:name] == "TestModule" })
    end

    it "has nested constant" do
      constant = json[:toplevel][:TestClass]
      klass = json[:modules][constant[:id].to_sym]
      nested = klass[:constants][:TestConstant]

      refute_nil nested
      assert_equal 'value', nested[:type]
      assert_equal 'TestSuperClass', nested[:class][:name]
    end

    it "does not have nested constants from Object" do
      constant = json[:toplevel][:TestClass]
      klass = json[:modules][constant[:id].to_sym]
      constants = klass[:constants]

      assert_nil constants[:Enumerable]
    end

    it "has inherited methods" do
      constant = json[:toplevel][:TestClass]
      klass = json[:modules][constant[:id].to_sym]

      assert(klass[:instance_methods][:public].any? {|m| m[:name] == "__id__" })
    end

    it "contains new method" do
      constant = json[:toplevel][:TestClass]
      klass = json[:modules][constant[:id].to_sym]

      assert(klass[:methods][:public].any? {|m| m[:name] == "new" })
    end

    it "contains reference to method definition" do
      constant = json[:toplevel][:TestClass]
      klass = json[:modules][constant[:id].to_sym]

      method_ref = klass[:instance_methods][:public].find {|m| m[:name] == "test_method" }
      method_def = json[:methods][method_ref[:id].to_sym]

      refute_nil method_def
      assert_equal "TestClass", method_def[:owner][:name]
      assert_kind_of Array, method_def[:location]
      assert_equal [], method_def[:parameters]
    end
  end

  describe "libs" do
    it "contains required libs" do
      libs = json[:libs]
      refute_nil libs
      assert(libs.any? {|lib| Pathname(lib).basename.to_s == "tsort.rb" })
      assert(libs.any? {|lib| Pathname(lib).basename.to_s == "sample2.rb" })
    end
  end
end

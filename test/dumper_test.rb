require 'test_helper'

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

describe Defsdb::Dumper do
  let(:dumper) { $dumper }
  let(:result) { $dumper.as_json }

  before do
    unless $dumper
      $dumper = Defsdb::Dumper.new
      $dumper.run
    end
  end

  describe "toplevel constant" do
    it "contains constant" do
      entry = dumper.constants['TestConstant']

      refute_nil entry
      assert_equal 'value', entry[:type]
    end

    it "records class of constant" do
      entry = dumper.constants['TestConstant']

      assert_equal "TestClass", entry[:class][:name]
    end

    it "contains methods" do
      entry = dumper.constants['TestConstant']
      assert(entry[:methods][:public].any? {|m| m[:name] == 'test_method' })
      assert(entry[:methods][:private].any? {|m| m[:name] == 'test_private_method' })
      assert(entry[:methods][:protected].any? {|m| m[:name] == 'test_protected_method' })
    end
  end

  describe "classes" do
    it "contains class definition as constant" do
      constant = dumper.constants['TestClass']

      refute_nil constant
      assert_equal 'class', constant[:type]
      refute_nil constant[:id]
      assert_equal "TestClass", constant[:name]
    end

    it "contains class definition" do
      constant = dumper.constants['TestClass']
      klass = dumper.classes[constant[:id]]

      refute_nil klass
    end

    it "contains methods" do
      constant = dumper.constants['TestClass']
      klass = dumper.classes[constant[:id]]

      assert(klass[:methods][:public].any? {|m| m[:name] == 'test_singleton_method' })
      assert(klass[:methods][:private].any? {|m| m[:name] == 'test_private_singleton_method' })
      assert(klass[:methods][:protected].any? {|m| m[:name] == 'test_protected_singleton_method' })
    end

    it "contains instance methods" do
      constant = dumper.constants['TestClass']
      klass = dumper.classes[constant[:id]]

      assert(klass[:instance_methods][:public].any? {|m| m[:name] == 'test_method' })
      assert(klass[:instance_methods][:private].any? {|m| m[:name] == 'test_private_method' })
      assert(klass[:instance_methods][:protected].any? {|m| m[:name] == 'test_protected_method' })
    end

    it "has super class" do
      constant = dumper.constants['TestClass']
      klass = dumper.classes[constant[:id]]

      refute_nil klass[:superclass]
      assert_equal "TestSuperClass", klass[:superclass][:name]
    end

    it "has included modules" do
      constant = dumper.constants['TestClass']
      klass = dumper.classes[constant[:id]]

      assert(klass[:included_modules].any? {|m| m[:name] == "TestModule" })
    end

    it "has nested constant" do
      constant = dumper.constants['TestClass']
      klass = dumper.classes[constant[:id]]
      nested = klass[:constants]['TestConstant']

      refute_nil nested
      assert_equal 'value', nested[:type]
      assert_equal 'TestSuperClass', nested[:class][:name]
    end

    it "does not have nested constants from Object" do
      constant = dumper.constants['TestClass']
      klass = dumper.classes[constant[:id]]
      constants = klass[:constants]

      assert_nil constants['Enumerable']
    end
  end
end
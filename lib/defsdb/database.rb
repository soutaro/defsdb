module Defsdb
  class Database
    attr_reader :toplevel, :modules

    def initialize(json)
      @toplevel = {}
      @modules = {}

      @json = json

      json[:modules].each do |_, json|
        load_module(json)
      end

      json[:toplevel].each do |name, json|
        load_constant(name.to_s, json, @toplevel)
      end
    end

    def self.open(file)
      File.open(file) do |io|
        json = JSON.load(io.read, symbolize_keys: true)
        new(json)
      end
    end

    class MethodDefinition
      attr_reader :name, :owner, :location, :parameters, :instance_method, :visibility

      def initialize(name, owner, location, parameters, instance_method, visibility)
        @name = name
        @owner = owner
        @location = location
        @parameters = parameters
        @instance_method = instance_method
        @visibility = visibility
      end

      def instance_method?
        @instance_method
      end

      def singleton_method?
        !@instance_method
      end

      def inspect
        "#<Defsdb::Database::MethodDefinition:#{__id__}, name=#{name}, owner=#{owner.name}, location=#{location}, parameters=#{parameters}, instance_method=#{instance_method?}, visibility=#{visibility}>"
      end
    end

    module MethodHelper
      def defined_instance_methods
        defined_methods.select(&:instance_method?)
      end

      def defined_singleton_methods
        defined_methods.select(&:singleton_method?)
      end
    end

    class Constant
      include MethodHelper

      attr_reader :defined_methods
      attr_reader :name, :klass

      def initialize(name, klass)
        @name = name
        @klass = klass
        @defined_methods = []
      end
    end

    class Module
      include MethodHelper

      attr_reader :defined_methods
      attr_reader :id, :name, :included_modules, :ancestors, :constants

      def initialize(id, name)
        @id = id
        @name = name

        @included_modules = []
        @ancestors = []
        @constants = {}

        @defined_methods = []
      end
    end

    class Class < Module
      attr_accessor :superclass
    end

    def each_module
      if block_given?
        modules.each do |_, mod|
          yield mod
        end
      else
        Enumerator.new(self, :each_module)
      end
    end

    def each_method(&block)
      if block_given?
        each_module do |mod|
          mod.defined_methods.each &block
        end
      else
        Enumerator.new(self, :each_method)
      end
    end

    private

    def load_constant(name, json, env)
      if json[:type] == 'value'
        klass = modules[json[:class][:id]]
        constant = Constant.new(name, klass)
        env[name] = constant

        [:public, :protected, :private].each do |visibility|
          json[:methods][visibility].each do |method|
            constant.defined_methods << load_method(method, visibility, false)
          end
        end
      else
        mod = modules[json[:id]]
        env[name] = mod
      end
    end

    def load_module(json)
      id = json[:id]
      m =  @modules[id]
      return m if m

      case json[:type]
      when 'module'
        @modules[id] = mod = Module.new(json[:id], json[:name])
      when 'class'
        @modules[id] = mod = Class.new(json[:id], json[:name])
        superclass = json[:superclass]
        if superclass
          mod.superclass = load_module(find_class_definition(superclass[:id]))
        end
      end

      json[:included_modules].each do |ref|
        mod.included_modules << load_module(find_class_definition(ref[:id]))
      end

      json[:ancestors].each do |ref|
        mod.ancestors << load_module(find_class_definition(ref[:id]))
      end

      [:instance_methods, :methods].each do |key|
        [:public, :protected, :private].each do |visibility|
          json[key][visibility].each do |method|
            mod.defined_methods << load_method(method, visibility, key == :instance_methods)
          end
        end
      end

      json[:constants].each do |name, json|
        load_constant(name, json, mod.constants)
      end

      mod
    end

    def find_class_definition(id)
      @json[:modules][id]
    end

    def load_method(json, visibility, instance_method)
      MethodDefinition.new(json[:name],
                           load_module(find_class_definition(json[:owner][:id])),
                           json[:location],
                           json[:parameters],
                           instance_method,
                           visibility)
    end
  end
end

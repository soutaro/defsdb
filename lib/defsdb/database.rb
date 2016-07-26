module Defsdb
  class Database
    # Constant environment of toplevel
    # String -> Constant | Module | Class
    attr_reader :toplevel

    # Module environment of toplevel
    # String(id) -> Module | Class
    attr_reader :modules

    # Method body environment
    # String(id) -> MethodBody
    attr_reader :methods

    # Path to required libraries
    attr_reader :required_libs

    def initialize
      @toplevel = {}
      @modules = {}
      @methods = {}
      @required_libs = []
    end

    def find_method_definition(class_path, instance_method: nil, singleton_method: nil)
      raise "Cannot specify both instance_method and singleton_method" if instance_method && singleton_method
      raise "Cannot leave both instance_method and singleton_method nil" if instance_method && singleton_method

      mod = resolve_constant(class_path)
      raise "Cannot find #{class_path}" unless mod.is_a?(Module)

      mod.defined_methods.find {|method| (instance_method && method.name == instance_method) || (singleton_method && method.name == singleton_method) }
    end

    class InvalidModuleContextError < StandardError
    end

    class ConstantLookupError < StandardError
    end

    # module A
    #   module B
    #     module SomeModule
    #       x = X::Y
    #     end
    #   end
    # end
    #
    # => lookup_constant(["X", "Y"], current_module: some_module, module_context: ["A", "B"])
    #
    # x = ::A::B::C
    #
    # => lookup_constant([:root, "A", "B", "C"], current_module: nil, module_context: [])
    #
    def lookup_constant_path(path, current_module:, module_context:)
      name = path.shift

      top_mod = if name == :root
                  name = path.shift
                  lookup_constant(name, object_class, [])
                else
                  lookup_constant(name, current_module || object_class, module_context)
                end

      raise ConstantLookupError, "failed to lookup top constant #{name}" unless top_mod

      path.inject(top_mod) {|mod, name|
        lookup_constant_from_ancestors(name, mod) or raise ConstantLookupError, "#{name} is not defined in #{mod.name}"
      }
    end

    def object_class
      @object_class ||= toplevel["Object"]
    end

    def lookup_constant(name, current_module, module_context)
      # Try current_module first
      if current_module.constants.has_key?(name)
        return current_module.constants[name]
      end

      # Try nested constant
      until module_context.empty?
        mod = module_context.pop
        const = mod.constants[name]
        return const if const
      end

      # Lookup constant from ancestors
      lookup_constant_from_ancestors(name, current_module)
    end

    def lookup_constant_from_ancestors(name, mod)
      mod.ancestors.each do |m|
        c = m.constants[name]
        return c if c
      end

      nil
    end

    class MethodDefinition
      attr_reader :body, :visibility, :instance_method

      def initialize(instance_method, visibility, body)
        @body = body
        @instance_method = instance_method
        @visibility = visibility
      end

      def instance_method?
        @instance_method
      end

      def singleton_method?
        !@instance_method
      end

      def name
        body.name
      end
    end

    class MethodBody
      attr_reader :name, :owner, :location, :parameters

      def initialize(name, owner, location, parameters)
        @name = name
        @owner = owner
        @location = location
        @parameters = parameters
      end

      def inspect
        "#<Defsdb::Database::MethodBody:#{__id__}, name=#{name}, owner=#{owner.name}, location=#{location}, parameters=#{parameters}>"
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

      def inspect
        "#<Defsdb::Database::Module:#{__id__}, name=#{name}, included_modules=#{included_modules.map(&:name)}, ancestors=#{ancestors.map(&:name)}, constants=#{constants.keys}, defined_methods=#{defined_methods.map(&:name)}>"
      end
    end

    class Class < Module
      attr_accessor :superclass

      def inspect
        "#<Defsdb::Database::Class:#{__id__}, name=#{name}, superclass=#{superclass.name}, included_modules=#{included_modules.map(&:name)}, ancestors=#{ancestors.map(&:name)}, constants=#{constants.keys}, defined_methods=#{defined_methods.map(&:name)}>"
      end
    end

    def each_module
      if block_given?
        modules.each do |_, mod|
          yield mod
        end
      else
        enum_for :each_module
      end
    end

    def each_method(&block)
      if block_given?
        each_module do |mod|
          mod.defined_methods.each &block
        end
      else
        enum_for :each_method
      end
    end

    def each_method_body
      if block_given?
        methods.each do |_, body|
          yield(body)
        end
      else
        enum_for :each_method_body
      end
    end
  end
end

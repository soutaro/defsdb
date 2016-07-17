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

    def initialize(json)
      @toplevel = {}
      @modules = {}
      @methods = {}

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
        json = JSON.parse(io.read, symbolize_names: true)
        new(json)
      end
    end

    def required_scripts
      @json[:libs]
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

    def resolve_constant(path, context = [], outer_envs = [toplevel])
      if path =~ /\A::/
        context = []
      end

      context.each do |name|
        constant = outer_envs.last[name]
        if constant && constant.is_a?(Module)
          outer_envs << constant.constants
        else
          raise InvalidModuleContextError, "Could not find module #{name}"
        end
      end

      components = path.split("::").select {|s| s.length > 0 }

      constant = nil
      top_name = components.shift
      while outer_envs.size > 0
        env = outer_envs.pop
        if env.has_key?(top_name)
          constant = env[top_name]
          break
        end
      end

      return unless constant

      if components.size > 0
        env = constant.constants
        while components.size > 0
          component = components.shift

          constant = env[component]
          break unless constant
          env = constant.constants
        end
      end

      constant
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
        env[name] = load_module(find_class_definition(json[:id]))
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
        load_constant(name.to_s, json, mod.constants)
      end

      mod
    end

    def find_class_definition(id)
      @json[:modules][id.to_sym]
    end

    def load_method(ref, visibility, instance_method)
      id = ref[:id]

      unless methods[id]
        body_json = @json[:methods][id.to_sym]

        parameters = body_json[:parameters].map {|param|
          param.map {|x|
            if x.is_a?(String)
              x.to_sym
            else
              x
            end
          }
        }

        methods[id] = MethodBody.new(body_json[:name],
                                     load_module(find_class_definition(body_json[:owner][:id])),
                                     body_json[:location],
                                     parameters)
      end

      MethodDefinition.new(instance_method, visibility, methods[ref[:id]])
    end
  end
end

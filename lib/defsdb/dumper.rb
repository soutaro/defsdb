module Defsdb
  class Dumper
    attr_reader :toplevel
    attr_reader :modules
    attr_reader :methods

    def initialize
      @modules = {}
      @toplevel = {}
      @methods = {}
    end

    def dump_constant(name, constant, env)
      if constant.is_a?(Module)
        env[name] = {
          type: const_type(constant),
          name: constant.name,
          id: constant.__id__.to_s
        }

        dump_module(constant)
      else
        dump_module(constant.class)

        env[name] = {
          type: const_type(constant),
          class: module_ref(constant.class),
          methods: {
            public: dump_methods(constant.public_methods) {|name| constant.method(name) },
            private: dump_methods(constant.private_methods) {|name| constant.method(name) },
            protected: dump_methods(constant.protected_methods) {|name| constant.method(name) }
          }
        }
      end
    end

    def dump_module(klass)
      id = klass.__id__.to_s

      return if @modules[id]

      hash =  {
        type: const_type(klass),
        name: klass.name,
        id: id
      }
      @modules[id] = hash

      if klass.is_a?(Class)
        if klass.superclass
          hash[:superclass] = module_ref(klass.superclass)
          dump_module(klass.superclass)
        end
      end

      hash[:included_modules] = klass.included_modules.map {|mod|
        dump_module(mod)
        module_ref(mod)
      }

      hash[:ancestors] = klass.ancestors.map {|mod|
        dump_module(mod)
        module_ref(mod)
      }

      hash[:instance_methods] = {
        public: dump_methods(klass.public_instance_methods) {|name| klass.instance_method(name) },
        private: dump_methods(klass.private_instance_methods) {|name| klass.instance_method(name) },
        protected: dump_methods(klass.protected_instance_methods) {|name| klass.instance_method(name) }
      }

      hash[:methods] = {
        public: dump_methods(klass.public_methods) {|name| klass.method(name) },
        private: dump_methods(klass.private_methods) {|name| klass.method(name) },
        protected: dump_methods(klass.protected_methods) {|name| klass.method(name) }
      }

      hash[:constants] = klass.constants(false).each.with_object({}) do |name, env|
        safely_get_constant(klass, name) do |constant|
          dump_constant(name, constant, env)
        end
      end
    end

    def module_ref(klass)
      {
        id: klass.__id__.to_s,
        name: klass.name
      }
    end

    def const_type(constant)
      case constant
      when Class
        :class
      when Module
        :module
      else
        :value
      end.to_s
    end

    def dump_methods(methods)
      methods.map do |name|
        method = yield(name)
        dump_module(method.owner)

        id = "#{method.owner.__id__}:#{method.owner.name}:#{method.name}"

        @methods[id] ||= {
          id: id,
          name: name.to_s,
          location: method.source_location,
          owner: module_ref(method.owner),
          parameters: method.parameters
        }

        {
          id: id,
          name: name.to_s
        }
      end
    end

    def safely_get_constant(mod, name)
      constant = nil

      begin
        unless mod.autoload?(name)
          constant = mod.const_get(name)
        end
      rescue NameError
        return nil
      end

      yield constant
    end

    def as_json
      {
        modules: @modules,
        toplevel: @toplevel,
        methods: @methods,
        libs: $"
      }
    end

    def run
      ::Object.constants.each do |name|
        safely_get_constant(::Object, name) do |constant|
          dump_constant(name, constant, @toplevel) if constant
        end
      end

      self
    end

    def dump
      Pathname(ENV["DEFSDB_DATABASE_NAME"] || "defs_database.json").open('w') do |io|
        io.write(run.as_json.to_json)
      end
    end
  end
end

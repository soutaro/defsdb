module Defsdb
  class Dumper
    attr_reader :classes
    attr_reader :constants
    attr_reader :methods

    def initialize
      @classes = {}
      @constants = {}
      @methods = {}
    end

    def dump_constant(name, constant, env)
      if constant.is_a?(Module)
        env[name] = {
          type: const_type(constant),
          name: constant.name,
          id: constant.__id__
        }

        dump_class(constant)
      else
        dump_class(constant.class)

        env[name] = {
          type: const_type(constant),
          class: class_ref(constant.class),
          methods: {
            public: dump_methods(constant.public_methods(false)) {|name| constant.method(name) },
            private: dump_methods(constant.private_methods(false)) {|name| constant.method(name) },
            protected: dump_methods(constant.protected_methods(false)) {|name| constant.method(name) }
          }
        }
      end
    end

    def dump_class(klass)
      id = klass.__id__

      return if @classes[id]

      hash =  {
        type: const_type(klass),
        name: klass.name,
        id: id
      }
      @classes[id] = hash

      if klass.is_a?(Class)
        if klass.superclass
          hash[:superclass] = class_ref(klass.superclass)
          dump_class(klass.superclass)
        end
      end

      hash[:included_modules] = klass.included_modules.map {|mod|
        dump_class(mod)
        class_ref(mod)
      }

      hash[:ancestors] = klass.ancestors.map {|mod|
        dump_class(mod)
        class_ref(mod)
      }

      hash[:instance_methods] = {
        public: dump_methods(klass.public_instance_methods(false)) {|name| klass.instance_method(name) },
        private: dump_methods(klass.private_instance_methods(false)) {|name| klass.instance_method(name) },
        protected: dump_methods(klass.protected_instance_methods(false)) {|name| klass.instance_method(name) }
      }

      hash[:methods] = {
        public: dump_methods(klass.public_methods(false)) {|name| klass.method(name) },
        private: dump_methods(klass.private_methods(false)) {|name| klass.method(name) },
        protected: dump_methods(klass.protected_methods(false)) {|name| klass.method(name) }
      }

      hash[:constants] = klass.constants(false).each.with_object({}) do |name, env|
        safely_get_constant(klass, name) do |constant|
          dump_constant(name, constant, env)
        end
      end
    end

    def class_ref(klass)
      {
        id: klass.__id__,
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
        id = "#{method.owner.__id__}:#{method.owner.name || "--"}:#{name}"

        unless @methods[id]
          @methods[id] = {
            name: name.to_s,
            location: method.source_location,
            owner: class_ref(method.owner),
            parameters: method.parameters
          }
        end

        { name: name.to_s, id: id }
      end
    end

    def safely_get_constant(mod, name)
      constant = nil

      begin
        constant = mod.const_get(name)
      rescue NameError
        return nil
      end

      yield constant
    end

    def as_json
      {
        classes: @classes,
        toplevel: @constants,
        methods: @methods
      }
    end

    def run
      ::Object.constants.each do |name|
        safely_get_constant(::Object, name) do |constant|
          dump_constant(name, constant, @constants) if constant
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

module Defsdb
  class Database
    def self.open(file)
      File.open(file) do |io|
        json = JSON.parse(io.read, symbolize_names: true)
        new.tap do |database|
          LoadJSON.new(database, json).run
        end
      end
    end

    class LoadJSON
      attr_reader :database, :json

      def initialize(database, json)
        @database = database
        @json = json
      end

      def run
        json[:modules].each do |_, json|
          load_module(json)
        end

        json[:toplevel].each do |name, json|
          load_constant(name.to_s, json, database.toplevel)
        end

        json[:libs].each do |lib|
          database.required_libs << lib
        end
      end

      private

      def load_constant(name, json, env)
        if json[:type] == 'value'
          klass = database.modules[json[:class][:id]]
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
        m =  database.modules[id]
        return m if m

        case json[:type]
        when 'module'
          database.modules[id] = mod = Module.new(json[:id], json[:name])
        when 'class'
          database.modules[id] = mod = Class.new(json[:id], json[:name])
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
        json[:modules][id.to_sym]
      end

      def load_method(ref, visibility, instance_method)
        id = ref[:id]

        unless database.methods[id]
          body_json = json[:methods][id.to_sym]

          parameters = body_json[:parameters].map {|param|
            param.map {|x|
              if x.is_a?(String)
                x.to_sym
              else
                x
              end
            }
          }

          database.methods[id] = MethodBody.new(body_json[:name],
                                                load_module(find_class_definition(body_json[:owner][:id])),
                                                body_json[:location],
                                                parameters)
        end

        MethodDefinition.new(instance_method, visibility, database.methods[ref[:id]])
      end
    end
  end
end

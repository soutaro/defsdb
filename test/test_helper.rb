require 'defsdb'
require 'minitest/autorun'

module WithDumper
  DumpCache = {}

  def dump_data(script)
    unless DumpCache.has_key?(script)
      path = Pathname(__dir__) + "../lib"
      script_path = Pathname(__dir__) + "data" + script
      system "ruby", "-I#{path}", "-rdefsdb/autorun", script_path.to_s

      db_path = Pathname("defs_database.json")
      json = JSON.parse(db_path.read, symbolize_names: true)

      db_path.unlink

      DumpCache[script] = json
    end

    DumpCache[script]
  end
end

require "defsdb"

at_exit do
  Defsdb::Dumper.new.dump
end


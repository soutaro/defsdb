require_relative "lib/defsdb/version"

Gem::Specification.new do |s|
  s.name        = 'defsdb'
  s.version       = Defsdb::VERSION
  s.licenses    = ['MIT']
  s.summary     = "Ruby runtime class/method definitions database"
  s.description = "Ruby runtime class/method definitions database"
  s.authors     = ["Soutaro Matsumoto"]
  s.email       = 'matsumoto@soutaro.com'
  s.homepage    = 'https://github.com/soutaro/defsdb'

  s.files         = `git ls-files -z`.split("\x0")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_development_dependency "rake", "~> 10.0"
  s.add_development_dependency "minitest", "~> 5.8"
end

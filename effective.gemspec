# -*- encoding: utf-8 -*-
require File.expand_path('../lib/effective/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Adam Jacob"]
  gem.email         = ["adam@opscode.com"]
  gem.description   = %q{Decide which piece of data should be effective for a given block}
  gem.summary       = %q{Pick between data easily}
  gem.homepage      = "http://github.com/adamhjk/effective"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "effective"
  gem.require_paths = ["lib"]
  gem.version       = Effective::VERSION
  gem.add_development_dependency "rspec", "~> 2.8"
  gem.add_development_dependency "pry", "> 0"
  gem.add_development_dependency "redcarpet", "> 0"
  gem.add_development_dependency "yard", "> 0"
  gem.add_development_dependency "chef", ">= 0.10.8"
end

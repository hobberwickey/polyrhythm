# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'polyrhythm/version'

Gem::Specification.new do |spec|
  spec.name          = "polyrhythm"
  spec.version       = Polyrhythm::VERSION
  spec.authors       = ["Joel Weber"]
  spec.email         = ["hobberwickey@gmail.com"]

  spec.summary       = %q{Sinatra/ActiveRecord + Siren + Polymer = Polyrhythm}
  spec.description   = %q{Polyrhythm is a framework for generating a highly configurable API with the concept of users and roles baked in from your data structure - and a robust client built on Polymer to make building web app, mobile apps, or basically anything else that uses an API a breeze}
  spec.homepage      = "http://github.com/hobberwickey/polyrhythm"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  
  # if spec.respond_to?(:metadata)
  #   spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  # else
  #   raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  # end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  spec.executables   = ["polyrhythm"]
  spec.require_paths = ["lib"]

  spec.add_dependency "bundler", ["~> 1.10"]
  spec.add_dependency "rake", ["~> 10.0"]
  spec.add_dependency "activerecord", ["~> 4.0"]
  spec.add_dependency "bcrypt", ["~> 3.0"]
  spec.add_dependency "highline", ["~> 1.0"]
  spec.add_dependency "pg", ["~> 0.1"]
end

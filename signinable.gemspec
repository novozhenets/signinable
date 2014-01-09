$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "signinable/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "signinable"
  s.version     = Signinable::VERSION
  s.authors     = ["Ivan Novozhenets"]
  s.email       = ["novozhenets@gmail.com"]
  s.homepage    = "https://github.com/novozhenets/signinable"
  s.summary     = "Token based signin"
  s.description = "Allows authentication with tokens"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]

  s.add_dependency "rails", ">= 4.0.0"

  s.add_development_dependency "sqlite3"
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "capybara"
  s.add_development_dependency "guard-rspec"
  s.add_development_dependency "guard-spork"
  s.add_development_dependency "shoulda"
  s.add_development_dependency "timecop"
  s.add_development_dependency "factory_girl_rails"
  s.add_development_dependency "database_cleaner"
end

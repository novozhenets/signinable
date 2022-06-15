# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'signinable/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'signinable'
  s.version     = Signinable::VERSION
  s.authors     = ['Ivan Novozhenets']
  s.email       = ['novozhenets@gmail.com']
  s.homepage    = 'https://github.com/novozhenets/signinable'
  s.summary     = 'Token based signin'
  s.description = 'Allows authentication with tokens'

  s.required_ruby_version = '>= 2.5'

  s.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.rdoc']

  s.add_dependency 'jwt', '>= 2.4.1'
  s.add_dependency 'rails', '>= 5.0.0'

  s.add_development_dependency 'factory_bot_rails'
  s.add_development_dependency 'pry-rails'
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'timecop'

  s.test_files = Dir['spec/**/*']
  s.metadata['rubygems_mfa_required'] = 'true'
end

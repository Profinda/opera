require_relative 'lib/opera/version'

Gem::Specification.new do |spec|
  spec.name          = 'opera'
  spec.version       = Opera::VERSION
  spec.authors       = ['ProFinda Development Team']
  spec.email         = ['francisco.ruiz@profinda.com']

  spec.summary       = 'Use simple DSL language to keep your Operations clean and maintainable'
  spec.homepage      = 'https://github.com/Profinda/opera'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.3.0')

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = 'https://github.com/Profinda/opera/blob/master/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'dry-validation'
end

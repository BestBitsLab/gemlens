# frozen_string_literal: true

require_relative "lib/gemlens/version"

Gem::Specification.new do |s|
  s.name          = "gemlens"
  s.version       = Gemlens::VERSION
  s.authors       = ["Fai Wong"]
  s.email         = ["wongwf82@gmail.com"]

  s.summary     = "Track and visualize changes to your Gemfile over time."
  s.description = "GemLens is a developer tool that analyzes the history of your Gemfile using Git and presents a timeline of gem additions, removals, and version updates. It's useful for auditing dependency changes, generating changelogs, and understanding how your project's gem dependencies evolved. Built for maintainers, teams, and curious developers."
  s.license       = "MIT"
  s.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  s.homepage = "https://github.com/BestBitsLab/gemlens"
  s.metadata["source_code_uri"] = "https://github.com/BestBitsLab/gemlens"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  s.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  s.bindir        = "bin"
  s.executables   = s.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "colorize", "~> 1.1.0"
end

# frozen_string_literal: true

require_relative "lib/annotato/version"

Gem::Specification.new do |spec|
  spec.name          = "annotato"
  spec.version       = Annotato::VERSION
  spec.authors       = ["Serhii Bodnaruk"]
  spec.email         = ["sergiwez@gmail.com"]

  spec.summary       = "Adds schema info comments to your Rails models — columns, indexes, and triggers."
  spec.description   = "Annotato automatically adds or updates comments at the end of your Rails models to show schema details like columns, indexes, and PostgreSQL triggers."
  spec.homepage      = "https://github.com/serhii-bodnaruk/annotato"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"]      = spec.homepage
  spec.metadata["source_code_uri"]   = "https://github.com/serhiibodnaruk/annotato"
  spec.metadata["changelog_uri"]     = "https://github.com/serhiibodnaruk/annotato/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/}) || f.start_with?(".github")
    end
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 6.0"
end

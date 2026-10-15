# frozen_string_literal: true

require_relative "lib/jolie/version"

Gem::Specification.new do |spec|
  spec.name = "joliegg"
  spec.version = Jolie::VERSION
  spec.authors = ["Diana Islas Ocampo"]
  spec.email = "dev@hyuchia.com"
  spec.summary = "Jolie's Ruby toolkit"
  spec.description = "Jolie's Ruby libraries"
  spec.homepage = "https://github.com/joliegg/gem"
  spec.license = "Nonstandard" # Hippocratic License HL3-CL — see LICENSE.md
  spec.required_ruby_version = ">= 3.4"

  spec.files = Dir["lib/**/*.rb", "data/*.json", "LICENSE.md", "README.md"]
  spec.require_paths = ["lib"]

  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "rubygems_mfa_required" => "true"
  }
end

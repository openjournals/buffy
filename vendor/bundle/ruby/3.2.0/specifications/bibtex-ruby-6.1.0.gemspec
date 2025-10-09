# -*- encoding: utf-8 -*-
# stub: bibtex-ruby 6.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "bibtex-ruby".freeze
  s.version = "6.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Sylvester Keil".freeze]
  s.date = "2024-01-08"
  s.description = "BibTeX-Ruby is the Rubyist's swiss-army-knife for all things BibTeX. It\nincludes a parser for all common BibTeX objects (@string, @preamble,\n@comment and regular entries) and a sophisticated name parser that\ntokenizes correctly formatted names; BibTeX-Ruby recognizes BibTeX string\nreplacements, joins values containing multiple strings or variables,\nsupports cross-references, and decodes common LaTeX formatting\ninstructions to unicode; if you are in a hurry, it also allows for easy\nexport/conversion to formats such as YAML, JSON, CSL, and XML (BibTeXML).\n".freeze
  s.email = ["sylvester@keil.or.at".freeze]
  s.homepage = "http://inukshuk.github.com/bibtex-ruby".freeze
  s.licenses = ["GPL-3.0-or-later".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.4.0".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "A BibTeX parser, converter and API for Ruby.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<racc>.freeze, ["~> 1.7"])
  s.add_runtime_dependency(%q<latex-decode>.freeze, ["~> 0.0"])
end

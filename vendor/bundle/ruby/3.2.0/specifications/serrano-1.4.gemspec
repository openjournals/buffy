# -*- encoding: utf-8 -*-
# stub: serrano 1.4 ruby lib

Gem::Specification.new do |s|
  s.name = "serrano".freeze
  s.version = "1.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/sckott/serrano/issues", "changelog_uri" => "https://github.com/sckott/serrano/releases/tag/v1.4", "documentation_uri" => "https://www.rubydoc.info/gems/serrano", "homepage_uri" => "https://github.com/sckott/serrano", "source_code_uri" => "https://github.com/sckott/serrano" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Scott Chamberlain".freeze]
  s.date = "2022-03-26"
  s.description = "Low Level Ruby Client for the Crossref Search API".freeze
  s.email = "myrmecocystus@gmail.com".freeze
  s.executables = ["serrano".freeze]
  s.files = ["bin/serrano".freeze]
  s.homepage = "https://github.com/sckott/serrano".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.1".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Crossref Client".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<bundler>.freeze, ["~> 2.1", ">= 2.1.4"])
  s.add_development_dependency(%q<codecov>.freeze, ["~> 0.5.0"])
  s.add_development_dependency(%q<json>.freeze, ["~> 2.3", ">= 2.3.1"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.0", ">= 13.0.1"])
  s.add_development_dependency(%q<standard>.freeze, ["~> 1.0"])
  s.add_development_dependency(%q<simplecov>.freeze, ["~> 0.21.2"])
  s.add_development_dependency(%q<test-unit>.freeze, ["~> 3.3", ">= 3.3.6"])
  s.add_development_dependency(%q<vcr>.freeze, ["~> 6.1"])
  s.add_development_dependency(%q<webmock>.freeze, ["~> 3.14"])
  s.add_runtime_dependency(%q<faraday>.freeze, ["~> 2.2"])
  s.add_runtime_dependency(%q<faraday-follow_redirects>.freeze, ["~> 0.1.0"])
  s.add_runtime_dependency(%q<multi_json>.freeze, ["~> 1.15"])
  s.add_runtime_dependency(%q<rexml>.freeze, ["~> 3.2", ">= 3.2.5"])
  s.add_runtime_dependency(%q<thor>.freeze, ["~> 1.2", ">= 1.2.1"])
end

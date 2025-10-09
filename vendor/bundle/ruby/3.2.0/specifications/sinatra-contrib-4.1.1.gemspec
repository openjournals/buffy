# -*- encoding: utf-8 -*-
# stub: sinatra-contrib 4.1.1 ruby lib

Gem::Specification.new do |s|
  s.name = "sinatra-contrib".freeze
  s.version = "4.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "documentation_uri" => "https://www.rubydoc.info/gems/sinatra-contrib", "homepage_uri" => "http://sinatrarb.com/contrib/", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/sinatra/sinatra/tree/main/sinatra-contrib" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["https://github.com/sinatra/sinatra/graphs/contributors".freeze]
  s.date = "2024-11-20"
  s.description = "Collection of useful Sinatra extensions".freeze
  s.email = "sinatrarb@googlegroups.com".freeze
  s.homepage = "http://sinatrarb.com/contrib/".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.7.8".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Collection of useful Sinatra extensions.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<multi_json>.freeze, [">= 0.0.2"])
  s.add_runtime_dependency(%q<mustermann>.freeze, ["~> 3.0"])
  s.add_runtime_dependency(%q<rack-protection>.freeze, ["= 4.1.1"])
  s.add_runtime_dependency(%q<sinatra>.freeze, ["= 4.1.1"])
  s.add_runtime_dependency(%q<tilt>.freeze, ["~> 2.0"])
end

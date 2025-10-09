# -*- encoding: utf-8 -*-
# stub: faraday-follow_redirects 0.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "faraday-follow_redirects".freeze
  s.version = "0.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/tisba/faraday-follow_redirects/issues", "changelog_uri" => "https://github.com/tisba/faraday-follow_redirects/blob/v0.1.0/CHANGELOG.md", "documentation_uri" => "http://www.rubydoc.info/gems/faraday-follow_redirects/0.1.0", "homepage_uri" => "https://github.com/tisba/faraday-follow_redirects", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/tisba/faraday-follow_redirects", "wiki_uri" => "https://github.com/tisba/faraday-follow_redirects/wiki" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Sebastian Cohnen".freeze]
  s.date = "2022-02-24"
  s.description = "Faraday 2.x compatible extraction of FaradayMiddleware::FollowRedirects.\n".freeze
  s.email = ["tisba@users.noreply.github.com".freeze]
  s.homepage = "https://github.com/tisba/faraday-follow_redirects".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new([">= 2.6".freeze, "< 4".freeze])
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Faraday 2.x compatible extraction of FaradayMiddleware::FollowRedirects".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<faraday>.freeze, [">= 2", "< 3"])
  s.add_development_dependency(%q<bundler>.freeze, ["~> 2.0"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
  s.add_development_dependency(%q<simplecov>.freeze, ["~> 0.21.0"])
  s.add_development_dependency(%q<webmock>.freeze, ["~> 3.14.0"])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 1.25.0"])
  s.add_development_dependency(%q<rubocop-packaging>.freeze, ["~> 0.5.0"])
  s.add_development_dependency(%q<rubocop-performance>.freeze, ["~> 1.13"])
  s.add_development_dependency(%q<rubocop-rspec>.freeze, ["~> 2.8"])
end

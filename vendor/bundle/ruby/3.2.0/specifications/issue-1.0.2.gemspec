# -*- encoding: utf-8 -*-
# stub: issue 1.0.2 ruby lib

Gem::Specification.new do |s|
  s.name = "issue".freeze
  s.version = "1.0.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/xuanxu/issue/issues", "changelog_uri" => "https://github.com/xuanxu/issue/blob/main/CHANGELOG.md", "documentation_uri" => "https://www.rubydoc.info/gems/issue", "homepage_uri" => "http://github.com/xuanxu/issue", "source_code_uri" => "http://github.com/xuanxu/issue" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Juanjo Baz\u00E1n".freeze]
  s.date = "2024-06-27"
  s.description = "Receive, parse and manage GitHub webhook events for issues, PRs and issue's comments".freeze
  s.homepage = "http://github.com/xuanxu/issue".freeze
  s.licenses = ["MIT".freeze]
  s.rdoc_options = ["--main".freeze, "README.md".freeze, "--charset=UTF-8".freeze]
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Manage webhook payload for issue events".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<openssl>.freeze, ["~> 3.2"])
  s.add_runtime_dependency(%q<rack>.freeze, ["~> 3.1"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.2"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.13"])
end

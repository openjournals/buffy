source 'https://rubygems.org'

if ENV["CUSTOM_RUBY_VERSION"]
  ruby ENV["CUSTOM_RUBY_VERSION"]
end

gem 'octokit'
gem 'sinatra', '3.1.0'
gem 'sinatra-contrib', '3.1.0'
gem 'openssl'
gem 'puma'
gem 'sidekiq'
gem 'bibtex-ruby'
gem 'faraday'
gem 'faraday-retry'
gem 'serrano'
gem 'rexml'
gem 'github-linguist'
# Remove git ref once a version > 9.16 is released allowing use of latest octokit
gem 'licensee', git: 'https://github.com/licensee/licensee.git', ref: '8d95400835b'
gem 'issue'
gem 'chronic'

group :test do
  gem 'rack-test'
  gem 'rspec'
  gem 'webmock'
end

eval_gemfile './Gemfile_custom'

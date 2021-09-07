require 'yaml'
require 'erb'
require 'faraday'
require 'sidekiq'

require_relative '../lib/defaults'
require_relative '../lib/github'
require_relative '../lib/actions'
require_relative '../lib/templating'
require_relative '../lib/utilities'
require_relative '../lib/paper_file'
require_relative '../lib/doi_checker'
require_relative '../lib/logging'

class BuffyWorker
  include Sidekiq::Worker
  include Defaults
  include GitHub
  include Actions
  include Templating
  include Utilities
  include Logging

  sidekiq_options retry: false

  attr_accessor :env, :buffy_settings, :context

  def rack_environment
    ENV['RACK_ENV'] || 'test'
  end

  def path
    "tmp/#{jid}"
  end

  def cleanup
    FileUtils.rm_rf(path) if Dir.exist?(path)
  end

  def load_context_and_env(config)
    @context = OpenStruct.new(config)

    document = ERB.new(IO.read("#{File.expand_path '../../../config', __FILE__}/settings-#{rack_environment}.yml")).result
    yaml = YAML.load(document)
    @buffy_settings = yaml['buffy']

    @env = {}
    @env[:templates_path] = buffy_settings['env']['templates_path'] || default_settings[:templates_path]
    @env[:gh_access_token] = buffy_settings['env']['gh_access_token'] || default_settings[:gh_access_token]
  end

  def setup_local_repo(url, branch)
    msg_no_repo = "Downloading of the repository failed. Please make sure the URL is correct."
    msg_no_branch = "Couldn't check the bibtex because branch name is incorrect: #{branch.to_s}"

    error = clone_repo(url, path) ? nil : msg_no_repo
    (error = change_branch(branch, path) ? nil : msg_no_branch) unless error

    respond(error) if error
    error.nil?
  end
end
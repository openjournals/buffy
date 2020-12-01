require 'sinatra/indifferent_hash'

module Defaults

  # Default value for needed env settings.
  # Can be overriden from the config/settings YAML file.
  def default_settings
    @defaults ||= Sinatra::IndifferentHash[
      bot_github_user: ENV['BUFFY_BOT_GH_USER'],
      gh_access_token: ENV['BUFFY_GH_ACCESS_TOKEN'],
      gh_secret_token: ENV['BUFFY_GH_SECRET_TOKEN'],
      templates_path:  ".buffy/templates",
    ]
  end

end

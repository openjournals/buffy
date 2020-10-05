require_relative '../lib/github'

class BuffyWorker
  include Sidekiq::Worker
  include GitHub

  def path
    "tmp/#{jid}"
  end
end
require 'sidekiq'

require "#{File.expand_path '../..', __FILE__}/workers/buffy_worker.rb"
Dir["#{File.expand_path '../..', __FILE__}/workers/**/*.rb"].sort.each { |f| require f }
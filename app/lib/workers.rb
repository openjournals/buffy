require 'sidekiq'

Dir["#{File.expand_path '../..', __FILE__}/workers/**/*.rb"].sort.each { |f| require f }
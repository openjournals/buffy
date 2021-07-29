require 'logger'

module Logging
  def logger
    @logger ||= Logger.new(STDOUT)
  end
end

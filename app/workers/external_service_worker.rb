class ExternalServiceWorker < BuffyWorker
  def perform(service, locals)
    # Faraday call service[:url]
  end
end
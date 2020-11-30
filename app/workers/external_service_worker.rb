class ExternalServiceWorker < BuffyWorker

  def perform(service, locals)
    load_context_and_env(locals)

    http_method = service['method'] || 'post'
    url = service['url']
    template = nil

    headers = service['headers'] || {}

    query_parameters = service['query_params'] || {}
    service_mapping = service['mapping'] || {}
    mapped_parameters = {}

    service_mapping.each_pair do |k, v|
      mapped_parameters[k] = locals.delete(v)
    end

    parameters = {}.merge(query_parameters, mapped_parameters, locals)

    if http_method.downcase == 'get'
      response = Faraday.get(url, parameters, headers)
    else
      post_headers = {'Content-Type' => 'application/json', 'Accept' => 'application/json'}.merge(headers)
      response = Faraday.post(url, parameters.to_json, post_headers)
    end

    if response.status.between?(200, 299)
      if service['template_file']
        parsed_response = JSON.parse(response.body)
        respond_external_template(service['template_file'], parsed_response)
      else
        respond(response.body)
      end
    elsif response.status.between?(400, 599)
      respond("Error. The #{service['name']} service is currently unavailable")
    end
  end
end

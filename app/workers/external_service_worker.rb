class ExternalServiceWorker < BuffyWorker

  def perform(service, locals)
    load_context_and_settings(locals)

    http_method = service[:method] || 'post'
    url = service[:url]
    template = nil

    query_parameters = service[:query_params] || {}
    service_mapping = service[:mapping] || {}
    mapped_parameters = {}

    service[:mapping].each_pair do |k, v|
      mapped_parameters[k] = locals.delete(v)
    end

    parameters = {}.merge(query_parameters, mapped_parameters, locals)

    if http_method.downcase == 'get'
      response = Faraday.get(url, parameters)
    else
      headers = {"Content-Type" => "application/json", 'Accept' => 'application/json'}
      response = Faraday.post(url, parameters.to_json, headers)
    end

    if service[:template_file]
      parsed_response = JSON.parse(response.body)
      respond_external_template(service[:template_file], parsed_response)
    else
      respond(response)
    end
  end
end

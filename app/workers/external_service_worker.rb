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

    return true if service['silent'] == true

    if response.status.between?(200, 299)
      if service['template_file']
        parsed_response = parse_json_response(response.body)
        respond_external_template(service['template_file'], parsed_response)
      else
        respond(response.body)
      end
    elsif response.status.between?(400, 599)
      respond("Error (#{response.status}). The #{service['name']} service is currently unavailable")
    end
  end

  def parse_json_response(body)
    parsed = JSON.parse(body)
    if parsed.is_a? Array
      parsed = begin
        JSON.parse(parsed[0])
      rescue JSON::ParserError => err
        { response: parsed[0] }
      end
    end
    parsed
  end
end

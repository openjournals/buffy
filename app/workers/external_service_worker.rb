class ExternalServiceWorker < BuffyWorker

  def perform(service, locals)
    load_context_and_env(locals)

    http_method = service['method'] || 'post'
    url = service['url']
    headers = service['headers'] || {}
    actions_on_success = service['on_success'] || {}
    template = nil

    return true if url.to_s.strip.empty?

    query_parameters = service['query_params'] || {}
    service_mapping = service['mapping'] || {}
    inputs_from_issue = service['data_from_issue'] || {}
    mapped_parameters = {}

    inputs_from_issue.each do |input_from_issue|
      mapped_parameters[input_from_issue] = locals[input_from_issue].to_s
    end

    service_mapping.each_pair do |k, v|
      mapped_parameters[k] = locals.delete(v)
    end

    parameters = {}.merge(query_parameters, mapped_parameters)

    if http_method.downcase == 'get'
      response = Faraday.get(url, parameters, headers)
    else
      post_headers = {'Content-Type' => 'application/json', 'Accept' => 'application/json'}.merge(headers)
      response = Faraday.post(url, parameters.to_json, post_headers)
    end

    if response.status.between?(200, 299)
      if service['silent'] == true
      elsif service['template_file']
        parsed_response = parse_json_response(response.body)
        respond_external_template(service['template_file'], parsed_response)
      else
        respond(response.body)
      end

      if service['add_labels'] && service['add_labels'].is_a?(Array)
        labels_to_add = service['add_labels'].uniq.compact
        label_issue(labels_to_add) unless labels_to_add.empty?
      end
      if service['remove_labels'] && service['remove_labels'].is_a?(Array)
        labels_to_remove = service['remove_labels'].uniq.compact
        labels_to_remove.each{|label| unlabel_issue(label)} unless labels_to_remove.empty?
      end
      close_issue if service['close'] == true

    elsif response.status.between?(400, 599)
      if service['silent'] == true
      elsif service['error_msg']
        respond(service['error_msg'])
      else
        respond("Error (#{response.status}). The #{service['name'].to_s} service is currently unavailable")
      end
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

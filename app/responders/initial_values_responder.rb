require_relative "../lib/responder"

class InitialValuesResponder < Responder

  keyname :initial_values

  def define_listening
    required_params :values

    @event_action = "issues.opened"
    @event_regex = nil
  end

  def process_message(message)
    parsed_values = []

    params[:values].each do |value|
      parsed_values << parse_value(value)
    end

    prepend_texts = []
    append_texts = []
    empty = []

    parsed_values.compact.each do |v|
      value_name = v[:value_name]

      if v[:warn_if_empty] && read_value_from_body(value_name).empty?
        empty << value_name
      end

      unless issue_body_has?(value_name)
        new_text = new_content(v[:heading], value_name, v[:value])
        if v[:action] == "prepend"
          prepend_texts << new_text
        else
          append_texts << new_text
        end
      end
    end

    prepend_block = prepend_texts.empty? ? nil : prepend_texts.join("\n")
    append_block = append_texts.empty? ? nil : append_texts.join("\n")

    if prepend_block || append_block
      new_body [prepend_block, issue_body, append_block].compact.join("\n")
    end

    unless empty.empty?
      respond("Missing values: #{empty.join(', ')}")
    end
  end

  def parse_value(v)
    if v.kind_of?(String)
      value_name = v.strip
      default_change_for(value_name)
    elsif v.kind_of?(Hash)
      value_name = v.keys.first.to_s
      change_for(value_name, v.values.first)
    end
  end

  def new_content(value_heading, value_name, value)
    "#{value_heading} <!--#{value_name}-->#{value}<!--end-#{value_name}-->".strip
  end

  def default_heading(value_name)
    "**#{value_name.capitalize.gsub(/[_-]/, " ")}:**"
  end

  def default_change_for(value_name)
    Sinatra::IndifferentHash[
      value_name: value_name,
      action: "prepend",
      heading: default_heading(value_name),
      value: "",
      warn_if_empty: false
    ]
  end

  def change_for(value_name, value_params)
    return default_change_for(value_name) unless value_params.is_a?(Array)

    value_params = value_params.reduce(:merge)
    changes = default_change_for(value_name).merge(value_params)
  end

  def description
    "Check issue body for presence of needed values"
  end

  def example_invocation
    "Is invoked once, when an issue is created"
  end

  def hidden?
    true
  end
end

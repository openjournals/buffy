module ResponderParams
  def sample_params(responder_class)
    n = rand(1e5)
    params_by_responder = {
      SetValueResponder => { name: "set_value_#{n}"},
      LabelCommandResponder => { command: "label_command_#{n}", labels: ["label_#{n}"] },
      CloseIssueCommandResponder => { command: "close_command_#{n}", labels: ["label_#{n}"] },
      WelcomeTemplateResponder => { template_file: "test.md" },
      ExternalServiceResponder => { name: "external_service_#{n}", command: "bot call service #{n}", url: "https://github.com/openjournals"},
    }

    params_by_responder[responder_class] || {}
  end
end

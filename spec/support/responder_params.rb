module ResponderParams
  def sample_params(responder_class)
    n = rand(1e5)
    params_by_responder = {
      SetValueResponder => { name: "set_value_#{n}"},
      LabelCommandResponder => { command: "label_command_#{n}", labels: ["label_#{n}"] },
      CloseIssueCommandResponder => { command: "close_command_#{n}", labels: ["label_#{n}"] }
    }

    params_by_responder[responder_class] || {}
  end
end
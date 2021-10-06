module ResponderParams
  def sample_params(responder_class)
    n = rand(1e5)
    params_by_responder = {
      SetValueResponder => { name: "set_value_#{n}"},
      ListOfValuesResponder => { name: "list_value_#{n}"},
      BasicCommandResponder => { command: "basic_command_#{n}" },
      LabelCommandResponder => { command: "label_command_#{n}", add_labels: ["label_#{n}"] },
      CloseIssueCommandResponder => { command: "close_command_#{n}" },
      ExternalServiceResponder => { name: "external_service_#{n}", command: "bot call service #{n}", url: "https://github.com/openjournals"},
      AddAndRemoveUserChecklistResponder => { template_file: "checklist.md" },
      ReviewerChecklistCommentResponder => { template_file: "checklist.md" },
      GithubActionResponder => { workflow_repo: "openjournals/joss-reviews", workflow_name: "compiler", command: "generate pdf" },
    }

    params_by_responder[responder_class] || {}
  end
end

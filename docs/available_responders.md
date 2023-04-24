Available Responders
====================

Buffy listens to events in the target repo using responders. Every responder is a subclass of the `Responder` class.
Each responder have a `define_listening` method where the action and/or regex the responder is listening to are defined.
The actions a responder takes if called are defined in the `process_message` method.

Buffy includes a list of Responders that can be used by configuring them in the YAML settings file.


```eval_rst
.. toctree::
   :maxdepth: 1

   responders/help
   responders/hello
   responders/basic_command
   responders/assign_editor
   responders/remove_editor
   responders/reviewers_list
   responders/invite
   responders/set_value
   responders/list_of_values
   responders/list_team_members
   responders/add_remove_assignee
   responders/reviewer_checklist_comment
   responders/add_remove_checklist
   responders/label_command
   responders/check_references
   responders/repo_checks
   responders/thanks
   responders/reminders
   responders/initial_values
   responders/welcome
   responders/goodbye
   responders/close_issue_command
   responders/update_comment
   responders/external_start_review
   responders/external_service
   responders/github_action
   responders/wrong_command
```

```eval_rst
.. toctree::
   :caption: Custom responders
   :maxdepth: 1

   responders/openjournals/ping_track_eics
   responders/openjournals/set_archive
   responders/openjournals/whedon
   responders/openjournals/reviewers_log_review_start
   responders/openjournals/reviewers_log_review_end
   responders/openjournals/reviewers_list_with_api_call
```

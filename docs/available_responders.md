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
   responders/assign_reviewer_n
   responders/remove_reviewer_n
   responders/assign_editor
   responders/remove_editor
   responders/invite
   responders/set_value
   responders/list_of_values
   responders/add_remove_assignee
   responders/reviewer_checklist_comment
   responders/add_remove_checklist
   responders/label_command
   responders/check_references
   responders/repo_checks
   responders/thanks
   responders/initial_values
   responders/welcome
   responders/close_issue_command
   responders/external_service
   responders/github_action
```

```eval_rst
.. toctree::
   :caption: Custom responders
   :maxdepth: 1

```

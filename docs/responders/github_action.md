GitHub Action
=============

This responder triggers workflow run on a GitHub Action using the GitHub API. Optionally if the call is successful (not the result of the workflow run but the call to trigger it) a reply message can be posted as a comment in the issue.
Allows [labeling](../labeling).

## Listens to

```
@botname <command>
```

For example, if you configure the command to be _compile pdf_, it will respond to:
```
@botname compile pdf
```

## Requirements

Some parameters are required for the responder to work: the `command` to invoke it, and the `workflow_repo` and `workflow_name` values to identify the action to run. All can be set using the settings YAML file.

## Settings key

`github_action`

## Params
```eval_rst
:command: *Required*. The command this responder will listen to.
:workflow_repo: *Required*. The repo to run the action on, in *org/name* format.
:workflow_name: *Required*. Name of the workflow to run.
:workflow_ref: Optional. The git ref for the GitHub action to use. Defaults to *main*.
:message: An optional message to reply with once the workflow is triggered.
:description: The description of the action this command runs. It will show in the help command if the responder is not hidden.
:inputs: *<Map>* An optional list of params/values to pass as inputs to the GitHub Action.
:data_from_issue: *<Array>* An optional list of fields from the body of the issue to pass as inputs to the GitHub Action.
:mapping: *<Map>* An optional mapping of variable names to add to the inputs.

```

## Examples

**A complete example:**
```yaml
...
  github_action:
    only: editors
    command: compile pdf
    description: Generates a PDF based on the paper.md file in the repository
    workflow_repo: openjournals/reviews
    workflow_name: compile-pdf.yml
    inputs:
      file: paper.md
    data-from-issue:
      - branch
      - target_repository
    mapping:
      repository: target_repository
      number: issue_id
...
```
Once the responder is invoked it triggers the _compile-pdf.yml_ workflow on the _openjournals/reviews_ repository passing to it the _file_, _repository_, _branch_ and _number_ inputs.

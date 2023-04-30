GitHub Action
=============

This `buffy` responder dispatches an event to trigger a GitHub Action workflow in a repository, where the workflow is defined by a `.github/workflows/*.yaml` file. If desired, upon a successful event dispatch to trigger the workflow (not the outcome of the workflow run), a reply message can be posted as a comment in the (corresponding review) issue.
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

Some parameters are required for the responder to work: the `command` to invoke it, and the `workflow_repo` and `workflow_name` values to identify the action to run. All can be set using the respective settings YAML file (e.g., `buffy/config/settings-<environment>.yml`).

## Settings key

`github_action`

## Params
```eval_rst
:command: *Required*. The command this responder will listen to.
:description: The description of the action this command runs. It will show in the help command if the responder is not hidden.
:example_invocation:  *Optional* String to show as an example of the command being used when the help command is invoked.
:workflow_repo: *Required*. The repo to run the action on, in *org/name* format.
:workflow_name: *Required*. Name of the workflow to run.
:workflow_ref: Optional. The git ref for the GitHub action to use. Defaults to *main*.
:message: An optional message to reply with once the workflow is triggered.
:inputs: *<Map>* An optional list of params/values to pass as inputs to the GitHub Action.
:data_from_issue: *<Array>* An optional list of fields from the body of the issue to pass as inputs to the GitHub Action.
:mapping: *<Map>* An optional mapping of variable names to add to the inputs.

```

You can use this action to run other responder(s) after after the GitHub action is triggered:

```eval_rst
:run_responder: Allows to call a different responder. Subparams are:

  :responder_key: *Required*. The key to find the responder in the config file.
  :responder_name: *Optional*. The name of the responder in the config file if there are several instances under the same responder key.
  :message: *Optional*. The message to trigger the responder with.

```
If you want to run multiple responders, use an array of these subparams.


## Examples

**A complete example:**

The following snippet sets up `buffy` to react to a `@editorialbot generate pdf` command issued during a `joss` review:

```yaml
...
  github_action:
    - draft_paper:
        command: generate pdf
        workflow_repo: openjournals/joss-papers
        workflow_name: draft-paper.yml
        workflow_ref: master
        description: Generates the pdf paper
        data_from_issue:
          - branch
          - target-repository
          - issue_id
        mapping:
          repository_url: target-repository
...
```

Once invoked, this `github_action` responder triggers the [_draft-paper_](https://github.com/openjournals/joss-papers/blob/main/.github/workflows/draft-paper.yml) workflow on the [_openjournals/joss-papers_](https://github.com/openjournals/joss-papers) repository (see the [actions tab](https://github.com/openjournals/joss-papers/actions)). 

The `data_from_issue` field lists the values of _branch_, _target-repository_, and _issue-id_ (which `buffy` fetches from a review issue body) that serve as input arguments for this action. The optional `mapping` field indicates that the value _target-repository_ is mapped to the _repository_url_ variable.

For additional use cases, please refer to the complete [`settings-production.yml`](https://github.com/openjournals/buffy/blob/joss/config/settings-production.yml) file located under the `joss` branch of `buffy`.

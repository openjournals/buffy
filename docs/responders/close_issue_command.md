Close issue command
===================

This responder replies to a specific command closing the issue and possibly adding some labels.
Allows [labeling](../labeling).

## Listens to

```
@botname <command>
```

For example, if you configure the command to be _reject_, it would respond to:
```
@botname reject
```

## Settings key

`close_issue_command`

## Params

```eval_rst
:command: The command this responder will listen to.
:description:  *Optional* String to show when the help command is invoked (if the responder is not hidden).
```

## Examples

**Simplest use case:**

Just close the issue.

```yaml
...
  responders:
    close_issue_command:
      command: reject
...
```

**Close issue, add labels, restrict access to editors:**
```yaml
...
  responders:
    close_issue_command:
      only: editors
      command: reject
      add_labels:
        - rejected
...
```

## In action

![](../images/responders/close_issue_command.png "Close issue command responder in action")

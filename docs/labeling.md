Labeling
========

Several Buffy responders allow labeling. A responder allowing labeling means that if the responder finish successfully its main task, it can add and/or remove labels to the issue if they are specified in the settings file.

## Settings

Responders allowing labeling will accept in their settings two keys:

```eval_rst
:add_labels: an optional Array of labels to add
:remove_labels: an optional Array of labels to remove
```

**Example:**
```yaml
...
  responders:
    example_responder:
      add_labels:
        - review-finished
        - recommend publication
      remove_labels:
        - pending-review
...
```
If the example responder is successful the `review-finished` and `recommend publication` labels will be added and the `pending-review` label will be removed from the issue.

## Responders listening to Add/Remove actions

Some responders listen to two opposite `add` and `remove` actions (for instance the [add_remove_assignee responder](./responders/add_remove_assignee)). In these cases, the add action will process the labeling normally –adding the specified `:add_labels` and removing the `:remove_labels`– and the remove action will undo that labeling, i.e. removing the `:add_labels` and adding the labels from the `:remove_labels` setting.

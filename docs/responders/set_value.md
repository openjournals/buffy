Set value
=========

This responder can be used to update the value of any field in the body of the issue.
Allows [labeling](../labeling).

## Listens to

```
@botname set <value> as <name>
```

For example, if you configure this responder to change the value of the _version_, it would respond to:
```
@botname set v1.0.3 as version
```

## Requirements

The body of the issue should have the target field placeholder marked with HTML comments.

```html
<!--<name>-->  <!--end-<name>-->
```
Following the previous example if the name of the field is _version_:
```html
<!--version-->  <!--end-version-->
```

## Settings key

`set_value`

## Params
```eval_rst
:name: *Required.* The name of the target field in the body of the issue. It can be set using the ``name:`` keyword, or via the name of each instance if there are several instances of this responder specified in the settings file.

:if_missing: *Optional* Strategy when value placeholders are not defined in the body of the issue. Valid options: `append` (will add the value at the end of the issue body), `prepend` (will add the value at the beginning of the issue body) , `error` (will reply a not-found message). If this param is not present nothing will be done if value placeholder is not found.

:aliased_as: *Optional.* The name of the value to be used in the command, in case it is different from the target field placeholder marked with HTML comments.

:heading: if the value placeholder is missing and the `if_missing` strategy is set to append or prepend, when adding the value it will include this text as heading instead of just the value name.

:sample_value: A sample value string for the target field. It is used for documentation purposes when the :doc:`Help responder <./help>` lists all available responders. Default value is **xxxxx**.

:template_file: *Optional* A template file to use to build the response message (name and value are passed to it).

:external_call: *Optional* Configuration for a external service call. All available subparams are described in the `external_service docs`_.

.. _`external_service docs`: ./external_service.html#params
```

## Examples

**Simplest use case:**
```yaml
...
  responders:
    set_value:
      name: version
      sample_value: v1.0.1
...
```

**Multiple instances of the responder, some of them restricted to editors:**
```yaml
...
  responders:
    set_value:
      - version:
          only: editors
          sample_value: "v1.0.0"
      - archive:
          only: editors
          sample_value: "10.21105/joss.12345"
          if_missing: prepend
          heading: "Archive DOI"
      - repository:
          sample_value: "github.com/openjournals/buffy"
...
```

## In action

* **`Initial state:`**

![](../images/responders/set_value_1.png "Set value responder in action: Before")

* **`Invocation:`**

![](../images/responders/set_value_2.png "Set value responder in action: Invocation")

* **`Final state:`**

![](../images/responders/set_value_3.png "Set value responder in action: After")

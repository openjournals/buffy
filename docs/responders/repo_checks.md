Repository checks
=================

This responder performs (asynchronously) several checks on the target repository.

## Listens to

```
@botname check repository
```

A non-default branch can be specified to run the checks on it:
```
@botname check repository from branch <custom-branch-name>
```

## Requirements

The body of the issue should have the url of the repository marked with HTML comments.

```html
<!--target-repository--> URL HERE <!--end-target-repository-->
```

## Settings key

`repo_checks`

## Params
```eval_rst
:checks: An optional list (Array) of checks to perform. If non present or empty all available checks will be run (see `available checks`_ for the values to use in the config file).
:url_field: The optional name of the field marked with HTML comments where the URL of the repository with the paper is located. By default if this setting is not present, the value will be **target-repository**. Meaning Buffy will look for a string in the body of the issue between **<!--target-repository-->** and **<!--end-target-repository-->** HTML comments.
:branch_field: The optional name of the field marked with HTML comments where the name of the branch is located. Defaults to **branch** (so Buffy will look for **<!--branch-->** and **<!--end-branch-->** in the body of the issue). If the setting is not present or the branch field is not found in the body of the issue, the default branch of the git repo will be used.

.. _`available checks`: #available-checks
```

## Available checks

The following values are valid for the `:checks` list:

* `repo summary`: This check performs an analysis of the source code and list authorship, contributions and file types information.
* `languages`: This will detect the languages used in the repository and tagged the issue with the top three used languages.
* `wordcount`: This will count the number of words in the paper file.
* `license`: This will look for an Open Source License in the target repo and reply an error message if no license is found.
* `statement of need`: This check will look for an *Statement of need* section in the paper content.

## Examples

**Simplest case:**
```yaml
...
  repo_checks:
...
```
Buffy will clone the git repository specified between `<!--target-repository-->` and `<!--end-target-repository-->` HTML comments and run all available checks.


**Run selected checks:**
```yaml
...
  repo_checks:
    checks:
      - repo summary
      - languages
...
```
Buffy will only run the `repo summary` and the `languages` checks.


## In action

![](../images/responders/repo_checks.png "Repository checks responder in action")


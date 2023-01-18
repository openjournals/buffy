Log start of review to Reviewers API
====================================

Everytime a Review issue is created this responder calls the Reviewers management application's API to assign a new active review to all users in the reviewers list.

## Listens to

New review issue opened event.

## Requirements

Reviewers are extracted from a reviewers-list field in the issue's body.

```html
<!--reviewers-list-->  <!--end-reviewers-list-->
```

For the Reviewers API to be called, two valiables must be present in the `env`section of the settings:
`reviewers_host_url` and `reviewers_api_token`

## Settings key

`openjournals_reviewers_start_review`


## Examples

```yaml
...
  env:
    reviewers_host_url: "https://reviewe.rs"
    reviewers_api_token: 123456789ABC
...
  responders:
    openjournals_reviewers_start_review:
...
```

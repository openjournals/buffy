# Issue
[![Gem Version](https://badge.fury.io/rb/issue.svg)](https://badge.fury.io/rb/issue)
[![Tests](https://github.com/xuanxu/issue/actions/workflows/tests.yml/badge.svg)](https://github.com/xuanxu/issue/actions/workflows/tests.yml)

Issue is a small library dedicated to parse requests coming from GitHub webhooks triggered by `issues`, `issue_comment` and `pull_request` events.

## Getting started

Depending on your project you may:

Install the gem:
```bash
$ gem install issue
```
or add it to your Gemfile:
```ruby
gem 'issue'
```

Require the gem with:
```ruby
require 'issue'
```

## Usage

The `Issue::Webhook` is used to declare and parse a GitHub webhook. At initialization it accepts a hash of configuration settings:

- **secret_token**: The GitHub secret access token for authorization
- **origin**: The repository to accept payloads from. If nil any origin will be accepted. If not nil any request from a different repository will be ignored
- **discard_sender**: The GitHub handle of a user whose events will be ignored. Usually the organization bot. If nil no user will be ignored. To ignore only specific events use a Hash where keys are usernames and values are arrays of events to ignore for that username.
- **accept_events**: An Array of GitHub event types to accept. If nil all events will be accepted.

Once it is initialized a request can be parsed passing it to the **`parse_request`** method. After verifying the request signature and checking for the configurated conditions the `parse_request` method returns a [Payload, Error] pair, where the error is nil if nothing failed, and the payload is nil if an error ocurred.

```ruby
webhook = Issue::Webhook.new(secret_token: ENV["GH_SECRET"],
                             origin: "myorg/reponame",
                             discard_sender: "myorg_bot"
                             accept_events: ["issues", "issue_comment"])

payload, error = webhook.parse_request(request)

if webhook.errored?
  head error.status, msg: error.message
else
  # do_something_based_on_the(payload)
  head 200
end

```

### The Payload object

The `Issue::Payload` object includes all the parsed information coming from the webhook request. It has the following instance methods:

- **context**: This method returns a OpenStruct with the following structure:
```ruby
  action:             # the webhook action,
  event:              # the GitHub event coming in the HTTP_X_GITHUB_EVENT request header
  issue_id:           # the issue number
  issue_title:        # issue title,
  issue_body:         # body of the issue
  issue_author:       # author of the issue
  issue_labels:       # labels of the issue
  repo:               # the full name of the origin repository
  sender:             # the login of the user triggering the webhook action
  event_action:       # a string: "event.action"
  comment_id:         # id of the comment
  comment_body:       # body of the comment
  comment_created_at: # created_at value of the comment
  comment_url:        # the html url for the comment
  raw_payload:        # a hash with the complete parsed JSON request
```
- **accesor methods** for every key in the context
- **opened?**: `true` if the action is `opened` or `reopened`
- **closed?**: `true` if the action is `closed`
- **commented?**: `true` if the action is `created`
- **edited?**: `true` if the action is `edited`
- **locked?**: `true` if the action is `locked`
- **unlocked?**: `true` if the action is `unlocked`
- **pinned?**: `true` if the action is `pinned` or `unpinned`
- **assigned?**: `true` if the action is `assigned` or `unassigned`
- **labeled?**: `true` if the action is `labeled` or `unlabeled`

## License

Released under the MIT license.

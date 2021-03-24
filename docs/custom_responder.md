Creating a custom responder
===========================

Buffy will load and make available any responder that is located in the `app/responders` directory. The simplest way to organize your responders is to add them in a subfolder inside the `responders` dir.


During this guide as an example, we'll create a simple responder to get the time.
```text
So, we add a clock.rb file to app/responders/myresponders dir.
```

## Responder structure
A responder is a ruby class containing five elements:
* **keyname**: the handle for the responder in the configuration file
* **define_listening** method: a place to declare what events the responder is listening to
* **process_message** method: the code to perform whatever the responder does
* **description** method: to add a short description of the responder for documenting purposes
* **example_invokation** method: to show users how to invoke the responder

### The Responder Ruby class
A responder object is a class inheriting from the Responder class, so you should require the Responder class located in `/lib` and create a child class.


```ruby
relative_require '../../lib/responder'

class ClockResponder < Responder

end
```

When initialized, a responder will have accessor methods for the name of the bot (`bot_name`) and for the parameters of the responder coming from the config file (`params`).

### Keyname

Using `keyname` you can define the handle for the responder to be used in the configuration file. Using a symbol is ok.

For our example we'll just use _clock_:

```ruby
relative_require '../../lib/responder'

class ClockResponder < Responder
  keyname: :clock
end
```
Now we can use the responder add to the [config.yml](./configuration) file:
```yaml
...
  responders:
    clock:
...
```

### Define listening

The `define_listening` method is the place to specify what the responder is listening to.
You can set values for two instance variables here:
* **@event_action**: the action that triggered the event the responder will listen to
* **@event_regex**: (optional) a regular expression the text body of the event (a comment or the body of an issue) should match for the responder to respond

When an event is sent from the reviews repository to Buffy, only responders that match action and regex (if present) will be run.

#### Event action
* If you are listening to creation of issues, _@event_action_ should be `"issues.opened"`.
* If you are listening to new comments, _@event_action_ should be `"issue_comment.created""`.

#### Event regex
The _@event_regex_ variable is where the syntax of every specific command is declared. If it is `nil` the responder will respond to every event that matches _@event_action_.

Inside this method you have available the name of the bot in the `@botname` instace variable and all the parameters for this responder from the config file in the `@params` instance variable.

For our example, we will be listening to comments and we want the command to be "what time is it?":
```ruby
relative_require '../../lib/responder'

class ClockResponder < Responder
  keyname: :clock

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} what time is it\?\s*\z/i
  end
end
```

#### Mandatory parameters
You can also declare inside this method, which parameters are required in the configuration using `required_params`. This will create an reader method for every required parameter.

For example, we could make the command for invoking our responder declared in the config.yml file instead that in our regex, and make it required, that way the command for our responder can be easily configured:
```ruby
relative_require '../../lib/responder'

class ClockResponder < Responder
  keyname: :clock

  def define_listening
    required_params :command

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} #{command}\s*\z/i
  end
end
```
now the command must be added to the config file or the responder will error and not run:
```yaml
...
  responders:
    clock:
      command: tell me the time
...
````

But we don't want to be too strict so, we'll allow the command to be changed but by default we'll have one. For that we'll use an auxiliary instance method:

```ruby
relative_require '../../lib/responder'

class ClockResponder < Responder
  keyname: :clock

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} #{clock_command}\s*\z/i
  end

  def clock_command
    params[:command] || "what time is it\\?"
  end
end
```


### Process message
The `process_message` method will be called if an event reaches Buffy and it matches the action and the regex in the _define_listening_ method.

This method is the place of all the custom Ruby code needed to perform whatever is the responder does.
To interact back with the reviews repository there are several methods available:
* **respond(message)**: will post a comment with the specified _message_ string
* **respond_external_template(template_name, locals)**: will post a comment using [a template](./using_templates) and passing it the _locals_ variables
* **update_body(mark, end_mark, text)**: will update the body of the issue between marks with the passed _text_
* **add_assignee(user)**: will add the passed _user_ to the issue's assignees
* **remove_assignee(user)**: will remove the passed _user_ from the issue's assignees
* **process_labeling**: will add/remove labels as specified in the responder [config params](./labeling)

If you need to access any matched data from the [_@event_regex_](#event-regex) you have them available via the `match_data` array.

For our example we'll just reply a comment with the time:
```ruby
relative_require '../../lib/responder'

class ClockResponder < Responder
  keyname: :clock

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} #{clock_command}\s*\z/i
  end

  def process_message
    respond(Time.now.strftime("The time is %H:%M:%S, today is %d-%m-%Y"))
  end

  def clock_command
    params[:command] || "what time is it\\?"
  end
end
```




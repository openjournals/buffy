Hello
=====

A simple responder to reply to user greetings.

## Listens to

```
Hi @botname
```
```
Hello @botname
```

## Settings key

`hello`

## Examples

**Simplest use case:**
```yaml
...
  responders:
    hello:
...
```

**Hidden from public commands list**
```yaml
...
  responders:
    hello:
      hidden: true
...
```
## In action

![](../images/responders/hello.png "Hello responder in action")

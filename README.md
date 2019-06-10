## Events

**Issue opened**

```
X-GitHub-Event: issues
action: opened
message: ['issue']['body']
```

**Issue closed**

```
X-GitHub-Event: issues
action: closed
```

**Issue reopened**

```
X-GitHub-Event: issues
action: reopened
```

**Issue comment**

```
X-GitHub-Event: issue_comment
action: created
message: ['comment']['body']
```

**Issue edited**

```
X-GitHub-Event: issue_comment
action: edited
message: ['comment']['body']
```

**Issue labeled**

```
X-GitHub-Event: issues
action: labeled
labels: ['labels'] <- all labels
label: ['label'] <- the label just added
```

**Issue unlabeled**

```
X-GitHub-Event: issues
action: unlabeled
labels: ['labels']
label: ['label'] <- the label just removed
```

**Issue assigned**

```
X-GitHub-Event: issues
action: assigned
labels: ['assignees'] <- all assignees
label: ['assignee'] <- the user just assigned
```

**Issue unassigned**

```
X-GitHub-Event: issues
action: unassigned
labels: ['assignees'] <- all assignees
label: ['assignee'] <- the user just unassigned
```

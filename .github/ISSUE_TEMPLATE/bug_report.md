---
name: Bug Report
about: Report a bug or unexpected behavior
title: "[BUG] "
labels: bug
assignees: ''
---

## Bug Description
A clear and concise description of the bug.

## To Reproduce
Steps to reproduce the behavior:
1. Create a connection with '...'
2. Execute query '...'
3. See error

## Expected Behavior
What you expected to happen.

## Actual Behavior
What actually happened. Include error messages if applicable.

## Code Sample
```swift
// Minimal code to reproduce the issue
let db = try SurrealDB(url: "ws://localhost:8000/rpc")
// ...
```

## Environment
- **SurrealDB Swift Client Version**: [e.g., 1.0.0]
- **Swift Version**: [e.g., 5.9]
- **Platform**: [e.g., macOS 14.0, iOS 17.0, Linux]
- **SurrealDB Server Version**: [e.g., 1.5.0]
- **Transport**: [WebSocket / HTTP]

## Additional Context
Add any other context about the problem here.

## Possible Solution
If you have suggestions on how to fix the bug, please describe them here.

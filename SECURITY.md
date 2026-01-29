# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 2.0.x   | ✅ Full support    |
| 1.0.x   | ⚠️ Critical fixes only |

## Reporting Vulnerabilities

We take security seriously. If you discover a security vulnerability, please follow these steps:

### Private Disclosure

**Please do NOT open public issues for security vulnerabilities.**

Instead, report vulnerabilities through:

1. **GitHub Security Advisories** (preferred):
   - Navigate to the [Security tab](https://github.com/yourusername/surrealdb-swift/security)
   - Click "Report a vulnerability"
   - Provide detailed information about the vulnerability

2. **Email**:
   - Send to: security@example.com
   - Include "SECURITY" in the subject line
   - Provide detailed reproduction steps

### What to Include

When reporting a vulnerability, please include:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if you have one)
- Your contact information

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Varies by severity
  - Critical: 1-7 days
  - High: 7-30 days
  - Medium: 30-90 days
  - Low: Best effort

## Known Security Considerations

### v2.0+ Security Features

1. **SQL Injection Prevention**
   - All query values are automatically parameterized
   - Identifier validation prevents injection through table/field names
   - No unsafe string interpolation in queries

2. **Token Storage**
   - Tokens stored in memory only
   - Not persisted to disk by default
   - Applications should implement secure storage (e.g., Keychain) if needed

3. **Transport Security**
   - Supports TLS for both WebSocket (`wss://`) and HTTP (`https://`)
   - Always use secure transports in production

### v1.0 Security Issues

Version 1.0.x contains known SQL injection vulnerabilities in the QueryBuilder:

```swift
// ❌ VULNERABLE (v1.0): String interpolation allows injection
db.query().where("age >= \(userInput)")  // DO NOT USE
```

**Recommendation**: Upgrade to v2.0+ immediately for production use.

## Security Best Practices

For detailed security guidelines, see:
- [Security Documentation](./Sources/SurrealDB/Documentation.docc/Articles/Security.md)
- Use type-safe parameter binding
- Use secure transports (wss://, https://)
- Implement token refresh mechanisms
- Configure appropriate timeouts
- Validate all user input

## Security Updates

Security updates will be:
- Published through GitHub Security Advisories
- Tagged with version numbers
- Documented in CHANGELOG.md
- Announced in release notes

## Acknowledgments

We appreciate responsible disclosure from security researchers. Contributors who report valid security issues will be:
- Acknowledged in release notes (unless anonymity is requested)
- Listed in SECURITY_ACKNOWLEDGMENTS.md
- Credited in the fix commit/PR

Thank you for helping keep SurrealDB Swift secure!

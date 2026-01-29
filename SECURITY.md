# Security Policy

## Reporting Vulnerabilities

We take security seriously. If you discover a security vulnerability, please follow these steps:

### Private Disclosure

**Please do NOT open public issues for security vulnerabilities.**

Instead, report vulnerabilities through:

**GitHub Security Advisories** (preferred):
- Navigate to the [Security tab](https://github.com/briannadoubt/surrealdb-swift/security)
- Click "Report a vulnerability"
- Provide detailed information about the vulnerability

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

## Security Features

### Built-In Protection

1. **SQL Injection Prevention**
   - All query values are automatically parameterized
   - Identifier validation prevents injection through table/field names
   - No unsafe string interpolation in queries
   - Type-safe query building with `ComparisonOperator` enum

2. **Token Storage**
   - Tokens stored in memory only
   - Not persisted to disk by default
   - Applications should implement secure storage (e.g., Keychain) if needed

3. **Transport Security**
   - Supports TLS for both WebSocket (`wss://`) and HTTP (`https://`)
   - Always use secure transports in production
   - Configurable timeouts prevent resource exhaustion

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

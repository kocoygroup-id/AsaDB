# Security Policy

## Supported Version

Security fixes are developed for the latest source branch and the newest
published release. Older releases may no longer receive fixes.

## Reporting a Vulnerability

Do not open a public issue for vulnerabilities that could expose data, execute
untrusted input, bypass localhost protections, corrupt storage, or compromise a
host system.

Use GitHub's private vulnerability reporting feature for this repository. When
that feature is unavailable, contact the maintainer through the GitHub
organization profile and request a private reporting channel.

Include:

- affected version and operating system;
- minimal reproduction steps;
- expected and observed behavior;
- potential impact;
- logs or a test database with all sensitive data removed.

Please allow a reasonable remediation window before public disclosure.

## Deployment Boundary

AsAPanel is designed for `127.0.0.1`. Do not expose it directly to a public
network. AsaDB is an experimental database and should not be the only copy of
important data.

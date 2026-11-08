# Security policy

DayArk stores personal information, so security and data loss reports matter.

## Report security issues privately

Please **do not** post exploits, private keys, real user databases, exported diary content, backup files or detailed reproduction steps for exploitable vulnerabilities in public issues.

If the repository supports GitHub **Private Vulnerability Reporting**, use its *Security → Report a vulnerability* option. Otherwise, contact the maintainer privately through the official GitHub profile and request a private reporting channel. Do not attach personal information until a safe channel is agreed upon.

Include the relevant DayArk version, OS, impact, how the behavior can be reproduced using fictional test data, and whether the issue concerns local storage, backup/restore, LAN sync, files or updates.

## Security considerations for contributors

- Never add telemetry, cloud uploads, or network sharing of private data without user consent and documentation.
- Preserve encrypted backup password handling and protect all portable backup formats.
- Maintain TLS certificate pinning for LAN sync. Never “fix” pairing by accepting any certificate.
- Do not commit `.env` files, credentials, Android signing material, keystores, database dumps or personal backup archives.
- Threat-model password-manager and AI features before shipping them; local-first alone does not guarantee security.

## Supported versions

Security fixes should target actively maintained, up-to-date versions of DayArk. Historic releases may contain vulnerabilities and do not automatically receive backports.

No independent security audit is claimed for the supplied source snapshot.

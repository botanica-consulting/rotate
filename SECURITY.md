# Security Policy

## Reporting a vulnerability

Please report security issues privately to **security@botanica.consulting** (or open a
[GitHub security advisory](https://github.com/botanica-consulting/rotate/security/advisories/new)).
Do not open a public issue for a suspected vulnerability.

We'll acknowledge your report, keep you updated on the fix, and credit you if you'd like once
it's resolved.

## Scope

Rotate is a local iOS app with a deliberately small attack surface:

- **No server, no backend, no API.** The app never talks to a Botanica-operated service.
- **No account, no credentials.** There is nothing to phish and no session to steal.
- **No third-party SDKs or analytics.** The only dependency is Apple's own frameworks.
- **Data at rest** lives in the app's SwiftData store on-device and, if the user is signed
  into iCloud, mirrors to **their own private CloudKit database** — readable only by that
  Apple ID. Transport and storage there are handled by Apple's CloudKit.

Relevant reports include anything that could expose or corrupt a user's local/CloudKit journal,
defeat the app's data isolation, or abuse the `loop://` / `dexcomg7://` hand-off. General Apple
platform or CloudKit issues should go to [Apple](https://security.apple.com).

## Supported versions

Rotate ships from `main`; security fixes target the latest App Store / TestFlight release.

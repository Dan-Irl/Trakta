# Security policy

## Reporting a vulnerability

Please report security problems **privately**, not in a public issue:

- on GitHub: **Security → Report a vulnerability** in this repository, or
- by email to hello@trakta.app.

You will get an answer within a week. Once a fix is out, the advisory is published and, if you like, you are credited.

## Supported versions

Only the latest release gets fixes. Updates come from GitHub releases ([trakta.app/ladda-ner](https://trakta.app/ladda-ner/)) or the store you installed from.

## In scope

- The encryption of the app's database and of `.trakta` backup files, and how their keys and passwords are handled.
- Anything that makes the app send data over the network, or exposes data to other apps on the phone.
- Restoring a crafted backup file: crashes, code execution, or data written outside the app's storage.
- The release pipeline and signing: anything that could get an APK not built by this repository's release workflow, or not signed with the release key, to users.
- The website trakta.app (for example injected scripts or a weakened Content-Security-Policy).

## Out of scope

- Wrong tax amounts: use the "Wrong amount or rule" issue form.
- Attacks that need a rooted or jailbroken phone, or a phone that is already unlocked in the attacker's hands.
- Builds that someone else made from the source code.

## Checking a download

Every official APK is signed with the release key whose certificate SHA-256 is

```
20:EE:F0:03:4B:0B:29:D6:4E:3A:25:23:B8:9C:7D:27:D6:AD:91:DD:B8:97:B0:AD:EE:DB:A2:11:AA:2F:66:3E
```

Each release lists the APK's SHA-256 checksum, and `gh attestation verify trakta.apk --repo Dan-Irl/Trakta` checks that it was built by this repository's release workflow.

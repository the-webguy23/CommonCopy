# Security policy

## Supported versions

CommonCopy is pre-release software. Security fixes currently target the latest code on the default branch.

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability. Until private GitHub vulnerability reporting is enabled, contact the repository owner privately through their GitHub profile and include:

- affected version or commit;
- reproduction steps;
- potential impact;
- any suggested mitigation.

Do not include real passwords, tokens, clipboard contents, or private phrase data in a report.

## Security boundaries

CommonCopy is not a secrets manager. The MVP stores phrases in readable local JSON. It must not be used for passwords, private keys, access tokens, authentication cookies, or recovery codes.

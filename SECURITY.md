# Security Policy

## Reporting a vulnerability

Report vulnerabilities privately through GitHub:
<https://github.com/PERMATE-GLOBAL-JSC/permate-attribution-flutter/security/advisories/new>

Do not open a public issue or pull request for a vulnerability, and do not
include credentials, tokens, or customer data in any report.

## Scope

This repository contains only the Dart API and the thin Android and iOS bridge of
the `permate_attribution` plugin. The native SDK implementations are distributed
as pinned binary dependencies and are not part of this source tree.

## Release integrity

- Published versions come only from tags `permate_attribution-v<version>` on
  `main`, built by the `publish-pubdev` workflow after approval in the `pub.dev`
  environment.
- The repository stores no pub.dev token, deploy key, or personal access token.

# Security Policy

## Supported versions

The project is currently pre-1.0 and under active development. Security fixes will be applied to the latest development line unless a release note states otherwise.

## Reporting a vulnerability

Please do not open a public issue for a suspected security vulnerability.

Instead, contact the maintainer privately at:

**md.rajib.sarwar@gmail.com**

Include:

- a clear description of the issue
- affected platform and version
- reproduction steps or proof of concept, if available
- potential impact
- any suggested mitigation

You should receive an acknowledgement within 7 days.

## Scope

Security-sensitive areas include, but are not limited to:

- local model execution boundaries
- tool invocation and permission handling
- storage of embeddings or local memory
- prompt or data leakage
- unsafe fallback to network providers
- handling of secrets, tokens, and credentials
- sandboxing of model-triggered actions

## Disclosure

Please allow reasonable time for investigation and remediation before public disclosure.

# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the module
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Releases are cut automatically by `release-please` on merge to `main`,
driven by Conventional Commit prefixes (`feat:` → minor, `fix:`/`docs:`/`chore:` → patch,
`feat!:` or `BREAKING CHANGE:` footer → major).

## [Unreleased]

### Added
- Initial module scaffold.
- KMS key with sensible fintech defaults: annual rotation, 30-day deletion
  window, symmetric SYMMETRIC_DEFAULT / ENCRYPT_DECRYPT.
- Multi-region opt-in for cross-region DR.
- Feature-flagged key policy built from `key_administrators`, `key_users`,
  `service_principals` (gated by `kms:ViaService`), and an
  `additional_policy_statements` escape hatch.
- KMS alias (with the leading `alias/` prefix added by the module).
- `examples/basic` (single workload key) and `examples/complete` (full
  surface including multi-region + admins + users + service principals).
- `tests/unit.tftest.hcl` and `tests/contract.tftest.hcl` (mock_provider,
  plan-only), and `tests/integration.tftest.hcl` (real apply on
  workflow_dispatch).

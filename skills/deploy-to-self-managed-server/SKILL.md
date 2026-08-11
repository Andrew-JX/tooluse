---
name: deploy-to-self-managed-server
description: Assess, design, and verify a secure GitHub Actions deployment from a repository to Tencent Cloud or another self-managed Ubuntu host. Use when Codex needs to replace manual deployment, review a forced-command SSH boundary, define atomic release and rollback criteria, protect server-only credentials, configure China-facing nginx/HTTPS/ICP requirements, or diagnose a failed deployment pipeline. Apply the portable security checklist to both static-artifact and full-stack deployments, but keep those implementation shapes separate.
---

# Deploy to Self-Managed Server

Use a portable security checklist to review or design deployment. Do not assume that a static artifact pipeline, a full-stack checkout, or another project's scripts can be copied unchanged.

## 1. Establish the boundary

Before mutating anything:

- Inspect repository instructions, dirty files, build and verification commands, release artifact, branch policy, existing workflows, and server-side state.
- Decide whether the release is static files or requires backend restart, database migration, server-only environment variables, or coordinated services.
- Inspect DNS, nginx, Certbot, current release location, disk, runtime ownership, and privilege boundary with read-only commands.
- Obtain explicit authority before adding GitHub Secrets, installing an SSH key, pushing, or changing production.
- Preserve current configuration and release state for rollback. Never treat a successful build as visual acceptance.

Read [references/runbook.md](references/runbook.md) before server bootstrap, China-facing compliance work, failure diagnosis, or production closeout.

## 2. Apply the portable acceptance checklist

Require every applicable item below. Design project-specific code only after the checklist is fixed.

1. Create one dedicated Ed25519 key per repository. Never place a personal or general sudo-capable private key in GitHub Actions.
2. Force a root-owned entrypoint with `command="...",restrict`. Attempt an unrelated command such as `id`; require the entrypoint to reject it.
3. Pin `known_hosts` from a separately trusted connection. Do not trust a fresh `ssh-keyscan` result during every deployment.
4. Accept only a strict, anchored release identifier. Reject malformed verbs, extra arguments, and releases outside the authorized branch or history.
5. When transporting an archive, validate every member before extraction and reject unsafe paths, links, devices, and expansion beyond defined limits.
6. Serialize production deployments and switch releases atomically at the unit appropriate to the project.
7. Prove failure rollback restores the previous runnable state. Keep database rollback separate unless a reviewed migration plan explicitly permits it.
8. Keep server-only `.env`, database credentials, provider keys, and other production secrets out of artifacts, images, logs, workflow output, and Git.
9. Make the health check distinguish the requested release from the previous release; a generic 200 response is insufficient.

Treat these as acceptance criteria, not proof that any particular implementation is correct. Exercise permission, rejection, rollback, concurrency, and secret-hygiene boundaries in an isolated environment before production.

## 3. Compare reference shapes

### Shape A — static artifact streamed over restricted SSH stdin

Reference implementation: `Andrew-JX/mj-portfolio` → `ops/` (public repository). It streams a static artifact, validates archive members, switches a `/var/www` release atomically, and checks an HTTPS content marker that every release carries.

### Shape B — full-stack activation by exact commit

Reference implementation: `Andrew-JX/FitMind_ai` → `fitmind-ai/deploy/scripts/` (public repository).

Send only a strict `deploy <sha>` command. Require the server to accept commits traceable to the authorized branch, fetch and activate the exact commit, keep server `.env` and credentials off the transport, serialize with `flock`, run migrations on the server, and roll back only images or the runnable application version without running down migrations. Exercise invalid commands, unauthorized-branch commits, rollback execution, concurrent runs, forced-key installation, duplicate entries, and invalid keys in isolation.

Require a release-specific health gate rather than a generic 200 response. Neither reference implementation proves release identity today: Shape A greps a marker present in every release, and Shape B has no release-identifying check at all. Item 9 is unmet in both; treat it as a known gap, not as a reference property to copy.

These are two real but different deployment shapes. Use them to inspect decisions and failure handling; do not copy either script set across projects without rebuilding the project-specific threat model, release unit, rollback boundary, and tests.

## 4. Implement and verify the project-specific path

Use the repository's declared build and verification commands. Add only the workflow, server entrypoint, key installer, and tests justified by that repository's release shape.

Store the dedicated private key and pinned host keys as encrypted repository Secrets without printing their values. Delete temporary private-key copies after the Secret names are visible, and confirm Git status contains no credential files.

Install the reviewed forced entrypoint through an already-trusted administrator connection. Verify its ownership and permissions, then prove the dedicated key rejects an unrelated command. Test strict release parsing, archive or checkout validation, concurrency control, failure rollback, secret exclusion, and release-specific health checking without production credentials.

## 5. Prove the first real deployment

Commit and push only when authorized. Monitor the first Actions run through completion; do not call the pipeline working because it triggered or passed the build step.

Require all of the following evidence:

- repository verification, production build, SSH setup, release activation, and release-specific health checks succeeded;
- the live service identifies the requested commit or release rather than merely returning 200;
- nginx serves HTTPS and HTTP redirects as intended;
- the previous release remains available according to the reviewed rollback design;
- temporary uploads and local credential files are absent;
- the server has exactly one matching restricted deploy-key entry;
- the local worktree is clean.

On failure, read the failed step log and inspect only release-scoped server paths. Repair the project implementation when the fault is local; update this checklist only when evidence shows a portable boundary is missing.

## 6. Report accurately

Distinguish:

- **Pipeline verified**: a real authorized release completed and the live version changed.
- **Mechanically verified**: source, syntax, isolated tests, or build checks passed without a production run.
- **Visually unverified**: the user has not inspected the deployed page.

Report the Actions run URL, commit SHA, live URL, rollback state, certificate renewal state, and any remaining compliance item. Never publish a private key, Secret value, SSH host hash, database credential, or public-security application data code.

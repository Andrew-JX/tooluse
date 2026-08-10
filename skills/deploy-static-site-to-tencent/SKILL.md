---
name: deploy-static-site-to-tencent
description: Configure and verify secure automatic deployment of a static web build from GitHub Actions to Tencent Cloud or another Ubuntu nginx server. Use when Codex needs to publish a Vite, React, Vue, or similar static site; replace manual scp deployment; create a forced-command SSH deploy key; add GitHub Actions Secrets; implement atomic release switching and rollback; configure China-facing nginx/HTTPS/ICP requirements; or diagnose a failed static-site deployment pipeline.
---

# Deploy Static Site to Tencent

Build a repeatable deployment path from a GitHub `main` push to an Ubuntu nginx document root. Keep the deploy key unable to open a shell or run arbitrary commands.

## 1. Establish the boundary

Use this skill only when the deploy artifact is static files. Stop and redesign when the release also requires a backend restart, database migration, secret material inside the artifact, or coordinated multi-service rollout.

Before mutating anything:

- Inspect repository instructions, dirty files, build command, output directory, branch, and existing workflows.
- Inspect DNS, nginx, Certbot, current document root, disk, and passwordless `sudo` with read-only commands.
- Obtain explicit authority before adding GitHub Secrets, installing an SSH key, pushing, or changing production.
- Preserve existing nginx configuration and current site as backups. Never treat a successful build as visual acceptance.

Read [references/runbook.md](references/runbook.md) before server bootstrap, China-facing compliance work, failure diagnosis, or production closeout.

## 2. Scaffold repository files

Run the bundled generator from the skill directory:

```powershell
python scripts/scaffold.py `
  --project-root E:\path\to\project `
  --site-slug example-site `
  --domain example.example.com `
  --web-root /var/www/example-site `
  --healthcheck-text "expected public marker"
```

Pass the real build and output values when they differ from `npm run build` and `dist`. The generator creates:

- `.github/workflows/deploy-tencent.yml`
- `ops/deploy-<site-slug>.sh`
- `ops/install-<site-slug>-deploy-key.sh`

It refuses to overwrite existing files unless `--force` is supplied. Review every generated diff; templates are a safe baseline, not permission to replace project-specific behavior.

## 3. Verify locally and on the server

Run the repository's declared build command. Then verify the output contains a non-empty `index.html`, an assets directory, and the configured health marker.

Upload only the generated server scripts with an already-trusted administrator connection. Run `bash -n` on Ubuntu before installing the deploy script as `root:root` mode `0755` at the forced-command path embedded by the installer.

Generate a dedicated, temporary Ed25519 key with no passphrase. Install only its public half through the generated installer. The resulting `authorized_keys` entry must include both:

```text
command="/usr/local/sbin/deploy-<site-slug>",restrict
```

Test the dedicated key by attempting an unrelated command such as `id`. The test passes only when the fixed deploy script rejects it. Do not put a normal sudo-capable SSH key into GitHub Actions.

## 4. Configure GitHub

Create these repository Secrets without printing their values:

- `TENCENT_HOST`
- `TENCENT_USER`
- `TENCENT_DEPLOY_KEY`
- `TENCENT_KNOWN_HOSTS`

Pin `TENCENT_KNOWN_HOSTS` from an already-trusted connection; do not make every run trust a fresh `ssh-keyscan` result. Prefer `gh secret set`. If API access fails and a signed-in browser is used, obtain action-time confirmation before submitting the forms.

Delete every local temporary private-key copy immediately after all four Secret names are visible in repository settings. Confirm Git status does not include a credential directory.

## 5. Prove the first real deployment

Commit and push only when authorized. Monitor the first Actions run through completion; do not call the pipeline working because it triggered or passed the build step.

Require all of the following evidence:

- dependency install, production build, artifact checks, SSH setup, upload, activation, and health check succeeded;
- the live HTML points at the new hashed asset;
- nginx serves HTTPS and HTTP redirects to HTTPS;
- a release-specific backup directory exists;
- the temporary upload file is gone;
- the server has exactly one matching restricted deploy-key entry;
- the local worktree is clean and temporary credentials no longer exist.

On failure, read the failed step log and inspect only release-scoped server paths. Repair the reusable template when the fault is generic, then rerun through a new commit or an authorized manual dispatch.

## 6. Report accurately

Distinguish:

- **Pipeline verified**: a real push completed and the live artifact changed.
- **Mechanically verified**: scaffolding, syntax, or build checks passed without a production run.
- **Visually unverified**: the user has not inspected the deployed page.

Report the Actions run URL, commit SHA, live URL, backup path, certificate renewal state, and any remaining compliance item. Never publish a private key, Secret value, SSH host hash, or public-security application data code.

# Deployment runbook

## Contents

1. Preconditions
2. Portable security boundary
3. Reference implementations
4. GitHub and server bootstrap
5. nginx, HTTPS, and China-facing compliance
6. Failure patterns
7. Closeout evidence

## 1. Preconditions

- Identify the release unit: static files, images and containers, a Git checkout, or coordinated services.
- Point DNS to the server before Certbot or public health checks.
- Run the repository's own verification and production build before any remote change.
- Inventory server runtimes, ports, nginx ownership, disk, database dependencies, and existing sites before choosing paths or commands.
- Keep server-only secrets on the server and outside the transported artifact.

## 2. Portable security boundary

Use a dedicated Ed25519 key per repository. Never reuse a personal administrator key.

Force a root-owned entrypoint with `command="...",restrict`, pin trusted host-key lines, and prove an unrelated command is rejected. Validate a strict release identifier before any checkout, extraction, migration, or process change.

Serialize deployments. Validate transported content before activation. Switch at the release unit appropriate to the project, preserve a previous runnable state, and exercise failure recovery without production credentials. Keep database rollback separate unless an independently reviewed migration design permits it.

Exclude server-only `.env`, database credentials, provider keys, and private keys from Git, artifacts, images, and logs. Require a health signal that identifies the requested release, not just service availability.

## 3. Reference implementations

### mj-portfolio: static tar over stdin

Repository: `Andrew-JX/mj-portfolio`, directory: `ops/`.

- Builds a static Vite directory and streams a compressed tar archive through restricted SSH stdin.
- Uses a strict release identifier, archive size limits, `dd iflag=fullblock`, and member validation before extraction.
- Rejects absolute paths, `..`, links, and device entries; extracts without restoring archive ownership or permissions.
- Replaces a release-scoped directory under `/var/www`, keeps a backup, validates nginx, and checks an HTTPS release marker.

Use this shape only when the deployable unit is static files and archive transfer is justified.

### FitMind_ai: full-stack deploy by exact SHA

Repository: `Andrew-JX/FitMind_ai`, directory: `fitmind-ai/deploy/scripts/`.

- Runs pnpm repository verification and production builds before sending the fixed command `deploy <github.sha>`.
- Sends no tar archive and no server `.env`; the forced entrypoint fetches and checks out the exact commit only when it belongs to `origin/main`.
- Uses `flock`, server-only database and provider credentials, migrations, Docker services, release-specific health gates, and image-only rollback without down migrations.
- Includes isolated deployment and installer tests covering invalid commands, non-main commits, rollback execution, concurrent runs, forced-key installation, duplicate handling, and invalid keys.

Use this shape only after reviewing the backend, database, image, and schema compatibility boundaries. Do not copy scripts between this project and the static implementation.

## 4. GitHub and server bootstrap

1. Back up the current nginx configuration and runnable release.
2. Run repository-declared syntax and isolated deployment tests.
3. Install the reviewed entrypoint as a root-owned executable.
4. Generate a temporary dedicated Ed25519 key and install only its public half.
5. Verify the forced key rejects `id` or another unrelated command.
6. Pin the host-key record from an already-trusted connection.
7. Add only the encrypted repository Secrets required by the reviewed workflow.
8. Delete temporary private-key files and inspect Git status before staging.
9. Push only with explicit authorization and watch the first run through its release-specific health check.

Use non-cancelling production concurrency in GitHub Actions and a server-side lock when overlapping releases could corrupt state.

## 5. nginx, HTTPS, and China-facing compliance

For a Vite/React/Vue SPA, use a specific `server_name`, a specific document root, and:

```nginx
location / {
  try_files $uri $uri/ /index.html;
}
```

Add immutable caching only for hashed/static assets; do not mark `index.html` immutable. Enable gzip once at the correct nginx scope. Always run `sudo nginx -t` before reload.

Use Certbot for HTTPS and verify `certbot.timer` is enabled and active. The displayed expiry date is the current certificate's end date; successful automatic renewal replaces it before then.

For a public mainland-China site:

- display the exact service ICP number and link to `https://beian.miit.gov.cn/`;
- include `版权所有` and the registered organizer's Chinese name when required by the filing jurisdiction;
- add a static source-visible fallback such as `<noscript>` when the visible footer is rendered only by JavaScript;
- treat a public-security application data code as private workflow data, not as the public `公网安备` number;
- publish the police record number and icon only after approval provides the actual public number.

## 6. Failure patterns

### Gzip archive ends early

For an archive-over-stdin implementation, if Python or tar reports an unexpected EOF and the sender reports a broken pipe, check whether pipe short reads consumed a byte-count limit early. The mj reference uses `dd iflag=fullblock` for this implementation-specific failure.

### GitHub API TLS timeouts

Check local `HTTP_PROXY`, `HTTPS_PROXY`, and `ALL_PROXY`. Git push may work while Actions API or Secret endpoints fail. Retry the CLI; use a signed-in browser only after confirming the exact external Secret submissions.

### Upload or server-side build is slow

Measure the active release path before restarting work. Cross-border artifact upload, registry access, and server-side dependency installation fail for different reasons; choose the release shape after measuring bandwidth, server memory, and registry reachability.

### Run succeeded but the page looks old

Read the live version marker and compare it to the requested release. Check browser cache only after confirming the server release changed. A generic 200 response does not prove activation.

### Health check failed after activation

Confirm rollback restored the previous runnable release and public traffic still reaches it. Keep failed state in a release-scoped path for diagnosis; never run a broad delete against a shared document root, checkout parent, Docker store, or database.

## 7. Closeout evidence

Record:

- repository, branch, commit SHA, Actions run URL, and conclusion;
- live domain and release-specific version marker;
- nginx syntax result, HTTPS status, and Certbot timer state;
- previous release and rollback result;
- restricted key match count;
- absence of temporary upload and local private-key files;
- visual status as user-verified or unverified.

Backups and images accumulate by design. Define an independently reviewed retention policy before automating their deletion.

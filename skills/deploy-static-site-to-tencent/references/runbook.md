# Static-site deployment runbook

## Contents

1. Preconditions
2. Security boundary
3. GitHub and server bootstrap
4. nginx, HTTPS, and China-facing compliance
5. Failure patterns
6. Closeout evidence

## 1. Preconditions

- Use an Ubuntu host with nginx, OpenSSH, Python 3, `tar`, `curl`, and passwordless `sudo` for the chosen deploy user.
- Keep the application static. Add backend orchestration only through a separate design and approval.
- Point DNS to the server before Certbot or public health checks.
- Make nginx listen on public ports while the document root stays a specific path under `/var/www/`.
- Run the repository's own build before any remote change.

## 2. Security boundary

Use a dedicated Ed25519 key per repository. Never reuse a personal administrator key.

The public key entry must force the root-owned deploy script and include `restrict`. This removes PTY, forwarding, agent forwarding, X11, and user rc while allowing only the fixed command. Test an unrelated command and require rejection.

The deploy script must:

- accept only `deploy <40-hex-sha>-<run-id>-<attempt>` from `SSH_ORIGINAL_COMMAND`;
- cap compressed and expanded sizes;
- use `dd iflag=fullblock` so short pipe reads are not miscounted as whole megabyte blocks;
- reject absolute paths, `..`, symlinks, hard links, and device entries before extraction;
- extract without owner or permission restoration;
- require `index.html`, the assets directory, and a public health marker;
- swap only release-scoped absolute paths;
- roll back when nginx validation, reload, or public health checks fail;
- remove the temporary upload file on success and failure.

GitHub Secrets hold the private key and pinned host-key lines. Do not print, commit, log, or keep temporary copies after setup.

## 3. GitHub and server bootstrap

1. Back up the current nginx file and document root.
2. Run `bash -n` on generated scripts on Ubuntu.
3. Install the deploy script as `root:root` mode `0755` under `/usr/local/sbin/`.
4. Generate a temporary Ed25519 key and upload only the public key through the installer.
5. Verify the forced key rejects `id` or another unrelated command.
6. Pin the already-trusted host-key record as `TENCENT_KNOWN_HOSTS`.
7. Add all four repository Secrets.
8. Delete temporary private-key files and inspect Git status before staging.
9. Push the workflow and watch the first run through its public health check.

The workflow serializes deployments with a concurrency group and does not cancel an in-progress production upload.

## 4. nginx, HTTPS, and China-facing compliance

For a Vite/React/Vue SPA, use a specific `server_name`, a specific `root`, and:

```nginx
location / {
  try_files $uri $uri/ /index.html;
}
```

Add immutable caching only for hashed/static asset extensions; do not mark `index.html` immutable. Enable gzip once at the correct nginx scope. Always run `sudo nginx -t` before reload.

Use Certbot for HTTPS and verify `certbot.timer` is enabled and active. The displayed expiry date is the current certificate's end date; successful automatic renewal replaces it before then.

For a public mainland-China site:

- display the exact service ICP number and link to `https://beian.miit.gov.cn/`;
- include `版权所有` and the registered organizer's Chinese name when required by the filing jurisdiction;
- add a static source-visible fallback such as `<noscript>` when the visible footer is rendered only by JavaScript;
- treat a public-security application data code as private workflow data, not as the public `公网安备` number;
- publish the police record number and icon only after approval provides the actual public number.

## 5. Failure patterns

### Gzip archive ends early

If Python or tar reports an unexpected EOF and the sender reports a broken pipe, check that the receiver uses `dd iflag=fullblock`. Without it, pipe short reads consume the `count` limit early.

### GitHub API TLS timeouts

Check local `HTTP_PROXY`, `HTTPS_PROXY`, and `ALL_PROXY`. Git push may work while Actions API or Secret endpoints fail. Retry the CLI; use a signed-in browser only after confirming the exact external Secret submissions.

### Upload is slow

Tencent lightweight instances may have low peak bandwidth, and GitHub Runner traffic can be cross-border. Measure progress by the release-scoped temporary file. Do not restart a growing upload. Consider artifact reuse or server-side Git builds only after evaluating registry access and server memory.

### Run succeeded but the page looks old

Read live `index.html` and compare its hashed asset to the build. Check browser cache only after confirming the server artifact changed. `index.html` must not have immutable caching.

### Health check failed after swap

Confirm rollback restored the previous document root and nginx still passes `nginx -t`. Keep the failed release directory for scoped diagnosis; never run a broad delete against `/var/www`.

## 6. Closeout evidence

Record:

- repository, branch, commit SHA, Actions run URL, and conclusion;
- live domain and new hashed asset;
- nginx syntax result, HTTPS status, and Certbot timer state;
- release backup path and failed-release path if any;
- restricted key match count;
- absence of temporary upload and local private-key files;
- visual status as user-verified or unverified.

Backups accumulate by design. Define an independently reviewed retention policy before automating their deletion.

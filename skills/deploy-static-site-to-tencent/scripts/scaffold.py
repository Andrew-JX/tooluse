#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path, PurePosixPath


TOKEN_PATTERN = re.compile(r"@@[A-Z0-9_]+@@")
SLUG_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]{0,62}$")
DOMAIN_PATTERN = re.compile(r"^[A-Za-z0-9](?:[A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$")
USER_PATTERN = re.compile(r"^[a-z_][a-z0-9_-]{0,31}$")


def single_line(value: str, label: str) -> str:
    if not value or "\n" in value or "\r" in value:
        raise ValueError(f"{label} must be one non-empty line")
    return value


def shell_single_quote_safe(value: str, label: str) -> str:
    single_line(value, label)
    if "'" in value:
        raise ValueError(f"{label} cannot contain a single quote")
    return value


def relative_output_dir(value: str) -> str:
    path = PurePosixPath(single_line(value, "output directory"))
    if path.is_absolute() or ".." in path.parts or str(path) in {"", "."}:
        raise ValueError("output directory must be a non-empty relative path without '..'")
    return str(path)


def absolute_web_root(value: str) -> str:
    path = PurePosixPath(single_line(value, "web root"))
    if not path.is_absolute() or ".." in path.parts or str(path) == "/var/www":
        raise ValueError("web root must be a specific absolute path")
    if not str(path).startswith("/var/www/"):
        raise ValueError("web root must stay inside /var/www/")
    return str(path)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Scaffold a restricted Tencent/nginx static-site deployment")
    parser.add_argument("--project-root", required=True, type=Path)
    parser.add_argument("--site-slug", required=True)
    parser.add_argument("--domain", required=True)
    parser.add_argument("--web-root", required=True)
    parser.add_argument("--healthcheck-text", required=True)
    parser.add_argument("--deploy-user", default="ubuntu")
    parser.add_argument("--install-command", default="npm ci")
    parser.add_argument("--build-command", default="npm run build")
    parser.add_argument("--output-dir", default="dist")
    parser.add_argument("--node-version", default="22")
    parser.add_argument("--max-archive-mb", type=int, default=25)
    parser.add_argument("--max-extracted-mb", type=int, default=32)
    parser.add_argument("--max-members", type=int, default=2000)
    parser.add_argument("--force", action="store_true")
    return parser.parse_args()


def validate(args: argparse.Namespace) -> dict[str, str]:
    if not SLUG_PATTERN.fullmatch(args.site_slug):
        raise ValueError("site slug must use lowercase letters, digits, and hyphens")
    if not DOMAIN_PATTERN.fullmatch(args.domain) or "." not in args.domain:
        raise ValueError("domain must be a hostname")
    if not USER_PATTERN.fullmatch(args.deploy_user):
        raise ValueError("deploy user must be a simple Linux username")
    if not re.fullmatch(r"\d+(?:\.\d+)?", args.node_version):
        raise ValueError("node version must be numeric")
    if not 1 <= args.max_archive_mb <= 1024:
        raise ValueError("max archive size must be between 1 and 1024 MB")
    if not 1 <= args.max_extracted_mb <= 4096:
        raise ValueError("max extracted size must be between 1 and 4096 MB")
    if not 1 <= args.max_members <= 100000:
        raise ValueError("max members must be between 1 and 100000")

    output_dir = relative_output_dir(args.output_dir)
    web_root = absolute_web_root(args.web_root)
    replacements = {
        "@@SITE_SLUG@@": args.site_slug,
        "@@DOMAIN@@": args.domain.lower(),
        "@@WEB_ROOT@@": web_root,
        "@@HEALTHCHECK_TEXT@@": shell_single_quote_safe(args.healthcheck_text, "healthcheck text"),
        "@@DEPLOY_USER@@": args.deploy_user,
        "@@INSTALL_COMMAND@@": single_line(args.install_command, "install command"),
        "@@BUILD_COMMAND@@": single_line(args.build_command, "build command"),
        "@@OUTPUT_DIR@@": output_dir,
        "@@NODE_VERSION@@": args.node_version,
        "@@MAX_ARCHIVE_MB@@": str(args.max_archive_mb),
        "@@MAX_EXTRACTED_BYTES@@": str(args.max_extracted_mb * 1024 * 1024),
        "@@MAX_MEMBERS@@": str(args.max_members),
    }
    return replacements


def render(template: Path, destination: Path, replacements: dict[str, str], force: bool) -> None:
    if destination.exists() and not force:
        raise FileExistsError(f"refusing to overwrite {destination}; pass --force after reviewing it")
    content = template.read_text(encoding="utf-8")
    for token, value in replacements.items():
        content = content.replace(token, value)
    unresolved = sorted(set(TOKEN_PATTERN.findall(content)))
    if unresolved:
        raise ValueError(f"unresolved template tokens in {template.name}: {', '.join(unresolved)}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(content, encoding="utf-8", newline="\n")


def main() -> int:
    args = parse_args()
    project_root = args.project_root.resolve()
    if not project_root.is_dir():
        raise ValueError("project root must be an existing directory")

    replacements = validate(args)
    skill_root = Path(__file__).resolve().parent.parent
    assets = skill_root / "assets"
    targets = [
        (assets / "deploy-tencent.yml.template", project_root / ".github" / "workflows" / "deploy-tencent.yml"),
        (assets / "deploy-site.sh.template", project_root / "ops" / f"deploy-{args.site_slug}.sh"),
        (assets / "install-deploy-key.sh.template", project_root / "ops" / f"install-{args.site_slug}-deploy-key.sh"),
    ]

    for template, destination in targets:
        render(template, destination, replacements, args.force)
        print(destination)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (FileExistsError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(2) from None

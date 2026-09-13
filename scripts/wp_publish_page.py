#!/usr/bin/env python3
"""wp_publish_page.py — create, update, or inspect a WordPress page over
XML-RPC against weteraniszermierki.pl.

Sibling of scripts/cloud-sql.sh: that script turned ad-hoc Supabase Management
API curl calls into a reviewed, reusable tool; this one does the same for the
XML-RPC page-publishing that was done as one-off `python3 -` here-docs during
the 2026-09-05 WordPress deployment session (see
doc/plans/prod-deployment-handover-2026-09-05.html and
doc/plans/prod-deployment-step1-handover-2026-09-05.html). Gotchas from that
session, plus one found writing this script, are encoded here rather than
left as tribal knowledge:

  1. The WP username is the account name (e.g. "Olek"), NOT the application
     password's label ("AutomatRanklista" is a label, not a user, and fails
     login with "Bledna nazwa lub haslo" — looks exactly like a bad password).
  2. The host 403s Python's default xmlrpc/urllib User-Agent. A browser-ish
     one is required.
  3. The application password contains spaces and is stored quoted in .env.
  4. xmlrpc.client.ServerProxy CANNOT be used directly. Its dumps() hardcodes
     a single-quoted `<?xml version='1.0'?>` declaration, and this host's
     security layer redirects that exact signature back to itself (HTTP 301,
     Location == the request URL) — a silent block, not an auth failure.
     curl and hand-built double-quoted XML both pass; xmlrpc.client.dumps()
     with the quote swapped afterwards also passes. This is why the
     2026-09-05 session hand-built XML instead of using the stdlib client
     class, and why this script still uses xmlrpc.client's dumps()/loads()
     for correct marshalling but posts the body itself instead of going
     through ServerProxy/Transport.

Scope: page content only (post_type=page), matching what was actually proven
to work (wp.newPost / wp.editPost / wp.getPost / wp.getPosts). Menu items are
an ordinary post type too but are deliberately NOT supported here — WordPress
stores a menu item's structure in protected _menu_item_* meta that XML-RPC
accepts on write but hides on read, so a menu item written this way cannot be
verified. Build menu items in wp-admin, per ADR-090's open items.

Usage:
  scripts/wp_publish_page.py get --slug <slug>
  WP_PUBLISH_CONFIRM=yes scripts/wp_publish_page.py create --slug <slug> \\
      --title <title> --content-file <path> [--status draft|publish]
  WP_PUBLISH_CONFIRM=yes scripts/wp_publish_page.py update --page-id <id> \\
      [--title <title>] [--content-file <path>] [--status draft|publish]

Environment:
  WP_URL, WP_USER, WP_APP_PASSWORD — read from the environment, falling back
  to .env (never echoed), same convention as cloud-sql.sh.
  WP_PUBLISH_CONFIRM=yes — required for create/update; get never needs it.
"""
import argparse
import http.client
import os
import sys
import urllib.parse
import xmlrpc.client
from typing import Any, cast

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENV_FILE = os.path.join(REPO_ROOT, ".env")
USER_AGENT = "Mozilla/5.0 (compatible; spws-wp-publish/1.0)"


def env_lookup(name: str) -> str:
    """.env wins over the shell environment, matching cloud-sql.sh: .env is
    the file a human edits to rotate a credential in this repo."""
    if os.path.isfile(ENV_FILE):
        with open(ENV_FILE, encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\r\n")
                if line.startswith(f"{name}="):
                    val = line[len(name) + 1 :].strip()
                    if len(val) >= 2 and val[0] == val[-1] and val[0] in "\"'":
                        val = val[1:-1]
                    if val:
                        return val
    return os.environ.get(name, "")


def creds() -> tuple[str, str, str]:
    wp_url = env_lookup("WP_URL")
    user = env_lookup("WP_USER")
    password = env_lookup("WP_APP_PASSWORD")
    missing = [n for n, v in (("WP_URL", wp_url), ("WP_USER", user), ("WP_APP_PASSWORD", password)) if not v]
    if missing:
        print(f"ERROR: missing {', '.join(missing)} in .env or the environment", file=sys.stderr)
        sys.exit(1)
    return wp_url, user, password


def xmlrpc_call(wp_url: str, method: str, params: tuple[Any, ...]) -> Any:
    """POST one XML-RPC call by hand. Uses xmlrpc.client for marshalling
    (dumps/loads) but not for transport — see gotcha 4 in the module
    docstring for why ServerProxy silently fails on this host."""
    endpoint = wp_url.rstrip("/") + "/xmlrpc.php"
    parsed = urllib.parse.urlsplit(endpoint)
    if not parsed.hostname:
        print(f"ERROR: could not parse a host out of WP_URL-derived endpoint {endpoint!r}", file=sys.stderr)
        sys.exit(1)
    body = xmlrpc.client.dumps(params, methodname=method)
    body = body.replace("<?xml version='1.0'?>", '<?xml version="1.0"?>', 1)
    body_bytes = body.encode("utf-8")

    conn_cls = http.client.HTTPSConnection if parsed.scheme == "https" else http.client.HTTPConnection
    conn = conn_cls(parsed.hostname, parsed.port, timeout=30)
    try:
        conn.request(
            "POST",
            parsed.path or "/xmlrpc.php",
            body=body_bytes,
            headers={
                "User-Agent": USER_AGENT,
                "Content-Type": "text/xml",
                "Content-Length": str(len(body_bytes)),
            },
        )
        resp = conn.getresponse()
        data = resp.read()
    finally:
        conn.close()

    if resp.status != 200:
        print(f"ERROR: XML-RPC HTTP {resp.status} {resp.reason} calling {method}", file=sys.stderr)
        print(data[:500].decode("utf-8", "replace"), file=sys.stderr)
        sys.exit(1)

    try:
        result, _ = xmlrpc.client.loads(data.decode("utf-8"))
    except xmlrpc.client.Fault as fault:
        print(f"ERROR: XML-RPC fault {fault.faultCode} calling {method}: {fault.faultString}", file=sys.stderr)
        sys.exit(1)
    return result[0] if result else None


def _expect_list(value: Any, what: str) -> list[dict[str, Any]]:
    # The WP API contract guarantees a list of structs for these calls; fail
    # loudly at runtime (not just for the type checker) if that ever breaks.
    if not isinstance(value, list):
        print(f"ERROR: unexpected XML-RPC response for {what}: {value!r}", file=sys.stderr)
        sys.exit(1)
    return cast("list[dict[str, Any]]", value)


def _expect_dict(value: Any, what: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        print(f"ERROR: unexpected XML-RPC response for {what}: {value!r}", file=sys.stderr)
        sys.exit(1)
    return cast("dict[str, Any]", value)


def require_confirm(action: str, target: str):
    if os.environ.get("WP_PUBLISH_CONFIRM") != "yes":
        print(f"About to {action} on {target}.", file=sys.stderr)
        print("Re-run with WP_PUBLISH_CONFIRM=yes to proceed.", file=sys.stderr)
        sys.exit(2)


def cmd_get(args):
    wp_url, user, password = creds()
    posts = _expect_list(
        xmlrpc_call(
            wp_url,
            "wp.getPosts",
            (0, user, password, {"post_type": "page", "post_status": "any", "number": 500}),
        ),
        "wp.getPosts",
    )
    match = next((p for p in posts if p.get("post_name") == args.slug), None)
    if not match:
        print(f"No page with slug '{args.slug}' found on {wp_url}")
        return
    print(
        f"page_id={match['post_id']} status={match.get('post_status')} "
        f"title={match.get('post_title', '')!r} link={match.get('link', '')}"
    )


def cmd_create(args):
    wp_url, user, password = creds()
    require_confirm(f"CREATE page '{args.slug}' (status={args.status})", wp_url)
    content = open(args.content_file, encoding="utf-8").read()
    post = {
        "post_type": "page",
        "post_title": args.title,
        "post_name": args.slug,
        "post_content": content,
        "post_status": args.status,
    }
    post_id = xmlrpc_call(wp_url, "wp.newPost", (0, user, password, post))
    result = _expect_dict(xmlrpc_call(wp_url, "wp.getPost", (0, user, password, post_id)), "wp.getPost")
    print(
        f"Created page_id={post_id} status={result.get('post_status')} "
        f"link={result.get('link')}"
    )


def cmd_update(args):
    wp_url, user, password = creds()
    require_confirm(f"UPDATE page_id={args.page_id}", wp_url)
    fields = {}
    if args.title is not None:
        fields["post_title"] = args.title
    if args.content_file is not None:
        fields["post_content"] = open(args.content_file, encoding="utf-8").read()
    if args.status is not None:
        fields["post_status"] = args.status
    if not fields:
        print("ERROR: update needs at least one of --title, --content-file, --status", file=sys.stderr)
        sys.exit(1)
    xmlrpc_call(wp_url, "wp.editPost", (0, user, password, args.page_id, fields))
    result = _expect_dict(xmlrpc_call(wp_url, "wp.getPost", (0, user, password, args.page_id)), "wp.getPost")
    print(
        f"Updated page_id={args.page_id} status={result.get('post_status')} "
        f"link={result.get('link')}"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_get = sub.add_parser("get", help="Look up a page by slug (read-only)")
    p_get.add_argument("--slug", required=True)
    p_get.set_defaults(func=cmd_get)

    p_create = sub.add_parser("create", help="Create a new page")
    p_create.add_argument("--slug", required=True)
    p_create.add_argument("--title", required=True)
    p_create.add_argument("--content-file", required=True)
    p_create.add_argument("--status", choices=["draft", "publish"], default="draft")
    p_create.set_defaults(func=cmd_create)

    p_update = sub.add_parser("update", help="Update an existing page by id")
    p_update.add_argument("--page-id", required=True, type=int)
    p_update.add_argument("--title")
    p_update.add_argument("--content-file")
    p_update.add_argument("--status", choices=["draft", "publish"])
    p_update.set_defaults(func=cmd_update)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()

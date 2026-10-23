#!/usr/bin/env python3
"""
structure-check.py — Babel Fish
Keeps files where the repo says they go (#22).

The project map describes where things ARE. `.claude/structure.toml` says where
things SHOULD go: every approved folder, what each may hold, its lifecycle
(planned → active → deprecated), and the dev → stg → prod environments. This
script checks the tracked tree against it.

Opt-in: with no manifest it only explains the options and exits 0. The
pre-commit hook runs it only when the manifest exists.

Deliberately NOT part of generate.py: the hook runs generate.py only when code
is staged and discards its errors — a failure there could never block a commit.

Usage:
    python structure-check.py [--staged | --since REF] [--warn-only] [--project-root PATH]
    python structure-check.py --detect [--json]
    python structure-check.py --bootstrap [--layout NAME] [--mode MODE]

Exit: 0 clean (or no manifest), 1 violations, 2 unusable manifest or not a git repo.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from datetime import date
from functools import lru_cache
from pathlib import Path

try:
    import tomllib
except ImportError:  # ponytail: only this script needs 3.11; the rest of babel-fish keeps 3.8
    tomllib = None

PROJECT_ROOT = Path(__file__).parent.parent.parent
MANIFEST = PROJECT_ROOT / ".claude" / "structure.toml"
# Layout templates ship with the scripts (install.sh copies .claude/templates/).
LAYOUTS_DIR = Path(__file__).parent.parent / "templates" / "structure"

MODES = ("monorepo", "single", "multi-repo")
STATUSES = ("planned", "active", "deprecated")
TARGETS = ("local", "cloud")

# Environments. An env folder is <env_root>/<env name>/; siblings named below hold
# what every environment shares (base + overlay).
DEFAULT_ENV_ROOTS = ["infra/env", "infra/deploy"]
SHARED_ENV_DIRS = {"base", "shared", "common", "modules"}
ENV_PARENT_DIRS = {"env", "envs", "environments", "overlays", "config"}  # <parent>/<env>/ outside env_roots
MIGRATION_DIRS = {"migrations", "migration", "alembic"}
# .env files: ONE committed template (env_file, always named .env.example) holding every key for every
# environment and app, and ONE real .env beside it, gitignored. Stg/prod values come from the secret
# manager or CI, never from more files in the repo.
TEMPLATE_SUFFIXES = (".example", ".sample", ".template", ".dist")
TEMPLATE_WORDS = {"example", "sample", "template", "dist"}
# ponytail: fixed lists — extend here when a real repo needs another platform
LOCAL_ONLY = ["**/*compose*.yml", "**/*compose*.yaml", "**/seed*", "**/seeds/**",
              "**/fixtures/**", "**/*.pem", "**/*.crt", "**/*.key"]
DEPLOY_ONLY = ["**/*.tf", "**/*.tfvars", "**/*.hcl", "**/kustomization.yaml", "**/kustomization.yml",
               "**/Chart.yaml", "**/fly.toml", "**/render.yaml", "**/vercel.json", "**/railway.json"]
EMPTY_BLOB = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"  # identical empty files are not copies


def configure_paths(project_root: Path) -> None:
    """Rebind every root-derived path (#18: never set PROJECT_ROOT alone)."""
    global PROJECT_ROOT, MANIFEST
    PROJECT_ROOT = project_root
    MANIFEST = project_root / ".claude" / "structure.toml"


# ── globs ────────────────────────────────────────────────────────────────────

@lru_cache(maxsize=None)
def glob_re(pattern: str) -> re.Pattern:
    """Path glob: `*` and `?` stop at `/`, `**` crosses it, `**/` may match nothing."""
    out, i = [], 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out.append("(?:.*/)?")
            i += 3
        elif pattern.startswith("**", i):
            out.append(".*")
            i += 2
        elif pattern[i] == "*":
            out.append("[^/]*")
            i += 1
        elif pattern[i] == "?":
            out.append("[^/]")
            i += 1
        else:
            out.append(re.escape(pattern[i]))
            i += 1
    return re.compile("".join(out) + r"\Z")


def matches(path: str, patterns) -> bool:
    return any(glob_re(p).match(path) for p in patterns)


# ── git ──────────────────────────────────────────────────────────────────────

def git(*args: str) -> str:
    r = subprocess.run(["git", *args], cwd=PROJECT_ROOT, capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()}")
    return r.stdout


def is_git_repo() -> bool:
    try:
        return git("rev-parse", "--is-inside-work-tree").strip() == "true"
    except (RuntimeError, OSError):
        return False


# ── manifest ─────────────────────────────────────────────────────────────────

def load_manifest(path: Path) -> dict:
    with open(path, "rb") as f:
        m = tomllib.load(f)
    for f in m.get("folder", []):
        if isinstance(f.get("path"), str):
            f["path"] = f["path"].strip("/")
    return m


def _str_list(v) -> bool:
    return isinstance(v, list) and all(isinstance(x, str) for x in v)


def validate(m: dict) -> list[str]:
    """-> problems that make the manifest unusable (exit 2)."""
    errs = []
    if m.get("mode", "single") not in MODES:
        errs.append(f"mode = {m.get('mode')!r}; expected one of {', '.join(MODES)}")
    for key in ("root_files", "exceptions", "env_roots"):
        if key in m and not _str_list(m[key]):
            errs.append(f"{key} must be a list of strings")
    if "env_file" in m and (not isinstance(m["env_file"], str) or m["env_file"].rsplit("/", 1)[-1] != ".env.example"):
        errs.append(f"env_file = {m['env_file']!r}; must be a path to a file named .env.example")

    seen = set()
    for i, f in enumerate(m.get("folder", [])):
        where = f"[[folder]] #{i + 1}"
        p = f.get("path")
        if not isinstance(p, str) or not p:
            errs.append(f"{where}: path is required")
            continue
        where = f"[[folder]] {p}"
        if p in seen:
            errs.append(f"{where}: listed twice")
        seen.add(p)
        if f.get("status", "active") not in STATUSES:
            errs.append(f"{where}: status = {f.get('status')!r}; expected one of {', '.join(STATUSES)}")
        if "holds" in f and not _str_list(f["holds"]):
            errs.append(f"{where}: holds must be a list of glob strings")

    envs = m.get("environment", [])
    names = [e.get("name") for e in envs]
    for e in envs:
        where = f"[[environment]] {e.get('name', '?')}"
        if not isinstance(e.get("name"), str) or not e["name"]:
            errs.append(f"{where}: name is required")
        if e.get("target") not in TARGETS:
            errs.append(f"{where}: target = {e.get('target')!r}; expected one of {', '.join(TARGETS)}")
        for key in ("promotes_to", "mirrors"):
            if key in e and e[key] not in names:
                errs.append(f"{where}: {key} = {e[key]!r} is not a declared environment")
    if len(set(names)) != len(names):
        errs.append("[[environment]]: a name is declared twice")
    nxt = {e.get("name"): e.get("promotes_to") for e in envs}
    for start in nxt:
        cur, hops = start, 0
        while cur in nxt and nxt[cur] and hops <= len(nxt):
            cur, hops = nxt[cur], hops + 1
        if hops > len(nxt):
            errs.append(f"[[environment]]: promotes_to loops back through {start!r}")
            break

    for i, r in enumerate(m.get("repo", [])):
        if not isinstance(r.get("name"), str) or not r["name"]:
            errs.append(f"[[repo]] #{i + 1}: name is required")
        if not (r.get("path") or r.get("url")):
            errs.append(f"[[repo]] {r.get('name', '#' + str(i + 1))}: needs a path or a url")
    return errs


# ── checks ───────────────────────────────────────────────────────────────────

def tracked() -> dict[str, str]:
    """-> {path: blob sha} for every file in the index (what the next commit holds)."""
    out = {}
    for entry in git("ls-files", "-s", "-z").split("\0"):
        if entry:
            meta, path = entry.split("\t", 1)
            out[path] = meta.split()[1]
    return out


def added(staged: bool, since: str | None) -> set[str]:
    """-> paths new in this change: staged adds, or adds since REF (CI). Renames count as adds."""
    if staged:
        out = git("diff", "--cached", "--name-only", "--no-renames", "--diff-filter=A", "-z")
    elif since:
        try:
            out = git("diff", "--name-only", "--no-renames", "--diff-filter=A", "-z", f"{since}...HEAD")
        except RuntimeError as e:
            raise RuntimeError(f"{e} -- --since needs {since} and its merge base with HEAD; in CI fetch full "
                               "history (actions/checkout with fetch-depth: 0)") from None
    else:
        return set()
    return {p for p in out.split("\0") if p}


class Finding:
    def __init__(self, level: str, path: str, msg: str, exemptable: bool = True):
        self.level, self.path, self.msg, self.exemptable = level, path, msg, exemptable


def owner(path: str, folders: list[dict]) -> dict | None:
    """-> the deepest manifest folder containing `path` (folders pre-sorted deepest first)."""
    for f in folders:
        if path.startswith(f["path"] + "/"):
            return f
    return None


def check_folders(m: dict, files: dict[str, str], new: set[str]) -> list[Finding]:
    folders = sorted(m.get("folder", []), key=lambda f: -f["path"].count("/") - len(f["path"]))
    root_files = m.get("root_files", [])
    out, used = [], set()
    approved = {".claude/structure.toml", env_file_path(m)}  # the manifest and the one env template
    for path in sorted(files):
        if path in approved:  # declared by the manifest itself; never has to be listed again
            continue
        f = owner(path, folders)
        if f is None:
            if "/" not in path:
                if not matches(path, root_files):
                    out.append(Finding("FAIL", path, "root file not in root_files -- add it there, or move it into a folder"))
            else:
                out.append(Finding("FAIL", path, "under no manifest folder -- move it into one, or add a [[folder]] for it"))
            continue
        used.add(f["path"])
        rel = path[len(f["path"]) + 1:]
        if "holds" in f and not matches(rel, f["holds"]):
            out.append(Finding("FAIL", path, f"doesn't match {f['path']}/ holds {f['holds']} -- move it, or widen holds"))
        if f.get("status") == "deprecated" and path in new:
            out.append(Finding("FAIL", path, f"new file in deprecated folder {f['path']}/ -- put it where its replacement lives"))

    for f in folders:
        status, p = f.get("status", "active"), f["path"]
        if status == "planned" and p in used:
            out.append(Finding("WARN", p + "/", "planned folder now has files -- set status = \"active\""))
        elif status == "active" and p not in used:
            out.append(Finding("WARN", p + "/", "active folder has no tracked files -- planned, or finished retiring?"))
        elif status == "deprecated" and p not in used:
            out.append(Finding("WARN", p + "/", "deprecated folder is empty -- remove its [[folder]] entry (and the folder) in one commit"))
    return out


def env_kind(name: str) -> str | None:
    """-> "secret" (real values), "template" (keys + placeholders) or None (not an env file)."""
    if name.endswith(TEMPLATE_SUFFIXES) and (name.startswith((".env.", "env.")) or ".env." in name):
        return "template"  # .env.example, .env.prod.example, env.sample, api.env.example
    if name.endswith(".env") and name.split(".")[0] in TEMPLATE_WORDS:
        return "template"  # example.env
    if name == ".env" or name.startswith(".env.") or name.endswith(".env"):
        return "secret"    # .env, .env.local, .env.production, prod.env
    return None


def env_file_path(m: dict) -> str:
    """The one committed template: env_file, else <first env_root>/.env.example with environments, else root."""
    if m.get("env_file"):
        return m["env_file"].strip("/")
    if m.get("environment"):
        return m.get("env_roots", DEFAULT_ENV_ROOTS)[0].strip("/") + "/.env.example"
    return ".env.example"


def check_secrets(files) -> list[Finding]:
    """A real .env is never committed, in any mode; only an exact-path exception allows one."""
    out = []
    for path in files:
        if env_kind(path.rsplit("/", 1)[-1]) != "secret":
            continue
        out.append(Finding("FAIL", path, "secrets file is tracked -- git rm --cached it, keep values in "
                           "the environment or a secret manager, commit only .env.example (a committed "
                           "test fixture with no real secrets: list its exact path in exceptions)",
                           exemptable=False))
    return out


def check_env_files(m: dict, files: dict[str, str]) -> list[Finding]:
    """As close to a single .env as the structure allows: one template, one real file beside it."""
    want = env_file_path(m)
    home = want.rsplit("/", 1)[0] if "/" in want else ""
    real = f"{home}/.env" if home else ".env"
    out = check_secrets(files)
    for path in sorted(files):
        if env_kind(path.rsplit("/", 1)[-1]) != "template" or path == want:
            continue
        here = path.rsplit("/", 1)[0] if "/" in path else ""
        if here == home:
            out.append(Finding("FAIL", path, f"env template named differently -- rename it to {want}"))
        else:
            out.append(Finding("FAIL", path, f"scattered env template -- merge its keys into {want} and delete "
                               "this one (one template covers every environment and app; an app that "
                               f"expects its own .env loads {real} via --env-file / dotenv, or a symlink)"))

    # The working tree, not the index: this is what stops a real .env being committed in the first
    # place. In CI the tree is a clean checkout, so these find nothing.
    for path in git("ls-files", "--others", "--exclude-standard", "-z").split("\0"):
        if path and env_kind(path.rsplit("/", 1)[-1]) == "secret":
            out.append(Finding("FAIL", path, "real env file is not gitignored -- `git add -A` would commit it: "
                               "add `.env` and `.env.*` (with `!.env.example`) to .gitignore", exemptable=False))
    for path in git("ls-files", "--others", "--ignored", "--exclude-standard", "--directory", "-z").split("\0"):
        if path and not path.endswith("/") and path != real and env_kind(path.rsplit("/", 1)[-1]) == "secret":
            out.append(Finding("WARN", path, f"local env file outside {real} -- merge its values into {real} "
                               "and delete it (one real .env; stg/prod values live in the secret manager)"))
    return out


def check_environments(m: dict, files: dict[str, str]) -> list[Finding]:
    """dev → stg → prod: declared envs only, deltas only, stg mirrors prod, local vs cloud kept apart."""
    envs = {e["name"]: e for e in m.get("environment", [])}
    if not envs:
        return []
    roots = [r.strip("/") for r in m.get("env_roots", DEFAULT_ENV_ROOTS)]
    out, undeclared = [], set()
    env_files: dict[tuple[str, str], set[str]] = {}  # (root, env) -> paths relative to root/env
    in_env = set()

    for path in sorted(files):
        root = next((r for r in roots if path.startswith(r + "/")), None)
        parts = path.split("/")
        dirs = parts[:-1]
        if root is None:
            for i in range(1, len(dirs)):
                if dirs[i] in envs and dirs[i - 1] in ENV_PARENT_DIRS:
                    d = "/".join(dirs[:i + 1])
                    if d not in undeclared:
                        undeclared.add(d)
                        out.append(Finding("FAIL", d + "/", f"per-environment folder outside env_roots {roots} -- "
                                           f"move its deltas to <env_root>/{dirs[i]}/, or add its parent to env_roots"))
            if set(dirs) & MIGRATION_DIRS and set(dirs) & set(envs):
                out.append(Finding("FAIL", path, "per-environment migration -- migrations are shared: one folder, "
                                   "the same path forward in every environment"))
            continue
        sub = path[len(root) + 1:]
        if "/" not in sub:
            continue  # shared file directly in the env root
        env, rel = sub.split("/", 1)
        if env in SHARED_ENV_DIRS:
            continue
        if env not in envs:
            d = f"{root}/{env}"
            if d not in undeclared:
                undeclared.add(d)
                out.append(Finding("FAIL", d + "/", f"environment {env!r} is not declared -- add an [[environment]], "
                                   "or fold it into a declared one"))
            continue
        in_env.add(path)
        env_files.setdefault((root, env), set()).add(rel)
        target = envs[env]["target"]
        if target == "cloud" and matches(rel, LOCAL_ONLY):
            out.append(Finding("FAIL", path, f"local-only file in cloud environment {env!r} -- compose overrides, "
                               "seeds and local certs belong to a local environment"))
        elif target == "local" and matches(rel, DEPLOY_ONLY):
            out.append(Finding("FAIL", path, f"deploy config in local environment {env!r} -- Terraform, k8s and "
                               "platform files belong to a cloud environment"))
        if set(rel.split("/")[:-1]) & MIGRATION_DIRS:
            out.append(Finding("FAIL", path, "per-environment migration -- migrations are shared: one folder, "
                               "the same path forward in every environment"))

    for e in envs.values():
        m_env = e.get("mirrors")
        if not m_env:
            continue
        for root in roots:
            a, b = env_files.get((root, e["name"]), set()), env_files.get((root, m_env), set())
            for rel in sorted(b - a):
                out.append(Finding("FAIL", f"{root}/{e['name']}/{rel}", f"missing: {e['name']} mirrors {m_env}, "
                                   f"which has {root}/{m_env}/{rel} -- add it, or remove it from {m_env}"))
            for rel in sorted(a - b):
                out.append(Finding("FAIL", f"{root}/{m_env}/{rel}", f"missing: {e['name']} mirrors {m_env} and has "
                                   f"{root}/{e['name']}/{rel} -- add it to {m_env}, or remove it from {e['name']}"))

    shared = {sha: p for p, sha in files.items() if p not in in_env and sha != EMPTY_BLOB}
    for path in sorted(in_env):
        if files[path] in shared:
            out.append(Finding("FAIL", path, f"identical copy of {shared[files[path]]} -- an environment folder "
                               "holds only what differs; reference the shared file instead"))

    token = re.compile(r"(?<![A-Za-z0-9])(" + "|".join(map(re.escape, envs)) + r")(?![A-Za-z0-9])")
    groups: dict[str, list[str]] = {}
    for path in files:
        if path.startswith(".github/workflows/") and token.search(path):
            groups.setdefault(token.sub("{env}", path), []).append(path)
    for tmpl, paths in sorted(groups.items()):
        if len(paths) > 1:
            out.append(Finding("WARN", tmpl, f"per-environment workflow copies ({', '.join(sorted(paths))}) -- "
                               "prefer one workflow that takes the environment as input"))
    return out


def check_repos(m: dict) -> list[Finding]:
    out = []
    for r in m.get("repo", []):
        if r.get("path") and not (PROJECT_ROOT / r["path"] / ".git").exists():
            out.append(Finding("WARN", r["path"], f"[[repo]] {r['name']}: no git checkout here -- clone it or fix the path"))
    return out


def apply_exceptions(findings: list[Finding], exceptions: list[str]) -> tuple[list[Finding], int]:
    """Drop FAILs the baseline allows; WARN on baseline entries that allow nothing anymore."""
    kept, hit, baselined = [], set(), 0
    for f in findings:
        if f.level != "FAIL":
            kept.append(f)
            continue
        # A secrets FAIL yields only to its exact path: a glob must never wave through a new .env.
        pats = [e for e in exceptions if (glob_re(e).match(f.path) if f.exemptable else e == f.path)]
        if pats:
            hit.update(pats)
            baselined += 1
        else:
            kept.append(f)
    for e in exceptions:
        if e not in hit:
            kept.append(Finding("WARN", e, "exception no longer needed -- remove it from exceptions"))
    return kept, baselined


def run(m: dict, staged: bool, since: str | None) -> int:
    """Print the report; return the number of FAILs."""
    files = tracked()
    findings = (check_folders(m, files, added(staged, since)) + check_environments(m, files)
                + check_env_files(m, files) + check_repos(m))
    hard = {f.path for f in findings if not f.exemptable}  # a secret is reported as a secret, not twice
    findings = [f for f in findings if not f.exemptable or f.path not in hard]
    findings, baselined = apply_exceptions(findings, m.get("exceptions", []))
    fails = [f for f in findings if f.level == "FAIL"]
    warns = [f for f in findings if f.level == "WARN"]

    print(f"structure-check -- .claude/structure.toml (mode: {m.get('mode', 'single')})")
    for f in fails + warns:
        print(f"  {f.level}  {f.path}  -- {f.msg.split(' -- ', 1)[0]}")
        if " -- " in f.msg:
            print(f"        fix: {f.msg.split(' -- ', 1)[1]}")
    print(f"\n{len(files)} files checked" + (f", {baselined} allowed by exceptions" if baselined else ""))
    print("OK" if not fails else f"{len(fails)} FAILED")
    return len(fails)


# ── detect + bootstrap ───────────────────────────────────────────────────────
# Facts only. Judgment (what a folder is FOR, which layout fits) is the
# structure-bootstrap skill's job; this never guesses a purpose.

WORKSPACE_FILES = ["pnpm-workspace.yaml", "turbo.json", "nx.json", "lerna.json", "go.work", "rush.json"]
PACKAGE_MANIFESTS = {"package.json", "pyproject.toml", "go.mod", "Cargo.toml"}
PACKAGE_PARENTS = {"apps", "packages", "services", "libs"}
KNOWN_ENVS = ["local", "dev", "development", "test", "qa", "uat", "stg", "stage", "staging",
              "preprod", "prod", "production"]
WORKFLOW_ENV_RE = re.compile(r"^\s*environment:\s*(?:\n\s*name:\s*)?['\"]?([A-Za-z][\w-]*)", re.M)


def all_files() -> list[str]:
    """Tracked + untracked-but-not-ignored: a brand-new repo may have nothing staged yet."""
    out = git("ls-files", "--cached", "--others", "--exclude-standard", "-z")
    return sorted({p for p in out.split("\0") if p})


def read(rel: str) -> str:
    try:
        return (PROJECT_ROOT / rel).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def sibling_repos() -> list[str]:
    try:
        return sorted(c.name for c in PROJECT_ROOT.parent.iterdir()
                      if c != PROJECT_ROOT and c.is_dir() and (c / ".git").exists())
    except OSError:
        return []


def detect_envs(files: list[str]) -> dict[str, list[str]]:
    """-> {env name: [evidence paths]} from .env.<x>, compose.<x>.yml, <env dir>/<x>/, workflow environments."""
    found: dict[str, set[str]] = {}
    for p in files:
        parts = p.split("/")
        name = parts[-1]
        hits = []
        m = re.match(r"\.env\.([a-z]+)", name) or re.match(r"(?:docker-)?compose[.-]([a-z]+)\.ya?ml$", name)
        if m:
            hits.append(m.group(1))
        if len(parts) > 1 and "compose" in parts[-2] and name.rsplit(".", 1)[0] in KNOWN_ENVS:
            hits.append(name.rsplit(".", 1)[0])  # infra/compose/dev.yml
        for i in range(1, len(parts) - 1):
            if parts[i - 1] in ENV_PARENT_DIRS | {"deploy"}:
                hits.append(parts[i])
        for h in hits:
            if h in KNOWN_ENVS:
                found.setdefault(h, set()).add(p)
        if p.startswith(".github/workflows/") and p.endswith((".yml", ".yaml")):
            for h in WORKFLOW_ENV_RE.findall(read(p)):
                found.setdefault(h, set()).add(p)
    return {k: sorted(v) for k, v in sorted(found.items(), key=lambda kv: (KNOWN_ENVS + [kv[0]]).index(kv[0]))}


def detect() -> dict:
    files = all_files()
    workspace = [w for w in WORKSPACE_FILES if w in files]
    if "package.json" in files and '"workspaces"' in read("package.json"):
        workspace.append("package.json workspaces")
    if "Cargo.toml" in files and "[workspace]" in read("Cargo.toml"):
        workspace.append("Cargo.toml [workspace]")
    packages = sorted({p.rsplit("/", 1)[0] for p in files
                       if "/" in p and p.rsplit("/", 1)[1] in PACKAGE_MANIFESTS and "node_modules/" not in p})
    grouped = [p for p in packages if p.count("/") == 1 and p.split("/")[0] in PACKAGE_PARENTS]
    siblings = sibling_repos()
    submodules = ".gitmodules" in files

    reasons = []
    if workspace:
        mode = "monorepo"
        reasons.append(f"workspace config: {', '.join(workspace)}")
    elif len(grouped) >= 2:
        mode = "monorepo"
        reasons.append(f"{len(grouped)} packages with their own manifest: {', '.join(grouped[:5])}")
    elif siblings or submodules:
        mode = "multi-repo"
    else:
        mode = "single"
        reasons.append("no workspace config, package folders or sibling repos")
    if siblings:
        reasons.append(f"{len(siblings)} sibling git repo(s) in {PROJECT_ROOT.parent.name}/ -- candidates for [[repo]] pointers")
    if submodules:
        reasons.append(".gitmodules present -- submodules are other repos; point at them with [[repo]]")

    top: dict[str, dict] = {}
    for p in files:
        if "/" in p:
            d = top.setdefault(p.split("/", 1)[0], {"files": 0, "exts": {}})
            d["files"] += 1
            ext = Path(p).suffix or "(none)"
            d["exts"][ext] = d["exts"].get(ext, 0) + 1
    top_level = [{"path": k, "files": v["files"],
                  "exts": [e for e, _ in sorted(v["exts"].items(), key=lambda kv: -kv[1])[:4]]}
                 for k, v in sorted(top.items())]
    root_files = [p for p in files if "/" not in p]
    ignored = [p for p in git("ls-files", "--others", "--ignored", "--exclude-standard", "--directory", "-z").split("\0")
               if p and not p.endswith("/")]
    env_files = {"templates": [p for p in files if env_kind(p.rsplit("/", 1)[-1]) == "template"],
                 "real": sorted(p for p in files + ignored if env_kind(p.rsplit("/", 1)[-1]) == "secret")}
    near_empty = all(p.startswith(".") or p.upper().startswith(("README", "LICENSE", "CHANGELOG"))
                     for p in root_files) and not top_level
    return {
        "mode": mode, "reasons": reasons, "workspace": workspace, "packages": packages,
        "sibling_repos": siblings, "submodules": submodules, "environments": detect_envs(files),
        "top_level": top_level, "root_files": root_files, "env_files": env_files, "near_empty": near_empty,
        "manifest": MANIFEST.is_file(), "layouts": layouts(),
    }


def layouts() -> list[str]:
    return sorted(p.stem for p in LAYOUTS_DIR.glob("*.toml")) if LAYOUTS_DIR.is_dir() else []


def print_detect(d: dict) -> None:
    print(f"Detected mode: {d['mode']}")
    for r in d["reasons"]:
        print(f"  - {r}")
    if d["environments"]:
        print("Environments seen: " + ", ".join(f"{k} ({len(v)})" for k, v in d["environments"].items()))
    if d["top_level"]:
        print("Top-level folders: " + ", ".join(f"{t['path']}/ ({t['files']})" for t in d["top_level"]))
    print(f"Root files: {', '.join(d['root_files']) or '(none)'}")
    ef = d["env_files"]
    if ef["templates"] or ef["real"]:
        print(f"Env files: {len(ef['templates'])} template(s) {ef['templates']}, {len(ef['real'])} real {ef['real']}"
              + ("  -- aim for one of each" if len(ef["templates"]) > 1 or len(ef["real"]) > 1 else ""))
    if d["near_empty"]:
        print("New repo: nothing here yet but README/LICENSE/dotfiles")
    print(f"Layouts available: {', '.join(d['layouts']) or '(none installed)'}")


def print_options(d: dict) -> None:
    print("No .claude/structure.toml -- structure checking is off.\n")
    print_detect(d)
    print("""
Modes:
  single      one project, flat layout
  monorepo    several apps/packages in one repo (apps/<name>/, packages/<name>/)
  multi-repo  this repo is one of several; each runs its own babel-fish, and
              [[repo]] entries point at the others

To turn it on:
  ask Claude to "set up the repo structure"   (structure-bootstrap skill: reads the
                                               tree, fills in purposes, asks what it can't infer)
  python .claude/project-map/structure-check.py --bootstrap                   (dump the current tree)
  python .claude/project-map/structure-check.py --bootstrap --layout NAME     (start from a layout)""")


def fmt(v) -> str:
    if isinstance(v, list):
        items = [json.dumps(x) for x in v]
        one = "[" + ", ".join(items) + "]"
        return one if len(one) <= 80 else "[\n" + "".join(f"  {x},\n" for x in items) + "]"
    if isinstance(v, bool):
        return str(v).lower()
    return json.dumps(v) if isinstance(v, str) else str(v)


def to_toml(m: dict) -> str:
    lines = ["# Repo structure manifest -- checked by .claude/project-map/structure-check.py (#22).",
             "# This is the repo's own data: edit it by hand; babel-fish never overwrites it."]
    for k in ("mode", "env_roots", "env_file", "root_files", "exceptions"):
        if k in m:
            lines.append(f"{k} = {fmt(m[k])}")
    for table in ("folder", "environment", "repo"):
        for t in m.get(table, []):
            lines += ["", f"[[{table}]]"] + [f"{k} = {fmt(v)}" for k, v in t.items()]
    return "\n".join(lines) + "\n"


def bootstrap(layout: str | None, mode: str | None) -> int:
    if MANIFEST.exists():
        print(f"FAIL  {MANIFEST.relative_to(PROJECT_ROOT)} already exists -- edit it by hand; bootstrap never overwrites it")
        return 2
    d = detect()
    today = date.today().isoformat()
    if layout:
        src = LAYOUTS_DIR / f"{layout}.toml"
        if not src.is_file():
            print(f"FAIL  no layout {layout!r} -- available: {', '.join(d['layouts']) or '(none installed)'}")
            return 2
        if tomllib is None:
            warn_old_python(f"the {layout} layout")
            return 0
        m = load_manifest(src)
    else:
        m = {"mode": d["mode"], "root_files": d["root_files"], "folder": []}
    if mode:
        m["mode"] = mode

    files, on_disk = tracked(), all_files()
    for f in m.get("folder", []):  # a layout's folders: active if they exist, planned if not
        exists = any(p.startswith(f["path"] + "/") for p in on_disk)
        f["status"] = "active" if exists else "planned"
        f.setdefault("added", today)
    # The existing structure wins: a top-level folder nothing covers becomes its own entry. Never a
    # `dir/**` exception -- a glob would wave through every FUTURE file in it too.
    folders = sorted(m.get("folder", []), key=lambda f: -f["path"].count("/") - len(f["path"]))
    uncovered = sorted({p.split("/", 1)[0] for p in on_disk if "/" in p and owner(p, folders) is None})
    for top in uncovered:
        purpose = "TODO: what belongs here" + (f" (not in the {layout} layout)" if layout else "")
        m.setdefault("folder", []).append({"path": top, "purpose": purpose, "status": "active", "added": today})

    templates = [p for p in files if env_kind(p.rsplit("/", 1)[-1]) == "template"]
    if len(templates) == 1 and templates[0].rsplit("/", 1)[-1] == ".env.example":
        m["env_file"] = templates[0]  # already unified: the existing location wins over the layout's

    # Seed the baseline: whatever fails today is allowed until fixed; only NEW violations block.
    env = check_env_files(m, files)
    findings = check_folders(m, files, set()) + check_environments(m, files) + env
    secrets = [f for f in env if f.level == "FAIL" and not f.exemptable]
    never = {f.path for f in secrets}  # an exact-path exception would also silence the secrets FAIL
    exc = set()
    for f in findings:
        if f.level == "FAIL" and f.exemptable and f.path not in never:
            exc.add(f.path)  # exact paths only: the baseline must not allow anything new
    if exc:
        m["exceptions"] = sorted(exc)

    text = to_toml(m)
    if d["environments"] and not m.get("environment"):
        text += "\n# Environments seen in this tree -- declare them to turn on the dev -> stg -> prod rules:\n"
        for name in d["environments"]:
            target = "local" if name in ("local", "dev", "development") else "cloud"
            text += f'# [[environment]]\n# name = "{name}"\n# target = "{target}"\n'
    if m["mode"] == "multi-repo" and d["sibling_repos"] and not m.get("repo"):
        text += "\n# Sibling repos -- uncomment the ones this repo works with:\n"
        for name in d["sibling_repos"]:
            text += f'# [[repo]]\n# name = "{name}"\n# path = "../{name}"\n# purpose = "TODO"\n'
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(text)

    print(f"Wrote {MANIFEST.relative_to(PROJECT_ROOT)} (mode: {m['mode']}"
          + (f", layout: {layout}" if layout else "") + ")")
    print(f"  {len(m.get('folder', []))} folders, {len(exc)} exception(s) seeded from today's tree")
    for f in secrets:
        print(f"  FAIL  {f.path}  -- {f.msg.split(' -- ', 1)[0]}; the check fails until it's fixed "
              "(a committed fixture with no real secrets: add its exact path to exceptions by hand)")
    if len(templates) > 1:
        print(f"  {len(templates)} env templates -- all but {env_file_path(m)} are in exceptions as the merge backlog")
    print("Next: fill in each TODO purpose, tighten holds, run structure-check.py, commit the manifest.")
    return 0


# ── cli ──────────────────────────────────────────────────────────────────────

def warn_old_python(what: str = ".claude/structure.toml") -> None:
    v = ".".join(map(str, sys.version_info[:3]))
    print(f"WARN  structure-check skipped: it reads {what} with Python's built-in\n"
          f"      TOML parser (tomllib), which needs Python 3.11+. This is Python {v}.\n"
          f"      Nothing was checked. Upgrade to Python 3.11 or newer to turn the check on;\n"
          f"      CI running 3.11+ still enforces it.")


def main() -> None:
    ap = argparse.ArgumentParser(description="Check tracked files against .claude/structure.toml (#22).")
    ap.add_argument("--detect", action="store_true", help="print repo facts (mode, environments, folders) and exit")
    ap.add_argument("--json", action="store_true", help="with --detect: machine-readable output")
    ap.add_argument("--bootstrap", action="store_true", help="write a starting manifest; never overwrites")
    ap.add_argument("--layout", metavar="NAME", help="with --bootstrap: start from .claude/templates/structure/NAME.toml")
    ap.add_argument("--mode", choices=MODES, help="with --bootstrap: override the detected mode")
    new = ap.add_mutually_exclusive_group()
    new.add_argument("--staged", action="store_true",
                     help="treat staged additions as new files (pre-commit)")
    new.add_argument("--since", metavar="REF",
                     help="treat files added since REF as new (CI, e.g. --since origin/main)")
    ap.add_argument("--warn-only", action="store_true", help="report, but always exit 0")
    ap.add_argument("--project-root", type=Path, default=None)
    args = ap.parse_args()
    if args.project_root:
        configure_paths(args.project_root.resolve())

    if not is_git_repo():
        print(f"FAIL  {PROJECT_ROOT} is not a git repository -- structure-check reads the git index (git init first)")
        sys.exit(2)
    if args.detect:
        d = detect()
        if args.json:
            print(json.dumps(d, indent=2))
        else:
            print_detect(d)
        sys.exit(0)
    if args.bootstrap:
        sys.exit(bootstrap(args.layout, args.mode))
    if not MANIFEST.is_file():
        print_options(detect())
        sys.exit(0)
    if tomllib is None:
        warn_old_python()
        sys.exit(0)
    try:
        m = load_manifest(MANIFEST)
    except tomllib.TOMLDecodeError as e:
        print(f"FAIL  .claude/structure.toml is not valid TOML: {e}")
        sys.exit(2)
    errs = validate(m)
    for e in errs:
        print(f"FAIL  .claude/structure.toml: {e}")
    if errs:
        sys.exit(2)
    try:
        fails = run(m, args.staged, args.since)
    except RuntimeError as e:
        print(f"FAIL  {e}")
        sys.exit(2)
    sys.exit(1 if fails and not args.warn_only else 0)


if __name__ == "__main__":
    main()

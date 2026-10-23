#!/usr/bin/env python3
"""
mine-sessions.py — Session Vocabulary Miner
Parses Claude Code conversation JSONL files from ~/.claude/projects/<slug>/
to extract user-language → file-path aliases.

Pattern: user said "the numbers page" → Claude opened DealAnalyzerV2.tsx
         = learned alias: "numbers page" → DealAnalyzerV2.tsx

Scoring: frequency × recency_weight
  - Sessions from last 30 days: weight 1.0
  - 31-60 days: weight 0.5
  - 61-90 days: weight 0.25
  - >90 days: dropped

Minimum score of 5 to appear in output (filters one-off mentions).

Usage:
    python mine-sessions.py [--project-root PATH] [--dry-run] [--verbose]
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

# ── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR   = Path(__file__).parent
LEARNED_VOC  = SCRIPT_DIR / "learned-vocabulary.json"
# Incremental cursor. Not merely a cost guard: merge_learned() ADDS scores, so
# re-mining an already-counted transcript inflates it without bound.
MINE_CURSOR  = SCRIPT_DIR / ".mine-cursor.json"
PROJECT_ROOT = SCRIPT_DIR.parent.parent


def configure_paths(project_root: Path) -> None:
    """Write mined aliases into project_root's map, not the script's own.

    Previously --project-root selected whose TRANSCRIPTS to mine but left the
    output pointed at the script's directory, so mining another project wrote
    its aliases into this one's learned vocabulary.
    """
    global PROJECT_ROOT, LEARNED_VOC, MINE_CURSOR
    PROJECT_ROOT = project_root
    map_dir      = project_root / '.claude' / 'project-map'
    LEARNED_VOC  = map_dir / 'learned-vocabulary.json'
    MINE_CURSOR  = map_dir / '.mine-cursor.json'
    map_dir.mkdir(parents=True, exist_ok=True)

# ── Config ───────────────────────────────────────────────────────────────────
MIN_SCORE        = 5.0     # Minimum score to include in vocabulary
RECENCY_WINDOWS  = [       # (days_threshold, weight)
    (30,  1.00),
    (60,  0.50),
    (90,  0.25),
]
MAX_ALIAS_WORDS  = 6       # Ignore user phrases longer than this
MAX_LOOKAHEAD    = 120     # Messages scanned after a user turn for file activity
MIN_ALIAS_WORDS  = 1
STOP_WORDS = {
    'the', 'a', 'an', 'this', 'that', 'these', 'those', 'it', 'its',
    'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with',
    'is', 'are', 'was', 'were', 'be', 'been', 'has', 'have', 'had',
    'do', 'does', 'did', 'will', 'would', 'could', 'should', 'can',
    'i', 'me', 'my', 'we', 'our', 'you', 'your', 'he', 'she', 'they',
    'please', 'just', 'also', 'now', 'then', 'so', 'ok', 'yes', 'no',
    'what', 'how', 'why', 'when', 'where', 'which', 'who',
    'file', 'files', 'code', 'function', 'method', 'class', 'module',
    'here', 'there', 'look', 'see', 'check', 'let', 'make', 'get',
    'add', 'update', 'change', 'fix', 'show', 'find', 'help', 'need',
}

# Tool call names that indicate a file was opened/used
FILE_TOOL_NAMES = {
    'Read', 'Edit', 'Write', 'Grep', 'Glob',
    'read_file', 'edit_file', 'write_file',
}

# Tools whose arguments are a shell command rather than a file path.
BASH_TOOL_NAMES = {'Bash', 'bash', 'run_command'}

# ── Recency weight ────────────────────────────────────────────────────────────

def recency_weight(session_date: datetime) -> float:
    now = datetime.now(tz=timezone.utc)
    if session_date.tzinfo is None:
        session_date = session_date.replace(tzinfo=timezone.utc)
    age_days = (now - session_date).days
    for threshold, weight in RECENCY_WINDOWS:
        if age_days <= threshold:
            return weight
    return 0.0  # Too old — drop


# ── Session discovery ─────────────────────────────────────────────────────────

def find_session_files(project_root: Path) -> list[Path]:
    """Find Claude Code JSONL session files for this project."""
    candidates: list[Path] = []

    # ~/.claude/projects/ uses a path-encoded slug that KEEPS the leading
    # separator: /home/u/proj → -home-u-proj. Stripping it (the old
    # .lstrip('-')) meant the exact match never once hit, and every lookup
    # silently fell through to the fuzzy branch below.
    encoded = str(project_root).replace('/', '-')
    claude_projects = Path.home() / '.claude' / 'projects'

    if not claude_projects.exists():
        return []

    exact = claude_projects / encoded
    if exact.is_dir():
        return sorted(exact.glob('*.jsonl'))

    # Fallback only when the exact directory is absent. Substring matching on
    # the bare project name is not safe as an addition: "kentro" matches four
    # unrelated project directories, whose aliases would then be attributed to
    # this repo.
    project_name = project_root.name.lower()
    for d in sorted(claude_projects.iterdir()):
        if d.is_dir() and project_name in d.name.lower():
            candidates.extend(sorted(d.glob('*.jsonl')))

    return candidates


# ── JSONL parser ──────────────────────────────────────────────────────────────

def parse_session(path: Path) -> list[dict]:
    """Parse a JSONL session file into a list of message dicts."""
    messages = []
    try:
        for line in path.read_text(encoding='utf-8', errors='replace').splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
                messages.append(obj)
            except json.JSONDecodeError:
                pass
    except Exception:
        pass
    return messages


def extract_session_date(messages: list[dict]) -> datetime | None:
    """Extract the timestamp of the first message in a session."""
    for msg in messages:
        ts = msg.get('timestamp') or msg.get('created_at') or msg.get('ts')
        if ts:
            try:
                return datetime.fromisoformat(str(ts).replace('Z', '+00:00'))
            except ValueError:
                pass
    return None


# ── JSONL shape helpers ───────────────────────────────────────────────────────
# Claude Code nests the API message under a "message" key: the role and content
# live at msg["message"]["role"] / ["content"], not at the top level. Reading the
# top level yielded 0 tool_use blocks and 0 user messages from a real 1.8 MB
# transcript (see issue #7). Both shapes are accepted so older or third-party
# transcripts still parse.

def msg_content(msg: dict):
    inner = msg.get('message')
    if isinstance(inner, dict) and inner.get('content') is not None:
        return inner['content']
    return msg.get('content')


def msg_role(msg: dict) -> str:
    inner = msg.get('message')
    if isinstance(inner, dict) and inner.get('role'):
        return str(inner['role'])
    return str(msg.get('role') or msg.get('type') or '')


def is_user_turn(msg: dict) -> bool:
    """A real user message, not a tool_result carrier.

    Tool results are delivered with role="user": in a real transcript 167 of 181
    role=user messages were tool_result blocks. Treating those as user turns
    made the pairing window close on the assistant's own tool output.
    """
    if msg_role(msg) not in ('user', 'human'):
        return False
    # isMeta marks machine-injected text delivered in the user slot: skill
    # bodies, slash-command definitions, hook output. Mining it learned aliases
    # from the injected docs themselves ("block_index_edits", "superseded by v2
    # guide", "refactor authentication system" — the last from a skill's own
    # example). isSidechain marks subagent transcripts, which are not the user
    # speaking either.
    if msg.get('isMeta') or msg.get('isSidechain'):
        return False
    content = msg_content(msg)
    if isinstance(content, str):
        return bool(content.strip())
    if isinstance(content, list):
        return any(isinstance(b, dict) and b.get('type') == 'text' for b in content)
    return False


# Bash-mediated file access. A real session ran 148 Bash calls against 2 Read
# and 2 Edit, so a miner that only understands the file tools sees almost
# nothing. Candidate tokens are only accepted when they resolve to a file that
# actually exists in the repo — a wrong alias asserted confidently is worse than
# a missing one, so no cleverer shell parsing than this.
BASH_TOKEN_RE = re.compile(r'[\w./-]*[\w-]\.[A-Za-z0-9]{1,6}\b')


def extract_paths_from_bash(command: str, project_root: Path) -> list[str]:
    out = []
    for tok in BASH_TOKEN_RE.findall(command or ''):
        tok = tok.strip("'\"()[]{},;:").lstrip('./')
        if not tok or tok.startswith('-'):
            continue
        try:
            if (project_root / tok).is_file():
                out.append(tok)
        except OSError:
            pass
    return out


# ── Alias extraction ──────────────────────────────────────────────────────────

def extract_file_paths_from_tool_calls(messages: list[dict]) -> list[str]:
    """Extract file paths from tool use calls in a message sequence."""
    paths = []
    for msg in messages:
        content = msg_content(msg) or []
        if isinstance(content, str):
            continue
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get('type') not in ('tool_use', 'tool_result'):
                continue
            tool_name = block.get('name', '')
            inp_early = block.get('input') or {}
            if tool_name in BASH_TOOL_NAMES and isinstance(inp_early, dict):
                paths.extend(extract_paths_from_bash(inp_early.get('command', ''), PROJECT_ROOT))
                continue
            if tool_name not in FILE_TOOL_NAMES:
                continue
            # Extract file_path from input
            inp = block.get('input') or {}
            if isinstance(inp, dict):
                fp = inp.get('file_path') or inp.get('path') or inp.get('pattern')
                if fp and isinstance(fp, str):
                    # Normalize to relative path
                    try:
                        rel = Path(fp).relative_to(PROJECT_ROOT)
                        paths.append(str(rel))
                    except ValueError:
                        # Already relative or different root
                        if not fp.startswith('/'):
                            paths.append(fp)
    return paths


def extract_user_phrases(text: str) -> list[str]:
    """
    Extract candidate alias phrases from user message text.
    Returns noun phrases and quoted strings likely to be feature references.
    """
    phrases = []

    # Quoted strings are high-confidence aliases
    for m in re.finditer(r'["\']([^"\']{3,40})["\']', text):
        phrases.append(m.group(1).lower().strip())

    # "the X" / "the X page/screen/section/tab/view/panel/modal/form/button"
    for m in re.finditer(
        r'\bthe\s+([\w\s-]{2,40}?)\s*(?:page|screen|section|tab|view|panel|modal|form|button|component|widget|dashboard|list|table|chart|graph|map|sidebar|header|footer|nav|menu)\b',
        text, re.IGNORECASE
    ):
        phrases.append(m.group(1).lower().strip())

    # "X feature" / "X functionality" / "X system" / "X module"
    for m in re.finditer(
        r'\b([\w\s-]{2,30}?)\s+(?:feature|functionality|system|module|service|flow|workflow|pipeline|process)\b',
        text, re.IGNORECASE
    ):
        candidate = m.group(1).lower().strip()
        words = candidate.split()
        if 1 <= len(words) <= MAX_ALIAS_WORDS:
            phrases.append(candidate)

    # Filter: remove stop-word-only phrases, too short/long
    result = []
    for phrase in phrases:
        # Sentence punctuation means this is a clause, not a name for something
        # ("that, if not", "total documents:"). Aliases don't contain it.
        if any(ch in phrase for ch in ',:;?!'):
            continue
        # Strip punctuation BEFORE the stop-word test — otherwise "that," fails
        # to match the stop word "that" and survives as an alias.
        words = [w.strip('.\'"`()[]{}<>*_-') for w in phrase.split()]
        words = [w for w in words if w and w not in STOP_WORDS and len(w) > 1]
        # At least one substantial word, so "up to" and "as is" don't qualify.
        if not any(len(w) >= 3 for w in words):
            continue
        if MIN_ALIAS_WORDS <= len(words) <= MAX_ALIAS_WORDS:
            clean = ' '.join(words)
            if clean and clean not in result:
                result.append(clean)

    return result


# ── Core miner ────────────────────────────────────────────────────────────────

class SessionMiner:
    def __init__(self, project_root: Path, verbose: bool = False):
        self.project_root = project_root
        self.verbose = verbose
        # alias → {targets: set, raw_score: float, last_seen: str, count: int}
        self._data: dict[str, dict] = {}

    def mine(self, session_files: list[Path]) -> None:
        for path in session_files:
            self._mine_file(path)

    def _mine_file(self, path: Path) -> None:
        messages = parse_session(path)
        if not messages:
            return

        session_date = extract_session_date(messages)
        if session_date is None:
            session_date = datetime.fromtimestamp(path.stat().st_mtime, tz=timezone.utc)

        weight = recency_weight(session_date)
        if weight == 0.0:
            if self.verbose:
                print(f"  [skip] {path.name} — too old")
            return

        if self.verbose:
            print(f"  [mine] {path.name} (weight={weight}, date={session_date.date()})")

        # Walk messages in pairs: look for user message followed by tool calls
        for i, msg in enumerate(messages):
            if not is_user_turn(msg):
                continue

            # Extract text from this user message
            content = msg_content(msg) or ''
            if isinstance(content, list):
                text_parts = []
                for block in content:
                    if isinstance(block, dict) and block.get('type') == 'text':
                        text_parts.append(block.get('text', ''))
                    elif isinstance(block, str):
                        text_parts.append(block)
                text = ' '.join(text_parts)
            else:
                text = str(content)

            if len(text) < 5:
                continue

            # Everything the assistant touched before the next real user turn.
            # Bounded by MAX_LOOKAHEAD so one runaway turn can't scan the file.
            file_paths: list[str] = []
            for j in range(i + 1, min(i + 1 + MAX_LOOKAHEAD, len(messages))):
                if is_user_turn(messages[j]):
                    break
                file_paths.extend(extract_file_paths_from_tool_calls([messages[j]]))

            if not file_paths:
                continue

            # Extract phrases from user text and pair with opened files
            phrases = extract_user_phrases(text)
            for phrase in phrases:
                for fp in file_paths:
                    self._record(phrase, fp, weight, session_date)

    def _record(self, alias: str, target: str, weight: float, date: datetime) -> None:
        if alias not in self._data:
            self._data[alias] = {
                'targets': set(),
                'raw_score': 0.0,
                'last_seen': date.date().isoformat(),
                'count': 0,
            }
        entry = self._data[alias]
        entry['targets'].add(target)
        entry['raw_score'] += weight
        entry['count'] += 1
        if date.date().isoformat() > entry['last_seen']:
            entry['last_seen'] = date.date().isoformat()

    def results(self) -> dict[str, dict]:
        """Return aliases with score >= MIN_SCORE, serializable."""
        out = {}
        for alias, data in self._data.items():
            score = data['raw_score']
            if score >= MIN_SCORE:
                out[alias] = {
                    'targets': sorted(data['targets']),
                    'score': round(score, 2),
                    'count': data['count'],
                    'last_seen': data['last_seen'],
                    'source': 'session-mined',
                }
        return dict(sorted(out.items(), key=lambda x: -x[1]['score']))


# ── Merge with existing learned vocabulary ────────────────────────────────────

def merge_learned(existing: dict, new: dict) -> dict:
    """
    Merge new mined aliases into existing learned vocabulary.
    New entries add to score; existing entries are updated.
    Code-derived entries (source != 'session-mined') are never overwritten.
    """
    merged = dict(existing)
    for alias, data in new.items():
        if alias in merged:
            existing_entry = merged[alias]
            # Don't overwrite code-derived entries
            if existing_entry.get('source') != 'session-mined':
                continue
            # Merge scores and targets
            existing_entry['score'] = round(
                existing_entry.get('score', 0) + data['score'], 2
            )
            existing_entry['count'] = existing_entry.get('count', 0) + data['count']
            existing_entry['targets'] = sorted(
                set(existing_entry.get('targets', [])) | set(data['targets'])
            )
            if data['last_seen'] > existing_entry.get('last_seen', ''):
                existing_entry['last_seen'] = data['last_seen']
        else:
            merged[alias] = data
    return merged


def decay_old_entries(vocab: dict) -> dict:
    """Remove entries not seen in > 90 sessions / score below 1.0."""
    cutoff = (datetime.now() - timedelta(days=90)).date().isoformat()
    return {
        alias: data
        for alias, data in vocab.items()
        if data.get('source') != 'session-mined'
        or (data.get('last_seen', '0000-00-00') >= cutoff and data.get('score', 0) >= 1.0)
    }


# ── Main ──────────────────────────────────────────────────────────────────────

def load_cursor() -> float:
    try:
        return float(json.loads(MINE_CURSOR.read_text()).get('last_mined_mtime', 0.0))
    except Exception:
        return 0.0


def save_cursor(mtime: float) -> None:
    try:
        MINE_CURSOR.write_text(json.dumps({'last_mined_mtime': mtime}, indent=2))
    except OSError:
        pass


def main() -> None:
    parser = argparse.ArgumentParser(description='Mine Claude Code sessions for vocabulary aliases')
    parser.add_argument('--project-root', type=Path, default=None)
    parser.add_argument('--dry-run', action='store_true', help='Print results without saving')
    parser.add_argument('--verbose', '-v', action='store_true', help='Show per-file details')
    parser.add_argument('--all', action='store_true',
                        help='Ignore the incremental cursor and re-mine every transcript')
    args = parser.parse_args()

    if args.project_root:
        configure_paths(args.project_root.resolve())

    print(f"[mine-sessions] Project root: {PROJECT_ROOT}")

    # Find session files
    session_files = find_session_files(PROJECT_ROOT)
    if not session_files:
        print("[mine-sessions] No session files found in ~/.claude/projects/")
        print(f"  Looked for: ~/.claude/projects/*{PROJECT_ROOT.name.lower()}*/*.jsonl")
        print("  Sessions accumulate as you use Claude Code in this repo.")

        # Still update learned-vocabulary.json to ensure it exists and is valid
        if not LEARNED_VOC.exists():
            LEARNED_VOC.write_text('{}', encoding='utf-8')
            print("[mine-sessions] Created empty learned-vocabulary.json")
        sys.exit(0)

    print(f"[mine-sessions] Found {len(session_files)} session file(s)")

    # Only transcripts touched since the last run. Without this, every session
    # start re-reads the whole history AND re-adds its scores.
    cursor = 0.0 if args.all else load_cursor()
    newest = max((f.stat().st_mtime for f in session_files), default=0.0)
    if cursor:
        session_files = [f for f in session_files if f.stat().st_mtime > cursor]
        if not session_files:
            print("[mine-sessions] No transcripts changed since last run — nothing to do")
            sys.exit(0)
        print(f"[mine-sessions] {len(session_files)} changed since last run")

    # Mine
    miner = SessionMiner(PROJECT_ROOT, verbose=args.verbose)
    miner.mine(session_files)
    new_vocab = miner.results()

    print(f"[mine-sessions] Extracted {len(new_vocab)} alias(es) scoring >= {MIN_SCORE}")

    if args.verbose and new_vocab:
        print("\n  Top aliases:")
        for alias, data in list(new_vocab.items())[:10]:
            targets = ', '.join(data['targets'][:2])
            print(f"  {data['score']:5.1f}  {alias:<30}  → {targets}")
        print()

    if args.dry_run:
        print("[mine-sessions] Dry run — not saving")
        sys.exit(0)

    # Load existing, merge, decay, save
    existing: dict = {}
    if LEARNED_VOC.exists():
        try:
            existing = json.loads(LEARNED_VOC.read_text())
        except Exception:
            pass

    merged = merge_learned(existing, new_vocab)
    merged = decay_old_entries(merged)

    LEARNED_VOC.write_text(json.dumps(merged, indent=2, ensure_ascii=False), encoding='utf-8')
    save_cursor(newest)
    print(f"[mine-sessions] ✓ Saved {len(merged)} total aliases to {LEARNED_VOC}")
    print(f"  (run 'python generate.py --force' to rebuild sections with updated vocabulary)")


if __name__ == '__main__':
    main()

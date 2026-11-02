#!/usr/bin/env python3
"""追跡ファイルから、秘密と個人情報らしい文字列を探す。

見つかった値は出さない。ファイル名、行番号、種類だけを出す。
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

KINDS = ("トークン", "APIキー", "秘密鍵", "メールアドレス", "電話番号", "住所")

# 検査スクリプト自身のソースに、完成した秘密の形を書かない。
PRIVATE_KEY = "-----BEGIN " + "PRIVATE KEY-----"
TOKEN = "ghp_" + r"[A-Za-z0-9]{36}"
GITHUB_PAT = "github_pat_" + r"[A-Za-z0-9_]{20,}"
AWS_KEY = "AKIA" + r"[0-9A-Z]{16}"
SLACK = r"xox[baprs]-[0-9A-Za-z-]{10,}"
GOOGLE = "AIza" + r"[0-9A-Za-z\-_]{35}"
OPENAI = r"sk-(?:proj-)?[A-Za-z0-9]{20,}"
NPM = "npm_" + r"[A-Za-z0-9]{36}"
API_ASSIGN = (
    r"(?i)\b(?:api[_-]?key|secret|access[_-]?token|auth[_-]?token|password)\b"
    r"\s*[:=]\s*['\"]?([A-Za-z0-9+/=_\-]{16,})"
)
EMAIL = r"(?<![A-Za-z0-9._%+\-])[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"
PHONE = r"(?<!\d)(?:0[789]0-\d{4}-\d{4}|0[789]0\d{8}|0\d{1,4}-\d{1,4}-\d{4})(?!\d)"
ADDRESS = (
    r"(?:〒\s*\d{3}-\d{4})"
    r"|(?:北海道|東京都|大阪府|京都府|[一-龯々]{2,3}県)"
    r"[^\n]{0,24}(?:市|区|郡|町|村)[^\n]{0,24}"
    r"(?:\d+\s*丁目|\d+\s*番地|\d+-\d+-\d+)"
    r"|(?:\d+\s*丁目\s*\d+\s*番地)"
    r"|(?:号室)"
)

RULES: list[tuple[str, re.Pattern[str]]] = [
    ("秘密鍵", re.compile(re.escape(PRIVATE_KEY))),
    ("トークン", re.compile(TOKEN)),
    ("トークン", re.compile(GITHUB_PAT)),
    ("APIキー", re.compile(AWS_KEY)),
    ("トークン", re.compile(SLACK)),
    ("APIキー", re.compile(GOOGLE)),
    ("APIキー", re.compile(OPENAI)),
    ("トークン", re.compile(NPM)),
    ("APIキー", re.compile(API_ASSIGN)),
    ("メールアドレス", re.compile(EMAIL)),
    ("電話番号", re.compile(PHONE)),
    ("住所", re.compile(ADDRESS)),
]


def repo_root() -> Path:
    completed = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        check=True,
        capture_output=True,
        text=True,
    )
    return Path(completed.stdout.strip())


def tracked_files(root: Path) -> list[Path]:
    completed = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    names = [name.decode("utf-8", "surrogateescape") for name in completed.stdout.split(b"\0") if name]
    return [root / name for name in names]


def load_allowlist(path: Path) -> tuple[set[str], list[re.Pattern[str]]]:
    exact: set[str] = set()
    patterns: list[re.Pattern[str]] = []
    if not path.is_file():
        return exact, patterns
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("re:"):
            patterns.append(re.compile(line[3:]))
        else:
            exact.add(line)
    return exact, patterns


def allowed(value: str, exact: set[str], patterns: list[re.Pattern[str]]) -> bool:
    if value in exact:
        return True
    return any(pattern.fullmatch(value) for pattern in patterns)


def scan_text(text: str, exact: set[str], patterns: list[re.Pattern[str]]) -> list[tuple[int, str]]:
    findings: list[tuple[int, str]] = []
    seen: set[tuple[int, str]] = set()
    for number, line in enumerate(text.splitlines(), start=1):
        for kind, rule in RULES:
            for match in rule.finditer(line):
                value = match.group(1) if match.lastindex else match.group(0)
                if allowed(value, exact, patterns):
                    continue
                item = (number, kind)
                if item not in seen:
                    seen.add(item)
                    findings.append(item)
    return findings


def scan_file(path: Path, exact: set[str], patterns: list[re.Pattern[str]]) -> list[tuple[int, str]]:
    data = path.read_bytes()
    if b"\0" in data:
        return []
    text = data.decode("utf-8", "replace")
    return scan_text(text, exact, patterns)


def self_check(exact: set[str], patterns: list[re.Pattern[str]]) -> list[str]:
    samples = {
        "トークン": "ghp_" + ("a" * 36),
        "APIキー": "API_KEY=" + ("DUMMYNOTAREAL" + "0" * 8),
        "秘密鍵": "-----BEGIN " + "PRIVATE KEY-----",
        "メールアドレス": "not-a-real-person@" + "example.invalid",
        "電話番号": "090-" + "0000-0000",
        "住所": "架空県架空市" + "1丁目2-3",
    }
    problems: list[str] = []
    for kind in KINDS:
        found = {item[1] for item in scan_text(samples[kind], exact, patterns)}
        if kind not in found:
            problems.append(f"自己確認: {kind} を検出できませんでした")
    noreply = "12345678+user@" + "users.noreply.github.com"
    if scan_text(noreply, exact, patterns):
        problems.append("自己確認: GitHub の noreply アドレスを通していません")
    for name in ("さくら台", "駅前ロータリー", "あかね交通", "みどり交通"):
        if scan_text(name, exact, patterns):
            problems.append(f"自己確認: 架空の例を検出してしまいました ({name})")
    return problems


def main() -> int:
    root = repo_root()
    exact, patterns = load_allowlist(root / "scripts" / "secret-allowlist.txt")
    self_check_only = "--self-check" in sys.argv
    problems = self_check(exact, patterns)
    if self_check_only:
        if problems:
            print("\n".join(problems))
            return 1
        print("自己確認: 通りました")
        return 0
    if problems:
        print("\n".join(problems))
        return 2
    failed = False
    for path in tracked_files(root):
        if not path.is_file():
            continue
        relative = path.relative_to(root).as_posix()
        for line, kind in scan_file(path, exact, patterns):
            print(f"{relative}:{line}: {kind}")
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except subprocess.CalledProcessError as error:
        print(f"git の実行に失敗しました (exit {error.returncode})", file=sys.stderr)
        sys.exit(2)

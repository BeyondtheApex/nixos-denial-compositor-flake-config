#!/usr/bin/env python3
import json
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FLAKE = ROOT / "flake.nix"
VERSIONS = ROOT / "versions.nix"
NIX = shutil.which("nix") or "/root/.nix-profile/bin/nix"


def run(*args: str) -> str:
    return subprocess.check_output(args, cwd=ROOT, text=True)


def replace_literal(path: Path, old: str, new: str) -> None:
    if old == new:
        return
    text = path.read_text()
    count = text.count(old)
    if count == 0:
        raise RuntimeError(f"{path.name}: did not find expected value: {old}")
    path.write_text(text.replace(old, new))


def main() -> int:
    raw = run(NIX, "run", ".#update-check", "--", "--json")
    update = json.loads(raw)
    if update.get("has_update") != 1:
        print("Denial pins are already up to date.")
        return 0

    latest_tag = update["inputs"]["denial"]["latest_tag"]
    current_denial_url = update["inputs"]["denial"]["url"]
    current_shell_url = update["inputs"]["denial-shell"]["url"]
    next_denial_url = f"github:denialwm/denial/{latest_tag}"

    replace_literal(FLAKE, current_denial_url, next_denial_url)
    replace_literal(VERSIONS, current_denial_url, next_denial_url)
    if current_shell_url != current_denial_url:
        replace_literal(FLAKE, current_shell_url, next_denial_url)
        replace_literal(VERSIONS, current_shell_url, next_denial_url)

    replacements: dict[str, str] = {}
    for field in update["fields"].values():
        current = field["current"]
        next_value = field["next"]
        if not next_value:
            raise RuntimeError(f"missing next value for field with current value {current!r}")
        if current in replacements and replacements[current] != next_value:
            raise RuntimeError(
                f"conflicting replacement for {current!r}: "
                f"{replacements[current]!r} vs {next_value!r}"
            )
        replacements[current] = next_value

    for current, next_value in sorted(
        replacements.items(),
        key=lambda item: len(item[0]),
        reverse=True,
    ):
        replace_literal(VERSIONS, current, next_value)

    run(NIX, "flake", "update", "denial", "denialShell")
    print(f"Updated Denial pins to {latest_tag}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

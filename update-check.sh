#!/usr/bin/env bash
# denial-update-check — check Denial inputs/releases for updates and print every
# field that needs changing (including freshly computed hashes), so you never
# have to compute them by hand.
#
# The "@..."@ placeholders below are replaced at build time from
# denial/versions.nix (see package.nix). Run with --json for machine output.
set -euo pipefail

JSON="${DENIAL_UPDATE_CHECK_JSON:-0}"
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --json) JSON=1 ;;
    --force) FORCE=1 ;;
    -h | --help)
      echo "usage: denial-update-check [--json] [--force]"
      echo "  --json   machine-readable output"
      echo "  --force  compute the new hashes even when there is no update"
      exit 0
      ;;
    *) echo "unknown argument: $arg" >&2; exit 1 ;;
  esac
done

# ===== current pins (injected at build time from denial/versions.nix) =====
DENIAL_URL='@denial_url@'
DENIAL_SHELL_URL='@denialShell_url@'
RELEASE_VERSION='@release_version@'
RELEASE_DENIAL_URL='@release_denial_url@'
RELEASE_DENIAL_SHA256='@release_denial_sha256@'
RELEASE_ENGINE_VERSION='@release_engine_version@'
RELEASE_ENGINE_URL='@release_engine_url@'
RELEASE_ENGINE_SHA256='@release_engine_sha256@'
UI_DEV_VERSION='@uiDev_version@'
UI_DEV_URL='@uiDev_url@'
UI_DEV_SHA256='@uiDev_sha256@'
FLUTTER_VERSION='@flutterVersion@'
FLUTTER_FRAMEWORK_REPOSITORY='@flutterFramework_repository@'
FLUTTER_FRAMEWORK_REVISION='@flutterFramework_revision@'
FLUTTER_TOOL_BACKEND_SHELL_SHA256='@flutterFramework_toolBackendShellSha256@'
FLUTTER_TOOL_BACKEND_DART_SHA256='@flutterFramework_toolBackendDartSha256@'

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing dependency: $1" >&2; exit 1; }; }
need curl; need jq; need git

# "github:owner/repo/ref" -> owner, repo, ref
parse_url() {
  local u="$1"
  if [[ "$u" == github:* ]]; then
    local rest="${u#github:}"
    owner="${rest%%/*}"; rest="${rest#*/}"
    repo="${rest%%/*}"; ref="${rest#*/}"
  else
    owner=""; repo=""; ref=""
  fi
}

latest_release_tag() { # owner repo -> latest release tag (or "" on failure)
  # /releases/latest 404s when every release is a prerelease (Denial is
  # public-beta), so list releases and take the newest non-draft one.
  curl -fsSL -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/repos/$1/$2/releases?per_page=1" 2>/dev/null \
    | jq -r 'map(select(.draft == false)) | .[0].tag_name // empty'
}
latest_main_rev() { # owner repo -> HEAD revision of the default branch
  git ls-remote "https://github.com/$1/$2.git" HEAD 2>/dev/null | awk '{print $1}'
}
sha256_sri() { # url -> sha256-<base64> (nix-prefetch-url preferred)
  local tmp
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' RETURN
  if command -v nix-prefetch-url >/dev/null 2>&1; then
    local b32
    b32="$(nix-prefetch-url --type sha256 "$1" 2>/dev/null)"
    if [[ -n "$b32" ]] && command -v nix >/dev/null 2>&1; then
      nix hash convert --hash-algo sha256 --to sri "$b32"
      return
    fi
    printf 'sha256-%s' "$b32"
    return
  fi
  curl -fsSL "$1" -o "$tmp"
  local hex
  hex="$(sha256sum "$tmp" | awk '{print $1}')"
  printf 'sha256-%s' "$(printf '%s' "$hex" | xxd -r -p | base64 -w0)"
}
ui_development_manifest_for_tag() { # owner repo tag -> manifest json
  curl -fsSL "https://raw.githubusercontent.com/$1/$2/$3/packaging/arch/ui-development/manifest.json" 2>/dev/null
}

declare -A INPUTS
INPUTS[denial]="$DENIAL_URL"
INPUTS[denial-shell]="$DENIAL_SHELL_URL"

# ---- gather upstream state per input ----
declare -A LATEST_TAG LATEST_REV CURRENT_REF
for name in "${!INPUTS[@]}"; do
  parse_url "${INPUTS[$name]}"
  CURRENT_REF[$name]="$ref"
  if [[ -z "$owner" ]]; then
    LATEST_TAG[$name]=""
    LATEST_REV[$name]=""
    continue
  fi
  LATEST_TAG[$name]="$(latest_release_tag "$owner" "$repo")"
  LATEST_REV[$name]="$(latest_main_rev "$owner" "$repo")"
done

# ---- does the pinned denial tag match the latest release? ----
parse_url "$DENIAL_URL"
current_ref="$ref"          # e.g. v0.2.15
new_tag="${LATEST_TAG[denial]:-}"
has_update=0
if [[ -n "$new_tag" && "$new_tag" != "$current_ref" ]]; then has_update=1; fi

# ---- compute what would change ----
NEW_UI_DEV_VERSION="${new_tag#v}"
NEW_RELEASE_VERSION="$NEW_UI_DEV_VERSION"
NEW_RELEASE_DENIAL_URL=""
NEW_RELEASE_DENIAL_SHA256=""
NEW_RELEASE_ENGINE_VERSION=""
NEW_RELEASE_ENGINE_URL=""
NEW_RELEASE_ENGINE_SHA256=""
NEW_UI_DEV_URL=""
NEW_UI_DEV_SHA256=""
NEW_FLUTTER_VERSION=""
NEW_FLUTTER_FRAMEWORK_REPOSITORY=""
NEW_FLUTTER_FRAMEWORK_REVISION=""
NEW_FLUTTER_TOOL_BACKEND_SHELL_SHA256=""
NEW_FLUTTER_TOOL_BACKEND_DART_SHA256=""
if [[ "$has_update" == 1 ]] || [[ "$FORCE" == 1 ]]; then
  if [[ -n "$new_tag" ]]; then
    NEW_RELEASE_DENIAL_URL="https://github.com/denialwm/denial/releases/download/${new_tag}/denial-${NEW_RELEASE_VERSION}-1-x86_64.pkg.tar.zst"
    NEW_RELEASE_ENGINE_VERSION="1.${NEW_RELEASE_VERSION}"
    NEW_RELEASE_ENGINE_URL="https://github.com/denialwm/denial/releases/download/${new_tag}/denial-flutter-engine-${NEW_RELEASE_ENGINE_VERSION}-1-x86_64.pkg.tar.zst"
    NEW_UI_DEV_URL="https://github.com/denialwm/denial/releases/download/${new_tag}/denial-ui-development-${NEW_UI_DEV_VERSION}-1-x86_64.pkg.tar.zst"
    echo "computing sha256 for official denial release (${NEW_RELEASE_VERSION})..." >&2
    NEW_RELEASE_DENIAL_SHA256="$(sha256_sri "$NEW_RELEASE_DENIAL_URL")"
    echo "computing sha256 for official flutter engine (${NEW_RELEASE_ENGINE_VERSION})..." >&2
    NEW_RELEASE_ENGINE_SHA256="$(sha256_sri "$NEW_RELEASE_ENGINE_URL")"
    echo "computing sha256 for ui-development (${NEW_UI_DEV_VERSION})..." >&2
    NEW_UI_DEV_SHA256="$(sha256_sri "$NEW_UI_DEV_URL")"
    parse_url "$DENIAL_URL"
    manifest="$(ui_development_manifest_for_tag "$owner" "$repo" "$new_tag" || true)"
    if [[ -n "$manifest" ]]; then
      NEW_FLUTTER_VERSION="$(jq -r '.sources.flutter_version // empty' <<<"$manifest")"
      NEW_FLUTTER_FRAMEWORK_REPOSITORY="$(jq -r '.sources.flutter_repository // empty' <<<"$manifest")"
      NEW_FLUTTER_FRAMEWORK_REPOSITORY="${NEW_FLUTTER_FRAMEWORK_REPOSITORY%.git}"
      NEW_FLUTTER_FRAMEWORK_REVISION="$(jq -r '.sources.flutter_fork_revision // empty' <<<"$manifest")"
      if [[ -n "$NEW_FLUTTER_FRAMEWORK_REPOSITORY" && -n "$NEW_FLUTTER_FRAMEWORK_REVISION" ]]; then
        echo "computing sha256 for flutter tool_backend files (${NEW_FLUTTER_FRAMEWORK_REVISION})..." >&2
        NEW_FLUTTER_TOOL_BACKEND_SHELL_SHA256="$(sha256_sri "${NEW_FLUTTER_FRAMEWORK_REPOSITORY}/raw/${NEW_FLUTTER_FRAMEWORK_REVISION}/packages/flutter_tools/bin/tool_backend.sh")"
        NEW_FLUTTER_TOOL_BACKEND_DART_SHA256="$(sha256_sri "${NEW_FLUTTER_FRAMEWORK_REPOSITORY}/raw/${NEW_FLUTTER_FRAMEWORK_REVISION}/packages/flutter_tools/bin/tool_backend.dart")"
      fi
    fi
  fi
fi

# ===== output =====
if [[ "$JSON" == 1 ]]; then
  jq -n \
    --arg denialUrl "$DENIAL_URL" \
    --arg denialShellUrl "$DENIAL_SHELL_URL" \
    --arg currentRef "$current_ref" \
    --arg latestTag "${LATEST_TAG[denial]:-}" \
    --arg latestRev "${LATEST_REV[denial]:-}" \
    --arg shellLatestTag "${LATEST_TAG[denial-shell]:-}" \
    --arg releaseVersion "$RELEASE_VERSION" \
    --arg releaseDenialUrl "$RELEASE_DENIAL_URL" \
    --arg releaseDenialSha256 "$RELEASE_DENIAL_SHA256" \
    --arg releaseEngineVersion "$RELEASE_ENGINE_VERSION" \
    --arg releaseEngineUrl "$RELEASE_ENGINE_URL" \
    --arg releaseEngineSha256 "$RELEASE_ENGINE_SHA256" \
    --arg newReleaseVersion "$NEW_RELEASE_VERSION" \
    --arg newReleaseDenialUrl "$NEW_RELEASE_DENIAL_URL" \
    --arg newReleaseDenialSha256 "$NEW_RELEASE_DENIAL_SHA256" \
    --arg newReleaseEngineVersion "$NEW_RELEASE_ENGINE_VERSION" \
    --arg newReleaseEngineUrl "$NEW_RELEASE_ENGINE_URL" \
    --arg newReleaseEngineSha256 "$NEW_RELEASE_ENGINE_SHA256" \
    --arg uiDevVersion "$UI_DEV_VERSION" \
    --arg uiDevUrl "$UI_DEV_URL" \
    --arg uiDevSha256 "$UI_DEV_SHA256" \
    --arg newUiDevVersion "$NEW_UI_DEV_VERSION" \
    --arg newUiDevUrl "$NEW_UI_DEV_URL" \
    --arg newUiDevSha256 "$NEW_UI_DEV_SHA256" \
    --arg flutterVersion "$FLUTTER_VERSION" \
    --arg newFlutterVersion "$NEW_FLUTTER_VERSION" \
    --arg flutterFrameworkRepository "$FLUTTER_FRAMEWORK_REPOSITORY" \
    --arg newFlutterFrameworkRepository "$NEW_FLUTTER_FRAMEWORK_REPOSITORY" \
    --arg flutterFrameworkRevision "$FLUTTER_FRAMEWORK_REVISION" \
    --arg newFlutterFrameworkRevision "$NEW_FLUTTER_FRAMEWORK_REVISION" \
    --arg flutterToolBackendShellSha256 "$FLUTTER_TOOL_BACKEND_SHELL_SHA256" \
    --arg newFlutterToolBackendShellSha256 "$NEW_FLUTTER_TOOL_BACKEND_SHELL_SHA256" \
    --arg flutterToolBackendDartSha256 "$FLUTTER_TOOL_BACKEND_DART_SHA256" \
    --arg newFlutterToolBackendDartSha256 "$NEW_FLUTTER_TOOL_BACKEND_DART_SHA256" \
    --argjson hasUpdate "$has_update" \
    '{ has_update: $hasUpdate,
       inputs: { denial: { url: $denialUrl, latest_tag: $latestTag, latest_rev: $latestRev },
                 "denial-shell": { url: $denialShellUrl, latest_tag: $shellLatestTag } },
       fields: {
         "denial/versions.nix release.version":    { current: $releaseVersion, next: $newReleaseVersion },
         "denial/versions.nix release.denial.url": { current: $releaseDenialUrl, next: $newReleaseDenialUrl },
         "denial/versions.nix release.denial.sha256": { current: $releaseDenialSha256, next: $newReleaseDenialSha256 },
         "denial/versions.nix release.engine.version": { current: $releaseEngineVersion, next: $newReleaseEngineVersion },
         "denial/versions.nix release.engine.url": { current: $releaseEngineUrl, next: $newReleaseEngineUrl },
         "denial/versions.nix release.engine.sha256": { current: $releaseEngineSha256, next: $newReleaseEngineSha256 },
         "denial/versions.nix uiDev.version":      { current: $uiDevVersion, next: $newUiDevVersion },
         "denial/versions.nix uiDev.url":          { current: $uiDevUrl, next: $newUiDevUrl },
         "denial/versions.nix uiDev.sha256":       { current: $uiDevSha256, next: $newUiDevSha256 },
         "denial/versions.nix flutterVersion":     { current: $flutterVersion, next: $newFlutterVersion },
         "denial/versions.nix flutterFramework.repository": { current: $flutterFrameworkRepository, next: $newFlutterFrameworkRepository },
         "denial/versions.nix flutterFramework.revision": { current: $flutterFrameworkRevision, next: $newFlutterFrameworkRevision },
         "denial/versions.nix flutterFramework.toolBackendShellSha256": { current: $flutterToolBackendShellSha256, next: $newFlutterToolBackendShellSha256 },
         "denial/versions.nix flutterFramework.toolBackendDartSha256": { current: $flutterToolBackendDartSha256, next: $newFlutterToolBackendDartSha256 }
       } }'
  exit 0
fi

echo "== Denial update check =="
echo "input denial       : $DENIAL_URL"
echo "  latest release   : ${LATEST_TAG[denial]:-(unavailable)}"
if [[ -n "${LATEST_REV[denial]:-}" ]]; then
  echo "  latest main rev  : ${LATEST_REV[denial]}"
fi
echo "input denial-shell : $DENIAL_SHELL_URL"
echo "  latest release   : ${LATEST_TAG[denial-shell]:-(unavailable)}"
echo

if [[ "$has_update" == 0 ]]; then
  echo "Up to date: the current pin matches the latest release (${new_tag:-unknown})."
  if [[ "$FORCE" == 0 ]]; then
    echo "(use --force to recompute the current field values anyway)"
    exit 0
  fi
  echo "(--force: recomputed values for the current release)"
fi

echo "Fields to update:"
echo "  flake.nix inputs.denial.url       : $current_ref -> $new_tag"
echo "  flake.nix inputs.denialShell.url  : ${CURRENT_REF[denial-shell]:-?} -> $new_tag   (same upstream as denial unless you use a custom shell repository)"
echo "  denial/versions.nix release.version: $RELEASE_VERSION -> ${NEW_RELEASE_VERSION:-?}"
echo "  denial/versions.nix release.denial.url:"
echo "                                      $RELEASE_DENIAL_URL"
echo "                                       -> ${NEW_RELEASE_DENIAL_URL:-?}"
echo "  denial/versions.nix release.denial.sha256:"
echo "                                      $RELEASE_DENIAL_SHA256"
echo "                                       -> ${NEW_RELEASE_DENIAL_SHA256:-?}"
echo "  denial/versions.nix release.engine.version:"
echo "                                      $RELEASE_ENGINE_VERSION -> ${NEW_RELEASE_ENGINE_VERSION:-?}"
echo "  denial/versions.nix release.engine.url:"
echo "                                      $RELEASE_ENGINE_URL"
echo "                                       -> ${NEW_RELEASE_ENGINE_URL:-?}"
echo "  denial/versions.nix release.engine.sha256:"
echo "                                      $RELEASE_ENGINE_SHA256"
echo "                                       -> ${NEW_RELEASE_ENGINE_SHA256:-?}"
echo "  denial/versions.nix uiDev.version : $UI_DEV_VERSION -> ${NEW_UI_DEV_VERSION:-?}"
echo "  denial/versions.nix uiDev.url     : $UI_DEV_URL"
echo "                                       -> ${NEW_UI_DEV_URL:-?}"
echo "  denial/versions.nix uiDev.sha256  : $UI_DEV_SHA256"
echo "                                       -> ${NEW_UI_DEV_SHA256:-?}"
echo "  denial/versions.nix flutterVersion: $FLUTTER_VERSION -> ${NEW_FLUTTER_VERSION:-?}   (read from the new ui-development manifest)"
echo "  denial/versions.nix flutterFramework.repository:"
echo "                                      $FLUTTER_FRAMEWORK_REPOSITORY"
echo "                                       -> ${NEW_FLUTTER_FRAMEWORK_REPOSITORY:-?}"
echo "  denial/versions.nix flutterFramework.revision:"
echo "                                      $FLUTTER_FRAMEWORK_REVISION"
echo "                                       -> ${NEW_FLUTTER_FRAMEWORK_REVISION:-?}"
echo "  denial/versions.nix flutterFramework.toolBackendShellSha256:"
echo "                                      $FLUTTER_TOOL_BACKEND_SHELL_SHA256"
echo "                                       -> ${NEW_FLUTTER_TOOL_BACKEND_SHELL_SHA256:-?}"
echo "  denial/versions.nix flutterFramework.toolBackendDartSha256:"
echo "                                      $FLUTTER_TOOL_BACKEND_DART_SHA256"
echo "                                       -> ${NEW_FLUTTER_TOOL_BACKEND_DART_SHA256:-?}"
echo
echo "After editing:"
echo "  nix flake lock                # update denial/denialShell revisions in flake.lock"
echo "  nix flake check && nix build"

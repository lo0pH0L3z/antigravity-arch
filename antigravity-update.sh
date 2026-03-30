#!/usr/bin/env bash
# antigravity-update.sh
# Checks antigravity.google/changelog for new versions, downloads from
# Google's CDN, updates PKGBUILD, and rebuilds.

set -euo pipefail

PKGBUILD_DIR="${ANTIGRAVITY_PKGBUILD_DIR:-$HOME/aur/antigravity}"
CHANGELOG_URL="https://antigravity.google/changelog"
CDN_BASE="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable"

log()  { echo "[$(date -u +%FT%TZ)] $*"; }
info() { log "INFO  $*"; }
die()  { log "ERROR $*" >&2; exit 1; }

# --- Step 1: Get latest version from changelog ---
info "Fetching changelog..."
HTML=$(curl -fsSL --user-agent "Mozilla/5.0" "$CHANGELOG_URL") \
  || die "Failed to fetch changelog."

LATEST_SEMVER=$(echo "$HTML" | grep -oP '\d+\.\d+\.\d+' | head -1)
[[ -z "$LATEST_SEMVER" ]] && die "Could not parse version from changelog."
info "Latest version: $LATEST_SEMVER"

# --- Step 2: Compare with current ---
PKGBUILD="$PKGBUILD_DIR/PKGBUILD"
[[ -f "$PKGBUILD" ]] || die "PKGBUILD not found at $PKGBUILD"

CURRENT_VER=$(grep -Po '^pkgver=\K.*' "$PKGBUILD")
info "Current version: $CURRENT_VER"

if [[ "$CURRENT_VER" == "$LATEST_SEMVER" ]]; then
  info "Already up to date. Nothing to do."
  exit 0
fi

info "New version detected: $CURRENT_VER -> $LATEST_SEMVER"

# --- Step 3: Find the build ID by probing the CDN ---
# The CDN URL format is: /stable/VERSION-BUILDID/linux-x64/Antigravity.tar.gz
# Build IDs are large integers. We probe with HEAD requests.
# Known pattern: build IDs are ~16 digits and increment with each release.
info "Searching CDN for build ID..."

CURRENT_BUILD_ID=$(grep -Po '_build_id="\K[^"]+' "$PKGBUILD")
info "Current build ID: $CURRENT_BUILD_ID"

FOUND_BUILD_ID=""
FOUND_URL=""

# Coarse probe: step by 1 trillion (build IDs are 16-digit numbers)
STEP=1000000000000
SEARCH_END=$(( CURRENT_BUILD_ID + 100000000000000 ))

for (( b=CURRENT_BUILD_ID+STEP; b<=SEARCH_END; b+=STEP )); do
  CANDIDATE="${CDN_BASE}/${LATEST_SEMVER}-${b}/linux-x64/Antigravity.tar.gz"
  STATUS=$(curl -o /dev/null -sS -w "%{http_code}" --head "$CANDIDATE" 2>/dev/null || echo "000")
  if [[ "$STATUS" == "200" ]]; then
    info "Hit near build ID $b — narrowing..."
    # Narrow down within the step
    for (( exact=b-STEP; exact<=b; exact+=1000000000 )); do
      EXACT_URL="${CDN_BASE}/${LATEST_SEMVER}-${exact}/linux-x64/Antigravity.tar.gz"
      S=$(curl -o /dev/null -sS -w "%{http_code}" --head "$EXACT_URL" 2>/dev/null || echo "000")
      if [[ "$S" == "200" ]]; then
        FOUND_BUILD_ID="$exact"
        FOUND_URL="$EXACT_URL"
        info "Found build ID: $FOUND_BUILD_ID"
        break 2
      fi
    done
  fi
done

if [[ -z "$FOUND_BUILD_ID" ]]; then
  die "Could not find tarball for $LATEST_SEMVER on CDN. \
Try manually: ${CDN_BASE}/${LATEST_SEMVER}-???/linux-x64/Antigravity.tar.gz"
fi

# --- Step 4: Download and hash ---
TMP_TAR=$(mktemp --suffix=.tar.gz)
trap 'rm -f "$TMP_TAR"' EXIT

info "Downloading Antigravity.tar.gz..."
curl -fsSL --progress-bar -o "$TMP_TAR" "$FOUND_URL" \
  || die "Download failed."

NEW_SHA256=$(sha256sum "$TMP_TAR" | awk '{print $1}')
info "sha256: $NEW_SHA256"

# --- Step 5: Patch PKGBUILD ---
info "Patching PKGBUILD..."
sed -i \
  -e "s/^pkgver=.*/pkgver=${LATEST_SEMVER}/" \
  -e "s/^pkgrel=.*/pkgrel=1/" \
  -e "s/_build_id=\".*\"/_build_id=\"${FOUND_BUILD_ID}\"/" \
  -e "s/sha256sums=('.*')/sha256sums=('${NEW_SHA256}')/" \
  "$PKGBUILD"

info "PKGBUILD patched."

# --- Step 6: Rebuild ---
info "Running makepkg -si..."
cd "$PKGBUILD_DIR"

if [[ "$EUID" -eq 0 ]]; then
  [[ -z "${SUDO_USER:-}" ]] && die "Running as root with no SUDO_USER. Run as your normal user."
  sudo -u "$SUDO_USER" makepkg -si --noconfirm
else
  makepkg -si --noconfirm
fi

info "✅ Antigravity updated to ${LATEST_SEMVER}."

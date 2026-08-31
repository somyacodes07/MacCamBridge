#!/bin/bash
set -e
echo "================================================="
echo " Verifying & Triggering Official GitHub Release  "
echo "================================================="

VERSION="$1"

if [ -z "$VERSION" ]; then
    git fetch --tags --force 2>/dev/null || true
    LATEST_TAG=$(git tag -l "v*" --sort=-v:refname | head -n 1)
    if [ -n "$LATEST_TAG" ]; then
        BASE_VER=${LATEST_TAG#v}
        MAJOR=$(echo "$BASE_VER" | cut -d. -f1)
        MINOR=$(echo "$BASE_VER" | cut -d. -f2)
        PATCH=$(echo "$BASE_VER" | cut -d. -f3)
        NEXT_PATCH=$((PATCH + 1))
        VERSION="v${MAJOR}.${MINOR}.${NEXT_PATCH}"
    else
        VERSION="v1.0.1"
    fi
    echo "[*] No version specified. Auto-incremented to: $VERSION"
fi

if [[ ! "$VERSION" =~ ^v ]]; then
    VERSION="v$VERSION"
fi

echo "[*] Preparing release $VERSION..."
echo "[*] Tagging release $VERSION and pushing to GitHub..."
git tag -a "$VERSION" -m "MacCam Bridge Release $VERSION"
git push origin "$VERSION"

echo ""
echo "[+] Release tag $VERSION pushed to GitHub successfully!"
echo "[+] GitHub Actions CI/CD will automatically build, package, and publish the release."

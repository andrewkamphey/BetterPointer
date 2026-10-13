#!/usr/bin/env bash
# One-time setup: creates a self-signed code-signing certificate in your login
# keychain so BetterPointer keeps a stable identity across rebuilds. macOS then
# remembers the Full Disk Access grant instead of resetting it every build.
#
# The certificate is local to this Mac and only used to sign your own build.
# Remove it any time in Keychain Access (search "BetterPointer Self-Signed").
set -euo pipefail

NAME="BetterPointer Self-Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "Certificate \"$NAME\" already exists. Nothing to do."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF

echo "Creating certificate \"$NAME\"…"
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$TMP/cert.cnf" \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
PASS="$(/usr/bin/openssl rand -hex 16)"
/usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$NAME" \
    -out "$TMP/cert.p12" -passout "pass:$PASS"

# -T lets codesign use the key without a keychain prompt on every build.
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$PASS" -T /usr/bin/codesign >/dev/null

echo "Done. ./build.sh will now sign with \"$NAME\"."
echo "Grant Full Disk Access to BetterPointer once more after the next build; it will stick from then on."

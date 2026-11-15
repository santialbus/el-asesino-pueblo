
#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

if [[ ! -f .env.local ]]; then
  echo "ERROR: No existe .env.local"
  exit 1
fi

set -a
source .env.local
set +a

VARS=(
  FIREBASE_API_KEY
  FIREBASE_AUTH_DOMAIN
  FIREBASE_PROJECT_ID
  FIREBASE_STORAGE_BUCKET
  FIREBASE_MESSAGING_SENDER_ID
  FIREBASE_APP_ID
)

for VAR in "${VARS[@]}"; do
  if [[ -z "${!VAR}" ]]; then
    echo "ERROR: $VAR está vacía"
    exit 1
  fi
done

echo "Firebase variables loaded successfully!"

flutter run -d chrome \
  --dart-define=FIREBASE_API_KEY="$FIREBASE_API_KEY" \
  --dart-define=FIREBASE_AUTH_DOMAIN="$FIREBASE_AUTH_DOMAIN" \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_STORAGE_BUCKET="$FIREBASE_STORAGE_BUCKET" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define=FIREBASE_APP_ID="$FIREBASE_APP_ID"

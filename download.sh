#!/bin/zsh

# --- Configuration ---
PANOPTO_HOST="your-org.cloud.panopto.eu"
CLIENT_ID="your-client-id"
CLIENT_SECRET="your-client-secret"

# Session IDs to download
SESSION_IDS=(
  "id-1"
  "id-2"
)

# --- Authentication ---
echo "Authenticating with $PANOPTO_HOST..."
TOKEN=$(curl -s -X POST "https://$PANOPTO_HOST/Panopto/oauth2/connect/token" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=api" | sed -E 's/.*"access_token":"([^"]+)".*/\1/')

if [[ -z "$TOKEN" || "$TOKEN" == *"error"* ]]; then
  echo "Authentication failed. Check CLIENT_ID and CLIENT_SECRET."
  exit 1
fi

# --- Processing ---
for id in "${SESSION_IDS[@]}"; do
  echo "--- Processing: $id ---"

  # Query the Viewer Delivery Engine for the internal stream URL
  RAW_PATH=$(curl -s -X POST "https://$PANOPTO_HOST/Panopto/Pages/Viewer/DeliveryInfo.aspx" \
    -d "deliveryId=$id" \
    -d "isEmbed=true" \
    -d "responseType=json" \
    | sed -E 's/.*"StreamUrl":"([^"]+)".*/\1/' | sed 's/\\//g')

  # Convert HLS manifest path to a direct MP4 URL
  # Panopto storage convention: .hls/master.m3u8 -> .mp4
  MP4_URL=$(echo "$RAW_PATH" | sed 's/\.hls\/master\.m3u8/\.mp4/')

  if [[ $MP4_URL == http* ]]; then
    echo "Stream resolved. Downloading..."
    curl -# -L "$MP4_URL" -o "video_$id.mp4"
  else
    echo "Error: could not resolve stream for session $id."
  fi
done

echo "Done."

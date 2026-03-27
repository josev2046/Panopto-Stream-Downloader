# Panopto Stream Downloader

A lightweight shell utility for downloading Panopto sessions as MP4 files.

## The Problem

Standard Panopto API methods such as `GetVideoDownloadURL` (SOAP) and `deliveryInfo` (REST) frequently return empty results when:

- The "Podcast" output is not explicitly enabled on the session.
- The API user does not hold "Creator" permissions on the target folder.
- Site-wide download settings are restrictive.

## The Approach

<img width="619" height="759" alt="image" src="https://github.com/user-attachments/assets/fde76165-f0eb-4fa9-ab0d-11539ec641fd" />


This script bypasses the Management API entirely by querying the **Viewer Delivery Engine** directly. It retrieves the internal HLS stream path used by the web player and converts it to a progressive MP4 download URL.

Note: because this method targets the public-facing viewer engine, no `UserKey` or `Password` (`AuthenticationInfo` in SOAP terms) is required. Only the `deliveryId` (Session ID) is needed, which keeps things considerably cleaner.

## Features

- Authenticates via OAuth2 (Client Credentials).
- Queries `DeliveryInfo.aspx` to locate internal stream paths.
- Automatically converts `.m3u8` HLS paths to direct `.mp4` download URLs.
- Processes multiple Session IDs in a single run.

## Prerequisites

- **Panopto API Client** — must be created as a **Server Application**.
- **Tools** — `curl`, `sed`, and either `zsh` or `bash`.

## Usage

1. Clone the repository.
2. Edit the variables at the top of `download.sh`.
3. Run the script:

```bash
chmod +x download.sh
./download.sh
```

## `download.sh`

```zsh
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
```

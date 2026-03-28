# Panopto Stream Downloader

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19265501.svg)](https://doi.org/10.5281/zenodo.19265501)

A lightweight, zero-auth shell utility for downloading Panopto sessions as MP4 files by bypassing the official API.

---

## The problem

Standard Panopto API methods — such as `GetVideoDownloadURL` (SOAP) and `deliveryInfo` (REST) — frequently return empty results or 404s when:

- The **Podcast** output is not explicitly enabled on the session.
- The API user does not hold **Creator** permissions on the target folder.
- Site-wide download settings are restrictive.

---

## The approach

This script bypasses the Management API entirely by querying the **Viewer Delivery Engine** directly. By simulating an anonymous request to the embedded web player, it retrieves the internal HLS stream path and converts it to a progressive MP4 download URL.

<img width="600" height="604" alt="image" src="https://github.com/user-attachments/assets/588e4f9d-9233-40ed-ac89-bb7d0aa904a9" />


> **Note:** Because this method mimics a public-facing embed player, no API credentials, OAuth tokens, or UserKeys are required. Only the `deliveryId` (Session ID) is needed, keeping the script fast and clean.

---

## Features

| Feature | Detail |
|---|---|
| **Zero Authentication** | No API clients or OAuth2 tokens required |
| **Internal Extraction** | Queries `DeliveryInfo.aspx` to locate hidden stream paths |
| **Automatic Conversion** | Converts fragmented `.m3u8` HLS paths to direct `.mp4` download URLs |
| **Batch Processing** | Downloads multiple Session IDs sequentially in a single run |

---

## Prerequisites

The following tools must be available on your system — both are native to macOS and Linux:

- `curl`
- `sed`
- `zsh` or `bash`

---

## Usage

1. **Clone the repository:**

   ```bash
   git clone https://github.com/your-org/panopto-stream-downloader.git
   cd panopto-stream-downloader
   ```

2. **Edit the configuration** in `download.sh`:
   - Set `HOST` to your organisation's Panopto domain.
   - Populate the `SESSIONS` array with the Session IDs you wish to download.

3. **Run the script:**

   ```bash
   chmod +x download.sh
   ./download.sh
   ```

---

## Script

```bash
#!/bin/zsh

# --- Configuration ---
HOST="your-org.cloud.panopto.eu"

# Session IDs to download
SESSIONS=(
  "id-1"
  "id-2"
)

# --- Processing ---
echo "🚀 Starting Panopto extraction..."

for id in "${SESSIONS[@]}"; do
  echo "--- Processing: $id ---"

  # 1. Fetch DeliveryInfo JSON exactly as the web player does (no auth required)
  RAW_JSON=$(curl -s -X POST "https://$HOST/Panopto/Pages/Viewer/DeliveryInfo.aspx" \
    -d "deliveryId=$id" \
    -d "isEmbed=true" \
    -d "responseType=json")

  # 2. Extract the StreamUrl, clean escape characters, and swap .m3u8 for .mp4
  #    Panopto storage convention: .hls/master.m3u8 → .mp4
  STREAM_URL=$(echo "$RAW_JSON" \
    | sed -E 's/.*"StreamUrl":"([^"]+)".*/\1/' \
    | sed 's/\\//g' \
    | sed 's/\.hls\/master\.m3u8/\.mp4/')

  # 3. Download the file
  if [[ $STREAM_URL == http* ]]; then
    echo "✅ Direct MP4 found. Downloading..."
    curl --progress-bar -L "$STREAM_URL" -o "video_$id.mp4"
  else
    echo "❌ Stream blocked or not found. Ensure the video is publicly accessible or shared via link."
  fi
done

echo "🎉 Batch download complete!"
```

---

## How it works

```
Session ID (deliveryId)
        │
        ▼
POST /Panopto/Pages/Viewer/DeliveryInfo.aspx
   isEmbed=true  |  responseType=json
        │
        ▼
  Parse "StreamUrl" from JSON response
        │
        ▼
  .hls/master.m3u8  →  .mp4
        │
        ▼
  curl download → video_<id>.mp4
```

---

## Troubleshooting

**`❌ Stream blocked or not found`**
The session may be restricted to authenticated viewers only. Verify the video is accessible via a shared or public link before running the script.

**Partial or corrupt downloads**
Re-run the script for the affected Session ID. Panopto's CDN occasionally throttles large files.


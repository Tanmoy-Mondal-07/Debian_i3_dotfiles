#!/usr/bin/env bash

  set -euo pipefail

  # -------- Configuration --------
  API_KEY="${GEMINI_API_KEY:?Error: GEMINI_API_KEY not set. Please run: export GEMINI_API_KEY='your_key'}"
  MODEL="${GEMINI_MODEL:-gemini-3-flash-preview}"
  API_URL="https://generativelanguage.googleapis.com/v1beta/interactions"

  # Memory tied to THIS terminal tab ($PPID)
  HISTORY_FILE="/tmp/gemini_history_$PPID.json"
  if [ ! -f "$HISTORY_FILE" ]; then echo '[]' > "$HISTORY_FILE"; fi

  # -------- Dependency Checks --------
  for cmd in curl jq glow file base64; do
      command -v "$cmd" >/dev/null 2>&1 || { echo >&2 "Error: $cmd is required. Install with: sudo apt install $cmd"; exit 1; }
  done

  usage() {
      echo "Usage: Ask Gemini [OPTIONS] [PROMPT]"
      echo "  -i, --image <file>    Attach an image."
      echo "  -f, --file <file>     Read prompt from text file."
      echo "  clear                 Reset memory for this terminal tab."
      exit 1
  }

  # -------- Variables --------
  PROMPT_TEXT=""
  IMAGE_FILE=""

  # -------- Argument Parsing & Auto-Detection --------
  if [[ "${1:-}" == "clear" ]]; then
      echo "[]" > "$HISTORY_FILE"
      echo "✨ Memory cleared."
      exit 0
  fi

  while [[ $# -gt 0 ]]; do
      case "$1" in
          -i|--image)
              IMAGE_FILE="$2"; shift 2 ;;
          -f|--file)
              PROMPT_TEXT+="$(< "$2") "; shift 2 ;;
  	      -v|--version)
  		      echo "Ask Gimini Version 0.12.5"; exit 1 ;;
          -h|--help)
              usage ;;
          *)
              if [[ -f "$1" ]] && file --mime-type "$1" | grep -qE 'image/(jpeg|png|webp|heic|heif)'; then
                  IMAGE_FILE="$1"
              else
                  PROMPT_TEXT+="$1 "
              fi
              shift
              ;;
      esac
  done

  # Trim whitespace
  PROMPT_TEXT="$(echo "$PROMPT_TEXT" | xargs || true)"

  # Fallbacks
  if [ -z "$PROMPT_TEXT" ] && [ -n "$IMAGE_FILE" ]; then
      PROMPT_TEXT="Describe this image."
  fi

  if [ -z "$PROMPT_TEXT" ]; then
      usage
  fi

  # -------- Image Processing --------
  BASE64_IMAGE=""
  MIME_TYPE=""
  if [ -n "${IMAGE_FILE:-}" ]; then
      if [ ! -f "$IMAGE_FILE" ]; then
          echo "Error: File '$IMAGE_FILE' not found." >&2
          exit 1
      fi
      MIME_TYPE=$(file -b --mime-type "$IMAGE_FILE")
      # base64 without linewraps; fallback for macOS/base64 variants
      if BASE64_IMAGE=$(base64 -w0 "$IMAGE_FILE" 2>/dev/null); then
          :
      else
          BASE64_IMAGE=$(base64 "$IMAGE_FILE" | tr -d '\n')
      fi
  fi

  # -------- Build Interactions Payload --------

  if [ -n "$IMAGE_FILE" ]; then
      BASE64_IMAGE=$(base64 -w0 "$IMAGE_FILE" 2>/dev/null || base64 "$IMAGE_FILE" | tr -d '\n')

      JSON_PAYLOAD=$(jq -n \
        --arg model "$MODEL" \
        --arg txt "$PROMPT_TEXT" \
        --arg mt "$MIME_TYPE" \
        --rawfile img <(printf '%s' "$BASE64_IMAGE") \
        '{
           model: $model,
           input: [
             { type: "text", text: $txt },
             { type: "image", data: $img, mime_type: $mt }
           ]
         }'
      )
  else
      JSON_PAYLOAD=$(jq -n \
        --arg model "$MODEL" \
        --arg txt "$PROMPT_TEXT" \
        '{ model: $model, input: [ { type: "text", text: $txt } ] }'
      )
  fi

  # -------- Save user turn to local history (simple) --------

  USER_ENTRY=$(jq -n --arg r "user" --arg c "$PROMPT_TEXT" '{role:$r, content:$c}')
  jq --argjson e "$USER_ENTRY" '. + [$e]' "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"

  # -------- API Call --------
  echo "🤖 Thinking..." >&2

  RESPONSE=$(
    printf '%s' "$JSON_PAYLOAD" | curl -s -X POST "$API_URL" \
      -H "Content-Type: application/json" \
      -H "x-goog-api-key: $API_KEY" \
      --data-binary @-
  )

  # -------- Error handling --------
  if echo "$RESPONSE" | jq -e 'has("error")' >/dev/null 2>&1; then
      echo "❌ API Error:" >&2
      echo "$RESPONSE" | jq -r '.error.message // (.error | tostring)' >&2
      exit 1
  fi

  # -------- Extract model text output --------
  # Prefer the last text output in .outputs
  ANSWER=$(echo "$RESPONSE" | jq -r '.outputs | map(select(.type == "text")) | .[-1].text // ""')

  if [ -z "$ANSWER" ]; then
      # If no text outputs, try generic outputs field fallback
      ANSWER=$(echo "$RESPONSE" | jq -r '.outputs[-1].text // .outputs[-1].content // ""')
  fi

  if [ -z "$ANSWER" ]; then
      echo "⚠️  No text response from model. Full response for debugging:" >&2
      echo "$RESPONSE" | jq . >&2
      exit 1
  fi

  # -------- Save model answer to history --------
  MODEL_ENTRY=$(jq -n --arg r "model" --arg c "$ANSWER" '{role:$r, content:$c}')
  jq --argjson e "$MODEL_ENTRY" '. + [$e]' "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"

  # -------- Render --------

  echo "$ANSWER" | glow -s tokyo-night
FROM nousresearch/hermes-agent:latest

ENV HERMES_HOME=/opt/data
ENV PORT=10000
ENV PYTHONUNBUFFERED=1

RUN mkdir -p /opt/data

RUN cat > /opt/hermes/render-entrypoint.sh <<'EOF'
#!/bin/sh
set -eu

echo "=============================================="
echo " Hermes Agent - Render"
echo "=============================================="

export HERMES_HOME=/opt/data

mkdir -p "$HERMES_HOME"
mkdir -p "$HERMES_HOME/logs"
mkdir -p "$HERMES_HOME/sessions"
mkdir -p "$HERMES_HOME/memories"
mkdir -p "$HERMES_HOME/skills"

# ------------------------------------------------
# Validate required environment variables
# ------------------------------------------------

if [ -z "${GEMINI_API_KEY:-}" ]; then
    echo "[ERROR] GEMINI_API_KEY is missing."
    exit 1
fi

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
    echo "[ERROR] TELEGRAM_BOT_TOKEN is missing."
    exit 1
fi

# ------------------------------------------------
# Write Hermes secrets
# ------------------------------------------------

cat > "$HERMES_HOME/.env" <<ENVFILE
GEMINI_API_KEY=${GEMINI_API_KEY}
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
ENVFILE

chmod 600 "$HERMES_HOME/.env"

# ------------------------------------------------
# Write Hermes configuration
# ------------------------------------------------

cat > "$HERMES_HOME/config.yaml" <<'YAML'
model:
  provider: gemini
  default: gemini-2.5-flash
  base_url: https://generativelanguage.googleapis.com/v1beta

agent:
  max_turns: 30

fallback_providers:
  - provider: openrouter
    model: google/gemini-2.5-flash

YAML

echo "[OK] Hermes configuration:"
echo "     HERMES_HOME : $HERMES_HOME"
echo "     Provider    : gemini"
echo "     Model       : gemini-2.5-flash"
echo "     Base URL    : native Gemini API"

# ------------------------------------------------
# Telegram allowlist
# ------------------------------------------------

if [ -n "${TELEGRAM_ALLOWED_USERS:-}" ]; then
    echo "[OK] Telegram allowlist configured."
else
    echo "[WARNING] TELEGRAM_ALLOWED_USERS is empty."
fi

# ------------------------------------------------
# Optional OpenRouter fallback
# ------------------------------------------------

if [ -n "${OPENROUTER_API_KEY:-}" ]; then

    cat >> "$HERMES_HOME/.env" <<ENVFILE
OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
ENVFILE

    echo "[OK] OpenRouter fallback credentials configured."

else

    echo "[WARNING] OPENROUTER_API_KEY not configured."
    echo "[WARNING] Gemini will be the only model provider."

fi

# ------------------------------------------------
# Render HTTP server
# ------------------------------------------------

echo "[OK] Starting Render HTTP server on port ${PORT}"

python -m http.server \
    "${PORT}" \
    --bind 0.0.0.0 \
    --directory /tmp \
    >/tmp/render-http.log 2>&1 &

HTTP_PID=$!

# ------------------------------------------------
# Cleanup
# ------------------------------------------------

cleanup() {

    echo "[INFO] Shutting down Hermes..."

    if [ -n "${HERMES_PID:-}" ]; then
        kill "${HERMES_PID}" 2>/dev/null || true
    fi

    if [ -n "${HTTP_PID:-}" ]; then
        kill "${HTTP_PID}" 2>/dev/null || true
    fi

}

trap cleanup INT TERM EXIT

# ------------------------------------------------
# Start Hermes
# ------------------------------------------------

echo "[OK] Starting Hermes Gateway..."

cd /opt/data

hermes gateway run &
HERMES_PID=$!

echo "[OK] Hermes PID: $HERMES_PID"
echo "[OK] HTTP PID:   $HTTP_PID"

# ------------------------------------------------
# Keep container alive while Hermes is alive
# ------------------------------------------------

wait "$HERMES_PID"

EXIT_CODE=$?

echo "[ERROR] Hermes stopped with exit code $EXIT_CODE"

exit "$EXIT_CODE"
EOF

RUN chmod +x /opt/hermes/render-entrypoint.sh

EXPOSE 10000

ENTRYPOINT ["/opt/hermes/render-entrypoint.sh"]

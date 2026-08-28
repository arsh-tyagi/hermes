# ============================================================
# Hermes Agent + Google Gemini + Telegram
# Render Docker deployment
# ============================================================

FROM nousresearch/hermes-agent:latest

ENV PORT=10000
ENV HERMES_HOME=/opt/data
ENV PYTHONUNBUFFERED=1

RUN cat > /opt/hermes/render-start.sh <<'EOF'
#!/bin/sh

set -eu

echo "================================================"
echo " Hermes Agent - Render Startup"
echo "================================================"

# ------------------------------------------------
# Validate required credentials
# ------------------------------------------------

if [ -z "${GEMINI_API_KEY:-}" ]; then
    echo "[ERROR] GEMINI_API_KEY is not configured."
    echo "[ERROR] Add GEMINI_API_KEY in Render Environment."
    exit 1
fi

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
    echo "[ERROR] TELEGRAM_BOT_TOKEN is not configured."
    echo "[ERROR] Add TELEGRAM_BOT_TOKEN in Render Environment."
    exit 1
fi

# ------------------------------------------------
# Hermes directories
# ------------------------------------------------

mkdir -p "${HERMES_HOME}"

CONFIG_FILE="${HERMES_HOME}/config.yaml"

# ------------------------------------------------
# Explicit Gemini configuration
# ------------------------------------------------

cat > "${CONFIG_FILE}" <<YAML
model:
  default: gemini-2.5-flash
  provider: gemini

YAML

echo "[OK] Hermes configuration created."
echo "[OK] Provider : gemini"
echo "[OK] Model    : gemini-2.5-flash"

# ------------------------------------------------
# Telegram configuration
# ------------------------------------------------

if [ -n "${TELEGRAM_ALLOWED_USERS:-}" ]; then
    echo "[OK] Telegram allowed users configured."
else
    echo "[WARNING] TELEGRAM_ALLOWED_USERS is empty."
    echo "[WARNING] The bot may not be restricted to your users."
fi

# ------------------------------------------------
# Render HTTP server
# ------------------------------------------------

echo "[OK] Starting HTTP server on port ${PORT}"

python -m http.server \
    "${PORT}" \
    --bind 0.0.0.0 \
    --directory /tmp \
    >/tmp/render-http.log 2>&1 &

HTTP_PID=$!

# ------------------------------------------------
# Graceful shutdown
# ------------------------------------------------

cleanup() {
    echo "[INFO] Shutting down..."

    if kill -0 "${HTTP_PID}" 2>/dev/null; then
        kill "${HTTP_PID}" 2>/dev/null || true
    fi

    if [ -n "${HERMES_PID:-}" ] &&
       kill -0 "${HERMES_PID}" 2>/dev/null; then
        kill "${HERMES_PID}" 2>/dev/null || true
    fi

    wait "${HTTP_PID}" 2>/dev/null || true

    if [ -n "${HERMES_PID:-}" ]; then
        wait "${HERMES_PID}" 2>/dev/null || true
    fi
}

trap cleanup INT TERM EXIT

# ------------------------------------------------
# Start Hermes Gateway
# ------------------------------------------------

echo "[OK] Starting Hermes Gateway..."

hermes gateway run &
HERMES_PID=$!

echo "[OK] Hermes PID: ${HERMES_PID}"
echo "[OK] HTTP PID:   ${HTTP_PID}"

echo "================================================"
echo " Hermes is running"
echo "================================================"

# ------------------------------------------------
# Keep container tied to Hermes process
# ------------------------------------------------

wait "${HERMES_PID}"

EXIT_CODE=$?

echo "[ERROR] Hermes exited with code ${EXIT_CODE}"

exit "${EXIT_CODE}"
EOF

RUN chmod +x /opt/hermes/render-start.sh

EXPOSE 10000

ENTRYPOINT ["/opt/hermes/render-start.sh"]

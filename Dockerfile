# ============================================================
# Hermes Agent + Groq + Telegram
# Render-compatible Docker deployment
# ============================================================

FROM nousresearch/hermes-agent:latest

# Render expects the web service to listen on this port.
ENV PORT=10000

# Hermes persistent/configuration directory.
ENV HERMES_HOME=/opt/data

# Prevent Python output buffering.
ENV PYTHONUNBUFFERED=1

# Create Render startup script.
RUN cat > /opt/hermes/render-start.sh <<'EOF'
#!/bin/sh

set -eu

echo "=============================================="
echo " Hermes Agent - Render Startup"
echo "=============================================="

# ------------------------------------------------------------
# Required secrets validation
# ------------------------------------------------------------

if [ -z "${GROQ_API_KEY:-}" ]; then
    echo "[ERROR] GROQ_API_KEY is not set."
    exit 1
fi

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
    echo "[ERROR] TELEGRAM_BOT_TOKEN is not set."
    exit 1
fi

# ------------------------------------------------------------
# Hermes directories
# ------------------------------------------------------------

mkdir -p "${HERMES_HOME}"

CONFIG_FILE="${HERMES_HOME}/config.yaml"

# ------------------------------------------------------------
# Explicit Hermes configuration
#
# This deliberately avoids OPENAI_BASE_URL.
# Groq is configured as a named custom provider.
# ------------------------------------------------------------

cat > "${CONFIG_FILE}" <<YAML
custom_providers:
  - name: groq
    base_url: https://api.groq.com/openai/v1
    key_env: GROQ_API_KEY
    api_mode: chat_completions

model:
  default: llama-3.3-70b-versatile
  provider: custom:groq

YAML

echo "[OK] Hermes configuration generated:"
echo "     Provider : custom:groq"
echo "     Model    : llama-3.3-70b-versatile"
echo "     Endpoint : https://api.groq.com/openai/v1"

# ------------------------------------------------------------
# Telegram security
# ------------------------------------------------------------

if [ -n "${TELEGRAM_ALLOWED_USERS:-}" ]; then
    echo "[OK] Telegram user allowlist configured."
else
    echo "[WARNING] TELEGRAM_ALLOWED_USERS is not set."
    echo "[WARNING] Consider setting it for security."
fi

# ------------------------------------------------------------
# Render health/keep-alive HTTP server
# ------------------------------------------------------------

echo "[OK] Starting HTTP server on 0.0.0.0:${PORT}"

python -m http.server "${PORT}" \
    --bind 0.0.0.0 \
    --directory /tmp \
    >/tmp/render-http.log 2>&1 &

HTTP_PID=$!

# ------------------------------------------------------------
# Graceful shutdown
# ------------------------------------------------------------

cleanup() {
    echo "[INFO] Shutting down Hermes..."

    if kill -0 "${HTTP_PID}" 2>/dev/null; then
        kill "${HTTP_PID}" 2>/dev/null || true
    fi

    if [ -n "${HERMES_PID:-}" ] && kill -0 "${HERMES_PID}" 2>/dev/null; then
        kill "${HERMES_PID}" 2>/dev/null || true
    fi

    wait "${HTTP_PID}" 2>/dev/null || true

    if [ -n "${HERMES_PID:-}" ]; then
        wait "${HERMES_PID}" 2>/dev/null || true
    fi
}

trap cleanup INT TERM EXIT

# ------------------------------------------------------------
# Start Hermes Gateway
# ------------------------------------------------------------

echo "[OK] Starting Hermes Gateway..."

hermes gateway run &
HERMES_PID=$!

echo "[OK] Hermes PID: ${HERMES_PID}"
echo "[OK] HTTP PID:   ${HTTP_PID}"
echo "=============================================="

# ------------------------------------------------------------
# Keep container alive while Hermes is running.
# If Hermes exits, terminate the container so Render restarts it.
# ------------------------------------------------------------

wait "${HERMES_PID}"

EXIT_CODE=$?

echo "[ERROR] Hermes exited with code ${EXIT_CODE}"

exit "${EXIT_CODE}"
EOF

RUN chmod +x /opt/hermes/render-start.sh

# Render's public HTTP port.
EXPOSE 10000

# We intentionally replace the image's default command with
# our Render launcher so both processes are started together.
ENTRYPOINT ["/opt/hermes/render-start.sh"]

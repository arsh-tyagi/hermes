# ============================================================
# Hermes Agent - Render Free
# Telegram + Google Gemini
#
# IMPORTANT:
# - Keep Hermes' official /init entrypoint.
# - Do NOT create /opt/data/.env manually.
# - Secrets come directly from Render environment variables.
# - A tiny HTTP server runs under s6 alongside Hermes.
# ============================================================

FROM nousresearch/hermes-agent:latest

USER root

ENV HERMES_HOME=/opt/data
ENV PORT=10000
ENV PYTHONUNBUFFERED=1

# ------------------------------------------------------------
# Add a tiny Render health/port service to Hermes' existing
# s6 supervision tree.
# ------------------------------------------------------------

RUN mkdir -p /etc/s6-overlay/s6-rc.d/render-http/dependencies.d \
             /etc/s6-overlay/s6-rc.d/user/contents.d

# Mark service as a long-running supervised service.
RUN printf 'longrun\n' \
    > /etc/s6-overlay/s6-rc.d/render-http/type

# Make it wait for Hermes' base/user services.
RUN touch /etc/s6-overlay/s6-rc.d/render-http/dependencies.d/base

# Add service to the user bundle.
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/render-http

# ------------------------------------------------------------
# Render HTTP service
# ------------------------------------------------------------

RUN cat > /etc/s6-overlay/s6-rc.d/render-http/run <<'EOF'
#!/command/with-contenv sh
set -eu

PORT="${PORT:-10000}"

echo "[render-http] Starting HTTP server on 0.0.0.0:${PORT}"

exec s6-setuidgid hermes \
    python -m http.server \
    "${PORT}" \
    --bind 0.0.0.0 \
    --directory /tmp
EOF

RUN chmod +x /etc/s6-overlay/s6-rc.d/render-http/run

# ------------------------------------------------------------
# Use the official Hermes entrypoint.
#
# This is CRITICAL:
# /init runs Hermes' stage2 bootstrap, fixes /opt/data
# permissions, loads environment variables and starts the
# correct runtime user.
# ------------------------------------------------------------

ENTRYPOINT ["/init", "/opt/hermes/docker/main-wrapper.sh"]

# ------------------------------------------------------------
# Run the gateway as the main command.
# ------------------------------------------------------------

CMD ["gateway", "run"]

EXPOSE 10000

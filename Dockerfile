FROM nousresearch/hermes-agent:latest

ENV HERMES_HOME=/opt/data
ENV PORT=10000
ENV PYTHONUNBUFFERED=1
ENV HERMES_DASHBOARD=0

USER root

RUN mkdir -p \
    /etc/s6-overlay/s6-rc.d/render-http/dependencies.d \
    /etc/s6-overlay/s6-rc.d/user/contents.d

RUN printf 'longrun\n' \
    > /etc/s6-overlay/s6-rc.d/render-http/type

RUN touch \
    /etc/s6-overlay/s6-rc.d/render-http/dependencies.d/base \
    /etc/s6-overlay/s6-rc.d/user/contents.d/render-http

RUN cat > /etc/s6-overlay/s6-rc.d/render-http/run <<'EOF'
#!/command/with-contenv sh
set -eu

PORT="${PORT:-10000}"

exec s6-setuidgid hermes \
    python -m http.server \
    "$PORT" \
    --bind 0.0.0.0 \
    --directory /tmp
EOF

RUN chmod +x /etc/s6-overlay/s6-rc.d/render-http/run

# ------------------------------------------------------------
# Generate only NON-SECRET Hermes configuration.
# Secrets remain in Render's environment.
# ------------------------------------------------------------
RUN cat > /opt/hermes/render-config.sh <<'EOF'
#!/command/with-contenv sh
set -eu

mkdir -p "$HERMES_HOME"

cat > "$HERMES_HOME/config.yaml" <<'YAML'
model:
  provider: openrouter
  default: openrouter/free

# Keep the main agent lightweight on Render Free.
agent:
  max_turns: 15

# Do not spend extra calls on optional auxiliary services.
auxiliary:
  compression:
    provider: main
    model: ""

# If the OpenRouter free router temporarily fails,
# Hermes can try another configured provider later.
fallback_providers: []
YAML

chown -R hermes:hermes "$HERMES_HOME"
chmod 755 "$HERMES_HOME"

echo "[render-config] OpenRouter Free Router configured."
EOF

RUN chmod +x /opt/hermes/render-config.sh

# ------------------------------------------------------------
# IMPORTANT:
# Run configuration immediately before Hermes starts.
# The actual /init remains Hermes' PID 1.
# ------------------------------------------------------------
RUN sed -i \
    '/^exec "\/opt\/hermes\/docker\/main-wrapper.sh"/i /opt/hermes/render-config.sh' \
    /opt/hermes/docker/main-wrapper.sh

EXPOSE 10000

ENTRYPOINT ["/init", "/opt/hermes/docker/main-wrapper.sh"]

CMD ["gateway", "run"]

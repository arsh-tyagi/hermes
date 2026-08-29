FROM nousresearch/hermes-agent:latest

USER root

ENV HERMES_HOME=/opt/hermes_home
ENV PORT=10000
ENV PYTHONUNBUFFERED=1
ENV HERMES_DASHBOARD=0

RUN mkdir -p /opt/hermes_home /etc/s6-overlay/s6-rc.d/render-http/dependencies.d /etc/s6-overlay/s6-rc.d/user/contents.d /etc/cont-init.d

COPY SOUL.md /opt/hermes_home/SOUL.md

RUN chown -R hermes:hermes /opt/hermes_home && chmod 755 /opt/hermes_home && chmod 644 /opt/hermes_home/SOUL.md

RUN cat > /etc/cont-init.d/10-render-hermes-config <<'EOF'
#!/command/with-contenv sh
set -eu
HERMES_HOME="${HERMES_HOME:-/opt/hermes_home}"
mkdir -p "$HERMES_HOME"
cat > "$HERMES_HOME/config.yaml" <<'YAML'
model:
  provider: openrouter
  default: openrouter/free
compression:
  enabled: true
  threshold: 0.50
  target_ratio: 0.20
  protect_last_n: 12
  min_tail_user_messages: 1
agent:
  max_turns: 12
YAML
chown -R hermes:hermes "$HERMES_HOME"
EOF
RUN chmod +x /etc/cont-init.d/10-render-hermes-config

RUN printf 'longrun\n' > /etc/s6-overlay/s6-rc.d/render-http/type
RUN touch /etc/s6-overlay/s6-rc.d/render-http/dependencies.d/base /etc/s6-overlay/s6-rc.d/user/contents.d/render-http

RUN cat > /etc/s6-overlay/s6-rc.d/render-http/run <<'EOF'
#!/command/with-contenv sh
set -eu
exec s6-setuidgid hermes python -m http.server "${PORT:-10000}" --bind 0.0.0.0 --directory /tmp
EOF
RUN chmod +x /etc/s6-overlay/s6-rc.d/render-http/run

EXPOSE 10000
ENTRYPOINT ["/init", "/opt/hermes/docker/main-wrapper.sh"]
CMD ["gateway", "run"]

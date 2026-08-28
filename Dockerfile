FROM nousresearch/hermes-agent:latest

ENV HERMES_HOME=/opt/data
ENV PORT=10000
ENV PYTHONUNBUFFERED=1

# Render only needs an HTTP listener.
# Hermes itself remains managed by its official /init + s6 setup.

USER root

# Disable optional dashboard to reduce RAM/disk overhead on Render Free.
ENV HERMES_DASHBOARD=0

# Add a tiny supervised HTTP service for Render's Web Service port.
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

exec s6-setuidgid hermes \
  python -m http.server \
  "${PORT:-10000}" \
  --bind 0.0.0.0 \
  --directory /tmp
EOF

RUN chmod +x /etc/s6-overlay/s6-rc.d/render-http/run

EXPOSE 10000

# IMPORTANT:
# Keep the official Hermes /init process.
ENTRYPOINT ["/init", "/opt/hermes/docker/main-wrapper.sh"]

CMD ["gateway", "run"]

# Pull the official public Hermes Agent base image from Docker Hub
FROM nousresearch/hermes-agent:latest

# Set standard OpenAI-compatible environment variables natively recognized by Hermes
ENV OPENAI_BASE_URL="https://api.groq.com/openai/v1"
ENV OPENAI_API_KEY=""
ENV HERMES_MODEL_DEFAULT="llama-3.3-70b-versatile"
ENV GATEWAY_ALLOW_ALL_USERS="true"

# Create a robust boot script that starts the Hermes gateway in the background
# and a lightweight Python web server in the foreground to satisfy port constraints.
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'hermes gateway &' >> /start.sh && \
    echo 'python3 -m http.server 10000' >> /start.sh && \
    chmod +x /start.sh

# Expose port 10000 for the keep-alive health check
EXPOSE 10000

# Execute the startup script on container boot
CMD ["/start.sh"]

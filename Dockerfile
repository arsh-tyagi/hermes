# Pull the official Hermes Agent image
FROM ghcr.io/nousresearch/hermes-agent:latest

# Create a dual-startup script
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'export LLM_PROVIDER="groq"' >> /start.sh && \
    echo 'export LLM_MODEL="llama-3.3-70b-versatile"' >> /start.sh && \
    echo 'hermes gateway &' >> /start.sh && \
    echo 'python3 -m http.server 10000' >> /start.sh && \
    chmod +x /start.sh

# Render requires web traffic on a port to stay awake
EXPOSE 10000

# Execute the script
CMD ["/start.sh"]

# Pull the official Hermes Agent image
FROM ghcr.io/nousresearch/hermes-agent:latest

# Create an automated startup script to bypass the interactive setup
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'export LLM_PROVIDER="groq"' >> /start.sh && \
    echo 'export LLM_MODEL="llama-3.3-70b-versatile"' >> /start.sh && \
    echo 'hermes gateway' >> /start.sh && \
    chmod +x /start.sh

# Execute the script when the container boots
CMD ["/start.sh"]

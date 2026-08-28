# Pull the official Hermes Agent image
FROM nousresearch/hermes-agent:latest

# Use Hermes's native CLI commands to configure the custom Groq provider
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'hermes config set model.provider custom:local' >> /start.sh && \
    echo 'hermes config set model.base_url "https://api.groq.com/openai/v1"' >> /start.sh && \
    echo 'hermes config set model.api_key "$GROQ_API_KEY"' >> /start.sh && \
    echo 'hermes config set model.default "llama-3.3-70b-versatile"' >> /start.sh && \
    echo 'hermes gateway &' >> /start.sh && \
    echo 'python3 -m http.server 10000' >> /start.sh && \
    chmod +x /start.sh

# Render requires web traffic on a port to stay awake
EXPOSE 10000

# Execute the script
CMD ["/start.sh"]

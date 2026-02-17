# Terraform Docker Image for Azure Deployment
FROM hashicorp/terraform:1.7

# Install Azure CLI
RUN apk add --no-cache \
    python3 \
    py3-pip \
    bash \
    curl \
    git \
    && pip3 install --upgrade pip \
    && pip3 install azure-cli

# Set working directory
WORKDIR /workspace

# Copy terraform files
COPY terraform/ /workspace/terraform/
COPY modules/ /workspace/modules/
COPY scripts/ /workspace/scripts/

# Set entrypoint to bash for interactive use
ENTRYPOINT ["/bin/bash"]

#!/bin/bash
# Helper script to run Terraform commands in Docker

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Azure Terraform Docker Runner ===${NC}\n"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${YELLOW}Error: Docker is not running. Please start Docker Desktop.${NC}"
    exit 1
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}Warning: .env file not found. You'll need to authenticate with Azure CLI inside the container.${NC}"
    echo -e "${YELLOW}Copy .env.example to .env and fill in your Azure credentials, or use 'az login' in the container.${NC}\n"
fi

# Build the Docker image
echo -e "${GREEN}Building Docker image...${NC}"
docker-compose build

# Start the container
echo -e "${GREEN}Starting Terraform container...${NC}"
docker-compose run --rm terraform

echo -e "\n${GREEN}Container stopped.${NC}"

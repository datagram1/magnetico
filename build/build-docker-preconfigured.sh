#!/bin/bash

# Build script for pre-configured Magnetico Docker image
# This builds a Docker image with SQLite database pre-configured

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="ghcr.io/datagram1/magnetico"
TAG="latest"
DOCKERFILE="Dockerfile.preconfigured"

echo -e "${GREEN}Building Pre-configured Magnetico Docker Image${NC}"
echo "=============================================="
echo -e "${BLUE}Image: ${IMAGE_NAME}:${TAG}${NC}"
echo -e "${BLUE}Dockerfile: ${DOCKERFILE}${NC}"
echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

# Check if Dockerfile exists
if [ ! -f "$DOCKERFILE" ]; then
    echo -e "${RED}Dockerfile not found: ${DOCKERFILE}${NC}"
    exit 1
fi

# Build the image
echo -e "${YELLOW}Building Docker image...${NC}"
docker build -f "$DOCKERFILE" -t "${IMAGE_NAME}:${TAG}" .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Docker image built successfully!${NC}"
    echo ""
    echo -e "${BLUE}Image details:${NC}"
    docker images "${IMAGE_NAME}:${TAG}"
    echo ""
    echo -e "${BLUE}Usage:${NC}"
    echo "  docker run --rm -it -v <your_data_dir>:/data -p 8080:8080/tcp ${IMAGE_NAME}:${TAG}"
    echo ""
    echo -e "${BLUE}With docker-compose:${NC}"
    echo "  cd docker && docker-compose up -d"
else
    echo -e "${RED}Failed to build Docker image${NC}"
    exit 1
fi

#!/bin/bash

# Sakai Docker Management Script

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function show_help() {
    echo "Usage: ./manage_docker.sh [command]"
    echo ""
    echo "Commands:"
    echo "  build   Build the Sakai Docker image and start services"
    echo "  start   Start existing Sakai and DB containers"
    echo "  stop    Stop services"
    echo "  logs    Watch the Sakai application logs"
    echo "  status  Check the status of Docker services"
    echo "  clean   Remove containers, networks, and VOLUMES (Warning: data loss!)"
}

if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

case "$1" in
    build)
        echo -e "${BLUE}[INFO]${NC} Building and starting Sakai services..."
        docker-compose up -d --build
        echo -e "${GREEN}[SUCCESS]${NC} Build initiated. Run './manage_docker.sh logs' to monitor startup."
        ;;
    start)
        echo -e "${BLUE}[INFO]${NC} Starting Sakai services..."
        docker-compose up -d
        echo -e "${GREEN}[SUCCESS]${NC} Services started."
        ;;
    stop)
        echo -e "${BLUE}[INFO]${NC} Stopping Sakai services..."
        docker-compose stop
        echo -e "${GREEN}[SUCCESS]${NC} Services stopped."
        ;;
    logs)
        docker-compose logs -f sakai
        ;;
    status)
        docker-compose ps
        ;;
    clean)
        echo -e "${RED}[WARNING]${NC} This will delete ALL your Sakai data (database & files)!"
        read -p "Are you sure you want to proceed? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker-compose down -v
            echo -e "${GREEN}[SUCCESS]${NC} Cleaned all Docker resources and volumes."
        else
            echo -e "${BLUE}[INFO]${NC} Operation cancelled."
        fi
        ;;
    *)
        show_help
        ;;
esac

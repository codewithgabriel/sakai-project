#!/bin/bash

# =============================================================================
# Sakai LMS — Unified Management Script
# =============================================================================
# Usage: ./manage.sh [command]
#
# Run without arguments to see all available commands.
# =============================================================================

set -e

# --- Configuration ---
SAKAI_CONTAINER="sakai-app"
DB_CONTAINER="sakai-db"
BACKUP_DIR="./backups"
PROPERTIES_FILE="./config/sakai.properties"
TOMCAT_LOG_DIR="/usr/local/tomcat/logs"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Helpers ---
info()    { echo -e "${BLUE}[INFO]${NC}    $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}    $1"; }
error()   { echo -e "${RED}[ERROR]${NC}   $1"; exit 1; }

# --- Docker Compose Detection & Auto-Install ---
detect_compose() {
    if docker compose version >/dev/null 2>&1; then
        COMPOSE="docker compose"
    elif docker-compose --version >/dev/null 2>&1; then
        COMPOSE="docker-compose"
    else
        warn "Docker not found. Attempting automatic installation (Ubuntu)..."
        install_docker
    fi
}

install_docker() {
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg

    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker "$USER"

    success "Docker and Docker Compose installed."
    info "You may need to log out and back in for group changes to take effect."
    COMPOSE="docker compose"
}

# --- Commands ---

cmd_build() {
    info "Building and starting Sakai services..."
    $COMPOSE up -d --build
    success "Build started. Run './manage.sh logs' to monitor startup."
}

cmd_rebuild() {
    info "Rebuilding from scratch (no cache)..."
    $COMPOSE build --no-cache
    info "Restarting services with the fresh image..."
    $COMPOSE up -d --force-recreate
    success "Rebuild complete. Run './manage.sh logs' to monitor startup."
}

cmd_start() {
    info "Starting Sakai services..."
    $COMPOSE up -d
    success "Services started."
}

cmd_stop() {
    info "Stopping Sakai services..."
    $COMPOSE stop
    success "Services stopped."
}

cmd_restart() {
    info "Restarting Sakai services..."
    $COMPOSE restart
    success "Services restarted."
}

cmd_logs() {
    info "Following Sakai logs (Ctrl+C to stop)..."
    $COMPOSE logs -f sakai
}

cmd_tomcat_logs() {
    info "Finding latest Tomcat access log in ${SAKAI_CONTAINER}:${TOMCAT_LOG_DIR}..."

    # Find the most recently modified localhost_access_log file
    LATEST_LOG=$(docker exec "$SAKAI_CONTAINER" bash -c \
        "ls -t ${TOMCAT_LOG_DIR}/localhost_access_log*.txt 2>/dev/null | head -1")

    if [ -z "$LATEST_LOG" ]; then
        warn "No localhost_access_log files found yet."
        info "Falling back to all Tomcat logs..."
        docker exec -it "$SAKAI_CONTAINER" ls -lh "$TOMCAT_LOG_DIR"
        return
    fi

    success "Tailing: ${LATEST_LOG}"
    info "Press Ctrl+C to stop."
    echo ""
    docker exec -it "$SAKAI_CONTAINER" tail -f "$LATEST_LOG"
}

cmd_catalina_logs() {
    info "Finding latest Catalina log in ${SAKAI_CONTAINER}:${TOMCAT_LOG_DIR}..."

    LATEST_LOG=$(docker exec "$SAKAI_CONTAINER" bash -c \
        "ls -t ${TOMCAT_LOG_DIR}/catalina.*.log 2>/dev/null | head -1")

    if [ -z "$LATEST_LOG" ]; then
        warn "No catalina log files found."
        info "Available logs:"
        docker exec -it "$SAKAI_CONTAINER" ls -lh "$TOMCAT_LOG_DIR"
        return
    fi

    success "Tailing: ${LATEST_LOG}"
    info "Press Ctrl+C to stop."
    echo ""
    docker exec -it "$SAKAI_CONTAINER" tail -${2:-200}f "$LATEST_LOG"
}

cmd_status() {
    $COMPOSE ps
}

cmd_shell() {
    info "Opening shell in Sakai container (${SAKAI_CONTAINER})..."
    docker exec -it "$SAKAI_CONTAINER" bash
}

cmd_db() {
    info "Opening MySQL shell in DB container (${DB_CONTAINER})..."
    info "Tip: password is defined in docker-compose.yml"
    docker exec -it "$DB_CONTAINER" mysql -u sakaiuser -p sakaidatabase
}

cmd_props() {
    EDITOR="${EDITOR:-nano}"
    info "Opening ${PROPERTIES_FILE} with ${EDITOR}..."
    "$EDITOR" "$PROPERTIES_FILE"
    echo ""
    info "Remember to restart for changes to take effect:"
    echo -e "  ${CYAN}./manage.sh restart${NC}"
}

cmd_backup() {
    mkdir -p "$BACKUP_DIR"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="${BACKUP_DIR}/sakai_backup_${TIMESTAMP}.sql"

    info "Dumping database to ${BACKUP_FILE}..."
    docker exec "$DB_CONTAINER" mysqldump -u sakaiuser -psakaipassword sakaidatabase > "$BACKUP_FILE"
    
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    success "Backup complete: ${BACKUP_FILE} (${SIZE})"
}

cmd_restore() {
    if [ -z "$2" ]; then
        echo "Usage: ./manage.sh restore <backup_file.sql>"
        echo ""
        echo "Available backups:"
        ls -lh "$BACKUP_DIR"/*.sql 2>/dev/null || echo "  No backups found in ${BACKUP_DIR}/"
        exit 1
    fi

    BACKUP_FILE="$2"
    if [ ! -f "$BACKUP_FILE" ]; then
        error "Backup file not found: ${BACKUP_FILE}"
    fi

    echo -e "${RED}[WARNING]${NC} This will OVERWRITE the current database with: ${BACKUP_FILE}"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Restoring database..."
        docker exec -i "$DB_CONTAINER" mysql -u sakaiuser -psakaipassword sakaidatabase < "$BACKUP_FILE"
        success "Database restored from ${BACKUP_FILE}"
        info "Restart Sakai to pick up changes: ./manage.sh restart"
    else
        info "Restore cancelled."
    fi
}

cmd_clean() {
    echo -e "${RED}[WARNING]${NC} This will delete ALL Sakai data (database & files)!"
    read -p "Are you sure you want to proceed? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        $COMPOSE down -v
        success "Cleaned all Docker resources and volumes."
    else
        info "Operation cancelled."
    fi
}

cmd_install() {
    if [ ! -f "./scripts/install_sakai.sh" ]; then
        error "install_sakai.sh not found in scripts/"
    fi
    warn "This will perform a BARE-METAL installation (Java, Tomcat, Maven, MySQL)."
    warn "Only use this on a fresh Ubuntu server — NOT inside Docker."
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo bash ./scripts/install_sakai.sh
    else
        info "Installation cancelled."
    fi
}

# --- Help / Usage ---

show_help() {
    echo ""
    echo -e "${BOLD}Sakai LMS — Management CLI${NC}"
    echo ""
    echo -e "Usage: ${CYAN}./manage.sh${NC} ${GREEN}<command>${NC}"
    echo ""
    echo -e "${BOLD}Docker Lifecycle${NC}"
    echo -e "  ${GREEN}build${NC}       Build the Docker image and start all services"
    echo -e "  ${GREEN}rebuild${NC}     Force a full rebuild with no cache (use after config changes)"
    echo -e "  ${GREEN}start${NC}       Start existing containers"
    echo -e "  ${GREEN}stop${NC}        Stop running containers"
    echo -e "  ${GREEN}restart${NC}     Restart all services"
    echo -e "  ${GREEN}logs${NC}        Follow Sakai application logs (docker compose)"
    echo -e "  ${GREEN}tomcat-logs${NC}  Tail the latest Tomcat access log inside the container"
    echo -e "  ${GREEN}catalina-logs${NC} Tail the latest Catalina engine log (errors, startup)"
    echo -e "  ${GREEN}status${NC}      Show container health and uptime"
    echo -e "  ${GREEN}clean${NC}       Remove containers and volumes (${RED}data loss!${NC})"
    echo ""
    echo -e "${BOLD}Quick Access${NC}"
    echo -e "  ${GREEN}shell${NC}       Open a bash shell inside the Sakai container"
    echo -e "  ${GREEN}db${NC}          Open a MySQL shell inside the database container"
    echo -e "  ${GREEN}props${NC}       Edit sakai.properties in your default editor"
    echo ""
    echo -e "${BOLD}Data Management${NC}"
    echo -e "  ${GREEN}backup${NC}      Dump the MySQL database to backups/"
    echo -e "  ${GREEN}restore${NC}     Restore a database backup  (usage: restore <file.sql>)"
    echo ""
    echo -e "${BOLD}Bare-Metal (Non-Docker)${NC}"
    echo -e "  ${GREEN}install${NC}     Run the full native Ubuntu installer script"
    echo ""
}

# --- Main ---

detect_compose

case "${1:-}" in
    build)   cmd_build   ;;
    rebuild) cmd_rebuild ;;
    start)   cmd_start   ;;
    stop)    cmd_stop    ;;
    restart) cmd_restart ;;
    logs)    cmd_logs    ;;
    tomcat-logs) cmd_tomcat_logs ;;
    catalina-logs) cmd_catalina_logs "$@" ;;
    status)  cmd_status  ;;
    shell)   cmd_shell   ;;
    db)      cmd_db      ;;
    props)   cmd_props   ;;
    backup)  cmd_backup  ;;
    restore) cmd_restore "$@" ;;
    clean)   cmd_clean   ;;
    install) cmd_install ;;
    help|--help|-h)
        show_help ;;
    *)
        show_help ;;
esac

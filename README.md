# Sakai LMS Automatic Installer

This project contains a "magic" shell script to automate the installation of **Sakai 23** on Ubuntu 20.04/22.04 LTS systems.

## Overview
The `install_sakai.sh` script handles the entire lifecycle of the installation:
- **Dependencies**: Java 11 (OpenJDK), Git, Maven 3.9.6, Tomcat 9
- **Database**: MySQL 8 Server (Creates `sakaidatabase`)
- **Configuration**: Sets up `JAVA_OPTS`, `server.xml` UTF-8 encoding, and `sakai.properties`
- **Build**: Downloads Sakai 23.x source, compiles it with Maven, and deploys to Tomcat
- **Service**: Creates a `sakai` systemd service for automatic startup

## Usage

**WARNING**: This script is designed for a **FRESH** installation. It installs system packages and modifies configuration files. Do not run this on a server running other critical applications without reviewing the script first.

### Shell Script Installation
1.  **Download/Clone** this repository to your Ubuntu server.
2.  **Make executable**:
    ```bash
    chmod +x install_sakai.sh
    ```
3.  **Run as Root**:
    ```bash
    sudo ./install_sakai.sh
    ```

### Docker Installation (Recommended)

For a containerized setup using Docker and Docker Compose:

1.  **Prerequisites**: Ensure you have [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/) installed.
2.  **Start Services**:
    ```bash
    docker-compose up -d
    ```
3.  **Monitor Build**:
    The initial build will take 15-30+ minutes as it clones and compiles Sakai from source.
    ```bash
    docker-compose logs -f sakai
    ```
4.  **Access Sakai**:
    Once the logs show that Tomcat has started, access Sakai at: `http://localhost:8080/portal`

**Docker Configuration**:
- **Database**: The MySQL 8.0 container is pre-configured with the necessary schema and user.
- **Persistence**: Database data and Sakai configuration are stored in Docker volumes (`db_data`, `sakai_data`).
- **Custom Properties**: Edit `sakai.properties.docker` before building if you need custom settings.

## Post-Installation
Once the script finishes (it can take 15-30+ minutes depending on internet and CPU speed for the Maven build):

1.  Access Sakai at: `http://localhost:8080/portal`
2.  **Database Credentials** (Default):
    - User: `sakaiuser`
    - Password: `sakaipassword`
    - **SECURITY NOTE**: Change these in `install_sakai.sh` and your database if using in production.

## Troubleshooting
- **Logs**: Check Tomcat logs at `/opt/tomcat/logs/catalina.out`
- **Service Status**: Check service with `systemctl status sakai`

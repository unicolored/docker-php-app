# Custom PHP Docker Starter Image

## Overview
This project provides a lightweight, production-ready Docker image for serving PHP applications, primarily built with Symfony (or occasionally WordPress). Based on the official `php:8.3-fpm-alpine` image, it integrates Nginx for web serving, Supervisor for process management, and essential tools/extensions for efficient, secure containerized deployments. Key features include:

- **Multi-Stage Build**: Separates build-time dependencies (e.g., Composer installs) from runtime for a lean final image (~200-250MB).
- **PHP Extensions**: Comprehensive support for PDO (MySQL/PostgreSQL), GD, Intl, APCu, AMQP, MongoDB, Redis, and more.
- **Tools Included**: Composer, WP-CLI (for WordPress), Node.js/Yarn (for asset building), Cachetool (for OPcache management), AWS CLI, Neovim (with custom config for editing), and cron support.
- **Security & Optimization**: Runs as non-root user (`devops`), stdout/stderr logging for Kubernetes observability, OPcache tuned for performance, and HTTPS/TLS handled externally (e.g., via nginx-ingress).
- **Cloud-Native Focus**: Designed for scalability in Kubernetes (deployed via `kubectl`) on a VPS, with health checks, env var configuration, and no baked-in certs/domains for flexibility.

This image serves as a reusable starter—mount your app code via volumes in development or bake it in for production. It's optimized for high-availability PHP workflows, ensuring dev/prod parity while prioritizing portability and efficiency.

## Prerequisites
- Docker installed (with Buildx for multi-platform builds).
- Git for version control.
- Optional: Kubernetes cluster (e.g., on a VPS) with `kubectl`, nginx-ingress, and cert-manager for production deployments.
- Environment Variables: Set `DOCKER_HOST` (your registry, e.g., Docker Hub or ECR) and `DOCKER_CLOUD_BUILDER` (your cloud builder name) for the build script.

## Building the Image
Use the provided `build.sh` script for streamlined builds:
- **Default (Cloud Build & Push)**: `./build.sh` – Builds using your cloud builder and pushes to the registry.
- **Local Build & Push**: `./build.sh --local` – Builds locally and pushes.
- **With Test Run**: Add `--test` (e.g., `./build.sh --test` or `./build.sh --local --test`) – Builds, pushes (if applicable), and runs a test container on port 8080 for quick verification.

The image is tagged with the current Git branch and `:latest`.

## Usage
### Local Development (Docker Compose)
Create a `docker-compose.yml` for dev/testing:
```yaml
version: '3.8'
services:
  app:
    image: your-repo/php-app:latest
    ports:
      - "8080:80"
    volumes:
      - .:/var/www/html  # Mount your app code
    environment:
      - APP_ENV=prod
      - PHP_SESSION_SAVE_HANDLER=files  # Or redis, etc.
```
Run: docker-compose up. Access at http://localhost:8080 (shows placeholder if no app code).

## Production (Kubernetes)
Deploy via YAML manifests:

```yaml
Deployment Example:
yamlapiVersion: apps/v1
kind: Deployment
metadata:
  name: php-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: php-app
  template:
    metadata:
      labels:
        app: php-app
    spec:
      containers:
        - name: app
          image: your-repo/php-app:latest
          ports:
            - containerPort: 80
          resources:
            limits:
              cpu: "500m"
              memory: "512Mi"
          env:
            - name: PHP_SESSION_SAVE_HANDLER
              value: "redis"
```

Pair with a Service and Ingress for exposure/TLS (using cert-manager for Let's Encrypt).
Apply: kubectl apply -f deployment.yaml.

For databases/caching (e.g., MySQL, Redis), use separate services or managed VPS resources.

## Project Structure and File Descriptions
The project follows a simple structure with the Dockerfile at the root and supporting configs/scripts in subdirectories. Below is a breakdown of all key files:

- Dockerfile: The core build file defining the multi-stage Docker image. It sets up the Alpine base, installs PHP extensions/tools (e.g., Neovim instead of Nano), configures non-root user (devops), and copies configs/scripts for Nginx, PHP-FPM, Supervisor, and cron. Optimized for production with stdout/stderr logging and health checks.
- build.sh: Bash script for building and pushing the image. Supports cloud builds (default), local builds (--local), and test runs (--test) that spin up a container for verification. Tags images with Git branch and :latest.
- build_files/: Directory containing configuration files copied into the image during build. These are modular for easy overrides.
    - build_files/conf.d/custom.ini: PHP configuration extensions for global settings (e.g., memory limits, OPcache tuning, session handling via env vars, timezone). Loaded via conf.d for both CLI and FPM modes.
    - build_files/conf.d.extend.conf: Nginx extension config (if needed for custom directives; currently minimal or empty).
    - build_files/fpm/website_pool.conf: PHP-FPM pool configuration for the website pool. Defines process management (dynamic PM), user/group, socket listening, disabled functions for security, and logging to stdout/stderr.
    - build_files/init.vim: Custom Neovim configuration file (e.g., enables line numbers and relative numbers). Copied to the devops user's home for powerful editing in containers.
    - build_files/mdcron: Cron configuration file defining scheduled jobs (e.g., for maintenance tasks). Installed to /etc/cron.d/mdcron and managed by Supervisor's cron program.
    - build_files/public/index.php: Fun placeholder HTML/PHP file served as the default root (e.g., "Hello from Your PHP Container!" with emojis and PHP version echo). Used for initial testing before mounting real app code.
    - build_files/sites-available-default.conf: Main Nginx server configuration. Defines HTTP listening (port 80), routing for PHP/static files, security denials, gzip compression, caching, and security headers. Configured for stdout/stderr logging and catch-all server_name.
    - build_files/supermd.conf: Supervisor program definitions for Nginx, PHP-FPM, and cron. Specifies commands, autorestart, and stdout/stderr redirection for container observability.
    - build_files/supervisord.conf: Main Supervisor daemon config. Sets up Unix socket, logging (to /dev/null for purity), and includes conf.d files for programs.


## Customization

- Env Vars: Use Kubernetes secrets or Docker env for dynamic configs (e.g., DB connections, session handlers).
- Extensions/Tools: Edit Dockerfile's apk add for additions; rebuild for changes.
- Security Scanning: Run trivy image your-repo/php-app:latest post-build.
- CI/CD: Integrate build.sh with GitHub Actions/GitLab CI for automated builds on pushes.

## License
MIT License – Feel free to use and modify for your projects.
For questions or contributions, open an issue or PR. Happy containerizing! 🚀

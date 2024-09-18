#!/usr/bin/env bash
# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}
# Determine the correct docker compose command
if command_exists docker-compose; then
    DOCKER_COMPOSE="docker-compose"
elif command_exists docker && docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    echo "Error: Neither docker-compose nor docker compose is available."
    exit 1
fi
# Function to validate domain name
validate_domain() {
    if [[ $1 =~ ^([a-zA-Z0-9](([a-zA-Z0-9-]){0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}
# Function to set up the configuration
setup() {
    echo "Setting up configuration..."
        # Prompt for domain name
    while true; do
        read -p "Enter your domain name: " domain
        if validate_domain "$domain"; then
            break
        else
            echo "Invalid domain name. Please try again."
        fi
    done
    # Create directories
    mkdir -p certbot/conf certbot/www
    
    # Create docker-compose.yml
    curl -fsSL -o docker-compose.yml https://raw.githubusercontent.com/Nibble-A-Bit/nginx-ssl/main/docker-compose.yml
    
    # Create nginx.conf
    curl -fsSL -o nginx.conf https://raw.githubusercontent.com/Nibble-A-Bit/nginx-ssl/main/nginx.conf
    sed 's/$domain/'$domain'/' nginx.conf -i

    echo "Configuration files created successfully."
}
# Function to certify
certify() {
    # Prompt for domain name
    while true; do
        read -p "Enter the domain name for the certificate: " domain
        if validate_domain "$domain"; then
            break
        else
            echo "Invalid domain name. Please try again."
        fi
    done
    # Prompt for email address
    while true; do
        read -p "Enter your email address: " email
        if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            echo "Invalid email address. Please try again."
        fi
    done
    echo "Ensuring nginx container is running..."
    $DOCKER_COMPOSE up -d nginx
    # Add a delay to ensure nginx is fully up
    echo "Requesting new SSL certificate..."
    $DOCKER_COMPOSE run --rm --entrypoint "\
      certbot certonly --webroot --webroot-path /var/www/certbot \
      --email "$email" --agree-tos --no-eff-email \
      -d "$domain"" certbot
    if [ $? -eq 0 ]; then
        echo "Certificate successfully obtained!"
        echo "Restarting nginx to apply the new certificate..."
        $DOCKER_COMPOSE restart nginx
    else
        echo "Failed to obtain certificate. Please check the error messages above."
        echo "Debugging information:"
        $DOCKER_COMPOSE logs nginx
        $DOCKER_COMPOSE logs certbot
    fi
}
# Function to perform a dry run of the certify process
certify_dryrun() {
    # Prompt for domain name
    while true; do
        read -p "Enter the domain name for the certificate (dry run): " domain
        if validate_domain "$domain"; then
            break
        else
            echo "Invalid domain name. Please try again."
        fi
    done
    # Prompt for email address
    while true; do
        read -p "Enter your email address: " email
        if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            echo "Invalid email address. Please try again."
        fi
    done
    echo "Ensuring nginx container is running..."
    $DOCKER_COMPOSE up -d nginx
    # Add a delay to ensure nginx is fully up
    echo "Performing dry run of SSL certificate request..."
    $DOCKER_COMPOSE run --rm --entrypoint "\
      certbot certonly --webroot --webroot-path /var/www/certbot \
      --email "$email" --agree-tos --no-eff-email \
      -d "$domain" --dry-run" certbot
    if [ $? -eq 0 ]; then
        echo "Dry run completed successfully. You should be able to obtain a real certificate."
    else
        echo "Dry run failed. Please check the error messages above and resolve any issues before requesting a real certificate."
        echo "Debugging information:"
        $DOCKER_COMPOSE logs nginx
        $DOCKER_COMPOSE logs certbot
    fi
}
# Function to run containers
run() {
    echo "Starting containers..."
    $DOCKER_COMPOSE up -d
}
# Function to restart containers
restart() {
    echo "Restarting containers..."
    $DOCKER_COMPOSE restart nginx
    $DOCKER_COMPOSE restart certbot
}
# Function to stop containers
stop() {
    echo "Stopping containers..."
    $DOCKER_COMPOSE down
}
# Main menu
while true; do
    echo "
    __      _      _____     _____      __      _   __     __       _____    _____   _____      
   /  \    / )    / ___ \   (_   _)    /  \    / ) (_ \   / _)     / ____\  / ____\ (_   _)     
  / /\ \  / /    / /   \_)    | |     / /\ \  / /    \ \_/ /      ( (___   ( (___     | |       
  ) ) ) ) ) )   ( (  ____     | |     ) ) ) ) ) )     \   /        \___ \   \___ \    | |       
 ( ( ( ( ( (    ( ( (__  )    | |    ( ( ( ( ( (      / _ \            ) )      ) )   | |   __  
 / /  \ \/ /     \ \__/ /    _| |__  / /  \ \/ /    _/ / \ \_      ___/ /   ___/ /  __| |___) ) 
(_/    \__/       \____/    /_____( (_/    \__/    (__/   \__)    /____/   /____/   \________/  

1. Setup
2. Certify (Dry Run)
3. Start
4. Restart
5. Stop
6. Certify
7. Exit
"
    read -p "Enter your choice: " choice
        case $choice in
        1) setup ;;
        2) certify_dryrun ;;
        3) run ;;
        4) restart ;;
        5) stop ;;
        6) certify ;;
        7) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac
done

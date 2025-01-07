#!/bin/bash
# Function to print messages in a consistent format
print_message() {
    echo -e "\n\033[1;34m$1\033[0m"
}

# Function to print error messages
print_error() {
    echo -e "\n\033[1;31mERROR: $1\033[0m"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root."
    exit 1
fi

# Function to check if command executed successfully
check_status() {
    if [ $? -eq 0 ]; then
        echo "✓ $1 completed successfully"
    else
        echo "✗ Error: $1 failed"
        exit 1
    fi
}


# Function to check Docker installation
check_docker() {
    if command -v docker &> /dev/null; then
        echo "Docker is already installed"
        docker --version
        if sudo docker run hello-world &> /dev/null; then
            echo "Docker is working properly"
            return 0
        else
            echo "Docker is installed but not working properly. Proceeding with repair..."
            return 1
        fi
    else
        echo "Docker is not installed"
        return 1
    fi
}

# Function to check Docker Compose installation
check_docker_compose() {
    if docker compose version &> /dev/null; then
        echo "Docker Compose (new version) is already installed and working"
        docker compose version
        return 0
    elif docker-compose --version &> /dev/null; then
        echo "Old docker-compose found. Will upgrade to new Docker Compose"
        return 1
    else
        echo "Docker Compose is not installed"
        return 1
    fi
}

# Function to install Docker
install_docker() {
    echo "Downloading Docker installation script..."
    wget -O get-docker.sh https://get.docker.com
    check_status "Docker script download"

    chmod +x get-docker.sh
    check_status "Setting execute permission"

    echo "Installing Docker..."
    sudo ./get-docker.sh
    check_status "Docker installation"

    echo "Starting Docker service..."
    sudo systemctl start docker
    sudo systemctl enable docker
    check_status "Docker service startup"

    # Clean up
    rm get-docker.sh
}

# Function to setup Docker permissions
setup_docker_permissions() {
    # Check if user is already in docker group
    if groups $USER | grep &>/dev/null '\bdocker\b'; then
        echo "User $USER is already in docker group"
    else
        echo "Setting up Docker permissions..."
        sudo groupadd docker 2>/dev/null || true
        sudo usermod -aG docker $USER
        check_status "Docker permission setup"
        echo "Note: You'll need to log out and log back in for group changes to take effect"
    fi
}
# Function to detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "Cannot detect OS"
        exit 1
    fi
}


# Check and install Docker if needed
if ! check_docker; then
    install_docker
fi

# Detect OS
detect_os
echo "Detected OS: $OS"



# Setup Docker permissions
setup_docker_permissions


check_jq() {
    if command -v jq &> /dev/null; then
        echo "jq is already installed"
        jq --version
        return 0
    else
        echo "jq is not installed"
        return 1
    fi
}



install_jq() {
    echo "Installing jq..."
    if [ "$OS" = "ubuntu" ]; then
        sudo apt-get update
        sudo apt-get install -y jq
    elif [ "$OS" = "centos" ]; then
        sudo yum install -y epel-release
        sudo yum install -y jq
    else
        echo "Unsupported OS for jq installation"
        exit 1
    fi
    check_status "jq installation"
}

if ! check_jq; then
    install_jq
fi

check_sysstat() {
    if command -v sadf &> /dev/null; then
        echo "sysstat is already installed"
        sysstat --version
        return 0
    else
        echo "sysstat is not installed"
        return 1
    fi
}


install_sysstat() {
    echo "Installing sysstat..."
    if [ "$OS" = "ubuntu" ]; then
        sudo apt-get update
        sudo apt-get install -y sysstat
        # Enable sysstat data collection
        sudo sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
        sudo systemctl enable sysstat
        sudo systemctl start sysstat
    elif [ "$OS" = "centos" ]; then
        sudo yum install -y sysstat
        sudo systemctl enable sysstat
        sudo systemctl start sysstat
    else
        echo "Unsupported OS for sysstat installation"
        exit 1
    fi
    check_status "sysstat installation"
}

# Add this code block before creating the telegraf.conf file
if ! check_sysstat; then
    install_sysstat
fi

# Main installation process
echo "Starting Docker setup verification..."

# Check and fix Docker Compose
if ! check_docker_compose; then
    if command -v docker-compose &> /dev/null; then
        echo "Removing old docker-compose..."
        if [ "$OS" = "ubuntu" ]; then
            sudo apt remove docker-compose
        elif [ "$OS" = "centos" ]; then
            sudo yum remove docker-compose
        fi
    fi
    
    echo "Docker Compose plugin will be installed via Docker installation"
    # Modern Docker installations include Docker Compose as a plugin
    # Verify installation
    if ! docker compose version &> /dev/null; then
        echo "Installing Docker Compose plugin..."
        if [ "$OS" = "ubuntu" ]; then
            sudo apt-get update
            sudo apt-get install -y docker-compose-plugin
        elif [ "$OS" = "centos" ]; then
            sudo yum install -y docker-compose-plugin
        fi
    fi
    check_status "Docker Compose installation"
fi

# Final verification
echo -e "\nFinal Verification:"
echo "Docker version:"
docker --version
echo -e "\nDocker Compose version:"
docker compose version
echo -e "\nTesting Docker:"
docker run hello-world

echo -e "\nSetup process completed!"


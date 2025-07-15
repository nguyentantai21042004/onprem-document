# Update system
sudo apt update
sudo apt upgrade -y

# Install required packages
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index
sudo apt update

# Install Docker
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Verify installation
docker --version

# Create jenkins user
sudo useradd -m -s /bin/bash jenkins

# Set password cho jenkins user (optional)
sudo passwd jenkins

# Create home directory
sudo mkdir -p /home/jenkins
sudo chown jenkins:jenkins /home/jenkins

# Add jenkins user to docker group
sudo usermod -aG docker jenkins

# Fix docker socket permissions
sudo chmod 660 /var/run/docker.sock
sudo chown root:docker /var/run/docker.sock

# Create docker group if not exists
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker jenkins

# Verify groups
groups jenkins

# Create workspace directory
sudo mkdir -p /var/lib/jenkins/workspace
sudo chown -R jenkins:jenkins /var/lib/jenkins

# Create source directory for builds
sudo mkdir -p /source
sudo chown jenkins:jenkins /source
sudo chmod 755 /source

# Create Jenkins agent working directory
sudo -u jenkins mkdir -p /home/jenkins/jenkins-agent
sudo chown jenkins:jenkins /home/jenkins/jenkins-agent
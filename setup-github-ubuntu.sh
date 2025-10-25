#!/bin/bash
# GitHub Setup Script for Ubuntu Laptop
# For: xavier.espiau@gmail.com
# Date: October 25, 2025

echo "🐧 GitHub Setup for Ubuntu - Homelab Documentation"
echo "==================================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Check and install git
echo -e "${YELLOW}Step 1: Checking Git installation...${NC}"
if ! command -v git &> /dev/null; then
    echo "Git not found. Installing..."
    sudo apt update
    sudo apt install -y git
else
    echo -e "${GREEN}✓ Git is already installed${NC}"
    git --version
fi
echo ""

# Step 2: Configure Git
echo -e "${YELLOW}Step 2: Configuring Git...${NC}"
git config --global user.email "xavier.espiau@gmail.com"
git config --global user.name "Xavier Espiau"
git config --global init.defaultBranch main
echo -e "${GREEN}✓ Git configured for xavier.espiau@gmail.com${NC}"
echo ""

# Step 3: Check for existing SSH keys
echo -e "${YELLOW}Step 3: Setting up SSH keys for GitHub...${NC}"
if [ -f ~/.ssh/id_ed25519.pub ]; then
    echo -e "${GREEN}✓ SSH key already exists${NC}"
    echo "Your public key:"
    cat ~/.ssh/id_ed25519.pub
else
    echo "Creating new SSH key..."
    ssh-keygen -t ed25519 -C "xavier.espiau@gmail.com" -f ~/.ssh/id_ed25519 -N ""
    echo -e "${GREEN}✓ SSH key created${NC}"
    echo ""
    echo "Your new public key:"
    cat ~/.ssh/id_ed25519.pub
fi
echo ""

# Step 4: Start SSH agent and add key
echo -e "${YELLOW}Step 4: Adding SSH key to agent...${NC}"
eval "$(ssh-agent -s)" > /dev/null 2>&1
ssh-add ~/.ssh/id_ed25519 2> /dev/null
echo -e "${GREEN}✓ SSH key added to agent${NC}"
echo ""

# Step 5: Display instructions for GitHub
echo -e "${YELLOW}Step 5: Add SSH key to GitHub${NC}"
echo "=================================================="
echo -e "${GREEN}Copy your SSH public key above, then:${NC}"
echo ""
echo "1. Go to: https://github.com/settings/keys"
echo "2. Click 'New SSH key'"
echo "3. Title: 'Ubuntu Laptop - Homelab'"
echo "4. Key type: 'Authentication Key'"
echo "5. Paste the public key"
echo "6. Click 'Add SSH key'"
echo ""
echo -e "${YELLOW}Press Enter after you've added the key to GitHub...${NC}"
read -p ""

# Step 6: Test GitHub connection
echo -e "${YELLOW}Step 6: Testing GitHub connection...${NC}"
ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully connected to GitHub!${NC}"
else
    echo -e "${YELLOW}Note: You may see a warning about authenticity. Type 'yes' to continue.${NC}"
    ssh -T git@github.com
fi
echo ""

# Step 7: Create useful git aliases
echo -e "${YELLOW}Step 7: Creating helpful Git aliases...${NC}"
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.cm commit
git config --global alias.pl pull
git config --global alias.ps push
git config --global alias.lg "log --oneline --graph --decorate --all"
echo -e "${GREEN}✓ Git aliases configured${NC}"
echo ""

# Step 8: Install GitHub CLI (optional but useful)
echo -e "${YELLOW}Step 8: Install GitHub CLI? (Recommended)${NC}"
read -p "Install GitHub CLI for easier repository creation? (y/n): " install_gh
if [[ $install_gh == "y" ]]; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
    sudo apt install -y gh
    echo -e "${GREEN}✓ GitHub CLI installed${NC}"
    echo ""
    echo "Authenticating with GitHub..."
    gh auth login
else
    echo "Skipping GitHub CLI installation"
fi
echo ""

echo -e "${GREEN}==================================================="
echo "✅ GitHub Setup Complete!"
echo "===================================================${NC}"
echo ""
echo "Your Git configuration:"
echo "  Email: $(git config --global user.email)"
echo "  Name: $(git config --global user.name)"
echo "  Default branch: $(git config --global init.defaultBranch)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Navigate to your homelab documentation:"
echo "   cd ~/Documents/Homelab_Promox_Cluster_Project/homelab-proxmox-cluster"
echo ""
echo "2. Initialize and push to GitHub:"
echo "   git init"
echo "   git add ."
echo "   git commit -m \"Initial commit: Homelab documentation\""
echo "   git remote add origin git@github.com:YOUR_USERNAME/homelab-proxmox-cluster.git"
echo "   git push -u origin main"
echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"

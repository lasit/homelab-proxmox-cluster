#!/bin/bash
# GitHub Repository Setup Script for Homelab Documentation
# Run this on your laptop after downloading the files

echo "🚀 Homelab Proxmox Cluster - GitHub Setup Script"
echo "================================================="
echo ""

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "❌ Git is not installed. Please install git first:"
    echo "   Ubuntu/Debian: sudo apt install git"
    echo "   MacOS: brew install git"
    exit 1
fi

# Get user input
read -p "Enter your GitHub username: " github_user
read -p "Enter repository name (homelab-proxmox-cluster): " repo_name
repo_name=${repo_name:-homelab-proxmox-cluster}

echo ""
echo "📁 Creating repository structure..."

# Initialize git if not already done
if [ ! -d .git ]; then
    git init
    git branch -M main
fi

# Configure git
git config user.name "$github_user"
read -p "Enter your email for git commits: " git_email
git config user.email "$git_email"

# Add all files
git add .

# Create initial commit
echo "📝 Creating initial commit..."
git commit -m "Initial commit: Homelab documentation structure

- Complete documentation framework
- Network architecture and hardware inventory
- Installation guides structure
- Service catalog
- Current status tracking"

echo ""
echo "🌐 Next steps to push to GitHub:"
echo "================================="
echo "1. Create a new repository on GitHub.com:"
echo "   - Go to: https://github.com/new"
echo "   - Repository name: $repo_name"
echo "   - Set as Public or Private as desired"
echo "   - Do NOT initialize with README (we have one)"
echo ""
echo "2. After creating, run these commands:"
echo ""
echo "git remote add origin https://github.com/$github_user/$repo_name.git"
echo "git push -u origin main"
echo ""
echo "3. Future updates:"
echo "   git add ."
echo "   git commit -m \"Your update message\""
echo "   git push"
echo ""
echo "✅ Local repository is ready!"

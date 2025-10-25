# 🐧 GitHub Setup Guide for Ubuntu

**For:** xavier.espiau@gmail.com  
**Date:** October 25, 2025  
**Purpose:** Set up GitHub on your Ubuntu laptop for the homelab documentation

## 📦 Step 1: Install Git

Open a terminal and run:

```bash
# Update package list
sudo apt update

# Install git
sudo apt install -y git

# Verify installation
git --version
```

## ⚙️ Step 2: Configure Git

Set your identity for commits:

```bash
git config --global user.email "xavier.espiau@gmail.com"
git config --global user.name "Xavier Espiau"
git config --global init.defaultBranch main
```

Verify configuration:
```bash
git config --global --list
```

## 🔐 Step 3: Set Up SSH Keys

### Generate SSH Key
```bash
# Generate ED25519 key (recommended)
ssh-keygen -t ed25519 -C "xavier.espiau@gmail.com"

# When prompted:
# - Press Enter to accept default location (~/.ssh/id_ed25519)
# - Enter a passphrase (optional but recommended)
```

### View Your Public Key
```bash
cat ~/.ssh/id_ed25519.pub
```
Copy this entire output - you'll need it for GitHub.

### Start SSH Agent
```bash
# Start the agent
eval "$(ssh-agent -s)"

# Add your key
ssh-add ~/.ssh/id_ed25519
```

## 🌐 Step 4: Add SSH Key to GitHub

1. **Copy your SSH public key** from the terminal output above

2. **Go to GitHub:**
   - Navigate to: https://github.com/settings/keys
   - Or: Click your profile → Settings → SSH and GPG keys

3. **Add new SSH key:**
   - Click "New SSH key"
   - Title: `Ubuntu Laptop - Homelab`
   - Key type: `Authentication Key`
   - Key: Paste your public key
   - Click "Add SSH key"

4. **Test the connection:**
```bash
ssh -T git@github.com
```

You should see: "Hi [username]! You've successfully authenticated..."

## 📦 Step 5: Install GitHub CLI (Optional but Helpful)

The GitHub CLI makes creating repositories easier:

```bash
# Add GitHub CLI repository
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

# Install
sudo apt update
sudo apt install gh

# Authenticate
gh auth login
```

Choose:
- GitHub.com
- SSH
- Authenticate with browser

## 🚀 Step 6: Create Your Repository

### Option A: Using GitHub CLI (Easier)
```bash
cd ~/Documents/Homelab_Promox_Cluster_Project/homelab-proxmox-cluster

# Create repository on GitHub
gh repo create homelab-proxmox-cluster --public --source=. --remote=origin --push
```

### Option B: Using Web Browser + Git Commands

1. **Create repository on GitHub.com:**
   - Go to: https://github.com/new
   - Repository name: `homelab-proxmox-cluster`
   - Description: `3-node Proxmox cluster documentation for Darwin homelab`
   - Public or Private (your choice)
   - DO NOT initialize with README
   - Create repository

2. **Push your local documentation:**
```bash
cd ~/Documents/Homelab_Promox_Cluster_Project/homelab-proxmox-cluster

# Initialize repository
git init
git add .
git commit -m "Initial commit: Homelab documentation structure"

# Add remote and push
git remote add origin git@github.com:YOUR_GITHUB_USERNAME/homelab-proxmox-cluster.git
git branch -M main
git push -u origin main
```

## 🎯 Useful Git Aliases

Make Git easier to use with shortcuts:

```bash
# Status
git config --global alias.st status

# Commit
git config --global alias.cm commit

# Branch
git config --global alias.br branch

# Checkout
git config --global alias.co checkout

# Pretty log
git config --global alias.lg "log --oneline --graph --decorate --all"

# Push
git config --global alias.ps push

# Pull
git config --global alias.pl pull
```

Now you can use:
- `git st` instead of `git status`
- `git cm -m "message"` instead of `git commit -m "message"`
- `git lg` for a pretty commit history

## 📝 Daily Workflow

Once everything is set up, your daily workflow will be:

```bash
# Navigate to repository
cd ~/Documents/Homelab_Promox_Cluster_Project/homelab-proxmox-cluster

# Check status
git st

# Add changes
git add .

# Commit with message
git cm -m "Update: Added Phase 6 service deployments"

# Push to GitHub
git ps
```

## 🔧 Troubleshooting

### Permission Denied (publickey)
```bash
# Check if key exists
ls -la ~/.ssh/

# Ensure ssh-agent is running
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Test connection
ssh -T git@github.com
```

### Wrong Email/Name in Commits
```bash
# Fix globally
git config --global user.email "xavier.espiau@gmail.com"
git config --global user.name "Xavier Espiau"
```

### Can't Push (non-fast-forward)
```bash
# Pull latest changes first
git pull origin main

# Then push
git push origin main
```

## 📚 Additional Resources

- [GitHub SSH Documentation](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
- [Git Basics](https://git-scm.com/book/en/v2/Getting-Started-Git-Basics)
- [GitHub CLI Manual](https://cli.github.com/manual/)

## ✅ Verification Checklist

- [ ] Git installed and configured
- [ ] SSH key generated
- [ ] SSH key added to GitHub
- [ ] Can connect to GitHub (`ssh -T git@github.com`)
- [ ] Repository created on GitHub
- [ ] Local repository pushed to GitHub
- [ ] Can view repository at github.com/YOUR_USERNAME/homelab-proxmox-cluster

---

**Need help?** The GitHub community is very helpful! Check [GitHub Community Forum](https://github.community/)

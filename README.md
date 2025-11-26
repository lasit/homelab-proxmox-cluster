# 🏠 Homelab Proxmox Cluster - Darwin, Australia

[![Status](https://img.shields.io/badge/Status-Operational-success)](./CURRENT_STATUS.md)
[![Nodes](https://img.shields.io/badge/Nodes-3-blue)]()
[![Services](https://img.shields.io/badge/Services-8-green)]()
[![Uptime](https://img.shields.io/badge/Uptime-99.9%25-brightgreen)]()

**A comprehensive 3-node Proxmox VE cluster with OPNsense routing, Ceph storage, and self-hosted services**

## 🚀 Quick Navigation

| [**Current Status**](./CURRENT_STATUS.md) | [**Quick Start**](./QUICKSTART.md) | [**Documentation**](./docs/) | [**Scripts**](./scripts/) |
|:---:|:---:|:---:|:---:|
| Live cluster status | Common tasks | Full documentation | Automation tools |

## 📋 Project Instructions

For detailed instructions on working with this project in Claude AI, see [PROJECT_INSTRUCTIONS.md](./PROJECT_INSTRUCTIONS.md)

## 📊 Infrastructure Overview
```
┌─────────────────────────────────────────────────────────┐
│                    INTERNET (NBN)                        │
└────────────────────┬───────────────────────────────────┘
                     │
              ┌──────▼──────┐
              │ ISP Router  │ 10.1.1.1
              └──────┬──────┘
                     │
              ┌──────▼──────┐
              │  OPNsense   │ Protectli FW4C
              │   Router    │ 192.168.10.1
              └──────┬──────┘
                     │
              ┌──────▼──────┐
              │   UniFi     │ 16-port PoE
              │   Switch    │ VLAN-aware
              └──────┬──────┘
                     │
     ┌───────────────┼───────────────┬──────────────┐
     │               │               │              │
┌────▼────┐    ┌────▼────┐    ┌────▼────┐    ┌────▼────┐
│  pve1   │    │  pve2   │    │  pve3   │    │ Mac Pro │
│ Node 1  │    │ Node 2  │    │ Node 3  │    │   NAS   │
└─────────┘    └─────────┘    └─────────┘    └─────────┘
   32GB           32GB           32GB            9.1TB
```

## 🎯 Project Goals

- **High Availability** - Automatic failover with 3-node cluster
- **Data Sovereignty** - Keep data in Australia under personal control  
- **Cost Efficiency** - Optimized for Darwin's $0.30/kWh electricity
- **Enterprise Learning** - Hands-on experience with production tech
- **10-Year Horizon** - Built for long-term reliability over bleeding edge

## ⚡ Quick Stats

| Category | Details |
|----------|---------|
| **Compute** | 3× HP Elite Mini 800 G9 (Intel i5-12500T, 32GB RAM each) |
| **Storage** | 172GB Ceph (3× 500GB NVMe) + 9.1TB NAS (Promise Pegasus R6) |
| **Network** | 5 VLANs, OPNsense routing, UniFi switching |
| **Services** | 8 containers (DNS, Proxy, Cloud, Monitoring, Automation) |
| **Power** | ~185W total (~$40 AUD/month) |
| **Uptime** | 99.9% since October 2025 |

## 🛠️ Deployed Services

| Service | Purpose | URL | Status |
|---------|---------|-----|--------|
| **Tailscale** | Remote VPN access | - | ✅ Operational |
| **Pi-hole** | DNS & ad-blocking | [pihole.homelab.local](http://pihole.homelab.local) | ✅ Operational |
| **Nginx Proxy** | Reverse proxy & SSL | [nginx.homelab.local](http://nginx.homelab.local) | ✅ Operational |
| **Uptime Kuma** | Service monitoring | [status.homelab.local](http://status.homelab.local) | ✅ Operational |
| **Nextcloud** | Cloud storage | [cloud.homelab.local](http://cloud.homelab.local) | ✅ Operational |
| **MariaDB** | Database backend | - | ✅ Operational |
| **Redis** | Cache server | - | ⚠️ Container only |
| **n8n** | Workflow automation | [automation.homelab.local](http://automation.homelab.local) | ✅ Operational |

## 📚 Documentation Structure
```
docs/
├── reference/          # Quick lookup tables and specs
├── guides/            # How-to guides for operations
├── deployments/       # Service installation procedures
└── architecture/      # Design decisions and philosophy
```

## 🔧 Key Features

- ✅ **High Availability** - 3-node Proxmox cluster with Ceph
- ✅ **Network Segmentation** - 5 VLANs for security isolation
- ✅ **Automated Backups** - Daily snapshots with retention
- ✅ **Remote Access** - Secure Tailscale VPN (no port forwarding)
- ✅ **Service Monitoring** - Real-time dashboard with Uptime Kuma
- ✅ **Ad Blocking** - Network-wide via Pi-hole
- ✅ **Self-Hosted Cloud** - Nextcloud replacing Google Drive
- ✅ **Workflow Automation** - n8n for service integration

## 🚦 Getting Started

1. **Check Status** → [CURRENT_STATUS.md](./CURRENT_STATUS.md)
2. **Quick Tasks** → [QUICKSTART.md](./QUICKSTART.md)  
3. **Full Setup** → [docs/deployments/](./docs/deployments/)
4. **Daily Ops** → [docs/guides/daily-operations.md](./docs/guides/daily-operations.md)

## 📖 Recent Updates

- **2025-11-24**: Mac Pro NAS boot issue resolved (stex driver fix)
- **2025-11-19**: Nextcloud and n8n deployed - cloud storage operational
- **2025-11-18**: Foundation services deployed (NPM, Uptime Kuma)
- **2025-11-15**: Automated backup system configured

See [CHANGELOG.md](./logs/changelog/2025-11.md) for full history.

## 🌟 Highlights

### Power Efficiency
Entire cluster runs at ~185W (including router, switch, nodes, and NAS) - approximately $40 AUD/month in Darwin.

### Reliability Focus
Built for 10-year operation with enterprise-grade hardware and conservative technology choices.

### Network Security  
Fully segmented with VLANs, isolated storage network, and neighbor WiFi isolation.

### Darwin Optimized
Designed for tropical climate with passive cooling where possible and high electricity costs in mind.

## 📊 Quick Commands
```bash
# Check cluster health
ssh root@192.168.10.11 "pvecm status"

# Run daily health check
./scripts/daily-health.sh

# Access services
curl http://status.homelab.local  # Monitoring dashboard
curl http://cloud.homelab.local   # Nextcloud

# View backups
ssh root@192.168.10.11 "ls -lh /mnt/macpro/proxmox-backups/dump/"
```

## 🤝 Contributing

This is a personal homelab project, but suggestions and feedback are welcome! Feel free to open issues for questions or ideas.

## 📄 License

Documentation: MIT License  
Scripts: MIT License  
Personal project - not for commercial use

---

**Location:** Darwin, NT, Australia  
**Started:** October 2025  
**Maintained by:** Xavier Espiau  
**Contact:** xavier.espiau@gmail.com
# 📬 Mailcow Professional Installer

> **One-click Mailcow setup for Ubuntu 22.04 — Proxmox Ready • Multi-DNS • Auto SSL**

---

## ⚡ One-Click Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sohelranacore/mailcow-installer/main/mailcow-installer.sh)
```

> Or with `wget`:
> ```bash
> bash <(wget -qO- https://raw.githubusercontent.com/sohelranacore/mailcow-installer/main/mailcow-installer.sh)
> ```

---

## ✅ What It Does

| Step | Action |
|------|--------|
| 🔍 **System Audit** | Detects Proxmox VM/LXC, checks RAM/CPU/Disk, audits running services & ports |
| 🐳 **Docker** | Installs Docker Engine + Compose plugin automatically |
| 🌐 **DNS Setup** | Configures A, MX, SPF, DMARC, DKIM, CNAME records automatically |
| 📦 **Mailcow** | Clones, configures, and starts all Mailcow containers |
| 🔒 **Firewall** | Sets up UFW with all required mail server ports |
| 🔑 **DKIM** | Generates and publishes DKIM key to your DNS provider |

---

## 🌐 Supported DNS Providers

| Provider | Auto DNS | Auto DKIM |
|----------|----------|-----------|
| **Cloudflare** | ✅ | ✅ |
| **Microsoft Azure DNS** | ✅ | ✅ |
| **Google Cloud DNS** | ✅ | ✅ |
| **Manual** | — | — (shown at end) |

---

## 🖥️ Requirements

- **OS:** Ubuntu 22.04 LTS (bare metal or Proxmox VM/LXC)
- **RAM:** 2 GB minimum (4 GB recommended)
- **Disk:** 10 GB free minimum (20 GB recommended)
- **CPU:** 2 cores minimum
- **Ports open:** 25, 80, 110, 143, 443, 465, 587, 993, 995, 4190
- **Root access** required

---

## 🚀 Quick Start

```bash
# Download and run as root
sudo bash <(curl -fsSL https://raw.githubusercontent.com/sohelranacore/mailcow-installer-ok/main/mailcow-installer.sh)
```

The installer will walk you through:
1. Domain name & server IP
2. Timezone
3. DNS provider selection (Cloudflare / Azure / Google / Manual)
4. Credential input for your chosen provider
5. Full automated installation

---

## 🔐 Default Admin Credentials

| Field | Value |
|-------|-------|
| **URL** | `https://mail.yourdomain.com/admin` |
| **Username** | `admin` |
| **Password** | `moohoo` |

> ⚠️ **Change the password immediately after first login!**

---

## 📋 Post-Installation Checklist

- [ ] Change admin password
- [ ] Add your domain: Admin Panel → Mail Setup → Domains
- [ ] Create first mailbox
- [ ] Verify DKIM: Admin Panel → Configuration → ARC/DKIM Keys
- [ ] Test MX propagation: `nslookup -type=MX yourdomain.com`
- [ ] Test deliverability: [mail-tester.com](https://mail-tester.com)

---

## 📁 Files

| File | Description |
|------|-------------|
| `mailcow-installer.sh` | Main installer script |
| `/root/mailcow-info.txt` | Installation record (created on server) |
| `/root/mailcow-dkim.txt` | DKIM key backup (created on server) |
| `/var/log/mailcow-installer.log` | Full installation log |

---

## 📄 License

MIT — Free to use, modify, and distribute.

---

<p align="center">
  Made with ❤️ — Ubuntu 22.04 • Docker • Mailcow • Cloudflare • Azure • GCP
</p>

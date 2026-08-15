# 🛡️ CasaOS Backup & Restore Suite

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/license/mit)
[![OS: Linux](https://img.shields.io/badge/OS-Linux-FCC624?style=flat&logo=linux&logoColor=black)](https://www.linux.org/)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Rsync](https://img.shields.io/badge/Tools-Rsync-4285F4?style=flat&logo=rsync&logoColor=white)](https://rsync.samba.org/)

A lightweight, robust Disaster Recovery (DR) solution for **CasaOS**. It automatically performs full MariaDB/SQL dumps and synchronizes Docker app volumes (`/DATA`) to a remote server over SSH/SFTP using `rsync`.

---

## ✨ Features

* **📦 Database Dumps:** Generates compressed `.sql.gz` dumps of all databases directly from your SQL container (e.g., MariaDB, MySQL).
* **🔄 Volume Sync:** Efficiently syncs `/DATA` using `rsync` over SSH, preserving bandwidth and time.
* **🚫 Smart Exclusions:** Flexible `exclude.txt` to skip heavy caches, temporary files, or database volume folders.
* **🔒 Safe Credentials:** Centralized `config.env` file kept out of version control. Users must create their own local `config.env` from the provided example template after cloning.
* **🛠️ Interactive Restore:** Simple step-by-step restoration script with built-in permission fixes (e.g., Nextcloud `0770` permissions).

---

## 🛠️ Project Structure

```text
.
├── casaos_backup.sh       # Automated backup script (Cron-friendly)
├── casaos_restore.sh      # Interactive restoration script
├── config.example.env     # Template configuration file
├── exclude.txt            # Paths to exclude from rsync
├── .gitignore             # Ignores sensitive .env files and logs
└── logs/                  # Local execution log directory
```

---

## 💡 Tips & Useful Commands

* **Make scripts executable:** Before running the scripts for the first time, grant execution permissions:
  ```bash
  chmod +x casaos_backup.sh casaos_restore.sh
  ```
* **Restrict `config.env` permissions:** Since `config.env` contains sensitive passwords and SSH key paths, secure it so only the owner can read and write to it:
  ```bash
  chmod 600 config.env
  ```
* **Run backups in background (detach):** Pass `--detach` (or `-d`) to free the terminal right after the banner while the backup keeps running:
  ```bash
  sudo ./casaos_backup.sh --detach
  # Or use the short form:
  sudo ./casaos_backup.sh -d
  ```
  The script detaches to the background and keeps writing to `logs/backup_*.log`. You can close the terminal safely.

---

## 📄 License

This project is licensed under the [MIT License](https://opensource.org/license/mit) - see the [LICENSE](LICENSE) file for details.
## wp-hack-fix

A lightweight, CLI-powered utility to automatically clean and restore hacked WordPress installations. Stop malicious processes, scrub compromised files, and reinstall core in just one command.

**Keywords**: WordPress security, malware cleanup, hacked site recovery, WP-CLI, server hardening, PHP security, automated fix, SEO optimization

---

### 🚀 Quick Start (one‑liner)

Run the entire cleanup and restore workflow in a single command:

```bash
curl -sSL https://raw.githubusercontent.com/kalprajsolutions/wp-hack-fix/main/wp-fix-hacked.sh | bash
```

> This fetches the latest script from GitHub and executes it with elevated privileges. Ensure you trust the source before running.

---

### 🔧 Features

* **Process shutdown**: Stops all processes owned by the current user to halt running malware.
* **Selective cleanup**: Deletes everything except `wp-config.php` and `wp-content/` in each WP install.
* **ELF binary removal**: Scans for and removes ELF payloads commonly dropped by attackers.
* **Suspicious code scan**: Flags any PHP files containing `eval(` or `base64_decode(` for manual review.
* **Core restoration**: Re-downloads a clean WordPress core via WP‑CLI (`wp core download --skip-content --force`).
* **SEO & performance**: Optional hooks to flush caches and optimize database (extendable).

---

### 📋 Usage

1. **Run the installer** (see Quick Start above).

2. **Or clone & run manually**:

   ```bash
   git clone https://github.com/kalprajsolutions/wp-hack-fix.git
   cd wp-hack-fix
   chmod +x wp-fix-hacked.sh
   sudo ./wp-fix-hacked.sh /path/to/your/webroot
   ```

3. **Options**:

   * `ROOT_DIR` (default `/var/www`): Base directory to scan for installs.
   * `--dry-run`: Show actions without deleting (coming soon).

4. **Post‑cleanup tips**:

   * Rotate database credentials and salts in `wp-config.php`.
   * Update all plugins/themes and core to latest versions.
   * Review server logs for unusual activity.
   * Implement a regular backup & security monitoring solution.

---

### 🔗 Resources & SEO Benefits

* **Improved security**: Removes backdoors and malicious code, reducing risk of reinfection.
* **Plugin/theme integrity**: Guarantees a clean install of WordPress core, improving compatibility and performance.
* **Search ranking**: Clean, fast sites are favored by search engines; removes hidden spam injections.

### 🤝 Contributing

1. Fork the repo.
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Commit your changes (`git commit -m "Add your feature"`).
4. Push to the branch and open a Pull Request.

---

### 📄 License

MIT © Kalpraj Solutions

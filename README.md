# 🏗️ Antigravity Arch Linux Installer

This repository contains the `PKGBUILD` and related files to install the **Antigravity IDE** natively on EndeavourOS or any Arch Linux distribution.

---

## 🛠️ Prerequisites

Before you start, ensure your Linux system has the necessary build tools and version control installed:

```bash
sudo pacman -S --needed base-devel git libarchive
```

*   `base-devel`: Essential collection of compiler and packaging tools.
*   `git`: Required for source management.
*   `libarchive`: Provides `bsdtar`, used for extracting the package.

---

## 📂 Step 1: Transfer Files

Copy all the following files from this repository to a new folder on your target Linux machine:

*   `PKGBUILD`
*   `antigravity.install`
*   `README.md`

---

## 🚀 Step 2: Build and Install

Navigate to the folder containing these files in your terminal and run the main build command:

```bash
makepkg -si
```

*   **What this does:**
    *   **Verification:** Automatically verifies the `.deb` package against the SHA256 checksum.
    *   **Packaging:** Extracts the official Google `.deb` and reorganizes it into an Arch-compatible structure.
    *   **System Integration:** Creates a symbolic link for the binary in `/usr/bin/` and updates the system's desktop/icon databases.
    *   **Installation:** Installs the final package using `pacman`.

---

## ✅ Step 3: Verify Installation

Once the process completes, you can verify that the installation was successful:

1.  **Run the IDE:** Type `antigravity` in your terminal or search for "Antigravity" in your application launcher.
2.  **Inspect Package Metadata:** `pacman -Qi antigravity`
3.  **Check Version:** `antigravity --version`

---

## 🧹 Cleanup & Updates

To uninstall Antigravity, use the standard `pacman` command:

```bash
sudo pacman -R antigravity
```

**For updates:** When a new version is released, update the `pkgver` and `sha256sums` in the `PKGBUILD` and run `makepkg -si` again.

---
**Source:** [Antigravity Official](https://antigravity.google/)

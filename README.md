# Hive SEC WarMachine – Fedora Edition

Professional ethical-hacking workspace for Fedora: interactive installer, advanced control TUI, multiplex tmux session, and integrated **Python 3**, **Rust**, and **Sliver** stacks.

## Legal / Ethical Notice

**Use only for authorized testing, research, education, and defensive work.**  
Unauthorized scanning, exploitation, or access to systems you do not own or lack explicit written permission to test is illegal. You are solely responsible for compliance with all applicable laws and engagement rules.

---

## Components

| File | Purpose |
|------|---------|
| `install_warmachine.sh` | Category installer (dnf, git, pip/venv, cargo, Sliver) |
| `wm-control` | Advanced control dashboard + guided tool runners |
| `tmux.warmachine.conf` | tmux theme, prefix, and keybindings for multiplex mode |
| `README.md` | This documentation |

---

## Quick Start

```bash
# 1. Place files under ~/WarMachine (or keep the folder together)
chmod +x install_warmachine.sh wm-control

# 2. Install tools (root for dnf / system packages)
sudo ./install_warmachine.sh
```

**Recommended install order**

| Option | What it installs |
|--------|------------------|
| **0** | Python core venv + high-value CLIs |
| **13** | Rust tools (prebuilt feroxbuster/findomain + cargo) |
| **1–12** | Recon, network, enum, vuln, system, web, passwords, wireless, forensics, social, malware, extra |
| **14** | Sliver C2 (**authorized use only**) |
| **a** | Everything |

```bash
# 3. Control interface
./wm-control              # dashboard
./wm-control start        # multiplex tmux workspace
./wm-control python       # venv shell
./wm-control status       # tool inventory
./wm-control search nmap  # find tools
./wm-control help
```

Optional global command:

```bash
sudo ln -sf "$(pwd)/wm-control" /usr/local/bin/wm-control
```

---

## Control Dashboard (`wm-control`)

### Features

- Live **status bar** (Python / Rust / Sliver stacks)
- Per-tool marks: **✓** installed · **·** missing
- Guided prompts for tools that need targets:
  - **rustscan** → IP/CIDR, ports, extra flags
  - **nmap** → target + scan profile
  - **feroxbuster** → URL + wordlist
  - **findomain** → domain
- Search, inventory, help screens
- Sliver launch requires explicit **y/N** confirmation

### Main menu

| Key | Section |
|-----|---------|
| 1–9 | Recon → Forensics |
| 10 | Python 3 environment |
| 11 | Rust security tools |
| 12 | Red Team – Sliver C2 (auth only) |
| 13 | Folders & logs |
| 14 | Tool inventory |
| 15 | Search tools |
| 16 | Help |
| **s** | Start multiplex session |
| **p** | Python venv shell |
| **q** | Quit |

### CLI modes

```bash
wm-control              # interactive dashboard
wm-control start        # tmux multiplex
wm-control python       # drop into venv
wm-control status       # inventory
wm-control search TERM  # search
wm-control help
```

---

## Multiplex Session (`wm-control start`)

Requires: `sudo dnf install tmux`

Uses `tmux.warmachine.conf` (prefix **Ctrl-a**, mouse, status bar).

### Windows

| Window | Name | Purpose |
|--------|------|---------|
| 1 | **HUD** | Control TUI (left) · ops shell · notes/reports |
| 2 | **Recon** | Scanning / OSINT panes |
| 3 | **Network** | Capture / traffic |
| 4 | **Web** | App testing + wordlists |
| 5 | **Exploit** | Post-exp / C2 notes (authorized only) |
| 6 | **Python** | WarMachine venv ready |
| 7 | **Logs** | Reports + live install.log tail |

### Keybindings

| Keys | Action |
|------|--------|
| **Ctrl-a** | Prefix |
| **Alt-1 … Alt-7** | Jump to window |
| **Ctrl-a \|** | Split vertical |
| **Ctrl-a -** | Split horizontal |
| **Ctrl-a h/j/k/l** | Move between panes |
| **Ctrl-a H/J/K/L** | Resize panes |
| **Ctrl-a z** | Zoom pane |
| **Ctrl-a d** | Detach (session keeps running) |
| **Ctrl-a m** | Jump to HUD |
| Mouse | Click / resize |

```bash
tmux attach -t WarMachine          # rejoin
tmux kill-session -t WarMachine    # destroy session
```

If a session already exists, the launcher offers **Attach** or **Kill & recreate**.

---

## Installer Categories

| # | Category |
|---|----------|
| 0 | Python Core Environment |
| 1 | Footprinting / Recon |
| 2 | Network Tools |
| 3 | Enumeration |
| 4 | Vulnerability Analysis |
| 5 | System Hacking / Post-Exploitation |
| 6 | Web Application |
| 7 | Password Cracking + Wordlists |
| 8 | Wireless |
| 9 | Forensics |
| 10 | Social Engineering (authorized simulations) |
| 11 | Malware Analysis |
| 12 | Extra / OSINT / Privacy |
| 13 | Rust Security Tools |
| 14 | Sliver (Red Team C2) – **AUTHORIZED ONLY** |
| a | All of the above |

---

## Python 3

Dedicated venv: `~/WarMachine/venv/`

```bash
source ~/WarMachine/activate
# or
~/WarMachine/bin/wm-python
# or
./wm-control python
```

| Tool | Role |
|------|------|
| theHarvester | OSINT |
| sqlmap | SQLi research |
| dirsearch | Web path discovery |
| wafw00f | WAF fingerprinting |
| Impacket | AD / network protocols |
| Scapy | Packet crafting |
| Responder | LLMNR/NBT-NS |
| Volatility 3 | Memory forensics |
| NetExec | Network / AD enum |
| Certipy | AD certificate research |

Also: sherlock, recon-ng, wfuzz, phoneinfoga, metagoofil, SET, and libraries such as `pwntools`, `shodan`, `censys`, `yara-python`.

---

## Rust Tools (option 13)

| Tool | Role | Install method |
|------|------|----------------|
| **feroxbuster** | Content discovery | Prebuilt (official script / GitHub zip) |
| **findomain** | Subdomains | Prebuilt zip (`findomain-linux.zip`) — *not* crates.io (yanked) |
| **rustscan** | Fast port scan | cargo (or package) |
| sn0int, x8, websocat, oha, hurl | OSINT / HTTP / params | cargo |
| rg, fd, bat | Search / find / cat | cargo |

Binaries: `~/.cargo/bin` (linked into `~/WarMachine/bin`).

### Manual fix if findomain 404’d

```bash
mkdir -p ~/.cargo/bin
cd /tmp
curl -fsSL -o findomain-linux.zip \
  https://github.com/Findomain/Findomain/releases/latest/download/findomain-linux.zip
unzip -o findomain-linux.zip
chmod +x findomain 2>/dev/null || chmod +x findomain-linux 2>/dev/null
mv -f findomain ~/.cargo/bin/findomain 2>/dev/null || mv -f findomain-linux ~/.cargo/bin/findomain
export PATH="$HOME/.cargo/bin:$PATH"
findomain -V
```

### rustscan from the dashboard

Menu **11 → 1** prompts for target IP/CIDR, ports, and flags.

From the shell:

```bash
rustscan -a 192.168.1.10 --ulimit 5000
rustscan -a 10.0.0.0/24 -r 80,443,8080
```

---

## Sliver – Red Team C2 (option 14)

[BishopFox Sliver](https://github.com/BishopFox/sliver) adversary-emulation framework.

- Official installer: `curl https://sliver.sh/install | bash`
- Fallback: GitHub release assets
- Launchers: `sliver`, `sliver-server`, `sliver-client`, `wm-sliver`
- Dashboard: menu **12** (confirmation required)

**AUTHORIZED USE ONLY.** Written permission required. Unauthorized use is illegal.

Docs: https://sliver.sh/

---

## Workspace Layout

```
~/WarMachine/   (or /opt/WarMachine when installer runs purely as root)
├── activate                 # source → enter Python venv
├── bin/                     # launchers & symlinks
├── tools/                   # git-cloned tools
├── venv/                    # Python 3 virtualenv
├── wordlists/               # SecLists, etc.
├── reports/                 # findings / notes
├── install.log
├── control.log
├── install_warmachine.sh
├── wm-control
├── tmux.warmachine.conf
└── README.md
```

PATH helper (after install): `/etc/profile.d/warmachine.sh`  
Includes `~/WarMachine/bin`, `~/.cargo/bin`, `~/go/bin`, `~/.local/bin`.

---

## Dependencies

```bash
sudo dnf install tmux git curl wget python3 python3-pip python3-devel \
  rust cargo unzip jq
```

Optional: `pipx`, Fedora Security Lab packages, Burp Suite Community (manual download).

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Rust cargo permission errors | Run installer option 13 again; ensure `~/.cargo` is owned by your user: `sudo chown -R "$USER:$USER" ~/.cargo` |
| feroxbuster compile fails | Installer uses prebuilt; or: `curl -sL https://raw.githubusercontent.com/epi052/feroxbuster/main/install-nix.sh \| bash -s ~/.cargo/bin` |
| findomain 404 | Use `findomain-linux.zip` from GitHub releases (see above) |
| rustscan “too many open files” | Add `--ulimit 5000` |
| tmux session already exists | Choose Attach, or Kill & recreate from `wm-control start` |
| Tool shows **·** in menu | Install the matching installer category |

---

## Ethics

Stay within scope. Prefer isolated labs and CTFs for practice. Always obtain proper authorization before testing production or third-party systems.

---

Hive SEC WarMachine — Python · Rust · Sliver · Multiplex TUI  
*For professional researchers only.*

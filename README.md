# Hive SEC WarMachine – Fedora Edition

Specialized workspace + interactive installer + **multiplex terminal TUI** with full **Python 3 + Rust** integration for professional ethical hackers and security researchers on Fedora Linux.

## Legal / Ethical Notice

**Use only for authorized testing, research, education, and defensive purposes.**  
Unauthorized scanning, exploitation, or access to systems you do not own or lack explicit written permission to test is a crime. You are solely responsible for complying with all applicable laws and regulations.

## Components

| File | Purpose |
|------|---------|
| `install_warmachine.sh` | Interactive installer (Python core + Rust tools + categories) |
| `wm-control` | Multiplex Terminal TUI control interface |
| `README.md` | This file |

## Sliver – Red Team C2 (option 14)

Integrates **BishopFox Sliver**, an open-source adversary emulation / C2 framework.

- Official installer path + GitHub release fallback
- Launchers: `sliver`, `sliver-server`, `sliver-client`, `wm-sliver`
- Control TUI → menu **13 – Red Team – Sliver C2**

**AUTHORIZED USE ONLY.** Explicit written authorization required. Unauthorized use is illegal.

Docs: https://sliver.sh/ · https://github.com/BishopFox/sliver

## Rust Security Tools (option 13)

Installs famous Rust-based security / recon tools via `cargo`:

| Tool | Purpose |
|------|---------|
| **rustscan** | Ultra-fast port scanner |
| **feroxbuster** | Recursive content discovery (dirbusting) |
| **findomain** | Subdomain discovery |
| **sn0int** | Semi-automatic OSINT framework |
| **x8** | Hidden HTTP parameter discovery |
| **websocat** | Netcat for WebSockets |
| **oha** | HTTP load / stress testing |
| **hurl** | HTTP testing & scripting |
| **rg** (ripgrep) | Extremely fast recursive search |
| **fd** | User-friendly find |
| **bat** | Better cat (handy for reports) |

Optional: rustcat, netscanner, authoscope, yara-x.

Tools land in `~/.cargo/bin` and are linked into `~/WarMachine/bin`.  
The control TUI has a dedicated **Rust Security Tools** menu (option 12).

## Python 3 Integration

The installer creates a dedicated virtual environment:

```
~/WarMachine/venv/
```

### How it works

1. **Option 0** in the installer (recommended first) creates the venv and installs high-value packages.
2. Many tools are installed **into the venv** (or as editable installs from git) so dependencies stay isolated.
3. Convenient launchers are placed in `~/WarMachine/bin/`.
4. The control TUI automatically activates the venv when launching Python tools.

### Activate the environment manually

```bash
source ~/WarMachine/activate
# or
~/WarMachine/bin/wm-python
```

### Key Python tools integrated

| Tool | Category | Notes |
|------|----------|-------|
| theHarvester | Recon | OSINT |
| sqlmap | Vuln / Web | SQL injection research |
| dirsearch | Enumeration | Web path discovery |
| wafw00f | Recon | WAF fingerprinting |
| Impacket | System / AD | secretsdump, psexec, etc. |
| Scapy | Network | Packet crafting |
| Responder | System | LLMNR/NBT-NS |
| Volatility 3 | Forensics | Memory analysis |
| NetExec / CME | Enumeration | Network/AD |
| Certipy | System | AD certificate research |
| phoneinfoga, metagoofil, sherlock, recon-ng, wfuzz, weevely, SET … | Various | |

Plus libraries: `scapy`, `impacket`, `pwntools`, `ropper`, `shodan`, `censys`, `yara-python`, `pefile`, etc.

## Quick Start

### 1. Install tools
```bash
chmod +x install_warmachine.sh
sudo ./install_warmachine.sh
```
**Strongly recommended:**  
- **0** → Python Core Environment  
- **13** → Rust Security Tools  
then any other categories you need (or `a` for all).

### 2. Launch the Control Interface
```bash
chmod +x wm-control

# Interactive TUI
./wm-control

# Full multiplex (tmux) session
./wm-control start

# Jump straight into the Python venv
./wm-control python
```

Optional symlink:
```bash
sudo ln -sf $(pwd)/wm-control /usr/local/bin/wm-control
```

## Control Interface highlights

- Main menu with all categories
- New **Python 3 Tools & Environment** menu (option 11)
- One-key access to scapy / impacket interactive shells
- Multiplex session now includes a dedicated **Python** window with the venv pre-activated
- Smart launcher that prefers:
  1. WarMachine bin launchers
  2. System binaries
  3. Tool directory + venv Python

## Multiplex Session Layout (`wm-control start`)

| Window | Name     | Purpose |
|--------|----------|---------|
| 0      | Control  | Split (menu \| tools \| reports) |
| 1      | Recon    | Recon tools |
| 2      | Network  | Network testing |
| 3      | Web      | Web application testing |
| 4      | Python   | WarMachine venv ready |
| 5      | Reports  | Notes & findings |

## Workspace layout

```
~/WarMachine/
├── activate          # source this to enter the venv
├── bin/              # launchers (wm-python, theHarvester, sqlmap, …)
├── tools/            # git-cloned tools
├── venv/             # dedicated Python 3 virtual environment
├── wordlists/        # SecLists etc.
├── reports/
├── install.log
├── install_warmachine.sh
└── wm-control
```

## Recommended extra packages

```bash
sudo dnf install tmux pipx
```

Stay ethical. Always obtain proper authorization before any testing.

---
Hive SEC WarMachine – Python 3 ready.

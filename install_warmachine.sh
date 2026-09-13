#!/usr/bin/env bash
#
# Hive SEC WarMachine Installer for Fedora
# Ethical security research & authorized pentesting workspace
# With full Python 3 tool integration (venv + pipx)
#
# Usage: sudo ./install_warmachine.sh
#
# LEGAL: Use ONLY on systems you own or have explicit written authorization to test.
# Unauthorized use is illegal. You are responsible for compliance with all laws.
#

set -euo pipefail

# ---------- Configuration ----------
WORKSPACE="${HOME}/WarMachine"
if [[ $EUID -eq 0 ]]; then
  WORKSPACE="/opt/WarMachine"
fi
LOGFILE="${WORKSPACE}/install.log"
TOOLS_DIR="${WORKSPACE}/tools"
BIN_DIR="${WORKSPACE}/bin"
WORDLISTS_DIR="${WORKSPACE}/wordlists"
REPORTS_DIR="${WORKSPACE}/reports"
VENV_DIR="${WORKSPACE}/venv"
PYTHON="${VENV_DIR}/bin/python"
PIP="${VENV_DIR}/bin/pip"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---------- Helpers ----------
log()   { echo -e "${GREEN}[+]${NC} $*" | tee -a "$LOGFILE"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*" | tee -a "$LOGFILE"; }
error() { echo -e "${RED}[-]${NC} $*" | tee -a "$LOGFILE"; }
info()  { echo -e "${CYAN}[*]${NC} $*" | tee -a "$LOGFILE"; }

check_root() {
  if [[ $EUID -ne 0 ]]; then
    error "This installer needs root privileges (dnf, system packages)."
    echo "Re-run with: sudo $0"
    exit 1
  fi
}

create_workspace() {
  mkdir -p "$WORKSPACE" "$TOOLS_DIR" "$BIN_DIR" "$WORDLISTS_DIR" "$REPORTS_DIR"
  touch "$LOGFILE"
  log "Workspace created at: $WORKSPACE"
  if [[ -n "${SUDO_USER:-}" ]]; then
    chown -R "$SUDO_USER:$SUDO_USER" "$WORKSPACE" || true
  fi
}

update_system() {
  log "Updating system packages..."
  dnf -y update || warn "System update had issues (continuing)"

  log "Installing base + Python development packages..."
  dnf -y install \
    dnf-plugins-core git curl wget \
    python3 python3-pip python3-devel python3-virtualenv python3-setuptools \
    python3-wheel python3-cffi python3-cryptography python3-lxml \
    golang rust cargo make gcc gcc-c++ cmake \
    openssl-devel libffi-devel libpcap-devel libxml2-devel libxslt-devel \
    zlib-devel sqlite-devel readline-devel \
    which unzip tar jq vim nano net-tools bind-utils whois traceroute \
    nmap-ncat tmux || warn "Some base packages failed"

  # pipx is excellent for isolated CLI tools
  if ! command -v pipx &>/dev/null; then
    log "Installing pipx..."
    dnf -y install pipx || python3 -m pip install --user pipx
    if [[ -n "${SUDO_USER:-}" ]]; then
      sudo -u "$SUDO_USER" pipx ensurepath || true
    fi
  fi
}

# ---------- Python environment ----------
setup_python_env() {
  log "=== Setting up WarMachine Python 3 environment ==="

  if [[ ! -d "$VENV_DIR" ]]; then
    log "Creating virtualenv at $VENV_DIR"
    python3 -m venv "$VENV_DIR"
  else
    info "Virtualenv already exists"
  fi

  # Upgrade core tooling
  "$PIP" install --upgrade pip setuptools wheel

  # Core libraries used by many security tools
  log "Installing core Python libraries into venv..."
  "$PIP" install --upgrade \
    requests urllib3 beautifulsoup4 lxml \
    scapy cryptography paramiko \
    colorama rich tqdm tabulate \
    pyyaml netaddr \
    dnspython future six \
    pycryptodome pycryptodomex \
    flask jinja2 \
    shodan censys \
    || warn "Some core libraries failed"

  # Make activation easy
  cat > "${BIN_DIR}/wm-python" << EOF
#!/usr/bin/env bash
# Activate WarMachine Python environment and run command (or drop into shell)
source "${VENV_DIR}/bin/activate"
if [[ \$# -eq 0 ]]; then
  echo "WarMachine Python venv activated. Type 'exit' to leave."
  exec bash --rcfile <(echo "PS1='(wm-python) \\u@\\h:\\w\\\$ '")
else
  exec "\$@"
fi
EOF
  chmod +x "${BIN_DIR}/wm-python"

  # Convenience activate script
  cat > "${WORKSPACE}/activate" << EOF
# Source this file:  source ${WORKSPACE}/activate
source "${VENV_DIR}/bin/activate"
export PATH="${BIN_DIR}:\$PATH"
export WAR_MACHINE="${WORKSPACE}"
echo "WarMachine Python environment activated."
EOF

  log "Python environment ready. Use:  source ${WORKSPACE}/activate"
  log "Or:  ${BIN_DIR}/wm-python"
}

# Install a Python tool from git + requirements
install_python_git() {
  local url="$1"
  local name="$2"
  local entry="${3:-}"          # optional entry point after install
  local dest="${TOOLS_DIR}/${name}"

  if [[ -d "$dest" ]]; then
    info "$name already present – updating..."
    git -C "$dest" pull --ff-only || true
  else
    log "Cloning $name..."
    git clone --depth 1 "$url" "$dest" || { warn "Failed to clone $name"; return 1; }
  fi

  # Install requirements if present
  if [[ -f "$dest/requirements.txt" ]]; then
    log "Installing requirements for $name into WarMachine venv..."
    "$PIP" install -r "$dest/requirements.txt" || warn "Some requirements for $name failed"
  fi
  if [[ -f "$dest/setup.py" ]] || [[ -f "$dest/pyproject.toml" ]]; then
    log "Installing $name in editable mode..."
    "$PIP" install -e "$dest" || warn "Editable install of $name failed"
  fi

  # Create a convenient launcher in BIN_DIR
  if [[ -n "$entry" ]]; then
    cat > "${BIN_DIR}/${name}" << EOF
#!/usr/bin/env bash
source "${VENV_DIR}/bin/activate"
cd "${dest}"
exec ${entry} "\$@"
EOF
    chmod +x "${BIN_DIR}/${name}"
  fi
}

# Generic git clone (non-python heavy)
install_git_tool() {
  local url="$1"
  local name="$2"
  local dest="${TOOLS_DIR}/${name}"
  if [[ -d "$dest" ]]; then
    info "$name already present – updating..."
    git -C "$dest" pull --ff-only || true
  else
    log "Cloning $name..."
    git clone --depth 1 "$url" "$dest" || warn "Failed to clone $name"
  fi
}

# ---------- Category install functions ----------

install_recon() {
  log "=== Footprinting / Reconnaissance ==="
  dnf -y install nmap whois bind-utils traceroute tcpdump wireshark-cli \
    theharvester whatweb nikto || true

  # Python-heavy tools
  install_python_git "https://github.com/laramies/theHarvester.git" "theHarvester" "python3 theHarvester.py"
  install_python_git "https://github.com/lanmaster53/recon-ng.git" "recon-ng" "python3 recon-ng"
  install_python_git "https://github.com/sherlock-project/sherlock.git" "sherlock" "python3 sherlock"
  install_python_git "https://github.com/EnableSecurity/wafw00f.git" "wafw00f" "wafw00f"
  install_python_git "https://github.com/darkoperator/dnsrecon.git" "dnsrecon" "python3 dnsrecon.py"
  install_python_git "https://github.com/aboul3la/Sublist3r.git" "Sublist3r" "python3 sublist3r.py"
  install_python_git "https://github.com/s0md3v/ReconDog.git" "ReconDog" "python3 dog"

  # Go tools
  install_git_tool "https://github.com/OWASP/Amass.git" "Amass"
  install_git_tool "https://github.com/projectdiscovery/subfinder.git" "subfinder"

  if command -v go &>/dev/null; then
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest || true
    go install -v github.com/owasp-amass/amass/v4/...@master || true
    go install -v github.com/tomnomnom/httprobe@latest || true
    go install -v github.com/tomnomnom/waybackurls@latest || true
    go install -v github.com/ffuf/ffuf/v2@latest || true
  fi

  log "Recon tools installed"
}

install_network() {
  log "=== Network Tools ==="
  dnf -y install wireshark wireshark-cli nmap aircrack-ng ettercap \
    hping3 tcpdump net-tools arp-scan macchanger bettercap \
    yersinia || true

  # Scapy is pure Python and extremely useful
  "$PIP" install --upgrade scapy || true

  install_git_tool "https://github.com/bettercap/bettercap.git" "bettercap"
  log "Network tools installed (scapy available in WarMachine venv)"
}

install_enumeration() {
  log "=== Enumeration ==="
  dnf -y install gobuster dirb enum4linux smbclient openldap-clients \
    net-snmp-utils || true

  install_python_git "https://github.com/maurosoria/dirsearch.git" "dirsearch" "python3 dirsearch.py"
  # NetExec is the maintained fork of CrackMapExec
  install_python_git "https://github.com/Pennyw0rth/NetExec.git" "NetExec" "nxc" || \
    install_python_git "https://github.com/byt3bl33d3r/CrackMapExec.git" "CrackMapExec" "cme"

  install_git_tool "https://github.com/OJ/gobuster.git" "gobuster"
  install_git_tool "https://github.com/CiscoCXSecurity/enum4linux.git" "enum4linux"
  install_git_tool "https://github.com/FortyNorthSecurity/EyeWitness.git" "EyeWitness"

  if command -v go &>/dev/null; then
    go install -v github.com/OJ/gobuster/v3@latest || true
    go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest || true
  fi

  log "Enumeration tools installed"
}

install_vuln() {
  log "=== Vulnerability Analysis ==="
  dnf -y install nikto sqlmap || true

  install_python_git "https://github.com/sqlmapproject/sqlmap.git" "sqlmap" "python3 sqlmap.py"
  install_python_git "https://github.com/sullo/nikto.git" "nikto" || true

  install_git_tool "https://github.com/projectdiscovery/nuclei.git" "nuclei"
  if command -v go &>/dev/null; then
    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest || true
  fi

  warn "OpenVAS / Greenbone requires additional configuration after install."
  log "Vulnerability tools installed"
}

install_system_hacking() {
  log "=== System Hacking / Post-Exploitation (authorized use only) ==="
  dnf -y install hydra john hashcat medusa || true

  # Metasploit
  if ! command -v msfconsole &>/dev/null; then
    log "Installing Metasploit Framework..."
    curl -s https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > /tmp/msfinstall
    chmod 755 /tmp/msfinstall
    /tmp/msfinstall || warn "Metasploit installer had issues – see https://docs.metasploit.com"
  fi

  # Important Python post-exploitation / AD tools
  install_python_git "https://github.com/fortra/impacket.git" "impacket" "python3"
  "$PIP" install --upgrade impacket || true

  install_python_git "https://github.com/lgandx/Responder.git" "Responder" "python3 Responder.py"
  install_python_git "https://github.com/carlospolop/PEASS-ng.git" "PEASS-ng"
  install_git_tool "https://github.com/PowerShellMafia/PowerSploit.git" "PowerSploit"
  install_git_tool "https://github.com/gentilkiwi/mimikatz.git" "mimikatz"

  # Certipy (AD cert abuse research)
  "$PIP" install --upgrade certipy-ad || true

  log "System hacking tools installed (use responsibly)"
}

install_web() {
  log "=== Web Application Tools ==="
  dnf -y install zaproxy || true

  install_python_git "https://github.com/sqlmapproject/sqlmap.git" "sqlmap" "python3 sqlmap.py"
  install_python_git "https://github.com/xmendez/wfuzz.git" "wfuzz" "wfuzz"
  install_python_git "https://github.com/epinna/weevely3.git" "weevely" "python3 weevely.py"
  install_python_git "https://github.com/wpscanteam/wpscan.git" "wpscan" || true

  install_git_tool "https://github.com/ffuf/ffuf.git" "ffuf"
  install_git_tool "https://github.com/zaproxy/zaproxy.git" "zaproxy" || true

  warn "Burp Suite Community: download from https://portswigger.net/burp/communitydownload"
  log "Web tools installed"
}

install_password() {
  log "=== Password Cracking / Brute-force ==="
  dnf -y install hashcat john hydra medusa crunch || true

  install_git_tool "https://github.com/hashcat/hashcat.git" "hashcat"
  install_git_tool "https://github.com/openwall/john.git" "john"
  install_git_tool "https://github.com/vanhauser-thc/thc-hydra.git" "thc-hydra"

  if [[ ! -d "$WORDLISTS_DIR/SecLists" ]]; then
    log "Cloning SecLists (large)..."
    git clone --depth 1 https://github.com/danielmiessler/SecLists.git "$WORDLISTS_DIR/SecLists" || true
  fi

  log "Password tools + wordlists installed"
}

install_wireless() {
  log "=== Wireless ==="
  dnf -y install aircrack-ng reaver kismet macchanger hcxtools || true
  install_git_tool "https://github.com/t6x/reaver-wps-fork-t6x.git" "reaver"
  log "Wireless tools installed"
}

install_forensics() {
  log "=== Forensics ==="
  dnf -y install autopsy sleuthkit || true

  # Volatility 3 is pure Python
  install_python_git "https://github.com/volatilityfoundation/volatility3.git" "volatility3" "python3 vol.py"
  "$PIP" install --upgrade volatility3 || true

  log "Forensics tools installed"
}

install_social() {
  log "=== Social Engineering (authorized phishing simulations only) ==="
  install_python_git "https://github.com/trustedsec/social-engineer-toolkit.git" "SET" "python3 setoolkit"
  install_git_tool "https://github.com/gophish/gophish.git" "gophish"
  warn "Social-engineering tools must only be used for authorized awareness training / red-team exercises."
  log "Social tools installed"
}

install_malware_analysis() {
  log "=== Malware Analysis (research) ==="
  dnf -y install yara radare2 || true

  install_git_tool "https://github.com/VirusTotal/yara.git" "yara"
  install_git_tool "https://github.com/radareorg/radare2.git" "radare2"

  # Useful Python helpers
  "$PIP" install --upgrade yara-python pefile capstone || true

  warn "Ghidra: preferred way is official NSA release or dnf if available."
  log "Malware analysis tools installed"
}

install_extra() {
  log "=== Extra / OSINT / Privacy + pure Python utilities ==="
  dnf -y install tor proxychains-ng macchanger keepassxc || true

  install_python_git "https://github.com/sundowndev/phoneinfoga.git" "phoneinfoga" "phoneinfoga"
  install_python_git "https://github.com/laramies/metagoofil.git" "metagoofil" "python3 metagoofil.py"

  # Popular pure-Python research libraries / CLIs
  log "Installing additional Python security libraries..."
  "$PIP" install --upgrade \
    shodan censys \
    pwntools \
    ropper \
    bloodhound \
    ldap3 \
    || warn "Some extra Python packages failed"

  log "Extra tools installed"
}

install_python_core() {
  log "=== Dedicated Python 3 Core Tools ==="
  setup_python_env

  # Tools that are best installed via pip into the venv
  log "Installing high-value Python CLIs into WarMachine venv..."
  "$PIP" install --upgrade \
    theHarvester \
    sqlmap \
    dirsearch \
    wafw00f \
    impacket \
    scapy \
    certipy-ad \
    volatility3 \
    shodan \
    || true

  # Also try pipx for truly isolated tools (if available)
  if command -v pipx &>/dev/null; then
    log "Installing selected tools with pipx (isolated)..."
    pipx install sqlmap || true
    pipx install dirsearch || true
    pipx install theHarvester || true
    pipx install impacket || true
  fi

  log "Python core tools ready"
}

# ---------- Rust tools ----------
# Resolve the real (non-root) user so cargo never writes as root into a user home
rust_real_user() {
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    echo "$SUDO_USER"
  elif [[ $EUID -ne 0 ]]; then
    echo "$(id -un)"
  else
    echo ""
  fi
}

rust_real_home() {
  local u
  u="$(rust_real_user)"
  if [[ -n "$u" ]]; then
    getent passwd "$u" | cut -d: -f6
  else
    echo "${HOME:-/root}"
  fi
}

setup_rust_env() {
  log "=== Setting up Rust toolchain ==="

  local real_user real_home
  real_user="$(rust_real_user)"
  real_home="$(rust_real_home)"

  if ! command -v rustc &>/dev/null || ! command -v cargo &>/dev/null; then
    log "Installing Rust via dnf (rust + cargo)..."
    dnf -y install rust cargo rust-src || {
      warn "dnf rust failed – trying rustup as the real user..."
      if [[ -n "$real_user" ]]; then
        sudo -u "$real_user" -H bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y' || true
      else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || true
      fi
    }
  else
    info "Rust already present: $(rustc --version 2>/dev/null || echo '?')"
  fi

  # User-owned cargo directories (never leave root-owned dirs in a user home)
  local cargo_home="${real_home}/.cargo"
  local cargo_bin="${cargo_home}/bin"
  if [[ -n "$real_user" ]]; then
    sudo -u "$real_user" -H mkdir -p "$cargo_bin" "${real_home}/.rustup" 2>/dev/null || true
    # Fix accidental root ownership from earlier runs
    chown -R "$real_user:$real_user" "$cargo_home" 2>/dev/null || true
    chown -R "$real_user:$real_user" "${real_home}/.rustup" 2>/dev/null || true
  else
    mkdir -p "$cargo_bin" 2>/dev/null || true
  fi

  # PATH helper
  if [[ ! -f /etc/profile.d/warmachine.sh ]]; then
    echo 'export PATH="$PATH:$HOME/WarMachine/bin:/opt/WarMachine/bin:$HOME/go/bin:$HOME/.local/bin:$HOME/.cargo/bin"' > /etc/profile.d/warmachine.sh
  fi
  if ! grep -q '\.cargo/bin' /etc/profile.d/warmachine.sh 2>/dev/null; then
    echo 'export PATH="$PATH:$HOME/.cargo/bin"' >> /etc/profile.d/warmachine.sh
  fi
  chmod 644 /etc/profile.d/warmachine.sh 2>/dev/null || true

  export PATH="${PATH}:${cargo_bin}:${real_home}/.cargo/bin"
  log "Rust environment ready (cargo home: ${cargo_home})"
}

install_rust_tools() {
  log "=== Famous Rust Hacking / Security Tools ==="
  setup_rust_env

  local real_user real_home cargo_home cargo_bin
  real_user="$(rust_real_user)"
  real_home="$(rust_real_home)"
  cargo_home="${real_home}/.cargo"
  cargo_bin="${cargo_home}/bin"

  # Ensure WarMachine bin exists and is writable by the real user when possible
  mkdir -p "$BIN_DIR"
  if [[ -n "$real_user" && -d "$WORKSPACE" ]]; then
    chown -R "$real_user:$real_user" "$WORKSPACE" 2>/dev/null || true
  fi

  # Run cargo strictly as the real user with explicit CARGO_HOME
  # Install into the user's ~/.cargo/bin (standard) and also link into WarMachine/bin
  cargo_install() {
    local crate="$1"
    log "cargo install $crate ..."

    local cmd="export CARGO_HOME='${cargo_home}'; export PATH=\"${cargo_bin}:\$PATH\"; source '${cargo_home}/env' 2>/dev/null || true; command -v cargo >/dev/null && cargo install --locked ${crate} || cargo install ${crate}"

    if [[ -n "$real_user" ]]; then
      if sudo -u "$real_user" -H bash -lc "$cmd"; then
        info "Installed $crate"
      else
        warn "Failed to install $crate (see cargo output above)"
      fi
    else
      # Already root / no SUDO_USER – install into root's cargo (lab VMs only)
      export CARGO_HOME="${cargo_home}"
      export PATH="${cargo_bin}:${PATH}"
      cargo install --locked "$crate" || cargo install "$crate" || warn "Failed to install $crate"
    fi
  }

  # --- Core famous tools ---
  cargo_install rustscan
  cargo_install feroxbuster
  cargo_install findomain
  cargo_install sn0int
  cargo_install x8
  cargo_install websocat
  cargo_install oha
  cargo_install hurl
  cargo_install ripgrep
  cargo_install fd-find
  cargo_install bat

  # Optional (failures ignored)
  cargo_install rustcat || true
  cargo_install netscanner || true
  cargo_install authoscope || true
  cargo_install yara-x || true

  # Symlink into WarMachine/bin (resolve alternate binary names)
  link_rust_bin() {
    local src_name="$1"
    local dst_name="${2:-$1}"
    if [[ -x "${cargo_bin}/${src_name}" ]]; then
      ln -sf "${cargo_bin}/${src_name}" "${BIN_DIR}/${dst_name}" 2>/dev/null || true
    fi
  }

  link_rust_bin rustscan
  link_rust_bin feroxbuster
  link_rust_bin findomain
  link_rust_bin sn0int
  link_rust_bin x8
  link_rust_bin websocat
  link_rust_bin oha
  link_rust_bin hurl
  link_rust_bin rg
  link_rust_bin fd
  link_rust_bin bat
  # fd-find crate installs as "fd"
  link_rust_bin fd fd

  if [[ -n "$real_user" ]]; then
    chown -R "$real_user:$real_user" "$cargo_home" 2>/dev/null || true
    chown -h "$real_user:$real_user" "${BIN_DIR}"/* 2>/dev/null || true
  fi

  log "Rust security tools installed"
  log "Binaries: ${cargo_bin}  (linked from ${BIN_DIR})"
  info "Open a new shell or run:  source /etc/profile.d/warmachine.sh"
  info "Examples:  rustscan -a 192.168.1.0/24"
  info "           feroxbuster -u https://target -w wordlist.txt"
  info "           findomain -t example.com"
}

# ---------- Sliver (Red Team C2) ----------
install_sliver() {
  log "=== Sliver – Adversary Emulation / Red Team C2 (BishopFox) ==="
  warn "AUTHORIZED USE ONLY. Sliver is a full C2 framework."
  warn "Use exclusively for authorized red-team engagements, labs, and research."
  warn "Unauthorized deployment or use against systems is illegal."

  local SLIVER_DIR="${TOOLS_DIR}/sliver"
  mkdir -p "$SLIVER_DIR" "$BIN_DIR"

  # Prefer official one-liner installer (places binaries in PATH)
  if ! command -v sliver &>/dev/null && ! command -v sliver-server &>/dev/null; then
    log "Running official Sliver installer (https://sliver.sh/install)..."
    if curl -fsSL https://sliver.sh/install | bash; then
      log "Official installer completed"
    else
      warn "Official installer failed or was interrupted – trying release download..."
    fi
  else
    info "Sliver binary already present on system"
  fi

  # Also stage copies / links inside WarMachine for the control TUI
  if command -v sliver &>/dev/null; then
    ln -sf "$(command -v sliver)" "${BIN_DIR}/sliver" 2>/dev/null || true
  fi
  if command -v sliver-server &>/dev/null; then
    ln -sf "$(command -v sliver-server)" "${BIN_DIR}/sliver-server" 2>/dev/null || true
  fi
  if command -v sliver-client &>/dev/null; then
    ln -sf "$(command -v sliver-client)" "${BIN_DIR}/sliver-client" 2>/dev/null || true
  fi

  # Fallback: download latest Linux assets from GitHub if still missing
  if ! command -v sliver &>/dev/null && ! [[ -x "${BIN_DIR}/sliver-server" ]]; then
    log "Attempting to fetch latest Sliver release assets..."
    local api="https://api.github.com/repos/BishopFox/sliver/releases/latest"
    local tmp
    tmp=$(mktemp -d)

    if command -v jq &>/dev/null; then
      local server_url client_url
      server_url=$(curl -fsSL "$api" | jq -r '.assets[] | select(.name | test("sliver-server_linux$")) | .browser_download_url' | head -1)
      client_url=$(curl -fsSL "$api" | jq -r '.assets[] | select(.name | test("sliver-client_linux$")) | .browser_download_url' | head -1)

      if [[ -n "$server_url" && "$server_url" != "null" ]]; then
        log "Downloading sliver-server..."
        curl -fsSL -o "${tmp}/sliver-server" "$server_url" && chmod +x "${tmp}/sliver-server"
        mv "${tmp}/sliver-server" "${BIN_DIR}/sliver-server"
        ln -sf "${BIN_DIR}/sliver-server" "${BIN_DIR}/sliver" 2>/dev/null || true
      fi
      if [[ -n "$client_url" && "$client_url" != "null" ]]; then
        log "Downloading sliver-client..."
        curl -fsSL -o "${tmp}/sliver-client" "$client_url" && chmod +x "${tmp}/sliver-client"
        mv "${tmp}/sliver-client" "${BIN_DIR}/sliver-client"
      fi
    else
      warn "jq not available – cannot auto-parse GitHub API. Install jq or use the official installer."
    fi
    rm -rf "$tmp"
  fi

  # Minimal helper scripts
  cat > "${BIN_DIR}/wm-sliver" << 'EOF'
#!/usr/bin/env bash
# WarMachine Sliver launcher – AUTHORIZED USE ONLY
echo "[!] Sliver is a C2 / adversary emulation framework."
echo "[!] Use only on systems you own or have explicit written authorization to test."
echo
if command -v sliver &>/dev/null; then
  exec sliver "$@"
elif [[ -x "$(dirname "$0")/sliver-server" ]]; then
  echo "Starting sliver-server (local mode)..."
  exec "$(dirname "$0")/sliver-server" "$@"
else
  echo "Sliver not found. Run installer option 14."
  exit 1
fi
EOF
  chmod +x "${BIN_DIR}/wm-sliver"

  cat > "${SLIVER_DIR}/README-AUTHORIZED-USE.txt" << 'EOF'
Sliver – BishopFox Adversary Emulation Framework
================================================

This tool is installed as part of the Hive SEC WarMachine workspace for
professional security research and AUTHORIZED red-team / adversary emulation.

LEGAL REQUIREMENTS
- You must have explicit written authorization before using Sliver against
  any system you do not own.
- Unauthorized access, deployment of implants, or C2 operations is a crime
  under applicable computer misuse and cybersecurity laws.
- You are solely responsible for compliance with all laws and engagement rules.

Documentation: https://sliver.sh/
Project:       https://github.com/BishopFox/sliver

Typical local start (after install):
  sliver
  # or
  sliver-server
  sliver-client
EOF

  if command -v sliver &>/dev/null || [[ -x "${BIN_DIR}/sliver-server" ]]; then
    log "Sliver is available"
    info "Launch via:  sliver   or   wm-sliver   or from the control TUI (Red Team menu)"
  else
    warn "Sliver installation may be incomplete. Re-run option 14 or install manually from https://sliver.sh/"
  fi

  log "Sliver (Red Team C2) setup finished – AUTHORIZED USE ONLY"
}

# ---------- Menu ----------
show_menu() {
  clear
  echo -e "${BLUE}"
  cat << 'EOF'
  _    _              __  __            _     _            
 | |  | |            |  \/  |          | |   (_)           
 | |  | | __ _ _ __  | \  / | __ _  ___| |__  _ _ __   ___ 
 | |/\| |/ _` | '__| | |\/| |/ _` |/ __| '_ \| | '_ \ / _ \
 \  /\  / (_| | |    | |  | | (_| | (__| | | | | | | |  __/
  \/  \/ \__,_|_|    |_|  |_|\__,_|\___|_| |_|_|_| |_|\___|
                                                           
  Hive SEC WarMachine  –  Fedora Ethical Hacking Workspace
  (Python 3 + Rust integrated)
EOF
  echo -e "${NC}"
  echo "Workspace: $WORKSPACE"
  echo "Python venv: $VENV_DIR"
  echo
  echo "Select categories to install (or 'all'):"
  echo
  echo "  0) Python Core Environment + high-value CLIs   ← recommended first"
  echo "  1) Footprinting / Recon"
  echo "  2) Network Tools"
  echo "  3) Enumeration"
  echo "  4) Vulnerability Analysis"
  echo "  5) System Hacking / Post-Exp"
  echo "  6) Web Application"
  echo "  7) Password Cracking + Wordlists"
  echo "  8) Wireless"
  echo "  9) Forensics"
  echo " 10) Social Engineering (auth only)"
  echo " 11) Malware Analysis"
  echo " 12) Extra / OSINT / Privacy"
  echo " 13) Rust Security Tools (rustscan, feroxbuster, sn0int…)"
  echo " 14) Sliver (Red Team C2 / Adversary Emulation)  ← AUTHORIZED ONLY"
  echo
  echo "  a) ALL of the above"
  echo "  q) Quit"
  echo
  read -rp "Choice: " choice
}

# ---------- Main ----------
main() {
  check_root
  create_workspace
  update_system

  # PATH helper (includes cargo + go + local)
  cat > /etc/profile.d/warmachine.sh << 'EOF'
export PATH="$PATH:$HOME/WarMachine/bin:/opt/WarMachine/bin:$HOME/go/bin:$HOME/.local/bin:$HOME/.cargo/bin"
export WAR_MACHINE="${HOME}/WarMachine"
[ -d /opt/WarMachine ] && export WAR_MACHINE="/opt/WarMachine"
EOF
  chmod 644 /etc/profile.d/warmachine.sh

  while true; do
    show_menu
    case "$choice" in
      0) install_python_core ;;
      1) install_recon ;;
      2) install_network ;;
      3) install_enumeration ;;
      4) install_vuln ;;
      5) install_system_hacking ;;
      6) install_web ;;
      7) install_password ;;
      8) install_wireless ;;
      9) install_forensics ;;
      10) install_social ;;
      11) install_malware_analysis ;;
      12) install_extra ;;
      13) install_rust_tools ;;
      14) install_sliver ;;
      a|A|all)
        install_python_core
        install_rust_tools
        install_recon
        install_network
        install_enumeration
        install_vuln
        install_system_hacking
        install_web
        install_password
        install_wireless
        install_forensics
        install_social
        install_malware_analysis
        install_extra
        install_sliver
        ;;
      q|Q) break ;;
      *) warn "Invalid choice" ;;
    esac
    echo
    read -rp "Press Enter to return to menu..."
  done

  # Final ownership fix
  if [[ -n "${SUDO_USER:-}" ]]; then
    chown -R "$SUDO_USER:$SUDO_USER" "$WORKSPACE" || true
  fi

  log "Installation finished. Workspace: $WORKSPACE"
  log "Python venv: $VENV_DIR"
  log "Rust tools:   ~/.cargo/bin  (rustscan, feroxbuster, sn0int…)"
  log "Sliver C2:    option 14  (AUTHORIZED red-team use only)"
  log "Activate Python:  source ${WORKSPACE}/activate"
  log "Or run:           ${BIN_DIR}/wm-python"
  log "Control TUI:      ${WORKSPACE}/wm-control   (or wm-control start)"
  log "Always obtain proper authorization before any testing."
  echo
  echo -e "${GREEN}WarMachine ready (Python 3 + Rust + Sliver). Stay ethical.${NC}"
}

main "$@"

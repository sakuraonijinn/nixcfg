# GUI hub. Internal 30G disk — no sdcard-store module here on purpose.
{ config, pkgs, lib, ... }:

{
  networking.hostName = "phone-lab";

  users.users.sakura = {
    isNormalUser = true;
    extraGroups = [
      "wheel" "networkmanager" "adbusers" "video" "input" "docker" "wireshark"
    ];
    shell = pkgs.bash;
    # Generate with: mkpasswd -m sha-512
    # Save the hash OUTSIDE the nix store: /etc/nixos/secrets/sakura.hash
    # (chmod 600, root-owned).
    hashedPasswordFile = "/etc/nixos/secrets/sakura.hash";
  };

  virtualisation.docker = {
    enable = true;
    # Docker images live outside the Nix store and aren't touched by
    # nix.gc — on a 30G disk they're the most likely thing to blow your
    # budget. Point at bigger/separate storage if you have it:
    # daemon.settings.data-root = "/mnt/bigger-disk/docker";
    # Otherwise: `docker system prune -af --volumes` regularly.
  };

  environment.systemPackages = with pkgs; [
    # ── Core Android / APK workflow ──
    apktool jadx apksigner android-tools jdk17
    frida-tools
    mitmproxy

    # ── Core recon ──
    nmap tcpdump

    bluez bluez-tools

    (python3.withPackages (p: with p; [
      frida-python androguard pwntools requests colorama rich
      scapy impacket pycryptodome paramiko beautifulsoup4 flask
    ]))

    # ── General utilities not already in common.nix ──
    neovim vim file binutils xxd zip p7zip
    bat eza fzf yq openssl screen tmux rsync usbutils pciutils
    distrobox crun

    (writeShellScriptBin "phone-lab-setup" ''
      mkdir -p "$HOME/.android" "$HOME/frida-scripts"
      if [ ! -f "$HOME/.android/debug.keystore" ]; then
        keytool -genkey -v -keystore "$HOME/.android/debug.keystore" \
          -alias androiddebugkey \
          -keyalg RSA -keysize 2048 -validity 10000 \
          -storepass android -keypass android \
          -dname "CN=,OU=,O=,L=,S=,C=" 2>/dev/null
        echo "[+] Debug keystore created at ~/.android/debug.keystore"
      fi
      echo "[+] frida-scripts dir ready at ~/frida-scripts — drop your own hook scripts there"
    '')
  ];

  environment.sessionVariables = {
    ANDROID_HOME = "$HOME/Android/Sdk";
    JAVA_HOME = "${pkgs.jdk17}/lib/openjdk";
  };

  environment.interactiveShellInit = ''
    apk-de() {
      if [ -z "$1" ]; then echo "Usage: apk-de <apk> [outdir]"; return 1; fi
      local out="''${2:-$(basename "$1" .apk)_src}"
      apktool d -f "$1" -o "$out"
      echo "[+] Decompiled → $out"
      (jadx-gui "$1" &>/dev/null &)
    }

    apk-re() {
      if [ -z "$1" ]; then echo "Usage: apk-re <decompiled_dir> [output.apk]"; return 1; fi
      local out="''${2:-modified.apk}"
      apktool b "$1" -o "$out" \
        && apksigner sign --ks "$HOME/.android/debug.keystore" \
          --ks-pass pass:android --ks-key-alias androiddebugkey \
          --key-pass pass:android "$out" \
        && apksigner verify --verbose "$out" \
        && echo "[+] Ready: $out"
    }

    apk-pull() {
      if [ -z "$1" ]; then echo "Usage: apk-pull <package.name>"; return 1; fi
      local pkg="$1"
      local path=$(adb shell pm path "$pkg" 2>/dev/null | cut -d: -f2)
      if [ -z "$path" ]; then echo "[-] Package $pkg not found"; return 1; fi
      adb pull "$path" "$pkg.apk" && echo "[+] Saved: $pkg.apk"
    }

    apk-install() {
      if [ -z "$1" ]; then echo "Usage: apk-install <patched.apk> [package]"; return 1; fi
      local pkg="$2"
      [ -n "$pkg" ] && adb uninstall "$pkg" 2>/dev/null
      adb install -r "$1"
    }

    frida-run() {
      if [ -z "$1" ] || [ -z "$2" ]; then echo "Usage: frida-run <package> <script.js>"; return 1; fi
      [ ! -f "$2" ] && echo "[-] Script not found: $2" && return 1
      frida -U -f "$1" -l "$2" --no-pause
    }

    proxy-on() {
      echo "[+] Starting mitmproxy on 8080..."
      mitmproxy --listen-port 8080 --showhost &
      sleep 1
      adb reverse tcp:8080 tcp:8080 2>/dev/null
      adb shell settings put global http_proxy 127.0.0.1:8080
      echo "[+] Proxy active — install mitm CA on device: http://mitm.it"
    }
    proxy-off() {
      adb shell settings put global http_proxy :0
      adb reverse --remove tcp:8080 2>/dev/null
      pkill mitmproxy 2>/dev/null
      echo "[+] Proxy stopped"
    }

    scan() {
      if [ -z "$1" ]; then echo "Usage: scan <target>"; return 1; fi
      sudo nmap -sV -sC -O "$1"
    }

    # Ephemeral shell for the heavy/occasional tools — not permanently
    # installed, eligible for GC as soon as you exit.
    pentest-shell() {
      echo "[+] Entering ephemeral shell with heavy pentest tools..."
      nix shell \
        nixpkgs#metasploit nixpkgs#hashcat nixpkgs#john nixpkgs#hydra \
        nixpkgs#sqlmap nixpkgs#nikto nixpkgs#gobuster nixpkgs#ffuf \
        nixpkgs#whatweb nixpkgs#bettercap nixpkgs#aircrack-ng \
        nixpkgs#wireshark nixpkgs#recon-ng nixpkgs#theharvester \
        nixpkgs#amass nixpkgs#subfinder nixpkgs#masscan nixpkgs#dnsrecon \
        nixpkgs#dex2jar nixpkgs#enjarify
    }

    cap() {
      if [ -z "$1" ]; then echo "Usage: cap <target-ip>"; return 1; fi
      sudo bettercap -eval "set arp.spoof.targets $1; arp.spoof on; net.sniff on"
    }
  '';
}

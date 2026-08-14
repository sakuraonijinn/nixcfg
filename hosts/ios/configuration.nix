# ios: iOS device connection/analysis box. Text-based, own dedicated sdcard.
{ config, pkgs, lib, ... }:

{
  networking.hostName = "iosbox";

  sdcardStore.uuid = "REPLACE-WITH-THIS-CARDS-UUID";

  users.users.ios = {
    isNormalUser = true;
    extraGroups = [ "wheel" "plugdev" "dialout" ];
    hashedPasswordFile = "/etc/nixos/secrets/ios.hash";
    openssh.authorizedKeys.keys = [
      # "ssh-ed25519 AAAA... your-key-comment"
    ];
  };
  users.groups.plugdev = {};

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  # NOTE: package names below are a starting point — confirm exact spelling
  # with `nix search nixpkgs <name>` before your first rebuild, nixpkgs
  # naming shifts occasionally for niche tooling like this.
  environment.systemPackages = with pkgs; [
    libimobiledevice   # idevice_id, ideviceinfo, idevicebackup2, etc.
    usbmuxd             # USB multiplexer daemon iOS device comms rely on
    ifuse                # mount an iOS device's filesystem via FUSE
    ideviceinstaller      # install/list/remove apps over USB
    libplist              # plist <-> xml/json conversion tools
    frida-tools
    sqlite
    exiftool
    python3
    unzip
  ];
}

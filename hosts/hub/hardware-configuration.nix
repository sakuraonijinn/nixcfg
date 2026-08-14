# PLACEHOLDER — replace this file with the real one for this machine:
#   sudo nixos-generate-config --show-hardware-config > hosts/hub/hardware-configuration.nix
# It defines root/boot/swap and CPU microcode — machine-specific, never
# hand-write it.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  # boot.initrd.availableKernelModules = [ ... ];
  # fileSystems."/" = { device = "/dev/disk/by-uuid/REPLACE-ME"; fsType = "ext4"; };
  # swapDevices = [ ];
}

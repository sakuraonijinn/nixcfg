# Running frp / ios / forensics as VMs on hub

The Nix side (`sdcardStore.uuid`, per-host packages) doesn't change —
a passed-through block device still shows up in the guest under
`/dev/disk/by-uuid/<uuid>` exactly like it would on bare metal, so
`modules/sdcard-store.nix` works unmodified. What's different is how the
card and any USB device (phone, MTK dongle, write-blocker) get into the
guest in the first place — that's a libvirt-level concern, not a NixOS
option.

## 1. Create the guest

Give each VM a small virtual disk for `/boot` + root (a few GB is enough —
`/nix/store` isn't going on it), and pass the physical sdcard straight
through as a second disk.

```
virt-install \
  --name frp \
  --memory 4096 --vcpus 2 \
  --disk size=8,path=/var/lib/libvirt/images/frp-root.qcow2 \
  --disk /dev/disk/by-id/usb-<your-sdcard-reader-id>,bus=virtio \
  --os-variant nixos-unstable \
  --network network=default \
  --graphics spice \
  --cdrom /path/to/nixos-minimal.iso
```

Find the card reader's stable id with `ls -l /dev/disk/by-id/ | grep usb`
rather than `/dev/sdX` — the letter can shift between boots.

Install NixOS on the small virtual disk as normal, get the guest's real
`hardware-configuration.nix` from inside it, drop it into
`hosts/<name>/hardware-configuration.nix`, then apply this flake's config
for that host as usual (`nixos-rebuild switch --flake .#frp`, run from
inside the guest, or copy the repo in).

## 2. Live-attach/detach the actual USB device

For the MTK dongle, phone, or card reader that needs to come and go (as
opposed to the sdcard disk, which stays attached permanently), use
`virsh attach-device` / `detach-device` rather than baking it into the
domain XML — this lets you unplug from the host and hand it to a
different guest without editing configs.

Find the device:
```
lsusb
# Bus 003 Device 012: ID 0e8d:0003 MediaTek Inc.
```

`usb-frp.xml`:
```xml
<hostdev mode='subsystem' type='usb'>
  <source>
    <vendor id='0x0e8d'/>
    <product id='0x0003'/>
  </source>
</hostdev>
```

Attach / detach:
```
virsh attach-device frp usb-frp.xml --live
virsh detach-device frp usb-frp.xml --live
```

Same pattern for the ios guest with the iPhone's vendor/product ID
(`0x05ac`), or a forensics write-blocker.

## 3. Permissions

The `frp` config's existing udev rule (vendor `0e8d` → `plugdev` group)
still matters — it applies *inside the guest* once the device is attached,
same as it would on bare metal. `virt-manager`'s Spice USB redirection
(enabled by `modules/libvirt-host.nix`) is an easier day-to-day option
than `virsh attach-device` if you're doing this interactively rather than
scripting it.

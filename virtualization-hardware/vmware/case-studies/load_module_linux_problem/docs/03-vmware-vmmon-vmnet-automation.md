# 03-vmware-vmmon-vmnet-automation

## Initial State

| Item | Value |
|---|---|
| Product | VMware® Workstation 17 Pro |
| Version | 17.6.2 build-24409262 |
| Linux Kernel | 6.8.0-138-generic (checked using `uname -r`, the unattended-upgrade for the Kernel update from 6.8.0-136-generic to 6.8.0-138-generic is available at virtualization-hardware/vmware/case-studies/load_module_linux_problem/logs/log_4.log ) |
| OS | Ubuntu 22.04.5 LTS (checked using `hostnamectl`) |



# Automating VMware Module Signing with a systemd Service and Bash Script

This solution ensures the vmmon/vmnet signing process runs silently in the background, keeping virtual machines highly available without requiring manual intervention after every kernel update.

## 1. Securely Store the MOK Keys

Move the signing key directory (containing `MOK.priv` and `MOK.der`) to `/root/module-signing/` to enforce maximum access control. Only the `root` user is permitted to access these files and execute the signing process.

```bash
sudo mv ~/module-signing /root/
sudo chown -R root:root /root/module-signing
sudo chmod 400 /root/module-signing/MOK.priv
```

## 2. Write the Auto-Sign Script

Create `/usr/local/bin/vmware-auto-sign.sh` and grant it execute permission (`chmod +x`):

```bash
#!/bin/bash
KERNEL_VER=$(uname -r)
MOK_PRIV="/root/module-signing/MOK.priv"
MOK_DER="/root/module-signing/MOK.der"

# If vmmon is not currently loaded, rebuild and re-sign the modules
if ! lsmod | grep -q vmmon; then
    vmware-modconfig --console --install-all

    /usr/src/linux-headers-$KERNEL_VER/scripts/sign-file sha256 $MOK_PRIV $MOK_DER $(modinfo -n vmmon)
    /usr/src/linux-headers-$KERNEL_VER/scripts/sign-file sha256 $MOK_PRIV $MOK_DER $(modinfo -n vmnet)

    depmod -a
    modprobe vmmon
    modprobe vmnet
    systemctl restart vmware
fi
```

```bash
sudo chmod +x /usr/local/bin/vmware-auto-sign.sh
```

**Logic:** the script only rebuilds and re-signs the modules when `vmmon` is not currently loaded — for example, right after a kernel upgrade produces a new, unsigned build. On a normal boot where the modules are already loaded and trusted, the script exits without taking any action.

## 3. Integrate with the Linux Boot Cycle

Create a systemd unit at `/etc/systemd/system/vmware-auto-sign.service` to trigger the script on every system startup:

```ini
[Unit]
Description=Auto-build and sign VMware modules on Kernel update
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vmware-auto-sign.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

**Configuration notes:**

- `Type=oneshot` — the service is expected to run once and exit, rather than remain running as a long-lived daemon.
- `RemainAfterExit=yes` — systemd continues to report the service as `active` after the script finishes, which is useful for dependency ordering and status checks.
- `After=network.target` — ensures the script runs only after basic networking is available, which `vmware-modconfig` and module loading may depend on.

## 4. Enable the Service

```bash
sudo systemctl daemon-reload
sudo systemctl enable vmware-auto-sign.service
```

From this point on, the signing process is a permanent part of the system's boot sequence and will run automatically on every startup.

## Advantages of This Architecture

- **Reduced operational overhead.** No more manually re-running the compilation command, hunting down `.ko` file paths, or having the working environment interrupted whenever a security patch silently updates the kernel.
- **Guaranteed independence from kernel updates.** This permanently resolves the virtualization hardware failure at its root. For backend applications running in containers that need direct interaction with the virtual network range — such as connecting into a VPN pod — the `vmnet` network layer remains stable and will not unexpectedly drop after a reboot.

For production use, the recommended approach is to rely on Ubuntu's native DKMS/MOK signing mechanism whenever possible; this automation serves as a practical workaround for my specific VMware setup.
Ref: https://manpages.ubuntu.com/manpages/noble/man8/dkms.8.html
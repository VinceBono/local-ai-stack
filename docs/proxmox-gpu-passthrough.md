# Giving a Proxmox VM an NVIDIA GPU

This is the short path to a VM that can run `compose.gpu.yaml`. It follows the [Proxmox PCI passthrough guide](https://pve.proxmox.com/wiki/PCI_Passthrough) and the [NVIDIA Container Toolkit install guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html). Read those when a step here doesn't match your hardware. The host loses the card while the VM runs, so don't pass through the only GPU of a machine you manage from its own screen.

## 1. Host: turn on IOMMU

Enable VT-d (Intel) or AMD-Vi/IOMMU (AMD) in the firmware setup. Then, on the Proxmox host:

```bash
# Intel only: add intel_iommu=on to the kernel command line. AMD has it on by default.
# GRUB:         edit GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub, then update-grub
# systemd-boot: edit /etc/kernel/cmdline, then proxmox-boot-tool refresh

printf 'vfio\nvfio_iommu_type1\nvfio_pci\n' >> /etc/modules
reboot
```

After the reboot, `dmesg | grep -e DMAR -e IOMMU` should show the IOMMU as enabled.

## 2. Host: keep its own drivers off the card

```bash
lspci -nn | grep -i nvidia          # note the IDs, for example 10de:1e84 and 10de:10f8
printf 'blacklist nouveau\nblacklist nvidia\nblacklist nvidiafb\n' > /etc/modprobe.d/blacklist-gpu.conf
echo 'options vfio-pci ids=10de:1e84,10de:10f8' > /etc/modprobe.d/vfio.conf   # your IDs, GPU and its audio device
update-initramfs -u -k all
reboot
```

`lspci -nnk` should now list `Kernel driver in use: vfio-pci` for the card.

## 3. VM: attach the card

Create the VM with machine type **q35** and BIOS **OVMF (UEFI)**, then add the card under Hardware → Add → PCI Device with "All Functions" and "PCI-Express" ticked. The command-line equivalent, for VM 100 and a card at address `01:00`:

```bash
qm set 100 --hostpci0 0000:01:00,pcie=1
```

Set the CPU type to `host`.

## 4. Guest: driver and container toolkit

Inside the VM (Ubuntu Server or Debian), install the NVIDIA driver from your distribution, install Docker, then install the NVIDIA Container Toolkit from the guide linked above and run:

```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
docker run --rm --gpus all ubuntu nvidia-smi    # should print your card
```

## 5. Start the stack with the GPU

```bash
docker compose -f compose.yaml -f compose.gpu.yaml up -d
docker compose exec ollama nvidia-smi
docker compose exec ollama ollama ps            # the PROCESSOR column should say GPU once a model is loaded
```

## If it doesn't work

- **The card shares an IOMMU group with other devices.** Move it to another slot. The ACS override patch works around it but weakens the isolation between devices.
- **`nvidia-smi` in the guest shows no devices.** Check that Secure Boot in the VM isn't blocking the unsigned driver module.
- **The VM won't start after attaching the card.** Look at `journalctl -b | grep -i vfio` on the host. The host is often still using the card for its console.

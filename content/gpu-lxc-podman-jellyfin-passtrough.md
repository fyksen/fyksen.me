+++
title = "Gpu lxc podman jellyfin passtrough"
date = 2023-08-28

[taxonomies]
tags = ["gpu", "proxmox", "jellyfin", "podman", "intel-ark"]
+++

I've had a lot of headache using Jellyfin without GPU transcoding, trying to direct-play everything. I finally bit the bullet and bought a Intel Arc a380 GPU to be able to transcode everything. My previous setup used Jellyfin inside of Podman. I want to continue using this setup. This way I do not need to go trough the process of migrating my Jellyfin users and settings to a new setup.

<!-- more -->

## Why LXC, and not a VM?

A couple of reasons:

* Disks on Proxmox perform better with Container mounts then with huge VM disks. I want to passtrough my video library as a separate zfs dataset to multiple LXC containers.
* If you passtrough a GPU to a VM, only that VM can use it. I want to make us of the GPU.

## How to notes:

* I used a Fedora LXC container for this, but it should work pretty simular for Debian or Ubuntu as well.
* I use Proxmox 8.
* I have a AMD APU (Ryzen 5650GE)
* I have a intel arc A 380 GPU.
* Have a look at [Jellyfin doc](https://jellyfin.org/docs/general/administration/hardware-acceleration/intel#arc-gpu-support) about ARC GPU.

#### Proxmox setup:

* Create a privileged container.
* Go to Options -> Features -> Tick Nesting, FUSE and Create Device Nodes.
* ssh into the `proxmox host` for the next few steps.
* We need to establish what the path to our GPU is. Run `lscpi | grep Arc`.
* Take note off the PCI number. In my case, this is `12:00.0`:

```
root@rack:~# lspci | grep Arc
12:00.0 VGA compatible controller: Intel Corporation DG2 [Arc A380] (rev 05)
```

* Now ne need to check where this PCI device is mounted. run `ls -la /dev/dri/by-path/ | grep 12:00`

```
root@rack:~# ls -la /dev/dri/by-path/ | grep 12:00
lrwxrwxrwx 1 root root   8 Aug 28 10:07 pci-0000:12:00.0-card -> ../card1
lrwxrwxrwx 1 root root  13 Aug 28 10:07 pci-0000:12:00.0-render -> ../renderD128
```

* My card is mounted as `/dev/dri/card1`, and `/dev/dri/renderD128`.
* We also need to check what group owns the /dev/dri files. run `ls -la /dev/dri`

```
root@rack:~# ls -la /dev/dri/
total 0
drwxr-xr-x  3 root root        160 Aug 28 10:07 .
drwxr-xr-x 18 root root       5040 Aug 28 10:07 ..
drwxr-xr-x  2 root root        140 Aug 28 10:07 by-path
crw-rw----  1 root video  226,   0 Aug 28 10:07 card0
crw-rw----  1 root video  226,   1 Aug 28 10:07 card1
crw-rw----  1 root video  226,   2 Aug 28 10:07 card2
crw-rw----  1 root render 226, 128 Aug 28 10:07 renderD128
crw-rw----  1 root render 226, 129 Aug 28 10:07 renderD129
```

* In my setup, `226` is the group that owns the cards.
* Now we need to map this into our container. My container have the ID 100, so my container config file is: `/etc/pve/lxc/100.conf`.
* Add the following at the end of the file. Please make sure to insert your owner, instead of 226:

```
# Allow C group:
lxc.cgroup2.devices.allow: c 226:* rwm

# Pass trough the files for the device:
lxc.mount.entry: /dev/dri/card1 dev/dri/card0 none bind,optional,create=file
lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file
```
* note that I passed trough host: `/dev/dri/card1` to  container: `dev/dri/card0`. This is to make it easier for the container. Most software expects the gpu to be on /dev/dri/card0. This way I do not have to specify this in Jellyfin settings later.

* Save the file, and start your container.

#### LXC setup:

* Install packages:
```
dnf install intel-gpu-tools podman
```

* Run `intel_gpu_top`, to check that you can access the GPU device.


* Run podman with passtrough of the gpu:

```
podman run  --name jellyfin-test -p 8096:8096 --device /dev/dri/card0:/dev/dri/card0 --device /dev/dri/renderD128:/dev/dri/renderD128 -v /root/jellyfin/config:/config -v /root/jellyfin/media/:/media/movies docker.io/jellyfin/jellyfin:latest
```

* Check the QSV and VA-API codecs inside container with: `podman exec -it jellyfin-test /usr/lib/jellyfin-ffmpeg/vainfo`
* Check OpenCL runtime status inside container: `podman exec -it jellyfin-test /usr/lib/jellyfin-ffmpeg/ffmpeg -v verbose -init_hw_device vaapi=va -init_hw_device opencl@va`
* Then login to your jellyfin `admin settings` -> `playback`. And tick the boxes ✅

![Jellyfin settings](/img/2023/intel-quicksync-podman-lxc-settings.png)

## I have not tested this for long, so this might not work as expected, we'll see.
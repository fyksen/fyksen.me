+++
title = "Immich import machine"
date = 2023-08-30

[taxonomies]
tags = ["immich", "usb", "photos", "selfhosting"]
+++

I have a Nikon Z 6 mirrorless camera. Im pretty happy with expect the lack of GPS. It really bugs me that I did not spend more money to remove  the headache of manually having to tag my photos with GPS (or use the Nikon app on my phone).

It also bugs me that there is no good way to automate wifi upload from Nikon cameras to a sftp or smb share. So I have to use a memory card or cable.

To make the process simpler, I created some scripts to automatically import photos to [Immich](https://github.com/immich-app/immich).

<!-- more -->

## What is the workflow?

* I have a server that have a XQC cardreader always installed in one of the USB 3 ports. 
* When someone plugs in a memory card, the machine checks what photos that are not imported, and imports them in photos divided by day.
* A webapp then shows the user the directories. The use can pick what subdirectories to import.
* If the user sets geolocation it gets the coordinates from address import, and checks that against Open Street map. The user then gets a map it can fine adjust the location on.
* The app then imports the photos to Immich.

## How do I set it up?

* The VM I'm using for this task is Alma Linux 9 on Proxmox 8.
* I have passtroughed the USB memory card reader to the VM in Proxmox.

![Proxmox screenshot](/static/img/2023/proxmox-usb-import.png)

* Boot the VM, and install:

```
sudo dnf install -y podman git
```

### Auto mount usb memory card

* Insert the memory card and run `blkid` to get the UUID of your memory card.

```
[fyksen@usb-import ~]$ sudo blkid
/dev/sr0: UUID="2023-08-30-13-58-07-00" LABEL="cidata" TYPE="iso9660"
/dev/sda4: UUID="280b97cf-dfc4-4d92-8670-aa43d13f5b51" TYPE="xfs" PARTLABEL="root" PARTUUID="5c70c77c-8e6b-48aa-b0a8-31766634f6a1"
/dev/sda2: SEC_TYPE="msdos" UUID="D33D-DD3C" TYPE="vfat" PARTLABEL="EFI System Partition" PARTUUID="9ae228c7-469f-46a9-938e-d05b6a544501"
/dev/sda3: UUID="c8d13f09-277f-4713-8459-f4ef6186360e" TYPE="xfs" PARTLABEL="boot" PARTUUID="d797ab0d-cc8d-49aa-8b6f-923c7fa148e3"
/dev/sdb1: LABEL="NIKON Z 6" UUID="56E6-55EA" TYPE="exfat"
/dev/sda1: PARTLABEL="biosboot" PARTUUID="571a83cc-9d0d-423b-b703-73ac811962ba"
```

* Mine is `56E6-55EA`
* Next we need to create the automount systemd .mount file

* Create the file `/etc/systemd/system/media-myusb.mount` and insert:

```
[Unit]
Description=Mount My USB Drive
BindsTo=dev-disk-by\x2duuid-56E6\x2d55EA.device
After=dev-disk-by\x2duuid-56E6\x2d55EA.device

[Mount]
What=UUID=56E6-55EA
Where=/media/myusb
Type=auto
Options=defaults,auto

[Install]
WantedBy=dev-disk-by\x2duuid-56E6\x2d55EA.device
```

* Okey, so this is a bit of a mess. The `BindsTo`, `After` and `WantedBy` strings does not support `-` so we need to use the URL-encoded form, that is `\x2d`. So `dev-disk-by-uuid-56E6-55EA` becomes `dev-disk-by\x2duuid-56E6\x2d55EA`. To use your UUID, simply change out `56E6\x2d55EA` with `XXXXx2dXXXX` where X is your UUID. This is a bit ugly, but it keeps us from having to mess with udev rules.

* Start and enable the service:

```
sudo systemctl daemon-reload
sudo systemctl enable --now media-myusb.mount
```

* Unplug the usb, and plug it back in to confirm that it automounts.

```
[root@usb-import ~]# df -h | grep /media
/dev/sdc1        56G   22G   35G  38% /media/myusb
```

### Import script

Firs off, what does it do?

* Creates a manifest file, to keep track off files that are already copied over.
* Extracts the photos modification date and create a target subdirectory for that date
* rsyncs over `.jpg`, `*.jpeg` files to the subdirectories.

* Create and configure the script. `/usr/local/bin/import-usb.sh`

```
#!/bin/bash

SOURCE="/media/myusb"
BASE_TARGET="/home/fyksen/import/photos/"
MANIFEST="/home/fyksen/import/import_manifest.txt"

# If manifest file doesn't exist, create it
touch "$MANIFEST"

# For each JPG, jpeg, and jpg file in SOURCE, check against manifest and copy if it's new
find "$SOURCE" -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) | while read -r file; do
    filename=$(basename "$file")
    
    if ! grep -q "^$filename$" "$MANIFEST"; then
        # Extract the file's modification date and create a target subdirectory for that date
        file_date=$(stat -c %y "$file" | cut -d ' ' -f1)
        TARGET="${BASE_TARGET}${file_date}/"
        mkdir -p "$TARGET"

        # Copy the file using rsync to preserve timestamps
        rsync -av --ignore-existing "$file" "$TARGET"
        
        # Add the filename to the manifest
        echo "$filename" >> "$MANIFEST"
    fi
done
```

* Make sure to specify the `SOURCE`, `BASE_TARGET` and `MANIFEST` targets. And create the directories.
* Remember to make it executable:

```
chmod +x /usr/local/bin/import-usb.sh
```

### Autostart import script after mount

To make the script automatically run every time you plug in the memory card, you need to create a .service file for it.

* create the file `/etc/systemd/system/import-usb.service` and import:

```
[Unit]
Description=Run import-usb.sh after USB is mounted
Requires=media-myusb.mount
After=media-myusb.mount

[Service]
ExecStart=/usr/local/bin/import-usb.sh
Type=oneshot
User=fyksen
Group=fyksen

[Install]
WantedBy=media-myusb.mount
```

* Make sure to change `User` and `Group`, so you own the files after the script is ran.
* Start and enable the .service file:

```
sudo systemctl enable --now import-usb.service
```

## Set up immich-geolocation-import

This is a python app hurdled together by me in half a day, so please use it at your own risk. With this out of the way, lets set it up!

* Clone the repo and build the container:

```
git clone https://github.com/fyksen/immich-geolocation-import
cd immich-geolocation-import/
podman build --tag immich-geolocation-import .
```

* This will take a bit, as it brings down the dependencies.
* Get your immich API key from the immich user interface.
* Run the container:

```
podman run -d --rm --name immich-geolocation-import \
-v /home/fyksen/import/photos/:/app/source:Z \
-p 8000:8000 \
-e API_KEY=YOU_IMMICH_API_KEY \
-e SERVER_URL=https://YOUR_IMMICH_INSTANSE.com \
-e SECRET_KEY=Just-some-text-to-make-flask-happy \
localhost/immich-geolocation-import:latest
```

* Note that the SECRET_KEY is just a key for the python webserver. Just gen a string for it.

### Auto run podman container when boot

We need to make the container run at startup.

* Set linger on your user, to make podman happy. Remember, I'm fyksen, you are not.

```
loginctl enable-linger fyksen
```

* Create systemd user folder:

```
cd
mkdir -p .config/systemd/user/
```

* Generate systemd .service file:

```
cd ~/.config/systemd/user/
podman generate systemd --new --files --name immich-geolocation-import
```

* Enable and start the .service file. Remember: no sudo this time:

```
systemctl --user enable --now container-immich-geolocation-import.service
```

# Testing the setup

This setup has pretty rough edges. It does not output much about it's progress, and it does not check if your HDD is big enough for the photos. There is however a couple of things you can check. It also takes about 10 seconds for the import to start after the site says "Photos imported successfully" 😅. 

* Visit `http://localhost:8000` and see if your directories are getting more files.
* Check the file `import_manifest.txt` with

```
tail -f ~/import/import_manifest.txt
```

Thanks for reading, happy photographing!

<iframe width="560" height="315" src="https://fyksen.me/img/2023/video-import.webm" frameborder="0" allowfullscreen></iframe>

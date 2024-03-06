+++
title = "VMware Horizon Client on Wayland"
date = 2024-03-01

[taxonomies]
tags = ["hotizon-viewer", "wayland"]
+++

Sometimes the field to input username and password on Vmware horizon client on Wayland is not visible. This is a known issue and the workaround is to use Xorg instead of Wayland. But I do not want to use Xorg, just to make this one appliaction work. So I found a workaround. Basically you need to set the username, password, rsa token and server address in the cli. Here is an example:

```bash
vmware-view -s <serveraddress> -t <username> -p <password> -n <desktopName> --singleAutoConnect -c <RSA token>
```

This is not a perfect solution, because it is a bit clunky.

<!-- more -->

## Creating a smoother experience

To make it a bit smoother, I created a script that uses environment variables to set the username, password, server address, desktop name. And then prompts the user for a RSA token. I used `zenity` to have the prompt use a GUI. Here is the script:

```bash
#!/bin/bash

# Prompt for input
input=$(zenity --entry --title="VMware View Launcher" --text="Enter input:")

# Check if input is empty
if [ -z "$input" ]; then
    zenity --error --title="Error" --text="Input cannot be empty."
    exit 1
fi

# Run the vmware-view command with the environment variables and the input
vmware-view -s $VMWARE_SERVER -t $VMWARE_USERNAME -p $VMWARE_PASSWORD -n $VMWARE_DESKTOP_NAME --singleAutoConnect -c "$input"
```

You can save this script to the path: `~/.local/bin/vmware`. Don't forget to `chmod +x` to make it executable.

You also need to set the environment variables in your `.bashrc` file. Here's an example:

```bash
## Setting vm-ware horizon variables:
export VMWARE_SERVER='desktop.serverlurl.com'
export VMWARE_USERNAME='username'
export VMWARE_PASSWORD='password'
export VMWARE_DESKTOP_NAME='desktop-name'
```

## Make a Launcher

You can also create a launcher for this script. Heres an example.

`Path: ~/.local/share/applications/vmware-custom-launcher.desktop`

```bash
[Desktop Entry]
Type=Application
Name=VMware Custom Launcher
Comment=Launch VMware with custom input
Icon=vmware-view
Exec=/path/to/your/vmware-launcher.sh
Terminal=false
Categories=Network;
```

Remember to update the path for Exec. Desktop shortcuts doesn't support environment variables, so you need to use the full path.

`protip`, you can delete the original .desktop file, to de-clutter your launcher. `sudo rm /usr/share/applications/vmware-view.desktop`

![Screenshot of the prompt](/img/2024/vmware-viewer.png)

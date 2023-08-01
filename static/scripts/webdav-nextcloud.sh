#!/bin/bash

# Function to display help text
show_help() {
    echo "Usage: $0 [--nextcloud_user=<user>] [--nextcloud_app_password=<password>] [--nextcloud_webdav_address=<address>] [--mount_point=<mount_point>]"
    echo "Options:"
    echo "  --nextcloud_user       Nextcloud User"
    echo "  --nextcloud_app_password Nextcloud App Password"
    echo "  --nextcloud_webdav_address Nextcloud WebDAV Address"
    echo "  --mount_point          Nextcloud Mount Point"
    exit 0
}

# Parse command-line arguments
for arg in "$@"; do
    case $arg in
        --nextcloud_user=*)
            nextcloud_user="${arg#*=}"
            ;;
        --nextcloud_app_password=*)
            nextcloud_app_password="${arg#*=}"
            ;;
        --nextcloud_webdav_address=*)
            nextcloud_webdav_address="${arg#*=}"
            ;;
        --mount_point=*)
            nextcloud_mount_point="${arg#*=}"
            ;;
        --help)
            show_help
            ;;
        *)
            echo "Error: Unknown option '$arg'. Use --help for usage."
            exit 1
            ;;
    esac
done

# Ask for user inputs if any argument was not provided
if [ -z "$nextcloud_user" ]; then
    read -p "Nextcloud User: " nextcloud_user
fi

if [ -z "$nextcloud_app_password" ]; then
    read -p "Nextcloud App Password: " nextcloud_app_password
fi

if [ -z "$nextcloud_webdav_address" ]; then
    read -p "Nextcloud WebDAV Address: " nextcloud_webdav_address
fi

if [ -z "$nextcloud_mount_point" ]; then
    read -p "Nextcloud Mount Point: " nextcloud_mount_point
fi

# Replace '/' with '-' in the mount point path
nextcloud_mount_point_file=${nextcloud_mount_point//\//-}

# Remove leading dash from mount point filename
if [[ ${nextcloud_mount_point_file:0:1} == "-" ]]; then
    nextcloud_mount_point_file=${nextcloud_mount_point_file:1}
fi

# Get the current user's username
current_user=$(whoami)

# Install davfs2 package
if command -v dnf &>/dev/null; then
    PKG_MANAGER="dnf"
elif command -v apt &>/dev/null; then
    PKG_MANAGER="apt"
else
    echo "Error: Unsupported package manager (dnf or apt is required)."
    exit 1
fi

sudo $PKG_MANAGER install -y davfs2

# Create the mount point
sudo mkdir -p "$nextcloud_mount_point"

# Add credentials to /etc/davfs2/secrets
echo -e "$nextcloud_mount_point $nextcloud_user $nextcloud_app_password" | sudo tee -a /etc/davfs2/secrets

# Create systemd mount unit file
cat <<EOF | sudo tee "/etc/systemd/system/$nextcloud_mount_point_file.mount"
[Unit]
Description=Nextcloud WebDAV Mount
Requires=network-online.target
After=network-online.target

[Mount]
What=$nextcloud_webdav_address
Where=$nextcloud_mount_point
Type=davfs
Options=noauto,user,uid=$current_user,gid=$current_user,rw,noatime

[Install]
WantedBy=multi-user.target
EOF

# Create systemd automount unit file
cat <<EOF | sudo tee "/etc/systemd/system/$nextcloud_mount_point_file.automount"
[Unit]
Description=Nextcloud WebDAV Automount
After=network-online.target
Wants=network-online.target

[Automount]
Where=$nextcloud_mount_point
TimeoutIdleSec=15

[Install]
WantedBy=remote-fs.target
EOF

# Enable and start the automount service
sudo systemctl enable "$nextcloud_mount_point_file.automount"
sudo systemctl start "$nextcloud_mount_point_file.automount"

# Output the changes made to the system
echo -e "\n \n"
echo "Nextcloud WebDAV automount service has been set up successfully."
echo "Summary of changes:"
echo "1. davfs2 package has been installed."
echo "2. Mount point directory created: $nextcloud_mount_point"
echo "3. Credentials added to /etc/davfs2/secrets"
echo "4. Systemd mount unit file created: /etc/systemd/system/$nextcloud_mount_point_file.mount"
echo "5. Systemd automount unit file created: /etc/systemd/system/$nextcloud_mount_point_file.automount"
echo "6. Automount service enabled and started."

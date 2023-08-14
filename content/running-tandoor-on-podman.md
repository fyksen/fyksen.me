+++
title = "Running tandoor on podman"
date = 2023-08-14

[taxonomies]
tags = ["tandoor", "podman", "selfhost"]
+++

I wanted to set up tandoor using podman-compose, but had some small problems.
I'm using the stock docker-compose file from the projects [doc](https://docs.tandoor.dev/install/docker/#plain) and podman running on Alma Linux 9 (EL9)

<!-- more -->

Lets get started.

## Pull down the files

```
# docker-compose.yml file
wget https://raw.githubusercontent.com/vabene1111/recipes/develop/docs/install/docker/plain/docker-compose.yml
# .env file:
wget https://raw.githubusercontent.com/vabene1111/recipes/develop/.env.template -O .env
```

## Changes in the files

### docker-compose.yml

I changed the nginx_recipes container to run on port 8088 instead of 80.
For systemd file sto work I also had to remove the `depends_on` section for web_recipes and nginx_recipes.


### .env

Set `POSTGRES_PASSWORD=` and `SECRET_KEY=`

## Pull and start

```
# Pull containers
docker-compose pull
# Start containers
docker-compose up -d
```

## Generate systemd files


```
# move into systemd user config files. Create folder if not available.
cd ~/.config/systemd/user/

# Generate systemd files
podman generate systemd --new --files --name tandoor_db_recipes_1 
podman generate systemd --new --files --name tandoor_nginx_recipes_1 
podman generate systemd --new --files --name tandoor_web_recipes_1 
```

## Stop podman-compose services

First `cd` back to directory where podman-compose is.
```
podman-compose stop
```

## Start systemd services

```
systemctl --user start container-tandoor_db_recipes_1.service
systemctl --user start container-tandoor_nginx_recipes_1.service
systemctl --user start container-tandoor_web_recipes_1.service
```

* Check that everything works as expected.

## Enable systemd services on boot

```
systemctl --user enable container-tandoor_db_recipes_1.service
systemctl --user enable container-tandoor_nginx_recipes_1.service
systemctl --user enable container-tandoor_web_recipes_1.service
```

# Backups

Make sure to backup you

* .env
* docker-compose.yml
* mediafiles dir.
* db

## Creating db backup

We need to dump the postgres database to take backup of it. This is how I did it.

### Create db dump script

Inside the directory that docker-compose.yml is in create file `pg_backup.sh`. Make this the content, and make sure to change the `BACKUP_DIR` path.

```
#!/bin/bash

TIMESTAMP=$(date +"%Y%m%d%H%M%S")
BACKUP_DIR="/your/dir"
CONTAINER_NAME="tandoor_db_recipes_1"

# Ensure backup directory exists
mkdir -p $BACKUP_DIR

# Backup
podman exec $CONTAINER_NAME pg_dumpall -U djangouser > $BACKUP_DIR/backup_$TIMESTAMP.sql

echo "Backup taken at $TIMESTAMP"
```
### Create folder for backup
Inside docker-compose dir, create a `backup` folder.

### Create systemd service and timer

Create the file `~/.config/systemd/user/backup-tandoor.service`, with the content following content: (make sure to change the ExecStart to your path).

```
[Unit]
Description=Backup PostgreSQL Database from Podman container

[Service]
Type=oneshot
ExecStart=/your/dir/pg_backup.sh
```

Create the file `~/.config/systemd/user/backup-tandoor.timer`, with the content:

```
[Unit]
Description=Run backup-tandoor.service daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

### Start systemd timer
Start and enable the unit files:

```
systemctl --user enable --now backup-tandoor.timer
```

# Make sure to have a good backup strategy for the directory

> That's it, go and cook some food.
+++
title = "Moving Pretix to containers"
date = 2023-07-11

[taxonomies]
tags = ["pretix", "podman", "containers", "linux"]
+++

A couple years ago I set up the fantastic software [pretix](https://pretix.eu/about/en/) for my track and field club. I set it up using this [guide](https://docs.pretix.eu/en/latest/admin/installation/manual_smallscale.html#requirements) from their docs. A couple years have gone by, and I want to move it to a container based setup using podman.

<!-- more -->

## Backing up the old setup

Lets start by taking the backup from the old setup.

### Postgres
Change user to postgres and take a dump of the database

```
su - postgres
pg_dumpall -f pretix_db_data
```

### Pretix data and settings

By default the data directory is located in `/var/pretix/data`, and the config is in `/etc/pretix/`. Backup those directories.

---

## Podman notes
* I want to run the containers as my user, aka rootless.
* I want to follow the [documentation](https://docs.pretix.eu/en/latest/admin/installation/docker_smallscale.html) from pretix as close as possible
* I already have a reverse proxy set up on this host.

### Podman setup

#### dir setup:
```
├── pretix-config
├── pretix-data
├── pretix-db
├── pretix-redis
└── sock
```

* Copy your pretix config file to `pretix-config`
* Data files to `pretix-data`

#### Podman network

* Create podman network

```
podman create network pretix
```

#### Postgres DB

* Create db container and import db backup

```
podman run --name pretix-db --rm -d \
-v /home/fyksen/pretix/pretix-db:/var/lib/postgresql/data:Z \
-e POSTGRES_PASSWORD=heehohkuh2Angeicoo9Kuenu  \
--network pretix \
docker.io/library/postgres:15
```

* cp in db backup file and restore from backup

```
podman cp pretix_db_data pretix-db:/pretix_db_data
podman exec -it pretix-db bash
su - postgres
psql -U postgres -f /pretix_db_data
```

* Add line to postgres config for pretix to connect trough network.
File is in: `/home/fyksen/pretix/pretix-db/pg_hba.conf`
Line to add:

```
host    pretix          pretix          0.0.0.0/0           md5
```

#### Redis

* Config file:
location: pretix-redis/redis.conf 

```
unixsocket /var/run/redis/redis.sock
unixsocketperm 777
```

* run container with:

```
podman run --rm --name pretix-redis \
--network pretix \
-v /home/fyksen/tickets.skvidar.run/pretix-redis/redis.conf:/usr/local/etc/redis/redis.conf:Z \
-v /home/fyksen/tickets.skvidar.run/sock:/var/run/redis:Z  \
docker.io/library/redis:7 redis-server /usr/local/etc/redis/redis.conf
```

#### Pretix-app

You need to make some changes to pretix.cfg:

```
[database]
backend=postgresql
name=pretix
user=pretix
; Replace with the password you chose above
password=YourDBPassword
; In most docker setups, 172.17.0.1 is the address of the docker host. Adjust
; this to wherever your database is running, e.g. the name of a linked container.
host=pretix-db

[redis]
location=unix:///var/run/redis/redis.sock?db=0
; Remove the following line if you are unsure about your redis' security
; to reduce impact if redis gets compromised.
sessions=true

[celery]
backend=redis+socket:///var/run/redis/redis.sock?virtual_host=1
broker=redis+socket:///var/run/redis/redis.sock?virtual_host=2

```

Then you'r ready to run the container:

```
podman run --name pretix-app --rm --network pretix \
-p 8345:80 \
-v /home/fyksen/tickets.skvidar.run/pretix-data:/data:Z \
-v /home/fyksen/tickets.skvidar.run/pretix-config:/etc/pretix:Z \
--sysctl net.core.somaxconn=4096 \
-v /home/fyksen/tickets.skvidar.run/sock:/var/run/redis:Z \
docker.io/pretix/standalone:stable all
```
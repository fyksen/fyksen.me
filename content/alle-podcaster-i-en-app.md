+++
title = "Få alle podcaster i en app"
date = 2024-03-25

[taxonomies]
tags = ["podcast", "nrk", "podme"]
+++

Det irriterer meg _grensesløst_ at Podcaster de siste årene sjeldnere blir lagt ut via RSS. Her er noen tips for å få flere av de i din favoritt app.

<!-- more -->

## Du trenger

* En Podcast app.
* En server. (for Podme), med docker eller podman.

## NRK

NRK er i mine øyne den største synderen. Det gjør meg vondt at skattepengene ikke går til åpne standarder. Heldigvis finnes det folk som er enige. Sindre Lindstad har laget den fantastiske tjenesten [sindrel.github.io/nrk-pod-feeds](https://sindrel.github.io/nrk-pod-feeds/). Her finner du rss lenker til alle NRK podcaster. Det er også verdt å se [videoen](https://vimeo.com/861697003) om hva hans motivasjon var for å lage den.

## Podme

Siden Podme ligger bak betalingsmur er det ingen som har laget en åpen nettside som man enkelt kan hente ut RSS. Det trengs en egen server. Heldigvis har [Mathias Oterhals Myklebust](https://oterbust.no/) laget en python app som henter ned episodene og genererer en RSS feed.

`docker-compose.yml`

```bash
services:
  pasjonsfrukt:
    container_name: pasjonsfrukt
    image: ghcr.io/mathiazom/pasjonsfrukt:schibsted-auth
    restart: unless-stopped
    #command: --host 0.0.0.0 --port 8000  # customize flags for 'api' startup command
    ports:
      - "8000:8000"
    volumes:
      # yield directory, where the podcasts are stored
      - ./yield:/app/yield
      # config, where config are stored
      - ./config.yaml:/app/config.yaml:ro
      # crontab, where scheduling are handled
      - ./crontab:/etc/cron.d/pasjonsfrukt-crontab:ro

```

Merk at denne compose filen tar utgangspunkt i at man bruker schibsted kontoen sin for innlogging, ikke Podme konto.

`config.yaml`

```bash
host: "https://podyou.yourdomain.com"
yield_dir: "/app/yield"
auth:
  email: "email-you-used-at-schibsted@email.com"
  password: "PasswordForAccount"
# Feeds: configure what podcast you want to fetch
podcasts:
  papaya:
    feed_name: "papaya"
  tore-og-haralds-podkast:
    feed_name: "tore-og-haralds-podcast"
  stopp-verden:
    feed_name: "stopp-verden"
  tusvik-tnne:
    feed_name: "tusvik-tnne"
    most_recent_episodes_limit: 20
#  gi-meg-alle-detaljene:
#  konspirasjonspodden:
```

`crontab`

```bash
# */30 8-21 * * * cd /app || exit 1; PATH=$PATH:/usr/local/bin pasjonsfrukt harvest >> /var/log/pasjonsfrukt.log 2>&1
* * * * * cd /app || exit 1; PATH=$PATH:/usr/local/bin pasjonsfrukt harvest >> /var/log/pasjonsfrukt.log 2>&1
# Empty line to please the cron gods ...
```

Etter en `docker compose up -d` vil du kunne nå f.eks http://serverip:8000/papaya, som er rss feeden du kan bruke i podcast appen din. Du kan peke en reverse proxy mot <ip>:8000 for å legge den bak proxy. Basic auth med nginx eller caddy funker fint.

## Patrion

Patrion gir ut rss til innhold. De generer RSS feeds pr bruker, sånn som Podme og NRK burde gjort.

## Har du tips?

Har du andre podcast-tjenester du har fått lurt inn i en RSS tjeneste? Skriv til meg på [fediverset](https://mastodon.fyksen.me/@fredrik).

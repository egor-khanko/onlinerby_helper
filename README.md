# OnlinerBy helper

Helps finding lowest prices for HDD in the onliner.by catalog.

### Run without docker
```sh
  USERS_TO_SEND=123,456 BOT_TOKEN=XXXXXXXXXX:XXX-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx ./app/watcher_bot.rb
```

### Run with docker:
1. Copy `docker-compose.yml.sample` to `docker-compose.yml` and change bot token and lost of users
```yml
environment:
  - BOT_TOKEN=XXXXXXXXXX:XXX-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  - USERS_TO_SEND=123,456
  - THRESHOLD=60
```
2. Run with docker
```sh
docker-compose up -d --no-deps --build worker
```

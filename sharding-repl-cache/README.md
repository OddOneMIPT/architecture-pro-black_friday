# sharding-repl-cache

Шардирование MongoDB с двумя шардами (replica set из трёх узлов в каждом) и кешированием через Redis.

## Архитектура

- `configSrv` — конфиг-сервер (replica set из одного узла), порт 27017
- `shard1-1`, `shard1-2`, `shard1-3` — replica set первого шарда, порт 27018
- `shard2-1`, `shard2-2`, `shard2-3` — replica set второго шарда, порт 27019
- `mongos` — маршрутизатор запросов, порт 27020
- `redis` — кеш Redis, порт 6379
- `pymongo_api` — приложение с включённым кешированием, порт 8080

## Как запустить

1. Запустить все сервисы:

```shell
docker compose up -d
```

2. Инициализировать replica set'ы, настроить шардирование и наполнить базу данными:

```shell
chmod +x scripts/mongo-init.sh
./scripts/mongo-init.sh
```

## Как проверить

Откройте в браузере: http://localhost:8080

В ответе должно быть:
- `mongo_topology_type: "Sharded"`
- `shards` с `shard1` и `shard2`
- `collections.helloDoc.documents_count >= 1000`
- `mongo_secondary_hosts` — список вторичных реплик
- `cache_enabled: true`

### Проверка кеширования

Эндпоинт `/helloDoc/users` кеширует результат на 60 секунд.
Первый вызов выполняется ~1 секунду (искусственная задержка в приложении + запрос к MongoDB).
Повторные вызовы в течение 60 секунд отдаются из Redis менее чем за 100 мс.

```shell
# Первый вызов — медленный (~1с)
time curl http://localhost:8080/helloDoc/users

# Второй вызов — быстрый (из кеша, <100мс)
time curl http://localhost:8080/helloDoc/users
```

## Шаги инициализации вручную

### 1. Инициализация replica set конфиг-сервера

```shell
docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [{ _id: 0, host: "configSrv:27017" }]
});
EOF
```

### 2. Инициализация replica set шарда shard1 (3 узла)

```shell
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1-1:27018" },
    { _id: 1, host: "shard1-2:27018" },
    { _id: 2, host: "shard1-3:27018" }
  ]
});
EOF
```

### 3. Инициализация replica set шарда shard2 (3 узла)

```shell
docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2-1:27019" },
    { _id: 1, host: "shard2-2:27019" },
    { _id: 2, host: "shard2-3:27019" }
  ]
});
EOF
```

### 4. Настройка шардирования

```shell
docker compose exec -T mongos mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018");
sh.addShard("shard2/shard2-1:27019,shard2-2:27019,shard2-3:27019");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name": "hashed" });
EOF
```

### 5. Наполнение данными

```shell
docker compose exec -T mongos mongosh --port 27020 --quiet <<EOF
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
db.helloDoc.countDocuments()
EOF
```

### 6. Проверка реплик и распределения

```shell
# Количество документов на shard1
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

# Количество документов на shard2
docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

# Статус replica set shard1
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.status().members.map(m => ({ name: m.name, state: m.stateStr }))
EOF

# Статус replica set shard2
docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
rs.status().members.map(m => ({ name: m.name, state: m.stateStr }))
EOF
```

# mongo-sharding

Шардирование MongoDB с двумя шардами и конфиг-сервером.

## Архитектура

- `configSrv` — конфиг-сервер (replica set из одного узла), порт 27017
- `shard1` — первый шард (replica set из одного узла), порт 27018
- `shard2` — второй шард (replica set из одного узла), порт 27019
- `mongos` — маршрутизатор запросов, порт 27020
- `pymongo_api` — приложение, порт 8080

## Как запустить

1. Запустить сервисы:

```shell
docker compose up -d
```

2. Инициализировать шардирование и наполнить базу данными:

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

Количество документов на каждом шарде:

```shell
# shard1
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

# shard2
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
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

### 2. Инициализация replica set шарда shard1

```shell
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1",
  members: [{ _id: 0, host: "shard1:27018" }]
});
EOF
```

### 3. Инициализация replica set шарда shard2

```shell
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id: "shard2",
  members: [{ _id: 0, host: "shard2:27019" }]
});
EOF
```

### 4. Настройка шардирования

```shell
docker compose exec -T mongos mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1:27018");
sh.addShard("shard2/shard2:27019");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name": "hashed" });
EOF
```

### 5. Наполнение данными и проверка распределения

```shell
docker compose exec -T mongos mongosh --port 27020 --quiet <<EOF
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
db.helloDoc.countDocuments()
EOF
```

Проверить количество документов на каждом шарде:

```shell
# shard1
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

# shard2
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

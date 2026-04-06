#!/bin/bash

echo "Ожидание запуска контейнеров MongoDB..."
sleep 15

echo "=== Инициализация replica set конфиг-сервера ==="
docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate(
  {
    _id: "config_server",
    configsvr: true,
    members: [{ _id: 0, host: "configSrv:27017" }]
  }
);
EOF

sleep 5

echo "=== Инициализация replica set шарда shard1 ==="
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate(
  {
    _id: "shard1",
    members: [{ _id: 0, host: "shard1:27018" }]
  }
);
EOF

sleep 2

echo "=== Инициализация replica set шарда shard2 ==="
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
rs.initiate(
  {
    _id: "shard2",
    members: [{ _id: 0, host: "shard2:27019" }]
  }
);
EOF

sleep 10

echo "=== Настройка шардирования через mongos ==="
docker compose exec -T mongos mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1:27018");
sh.addShard("shard2/shard2:27019");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name": "hashed" });
EOF

sleep 5

echo "=== Вставка 1000 документов ==="
docker compose exec -T mongos mongosh --port 27020 --quiet <<EOF
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
EOF

sleep 3

echo ""
echo "=== Общее количество документов в somedb.helloDoc ==="
docker compose exec -T mongos mongosh --port 27020 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo ""
echo "=== Количество документов на shard1 ==="
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo ""
echo "=== Количество документов на shard2 ==="
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

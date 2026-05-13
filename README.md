# «Мобильный мир» — Чёрная пятница: архитектура

Шардирование, репликация и кеширование MongoDB для высоконагруженного бэкенда интернет-магазина.

## Структура репозитория

| Директория / файл | Описание |
|---|---|
| `mongo-sharding/` | Задание 2 — шардирование с двумя шардами |
| `mongo-sharding-repl/` | Задание 3 — шардирование + replica set из трёх узлов на каждом шарде |
| `sharding-repl-cache/` | Задание 4 — шардирование + репликация + кеш Redis |
| `schemas.drawio` | Задания 1, 5, 6 — пять вариантов схем архитектуры |
| `architecture.md` | Задания 7–10 — архитектурный документ |

## Запуск финального стенда (sharding-repl-cache)

Директория `sharding-repl-cache` содержит итоговое решение заданий 2, 3 и 4: шардирование, репликация и кеширование.

### 1. Запустить все сервисы

```shell
cd sharding-repl-cache
docker compose up -d
```

### 2. Инициализировать MongoDB и наполнить данными

```shell
chmod +x scripts/mongo-init.sh
./scripts/mongo-init.sh
```

Скрипт выполняет следующие шаги:
- Инициализирует `configSrv` как replica set из одного узла
- Инициализирует `shard1` как replica set из трёх узлов (shard1-1, shard1-2, shard1-3)
- Инициализирует `shard2` как replica set из трёх узлов (shard2-1, shard2-2, shard2-3)
- Подключает шарды к маршрутизатору `mongos`
- Включает шардирование для базы `somedb` с хешированным ключом по полю `name` коллекции `helloDoc`
- Вставляет 1000 документов

### 3. Проверить работу

Откройте в браузере: http://localhost:8080

Ожидаемый ответ:
- `mongo_topology_type: "Sharded"`
- `shards` — список `shard1` и `shard2`
- `collections.helloDoc.documents_count >= 1000`
- `mongo_secondary_hosts` — вторичные реплики
- `cache_enabled: true`

### 4. Проверить кеширование

```shell
# Первый вызов — медленный 
time curl -s http://localhost:8080/helloDoc/users > /dev/null

# Второй вызов — быстрый (из Redis)
time curl -s http://localhost:8080/helloDoc/users > /dev/null
```

### 5. Проверить статус сервисов

```shell
docker compose ps
```

## Архитектурный документ

См. файл [`architecture.md`](architecture.md) — задания 7–10:
- Проектирование схем коллекций и выбор ключей шардирования (задание 7)
- Выявление и устранение «горячих» шардов (задание 8)
- Настройка чтения с реплик и консистентность (задание 9)
- Миграция на Cassandra (задание 10)

# nginx-prometheus-exporter

Репозиторий для быстрой установки nginx-prometheus-exporter.


## ENV

- `BIN_NAME` - имя бинарного файла (по умолчанию: nginx-prometheus-exporter)
- `BIN_PATH` - директория установки (по умолчанию: /etc/nginx-prometheus-exporter)
- `SERVICE_PORT` - порт для экспорта метрик (по умолчанию: 9113)
- `STUB_STATUS_PORT` - порт nginx stub_status (по умолчанию: 9114)
- `STUB_STATUS_PATH` - путь к конфигу nginx stub_status (по умолчанию: /etc/nginx/conf.d/stub_status.conf)
- `SERVICE_NAME` - имя systemd сервиса (по умолчанию: nginx-prometheus-exporter-9113)
- `USER` - пользователь для запуска сервиса (по умолчанию: nginx-prometheus-exporter)
- `GROUP` - группа для запуска сервиса (по умолчанию: nginx-prometheus-exporter)


## Установка

```bash
sudo ./install.sh
```

Скрипт автоматически:
- Создаёт пользователя и группу
- Копирует бинарный файл в `/etc/nginx-prometheus-exporter/`
- Создаёт конфигурацию NGINX stub_status в `/etc/nginx/conf.d/stub_status.conf`
- Тестирует и перезагружает NGINX
- Создаёт и запускает systemd сервис 

## Конфигурация Prometheus

```yml
scrape_configs:
  - job_name: 'nginx'
    static_configs:
      - targets: ['10.0.0.10:9113']

```


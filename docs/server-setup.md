# Конфигурация devops-vm (ПР №5–7)

## 1. Параметры машины
Parallels Desktop на macOS/Apple Silicon, Ubuntu Server 24.04.5 LTS arm64, 2 vCPU, 2 ГБ RAM, динамический диск 25 ГБ. Имя машины `devops-vm`. Сеть Shared (NAT) и Host-only. Это замена VirtualBox из методички для ARM-хоста.

## 2. Сетевые интерфейсы
`enp0s5`: 10.211.55.4/24 (Shared NAT); `enp0s6`: 10.37.129.3/24 (Host-only). С хоста сайт проверяется на Host-only адресе. В текущей macOS нет записи в `/etc/hosts`, поскольку её изменение требует пароля администратора; при проверке использовать `curl --resolve devops.local:443:10.37.129.3 --cacert ~/devops.crt https://devops.local/` либо внести `10.37.129.3 devops.local` в `/etc/hosts` и затем использовать команды методички без `--resolve`.

## 3. Доступ по SSH
На VM порт 2222. На хосте `~/.ssh/config`: псевдоним `devops`, адрес 10.211.55.4, порт 2222, пользователь devops, ключ `~/.ssh/devops_vm`, `IdentitiesOnly yes`. Отдельный псевдоним `devops.local` направлен на Host-only IP. Парольный вход и root запрещены. Ключ сервера: SHA256:pnRv6Nnc35bBOATjK2o9bzlhREsBg0kKJ9TUIz98fiQ. Снимки: `01-clean-install`, `02-keys-configured`, `03-ssh-hardened`.

## 4. Учётные записи
`student` — установочный пользователь; `devops` — администратор с группой sudo. Доступ по отдельному Ed25519-ключу; `~/.ssh` имеет режим 700, `authorized_keys` — 600. Пароль и закрытый ключ хранятся только на соответствующих машинах, в репозиторий не включаются.

## 5. Служба SSH
Исходный `/etc/ssh/sshd_config` сохранён как `/etc/ssh/sshd_config.backup`. Дополняющий файл `/etc/ssh/sshd_config.d/99-hardening.conf`: Port 2222, PermitRootLogin no, PasswordAuthentication no, PubkeyAuthentication yes, PermitEmptyPasswords no, MaxAuthTries 3, LoginGraceTime 30, AllowUsers devops, X11Forwarding no, ClientAliveInterval 300, ClientAliveCountMax 2. В более раннем `50-cloud-init.conf` закомментирована конфликтующая строка `PasswordAuthentication yes`. `ssh.socket` отключён, `ssh.service` включён. Перед применением проверены `sshd -t` и `sshd -T`; новый вход проверен до завершения действующего сеанса.

## 6. Межсетевой экран и имя
UFW: deny incoming, allow outgoing; 80/tcp и 443/tcp ALLOW, 2222/tcp LIMIT; logging medium. Блокировка порта 8080 подтверждена записью `UFW BLOCK`. FQDN VM: `devops-vm.devops.local` через запись `127.0.1.1` в `/etc/hosts` VM. Частые SSH-подключения могут временно попасть под LIMIT.

## 7. Восстановление
Снимки Parallels после выключения VM: `01-clean-install` (установка), `02-keys-configured` (ключ), `03-ssh-hardened` (SSH). При откате к 01 повторить создание devops, установку публичного ключа, SSH и UFW. Закрытый ключ на VM не переносить. Сверить ключ хоста после отката.

## 8. Веб-сервер
Пакеты `nginx` и `rsync`. Конфигурация `/etc/nginx/sites-available/devops-site`, ссылка в `sites-enabled`; ссылка `default` удалена. Каталог `/var/www/devops-site` принадлежит `devops:devops`, режим каталогов 755, файлов 644. Контент синхронизируется через `scripts/deploy.sh` и rsync 3.5.1 на macOS (`/opt/homebrew/bin/rsync`), с `--delete --chmod=D755,F644`.

Самоподписанный сертификат `/etc/ssl/certs/devops.crt` имеет режим 644; ключ `/etc/ssl/private/devops.key` принадлежит root и имеет режим 600. Создан командой `openssl req -x509 -nodes -days 365 -newkey rsa:2048 -subj '/CN=devops.local' -addext 'subjectAltName=DNS:devops.local'`. Действует 23.10.2026–23.10.2027. Только сертификат скопирован на хост в `~/devops.crt`. HTTP перенаправляется кодом 301 на HTTPS; TLSv1.2/1.3. Журналы ресурса: `/var/log/nginx/devops-site.access.log` и `.error.log`. Применение конфигурации: `sudo nginx -t && sudo systemctl reload nginx`. Снимок: `04-nginx-https`.

## 9. Контейнеризация
Docker Engine 29.9.2 и Compose v5.6.1 установлены из официального apt-репозитория Docker для Ubuntu 24.04 arm64; инструкция зафиксирована в `scripts/install-docker.sh`. В группе `docker` — пользователь `devops` (членство фактически даёт привилегии уровня root, поэтому посторонние пользователи не добавляются).

Проект расположен в `/home/devops/app`, исходники синхронизируются из `app/` репозитория командой `rsync -avz --delete --exclude=.env app/ devops:app/`. Секретный `/home/devops/app/.env` создан только на VM случайным паролем, права 600; в Git хранится лишь `.env.example`, а `.env` исключён из Git и контекста Docker. Dockerfile использует `python:3.12-slim`, устанавливает зависимости до копирования исходного кода и запускает Gunicorn от системного пользователя `app`.

Сервисы Compose: `app` и `db` (`postgres:16-alpine`). Оба соединены через изолированную сеть `app_backend`; встроенный DNS разрешает имя `db`. Данные PostgreSQL хранятся в именованном томе `app_db_data`. Приложение опубликовано исключительно на `127.0.0.1:5000`, PostgreSQL не опубликован. Проверка `pg_isready` обеспечивает запуск приложения после готовности БД. Для доступа извне Nginx на HTTPS 443 проксирует `/app/` в `http://127.0.0.1:5000/` (конфигурация `config/devops-site`); статический сайт `/` остаётся доступным. Порт 5001 публиковался на всех адресах только в учебном опыте обхода UFW и был сразу закрыт.

Снимок `05-docker-compose` создан после проверки приложения и тома, до добавления Nginx-прокси. Для диагностики выполнить `docker compose ps`, `docker compose logs app db`, `sudo tail /var/log/nginx/devops-site.error.log`. Не применять `docker compose down -v` к данным, которые требуется сохранить.

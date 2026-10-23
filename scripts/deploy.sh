#!/usr/bin/env bash
set -euo pipefail
fail() { echo "Ошибка: $*" >&2; exit 1; }
DRY_RUN=false
case "${1:-}" in
    '') [[ $# -eq 0 ]] || fail 'Допустим только --dry-run' ;;
    --dry-run) [[ $# -eq 1 ]] || fail 'Лишние аргументы'; DRY_RUN=true ;;
    *) fail 'Использование: scripts/deploy.sh [--dry-run]' ;;
esac
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel) || fail 'Нет репозитория'
RSYNC_BIN=${DEVOPS_RSYNC_BIN:-/opt/homebrew/bin/rsync}
REMOTE=devops
REMOTE_DIR=/var/www/devops-site
SITE_URL=https://devops.local
SITE_IP=${DEVOPS_SITE_IP:-10.37.129.3}
CA_CERT="${DEVOPS_CA_CERT:-${HOME}/devops.crt}"
LOCAL_DIR="$ROOT/site/"
[[ -f "${LOCAL_DIR}index.html" ]] || fail 'Отсутствует site/index.html'
status=$(git -C "$ROOT" status --porcelain --untracked-files=all) || exit 1
[[ -z "$status" ]] || fail 'Есть незафиксированные изменения'
commit=$(git -C "$ROOT" rev-parse --short HEAD) || exit 1
if ! $DRY_RUN; then
    [[ -r "$CA_CERT" ]] || fail 'Недоступен доверенный devops.crt'
fi
args=(-avz --delete --chmod=D755,F644)
$DRY_RUN && args+=(--dry-run)
# Единственное SSH-соединение открывает rsync. Проверка идёт по HTTPS.
if ! "$RSYNC_BIN" "${args[@]}" \
    -e 'ssh -o BatchMode=yes -o ConnectTimeout=5' \
    "$LOCAL_DIR" "$REMOTE:$REMOTE_DIR/"; then
    fail 'Синхронизация не выполнена'
fi
if $DRY_RUN; then
    echo "План доставки коммита $commit; сервер не изменён"
    exit 0
fi
curl --fail --silent --show-error --connect-timeout 5 --max-time 20 \
    --noproxy "*" --resolve "devops.local:443:$SITE_IP" \
    --cacert "$CA_CERT" "$SITE_URL/" >/dev/null || fail 'HTTPS-проверка не пройдена'
echo "Доставлен коммит $commit"

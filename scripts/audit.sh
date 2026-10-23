#!/usr/bin/env bash
# Запускать на Ubuntu VM от пользователя devops.
set -uo pipefail
export LC_ALL=C
PASS=0; FAIL=0
check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "  [OK] $desc"; ((PASS+=1))
    else
        echo "  [FAIL] $desc (expected=$expected, actual=$actual)"
        ((FAIL+=1))
    fi
}
sudo -v || exit 1
sshd_cfg=$(sudo /usr/sbin/sshd -T) || exit 1
ufw_cfg=$(sudo ufw status verbose) || exit 1
field() { awk -v key="$1" '$1==key {print $2}' <<< "$sshd_cfg"; }
echo "Аудит: $(hostname -f), $(date '+%F %R')"
echo '[1] Служба SSH'
check 'Вход root запрещён' no "$(field permitrootlogin)"
check 'Парольная аутентификация отключена' no \
    "$(field passwordauthentication)"
port_ok=no
ports=$(field port)
if [[ -n "$ports" ]] && ! grep -qx 22 <<< "$ports"; then
    port_ok=yes
fi
check 'Все порты SSH отличаются от 22' yes "$port_ok"
check 'MaxAuthTries равен 3' 3 "$(field maxauthtries)"
echo '[2] Межсетевой экран'
check 'UFW активен' active "$(awk '/^Status:/{print $2}' <<< "$ufw_cfg")"
check 'Входящая политика deny' deny \
    "$(sed -n 's/^Default: \([^ ]*\) (incoming).*/\1/p' <<< "$ufw_cfg")"
echo '[3] Учётные записи'
awk -F: '$3>=1000 && $3<65534 {printf "  %s (uid=%s)\n",$1,$3}' /etc/passwd
echo '[4] Веб-сервер'
check 'Nginx активен' active "$(systemctl is-active nginx 2>/dev/null)"
sudo nginx -t >/dev/null 2>&1; nginx_rc=$?
check 'Синтаксис Nginx корректен' 0 "$nginx_rc"
# Для отрицательного опыта: CERT_MIN_SECONDS=40000000 bash scripts/audit.sh
min_seconds=${CERT_MIN_SECONDS:-2592000}
openssl x509 -in /etc/ssl/certs/devops.crt -noout \
    -checkend "$min_seconds" >/dev/null 2>&1; cert_rc=$?
check 'Сертификат действует дольше заданного порога' 0 "$cert_rc"
permissions_ok=no
if writable=$(find /var/www/devops-site -perm -o+w -print) &&
   key_mode=$(sudo stat -c '%a' /etc/ssl/private/devops.key) &&
   [[ -z "$writable" && "$key_mode" == 600 ]]; then
    permissions_ok=yes
fi
check 'Нет записи для всех, ключ 600' yes "$permissions_ok"
echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

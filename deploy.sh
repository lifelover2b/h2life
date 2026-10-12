#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo 'Запустите установку через sudo bash deploy.sh'
    exit 1
fi

repo_ref=${H2LIFE_REF:-main}
download_url="https://raw.githubusercontent.com/lifelover2b/h2life/$repo_ref/index.html"
stage=$(mktemp)
trap 'rm -f "$stage"' EXIT

curl --fail --location --retry 3 --connect-timeout 15 --max-time 120 \
    "$download_url" -o "$stage"
python3 - "$stage" <<'PY'
import sys
from pathlib import Path
from html.parser import HTMLParser
text=Path(sys.argv[1]).read_text(encoding='utf-8')
assert '<!doctype html>' in text.lower(), 'Файл не похож на HTML'
assert '<title>H2Life' in text, 'Неверное название сайта'
assert 'data:image/jpeg;base64,' in text, 'Нет встроенных фотографий'
HTMLParser().feed(text)
PY

mkdir -p /var/www/html /var/backups/h2life
if [ -e /var/www/html/index.html ]; then
    cp -a /var/www/html/index.html "/var/backups/h2life/index-$(date +%Y%m%d-%H%M%S).html"
fi
# Rename в том же каталоге атомарно заменяет страницу.
install -m 0644 "$stage" /var/www/html/.h2life-index.new
mv -f /var/www/html/.h2life-index.new /var/www/html/index.html
echo 'Сайт установлен: https://h2life.tech'
echo 'Конфигурация Nginx и Telemt не изменялась.'

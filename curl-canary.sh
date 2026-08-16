#!/usr/bin/env bash
# Helper de testes de tráfego pro Ingress do curso (Aulas 07, 08, 09 e 12) —
# substitui digitar as funções curl_dev/curl_active/curl_abtest e o
# `while true; do curl ...; done &` na mão a cada vez.
#
# Resolve o host localmente via --resolve, sem precisar editar /etc/hosts
# (mesmo truque ensinado na Aula 07).
#
# Uso:
#   scripts/curl-canary.sh once            # 1 request: X-App-Version + pod
#   scripts/curl-canary.sh header          # força canary via header
#   scripts/curl-canary.sh cookie          # força canary via cookie (A/B, Aula 12)
#   scripts/curl-canary.sh loop [N]        # N requests (default 20), conta por versão
#   scripts/curl-canary.sh traffic start   # gerador contínuo em background
#   scripts/curl-canary.sh traffic stop    # para o gerador
#
# Variáveis de ambiente (todas opcionais, com o default da Aula 07):
#   HOST          host do Ingress            (default: dev.demo-app.local)
#   IP            endereço que --resolve usa  (default: 127.0.0.1)
#   PORT          porta                       (default: 80)
#   HEADER_VALUE  valor do X-Canary no modo "header" (default: always)
#                 — use HEADER_VALUE=true pro A/B testing da Aula 12
#   URL           se definida, ignora HOST/IP/PORT/--resolve e usa essa URL
#                 direto — pro preview do blue-green (Aula 08), que já é
#                 acessado via port-forward, sem host público nenhum
#
# Exemplos:
#   scripts/curl-canary.sh once
#   HOST=demo-app-ab-test.local HEADER_VALUE=true scripts/curl-canary.sh header
#   URL=http://localhost:8081/ scripts/curl-canary.sh once      # preview, Aula 08
#   scripts/curl-canary.sh traffic start && scripts/curl-canary.sh loop 20 && scripts/curl-canary.sh traffic stop

set -euo pipefail

HOST="${HOST:-dev.demo-app.local}"
IP="${IP:-127.0.0.1}"
PORT="${PORT:-80}"
HEADER_VALUE="${HEADER_VALUE:-always}"
# Chave do PID file inclui a URL quando ela existe, senão dois "traffic
# start" (um pro Ingress, outro pro preview via URL=) se atropelariam
PIDFILE="/tmp/curl-canary-traffic-$(echo "${URL:-$HOST}" | tr -c 'A-Za-z0-9' '-').pid"

_curl() {
  if [ -n "${URL:-}" ]; then
    curl -s "$@" "$URL"
  else
    curl -s "$@" --resolve "${HOST}:${PORT}:${IP}" "http://${HOST}:${PORT}/"
  fi
}

usage() {
  echo "Uso: $0 {once|header|cookie|loop [N]|traffic start|traffic stop}" >&2
  echo "Host atual: ${HOST} (mude com HOST=...)" >&2
  exit 1
}

cmd="${1:-}"
[ -n "$cmd" ] && shift || true

case "$cmd" in
  once)
    body="$(mktemp)"
    _curl -D - -o "$body" | grep -i '^x-app-version:'
    grep -o '<code>[^<]*</code>' "$body" || echo "(pod não encontrado no HTML)"
    rm -f "$body"
    ;;

  header)
    _curl -H "X-Canary: ${HEADER_VALUE}" -D - -o /dev/null | grep -i '^x-app-version:'
    ;;

  cookie)
    _curl -b "canary=always" -D - -o /dev/null | grep -i '^x-app-version:'
    ;;

  loop)
    n="${1:-20}"
    for _ in $(seq 1 "$n"); do
      _curl -D - -o /dev/null | grep -i '^x-app-version:'
    done | sort | uniq -c
    ;;

  traffic)
    sub="${1:-start}"
    case "$sub" in
      start)
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
          echo "Já rodando pra ${HOST} (PID $(cat "$PIDFILE"))." >&2
          exit 0
        fi
        ( while true; do _curl -o /dev/null || true; sleep 1; done ) &
        disown
        echo $! > "$PIDFILE"
        echo "Gerador rodando em background pra ${HOST} (PID $!)." >&2
        echo "Pare com: $0 traffic stop" >&2
        ;;
      stop)
        if [ -f "$PIDFILE" ]; then
          kill "$(cat "$PIDFILE")" 2>/dev/null || true
          rm -f "$PIDFILE"
          echo "Parado." >&2
        else
          echo "Nada rodando pra ${HOST}." >&2
        fi
        ;;
      *)
        usage
        ;;
    esac
    ;;

  *)
    usage
    ;;
esac

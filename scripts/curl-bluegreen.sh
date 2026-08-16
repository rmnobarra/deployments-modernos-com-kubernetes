#!/usr/bin/env bash
# Helper de testes de tráfego pro blue-green do curso (Aulas 08 e 09).
#
# Diferente do canary (scripts/curl-canary.sh): aqui não tem peso pra
# provar com "loop", nem header pra forçar rota — o active serve 100% de
# uma versão só o tempo todo, e o preview só existe via port-forward, nunca
# com host público (senão qualquer um veria a versão ainda não promovida).
#
# Uso:
#   scripts/curl-bluegreen.sh active           # 1 request no Ingress público (usuário real)
#   scripts/curl-bluegreen.sh preview          # 1 request no preview via port-forward
#   scripts/curl-bluegreen.sh traffic start    # gerador contínuo no active, em background
#   scripts/curl-bluegreen.sh traffic stop     # para o gerador
#
# Variáveis de ambiente (todas opcionais, com o default da Aula 07/08):
#   HOST          host do Ingress active         (default: dev.demo-app.local)
#   IP            endereço que --resolve usa      (default: 127.0.0.1)
#   PORT          porta do Ingress                (default: 80)
#   PREVIEW_URL   endereço do preview via port-forward (default: http://localhost:8081/)
#
# Exemplos:
#   scripts/curl-bluegreen.sh active
#   kubectl port-forward svc/dev-demo-app-preview 8081:80 -n dev &
#   scripts/curl-bluegreen.sh preview
#   scripts/curl-bluegreen.sh traffic start && kubectl argo rollouts promote dev-demo-app

set -euo pipefail

HOST="${HOST:-dev.demo-app.local}"
IP="${IP:-127.0.0.1}"
PORT="${PORT:-80}"
PREVIEW_URL="${PREVIEW_URL:-http://localhost:8081/}"
PIDFILE="/tmp/curl-bluegreen-traffic-$(echo "$HOST" | tr -c 'A-Za-z0-9' '-').pid"

_show() {
  body="$(mktemp)"
  curl -s "$@" -D - -o "$body" | grep -i '^x-app-version:'
  grep -o '<code>[^<]*</code>' "$body" || echo "(pod não encontrado no HTML)"
  rm -f "$body"
}

usage() {
  echo "Uso: $0 {active|preview|traffic start|traffic stop}" >&2
  echo "Host atual: ${HOST} (mude com HOST=...)" >&2
  exit 1
}

cmd="${1:-}"
[ -n "$cmd" ] && shift || true

case "$cmd" in
  active)
    _show --resolve "${HOST}:${PORT}:${IP}" "http://${HOST}:${PORT}/"
    ;;

  preview)
    _show "$PREVIEW_URL"
    ;;

  traffic)
    sub="${1:-start}"
    case "$sub" in
      start)
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
          echo "Já rodando pra ${HOST} (PID $(cat "$PIDFILE"))." >&2
          exit 0
        fi
        ( while true; do curl -s -o /dev/null --resolve "${HOST}:${PORT}:${IP}" "http://${HOST}:${PORT}/" || true; sleep 1; done ) &
        disown
        echo $! > "$PIDFILE"
        echo "Gerador rodando em background pro active, ${HOST} (PID $!)." >&2
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

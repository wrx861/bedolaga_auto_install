#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=preflight.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/preflight.sh"
# shellcheck source=host-bootstrap.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/host-bootstrap.sh"
# shellcheck source=questions.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/questions.sh"
# shellcheck source=render.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/render.sh"
# shellcheck source=deploy.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/deploy.sh"
# shellcheck source=repos.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/repos.sh"
# shellcheck source=materialize.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/materialize.sh"
# shellcheck source=verify.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/verify.sh"
# shellcheck source=runtime-actions.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/runtime-actions.sh"
# shellcheck source=pipeline.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/pipeline.sh"
# shellcheck source=deploy-runtime.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/deploy-runtime.sh"

mode_label() {
  case "${1:-}" in
    bot-only) printf '%s' 'Только бот' ;;
    cabinet-only) printf '%s' 'Только кабина' ;;
    bot+cabinet) printf '%s' 'Бот + Кабина' ;;
    *) printf '%s' 'Не выбран' ;;
  esac
}

show_plan() {
  load_state
  section "Текущее состояние"

  local bot_root=""
  local cabinet_root=""
  local remnawave_root="${EXISTING_REMNAWAVE_DIR:-}"
  local bot_state="не найден"
  local cabinet_state="не найден"
  local remnawave_state="не найден"
  local proxy_state="${PROXY_MODE:-не найден}"

  bot_root="$(resolve_bot_root 2>/dev/null || true)"
  cabinet_root="$(resolve_cabinet_root 2>/dev/null || true)"

  if [[ -z "$remnawave_root" ]]; then
    remnawave_root="$(detect_existing_remnawave_root 2>/dev/null || true)"
  fi

  [[ -n "$bot_root" ]] && bot_state="$bot_root"
  [[ -n "$cabinet_root" ]] && cabinet_state="$cabinet_root"
  [[ -n "$remnawave_root" ]] && remnawave_state="$remnawave_root"

  print_card "Текущее состояние" \
    "Режим      $(mode_label "${INSTALL_MODE:-}")" \
    "Бот        ${bot_state}" \
    "Кабинет    ${cabinet_state}" \
    "Прокси     ${proxy_state}" \
    "Remnawave  ${remnawave_state}"
}

auto_prepare_host() {
  section "Подготовка сервера"
  local prep_log
  prep_log="$(mktemp)"

  if run_preflight >"$prep_log" 2>&1 && run_host_bootstrap >>"$prep_log" 2>&1; then
    ok "Сервер проверен"
    ok "Docker, git, curl и базовые зависимости готовы"
    ok "Можно запускать установку"
    rm -f "$prep_log"
    return 0
  fi

  warn "Автоподготовка завершилась с ошибкой"
  warn "Показываю последние строки журнала:"
  tail -n 20 "$prep_log" | sed 's/^/  /'
  rm -f "$prep_log"
  return 1
}

run_mode_flow() {
  local mode="$1"
  collect_common_answers "$mode" "bedolaga-stack"

  case "$mode" in
    bot-only)
      collect_bot_answers
      ;;
    cabinet-only)
      collect_cabinet_answers
      ;;
    bot+cabinet)
      collect_bot_answers
      collect_cabinet_answers
      ;;
  esac

  render_scaffold
  run_full_prepare_pipeline
}

install_bot_flow() {
  run_mode_flow "bot-only"
  run_full_deploy_pipeline
}

install_cabinet_flow() {
  run_mode_flow "cabinet-only"
  run_full_deploy_pipeline
}

check_updates_now() {
  section "Проверка обновлений"
  load_state

  local checked=0
  local label path branch behind
  local bot_root=""
  local cabinet_root=""

  bot_root="$(resolve_bot_root 2>/dev/null || true)"
  cabinet_root="$(resolve_cabinet_root 2>/dev/null || true)"

  for entry in "${bot_root}|Бот" "${cabinet_root}|Кабинет"; do
    path="${entry%%|*}"
    label="${entry##*|}"
    [[ -n "$path" && -d "$path/.git" ]] || continue
    checked=1

    branch=$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)
    git -C "$path" fetch origin "$branch" --quiet || {
      warn "$label — не удалось проверить обновления"
      continue
    }

    behind=$(git -C "$path" rev-list --count HEAD.."origin/$branch" 2>/dev/null || echo 0)
    if [[ "$behind" =~ ^[0-9]+$ ]] && (( behind > 0 )); then
      warn "$label — доступно обновлений: $behind"
    else
      ok "$label — обновлений нет"
    fi
  done

  (( checked == 1 )) || warn "Пока нечего проверять, ни бот, ни кабинет не найдены"
}

show_menu_header() {
  clear_screen
  print_banner
  print_note "Сначала всё проверю сам, потом поставлю. Лишние технички не показываю."
  hr
}

show_finish_screen() {
  load_state
  printf "\n"

  case "${INSTALL_MODE:-}" in
    bot-only)
      print_card "Готово" \
        "Установлен режим: Только бот" \
        "Папка бота: ${BOT_INSTALL_DIR:-не выбрана}" \
        "Локальный порт бота: ${BOT_LOCAL_PORT:-—}" \
        "Remnawave: ${REMNAWAVE_SETUP_MODE:-не указан}" ;;
    cabinet-only)
      print_card "Готово" \
        "Установлен режим: Только кабина" \
        "Папка кабины: ${CABINET_INSTALL_DIR:-не выбрана}" \
        "Локальный порт кабины: ${CABINET_LOCAL_PORT:-—}" \
        "Домен кабины: ${CABINET_DOMAIN_VALUE:-не указан}" ;;
    bot+cabinet)
      print_card "Готово" \
        "Установлен режим: Бот + Кабина" \
        "Папка бота: ${BOT_INSTALL_DIR:-не выбрана}" \
        "Порт бота: ${BOT_LOCAL_PORT:-—}" \
        "Папка кабины: ${CABINET_INSTALL_DIR:-не выбрана}" \
        "Порт кабины: ${CABINET_LOCAL_PORT:-—}" ;;
    *)
      print_card "Готово" \
        "Режим: $(mode_label "${INSTALL_MODE:-}")" \
        "Бот: ${BOT_INSTALL_DIR:-не выбран}" \
        "Кабина: ${CABINET_INSTALL_DIR:-не выбрана}" ;;
  esac

  print_note "Дальше можно: 4) Обновить Бота • 5) Обновить Кабину • 6) Проверить обновления"
}

install_full_flow() {
  run_mode_flow "bot+cabinet"
  run_full_deploy_pipeline
}

run_main_menu() {
  auto_prepare_host || true
  while true; do
    show_menu_header
    local choice=""

    if supports_arrow_ui; then
      choice="$(interactive_select 'Главное меню' \
        'Установить Бота' \
        'Установить Кабинет' \
        'Установить Бот + Кабину' \
        'Обновить Бота' \
        'Обновить Кабину' \
        'Проверить обновления' \
        'Показать текущее состояние' \
        'Выход')"
    else
      print_card "Меню" \
        "1) Установить Бота" \
        "2) Установить Кабинет" \
        "3) Установить Бот + Кабину" \
        "4) Обновить Бота" \
        "5) Обновить Кабину" \
        "6) Проверить обновления" \
        "7) Показать текущее состояние" \
        "0) Выход"
      hr
      if ! read_input choice "Что делаем: "; then
        ok "Установщик закрыт"
        break
      fi
    fi

    case "$choice" in
      1) install_bot_flow; show_finish_screen ;;
      2) install_cabinet_flow; show_finish_screen ;;
      3) install_full_flow; show_finish_screen ;;
      4) update_bot_now ;;
      5) update_cabinet_now ;;
      6) check_updates_now ;;
      7) show_plan ;;
      8|0) ok "Установщик закрыт"; break ;;
      *) warn "Не понял пункт меню" ;;
    esac
    printf "\n"
    print_note "Enter — назад в меню"
    if ! read_input _menu_pause ""; then
      ok "Установщик закрыт"
      break
    fi
  done
}

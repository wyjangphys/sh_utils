#!/usr/bin/env sh

# ---------- Unicode 지원 감지 ----------
supports_unicode() {
  [ "${TERM:-}" = "dumb" ] && return 1
  case "${LC_ALL:-}${LC_CTYPE:-}${LANG:-}" in
    *[Uu][Tt][Ff]8*|*[Uu][Tt][Ff]-8*) return 0 ;;
  esac
  return 1
}

# ---------- 터미널 가로 폭 ----------
get_columns() {
  if [ -n "${COLUMNS-}" ] && [ "$COLUMNS" -gt 0 ] 2>/dev/null; then
    printf %s "$COLUMNS"; return
  fi
  if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    cols=$(tput cols 2>/dev/null)
    if [ -n "$cols" ] && [ "$cols" -gt 0 ] 2>/dev/null; then
      printf %s "$cols"; return
    fi
  fi
  if [ -t 1 ] && command -v stty >/dev/null 2>&1; then
    set -- $(stty size 2>/dev/null)   # rows cols
    if [ -n "$2" ] && [ "$2" -gt 0 ] 2>/dev/null; then
      printf %s "$2"; return
    fi
  fi
  printf %s 80
}

# ---------- 시간 포맷: 초 -> H:MM:SS 또는 M:SS ----------
fmt_hms() {
  sec=$1
  [ -n "$sec" ] || sec=0
  [ "$sec" -ge 0 ] 2>/dev/null || sec=0

  h=$(( sec / 3600 ))
  m=$(( (sec % 3600) / 60 ))
  s=$(( sec % 60 ))

  if [ "$h" -gt 0 ]; then
    # H:MM:SS
    printf '%d:%02d:%02d' "$h" "$m" "$s"
  else
    # M:SS
    printf '%d:%02d' "$m" "$s"
  fi
}

# ---------- 전역 상태 ----------
PB_STARTED=0
PB_START_TIME=0
PB_LAST_TIME=0
PB_LAST_COUNT=0
PB_RATE=""

# TTY면 창 크기 변경 시 COLUMNS 갱신
if [ -t 1 ]; then
  COLUMNS=$(get_columns)
  trap 'COLUMNS=$(get_columns)' WINCH
fi

# ---------- 초기화 (선택적) ----------
# progress_init TOTAL
progress_init() {
  total=$1
  [ "$total" -gt 0 ] 2>/dev/null || total=1
  PB_STARTED=1
  PB_START_TIME=$(date +%s)
  PB_LAST_TIME=$PB_START_TIME
  PB_LAST_COUNT=0
  PB_RATE=""
}

# ---------- 메인: 진행 표시 ----------
# progress_bar CURRENT TOTAL
progress_bar() {
  current=$1
  total=$2

  [ "$total" -gt 0 ] 2>/dev/null || total=1
  [ "$current" -ge 0 ] 2>/dev/null || current=0
  [ "$current" -le "$total" ] 2>/dev/null || current=$total

  # 초기화 자동 수행
  if [ "$PB_STARTED" -eq 0 ]; then
    progress_init "$total"
  fi

  now=$(date +%s)

  # 속도(ops/s) 계산 (정수/소수 1자리)
  delta_c=$(( current - PB_LAST_COUNT ))
  delta_t=$(( now - PB_LAST_TIME ))
  if [ "$delta_t" -gt 0 ] && [ "$delta_c" -ge 0 ]; then
    # awk로 부동소수 계산
    PB_RATE=$(awk -v dc="$delta_c" -v dt="$delta_t" 'BEGIN{
      if (dt>0) printf "%.1f", dc/dt; else print "";
    }')
    PB_LAST_TIME=$now
    PB_LAST_COUNT=$current
  fi

  # ETA 계산
  eta_text="ETA --:--"
  if [ -n "$PB_RATE" ]; then
    # 남은 작업량 / 속도
    rem=$(( total - current ))
    # 정수 초로 반올림
    eta_sec=$(awk -v r="$PB_RATE" -v rem="$rem" 'BEGIN{
      if (r>0) printf "%d", int(rem/r + 0.5); else print -1;
    }')
    if [ -n "$eta_sec" ] && [ "$eta_sec" -ge 0 ] 2>/dev/null; then
      eta_text="ETA $(fmt_hms "$eta_sec")"
    fi
  fi

  percent=$(( current * 100 / total ))
  percent_text=$(printf '%3d%%' "$percent")

  # rate 텍스트
  if [ -n "$PB_RATE" ]; then
    rate_text="$(printf '%s ops/s' "$PB_RATE")"
  else
    rate_text="-- ops/s"
  fi

  width=$(get_columns)

  # 폭이 작은 경우: 유니코드 대신 ASCII
  if [ "$width" -lt 40 ]; then
    symbol_filled='='
    symbol_empty='.'
  else
    if supports_unicode; then
      symbol_filled='█'
      symbol_empty='░'
    else
      symbol_filled='='
      symbol_empty='.'
    fi
  fi

  # 메타 문자열(퍼센트/속도/ETA) 구성 및 가변 표시
  tail_full=" $percent_text $rate_text $eta_text"
  overhead=$(( 2 + ${#tail_full} ))  # [ ] + tail 전체 길이
  inner_width=$(( width - overhead ))
  # 너무 좁으면 일부 항목 제거
  tail_used="$tail_full"
  if [ "$inner_width" -lt 1 ]; then
    # 먼저 ETA 제거
    tail_no_eta=" $percent_text $rate_text"
    overhead=$(( 2 + ${#tail_no_eta} ))
    inner_width=$(( width - overhead ))
    tail_used="$tail_no_eta"
  fi
  if [ "$inner_width" -lt 1 ]; then
    # 다음으로 rate 제거
    tail_no_rate=" $percent_text"
    overhead=$(( 2 + ${#tail_no_rate} ))
    inner_width=$(( width - overhead ))
    tail_used="$tail_no_rate"
  fi
  if [ "$inner_width" -lt 1 ]; then
    inner_width=1
  fi

  # 막대 계산
  filled=$(( current * inner_width / total ))
  [ "$filled" -ge 0 ] || filled=0
  [ "$filled" -le "$inner_width" ] || filled=$inner_width
  empty=$(( inner_width - filled ))

  bar=''
  i=0; while [ "$i" -lt "$filled" ]; do bar="${bar}${symbol_filled}"; i=$((i+1)); done
  i=0; while [ "$i" -lt "$empty"  ]; do bar="${bar}${symbol_empty}";  i=$((i+1)); done

  if [ -t 1 ]; then
    # 줄 전체 지우기 + 맨 앞으로 이동 후 출력
    printf '\r\033[2K[%s]%s' "$bar" "$tail_used"
  else
    # TTY가 아니면 누적 로그
    printf '[%s]%s\n' "$bar" "$tail_used"
  fi

  # 완료 시 개행
  if [ "$current" -ge "$total" ] && [ -t 1 ]; then
    printf '\n'
  fi
}

# ---------- 데모 ----------
# 아래 데모는 필요 시 주석 해제하여 테스트하세요.
#total=500
#progress_init "$total"
#i=0
#while [ "$i" -le "$total" ]; do
#  progress_bar "$i" "$total"
#  # 작업 시뮬레이션
#  sleep 0.05
#  step=$(( (i/50)  ))   # 점점 빨라지는 예시
#  i=$(( i + step ))
#done
for i in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 19 19 19 20 35 50 65 80 90 100; do
  progress_bar "$i" 100
  sleep 0.05
done
[ -t 1 ] && printf '\n'

#!/usr/bin/env sh

# UTF-8 지원 감지 (POSIX sh)
supports_unicode() {
  # TERM=dumb 이면 굳이 유니코드 안 씀
  [ "${TERM:-}" = "dumb" ] && return 1

  case "${LC_ALL:-}${LC_CTYPE:-}${LANG:-}" in
    *[Uu][Tt][Ff]8*|*[Uu][Tt][Ff]-8*) return 0 ;;
  esac
  return 1
}

# POSIX sh
get_columns() {
    # 1) 이미 유효한 COLUMNS가 있으면 사용
    if [ -n "${COLUMNS-}" ] && [ "$COLUMNS" -gt 0 ] 2>/dev/null; then
        printf %s "$COLUMNS"
        return
    fi

    # 2) tput (terminfo) 사용
    if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
        cols=$(tput cols 2>/dev/null)
        if [ -n "$cols" ] && [ "$cols" -gt 0 ] 2>/dev/null; then
            printf %s "$cols"
            return
        fi
    fi

    # 3) stty 사용 (많은 환경에서 동작)
    if [ -t 1 ] && command -v stty >/dev/null 2>&1; then
        # stty size → "<rows> <cols>"
        set -- $(stty size 2>/dev/null)
        if [ -n "$2" ] && [ "$2" -gt 0 ] 2>/dev/null; then
            printf %s "$2"
            return
        fi
    fi

    # 4) 마지막 폴백
    printf %s 80
}


progress_bar() {
  current=$1
  total=$2

  # 창 크기 변경 시 갱신 (TTY에서만 의미 있음)
  # trap은 POSIX 표준이며, WINCH는 대부분의 유닉스에서 지원
  if [ -t 1 ]; then
      trap 'COLUMNS=$(get_columns)' WINCH
  fi

  # 사용 예
  width=$(get_columns)

  # 경계 처리
  [ "$total" -gt 0 ] || total=1
  [ "$current" -ge 0 ] || current=0
  [ "$current" -le "$total" ] || current=$total

  inner_width=$(( width - 4 ))   # 양끝 대괄호와 공백·퍼센트를 위한 여유
  [ "$inner_width" -gt 0 ] || inner_width=1

  if supports_unicode; then
    symbol_filled='█'
    symbol_empty='░'
  else
    symbol_filled='='
    symbol_empty='.'
  fi

  percent=$(( current * 100 / total ))
  filled=$(( current * inner_width / total ))
  empty=$(( inner_width - filled ))

  # 막대 문자열 생성 (POSIX: += 미사용, tr/seq 미사용)
  bar=""
  i=0
  while [ "$i" -lt "$filled" ]; do
    bar="${bar}${symbol_filled}"
    i=$(( i + 1 ))
  done
  i=0
  while [ "$i" -lt "$empty" ]; do
    bar="${bar}${symbol_empty}"
    i=$(( i + 1 ))
  done

  printf "\r[%s] %3d%%" "$bar" "$percent"
}

# 데모
for i in 0 5 10 20 35 50 65 80 90 100; do
  progress_bar "$i" 100
  sleep 0.05
done
printf "\n"


#!/bin/sh

: "${RUN_COMMAND_TRIGGER_REGEX:=https?://}"
run_command() {
  desc=$1
  shift # this is to shift argument table to the left after removing $1.

  # Prepare temporary file
  tmpfile=$(mktemp "${TMPDIR:-/tmp}/cmd_output.XXXXXX") || exit 1
  fifofile="${tmpfile}.fifo"    # this fifo file required to display the result both in standard output and temp file.
  liveflag="${tmpfile}.live"
  newline=$(printf '\n')

  # Clean up instruction in case of exception
  trap 'rm -f "$tmpfile" "$fifofile" 2>/dev/null' EXIT HUP INT TERM

  printf "\r[\033[33m .... \033[0m] %s" "$desc"

  # Live output using FIFO and tee while also saving to a file (POSIX-compliant method)
  mkfifo "$fifofile" || { rm -f "$tmpfile"; return 1; }

  # Watcher: No print out before trigger detect URL from the stdout. Once a URL snippet detected, print out stdout
  awk -v re="$RUN_COMMAND_TRIGGER_REGEX" -v out="$tmpfile" -v flag="$liveflag" '
  BEGIN { live=0 }
  {
    print $0 >> out; fflush(out)
    if (!live && $0 ~ re) {
      live=1
      # 상태줄과 안 겹치도록 개행
      printf "\n"
      print $0; fflush(stdout)
      # 플래그 파일 생성 (touch 대체)
      print "" > flag; close(flag)
      next
    }
    if (live) {
      print $0; fflush(stdout)
    }
  }
  END { close(out) }
  ' <"$fifofile" &
  readerpid=$!

  # Run the actual command (redirect both standard output and error to FIFO)
  "$@" >"$fifofile" 2>&1
  cmdstatus=$?

  wait "$readerpid" 2>/dev/null
  rm -f "$fifofile"

  # Print out
  output=$(cat "$tmpfile")

  if [ "$cmdstatus" -eq 0 ]; then
    printf "\r[\033[32m  OK  \033[0m] %s\n" "$desc"
  else
    printf "\r[\033[31mFAILED\033[0m] %s\n" "$description"
  fi

  # Reprint policy:
  # - If no trigger occurred: show the buffered output once at the end
  # - If a trigger occurred: skip reprinting on success since it was already shown live.
  if [ ! -f "$liveflag" ]; then
    if [ -s "$tmpfile" ]; then
      # 길면 꼬리만 보고 싶을 때: tail -n "${RUN_COMMAND_TAIL:-200}" "$tmpfile" | sed 's/^/ |\t/'
      sed 's/^/ |\t/' "$tmpfile"
    fi
  elif [ "$cmdstatus" -ne 0 ]; then
    # 트리거 있었는데 실패했다면, 필요하면 꼬리만 추가 출력하도록 여기서 tail로 조절 가능
    : # (기본은 추가출력 안 함)
  fi

  return "$cmdstatus"
}

unicode_to_utf8() {
    hex="$1"
    dec=$((16#$hex))

    if [ "$dec" -le 0x7F ]; then
        # 1-byte
        printf '\\x%02X' "$dec"
    elif [ "$dec" -le 0x7FF ]; then
        # 2-byte
        b1=$(( (dec >> 6) | 0xC0 ))
        b2=$(( (dec & 0x3F) | 0x80 ))
        printf '\\x%02X\\x%02X' "$b1" "$b2"
    elif [ "$dec" -le 0xFFFF ]; then
        # 3-byte
        b1=$(( (dec >> 12) | 0xE0 ))
        b2=$(( ((dec >> 6) & 0x3F) | 0x80 ))
        b3=$(( (dec & 0x3F) | 0x80 ))
        printf '\\x%02X\\x%02X\\x%02X' "$b1" "$b2" "$b3"
    elif [ "$dec" -le 0x10FFFF ]; then
        # 4-byte
        b1=$(( (dec >> 18) | 0xF0 ))
        b2=$(( ((dec >> 12) & 0x3F) | 0x80 ))
        b3=$(( ((dec >> 6) & 0x3F) | 0x80 ))
        b4=$(( (dec & 0x3F) | 0x80 ))
        printf '\\x%02X\\x%02X\\x%02X\\x%02X' "$b1" "$b2" "$b3" "$b4"
    else
        echo "Error: Invalid code point (U+$hex)" >&2
        return 1
    fi
}

parse_git_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null | sed 's/^/(/' | sed 's/$/)/'
}

function shorten_path() {
  local path="$PWD"
  local home="$HOME"

  # Remove trailing slash if any
  path="${path%/}"

  # If path is inside home directory
  if [[ "$path" == "$home"* ]]; then
    # Remove $HOME prefix
    local subpath="${path#$home}"
    # Remove leading slash from subpath (if any)
    subpath="${subpath#/}"

    IFS='/' read -ra parts <<< "$subpath"
    local count=${#parts[@]}

    if (( count == 0 )); then
      echo "~"
    elif (( count == 1 )); then
      echo "~/${parts[0]}"
    else
      echo "~/.../${parts[count - 1]}"
    fi
  else
    IFS='/' read -ra parts <<< "$path"
    local count=${#parts[@]}

    if (( count <= 2 )); then
      echo "$path"
    else
      echo "/${parts[1]}/.../${parts[count - 1]}"
    fi
  fi
}

check_n_start_apptainer() {
  if [ -n "$APPTAINER_CONTAINER" ]; then
    echo "Running inside Apptainer"
    RED="\[\033[0;31m\]"
    GREEN="\[\033[0;32m\]"
    BLUE="\[\033[0;34m\]"
    YELLOW="\[\033[0;33m\]"
    PURPLE="\[\033[0;35m\]"
    CYAN="\[\033[0;36m\]"
    RESET="\[\033[0m\]"

    set_prompt
    return 0
  else
    echo "WARNING: Not inside Apptainer"
    return 1
  fi
}

set_prompt(){
  # POSIX standard set_prompt
  RED=$(printf '\033[0;31m')
  GREEN=$(printf '\033[0;32m')
  BLUE=$(printf '\033[0;34m')
  YELLOW=$(printf '\033[0;33m')
  PURPLE=$(printf '\033[0;35m')
  CYAN=$(printf '\033[0;36m')
  RESET=$(printf '\033[0m')

  user_name="${USER:-$(whoami)}"
  host_name="${HOSTNAME:-$(uname -n)}"
  current_path=$(shorten_path)
  git_branch=$(parse_git_branch)

  if [ -n "$APPTAINER_CONTAINER" ]; then
    prefix="${GREEN}[${RESET}${RED}Appt: ${RESET}"
  else
    prefix="${GREEN}[${RESET}"
  fi
  export PS1="${prefix}${CYAN}${user_name}${RESET}@${BLUE}${host_name}${RESET} ${current_path} ${YELLOW}${git_branch}${RESET}${GREEN}]${RESET} \$ "

}

upsls(){
  local package=$1
  if [ -z "$package" ]; then
    echo "Usage: upsls <package name>"
    return 1
  fi

  ups list -aK+ "$package" | \
    awk -F\" '{print $2, $4, $6, $8, $10}' | \
    sort -k2,2V | \
    awk '{printf "\"%s\" \"%s\" \"%s\" \"%s\" \"%s\"\n", $1, $2, $3, $4, $5}'
}

#alias real_cp='/bin/cp'
#cp() {
#  local use_ifdh=false
#
#  for arg in "$@"; do
#    if [[ "$arg" == /pnfs/* ]]; then
#      use_ifdh=true
#      break
#    fi
#  done
#
#  if $use_ifdh; then
#    echo "cp wrapper] Detected /pnfs path --> using ifdh cp"
#    ifdh cp "$@"
#  else
#    real_cp "$@"
#  fi
#}

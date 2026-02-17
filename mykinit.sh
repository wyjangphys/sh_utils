#!/bin/sh
. $HOME/.local/bin/utility.sh

printf "Running kinit...\n"
/usr/bin/kinit -A -f wyjang@FNAL.GOV

if [ $? -ne 0 ] ; then
  printf "kinit failed. Aborting.\n"
  exit 1
fi

case "$(uname -s)" in
  "Linux")
    run_command "Starting gpvm-scanner.service..." systemctl --user restart gpvm-scanner.service
    ;;
  "Darwin")
    run_command "Starting gpvm-scanner.service..." launchctl kickstart -k gui/$(id -u)/com.user.gpvm-scanner
    ;;
  *)
    ;;
esac

DUNE_FILE="$HOME/.local/etc/dunegpvm"
ICARUS_FILE="$HOME/.local/etc/icarusgpvm"

count=0
while [ $count -lt 10 ]; do
  if [ -f "$DUNE_FILE" ] && [ -f "$ICARUS_FILE" ] ; then
    d_val=$(cat "$DUNE_FILE")
    i_val=$(cat "$ICARUS_FILE")

    if [ "$d_val" -gt 0 ] 2>/dev/null && [ "$i_val" -gt 0 ] 2>/dev/null ; then
      break;
    fi
  fi
  sleep 1
  count=$((count + 1))
done

dunegpvm_idx=$(printf "%02d" "$(cat "$DUNE_FILE")")
icarusgpvm_idx=$(printf "%02d" "$(cat "$ICARUS_FILE")")

printf "Best dunegpvm node: $dunegpvm_idx\n"
printf "Best icarusgpvm node: $icarusgpvm_idx\n"
printf "Have fun, ${USER}!\n"

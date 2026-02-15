#!/bin/sh
. $HOME/.local/bin/utility.sh

duneapp_mntpt="$HOME/mnt/dune_app"
dunedata_mntpt="$HOME/mnt/dune_data"
icarusapp_mntpt="$HOME/mnt/icarus_app"
icarusdata_mntpt="$HOME/mnt/icarus_data"
all_mnt="$duneapp_mntpt $dunedata_mntpt $icarusapp_mntpt $icarusdata_mntpt"

sshfs_umount() {
  printf "Unmounting all sshfs filesystems...\n"

  for mnt in "$ALL_MNT"; do
    if [ -d "$mnt" ]; then
      if command -v fusermount >/dev/null 2>&1; then
        fusermount -u "$mnt" >/dev/null 2>&1
      else
        umount "$mnt" >/dev/null 2>&1
      fi

      if [ $? -eq 0 ]; then
        printf "[OK] Unmounted %s\n" "$mnt"
      else
        printf "[INFO] %s was not mounted or busy.\n" "$mnt"
      fi
    fi
  done
}
if [  "$1" = "-d" ]; then
  printf "Unmounting all sshfs filesystems and destorying tickets...\n"
  sshfs_umount

  if command -v kdestroy >/dev/null 2>&1; then
    kdestroy
    printf "[OK] Kerberos tickets destoryed.\n"
  fi
  exit 0
fi
if [ "$1" = "-u" ]; then
  sshfs_umount
  exit 0
fi

printf "Running kinit...\n"
/usr/bin/kinit -A -f wyjang@FNAL.GOV

if [ $? -ne 0 ] ; then
  printf "kinit failed. Aborting.\n"
  exit 1
fi

run_command "Starting gpvm-scanner.service..." systemctl --user restart gpvm-scanner.service

DUNE_FILE="$HOME/.local/etc/dunegpvm"
ICARUS_FILE="$HOME/.local/etc/icarusgpvm"

printf "Waiting for daemon to find the best gpvm node...\n"
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

mkdir -p "$duneapp_mntpt" "$dunedata_mntpt" "$icarusapp_mntpt" "$icarusdata_mntpt"

printf "Mounting dunegpvm%s...\n" "$dunegpvm_idx"
run_command "Mounting dune appdir..." sshfs "dunegpvm${dunegpvm_idx}.fnal.gov:/exp/dune/app/users/${USER}" $duneapp_mntpt -o "x-gvfs-name=dunegpvm-app","x-gvfs-symbolic-icon=folder-remote","reconnect"
run_command "Mounting dune datadir..." sshfs "dunegpvm${dunegpvm_idx}.fnal.gov:/exp/dune/data/users/${USER}" $dunedata_mntpt -o "x-gvfs-name=dunegpvm-data","x-gvfs-symbolic-icon=folder-remote","reconnect"

printf "Mounting icarusgpvm%s...\n" "$icarusgpvm_idx"
run_command "Mounting icarus appdir..." sshfs "icarusgpvm${icarusgpvm_idx}.fnal.gov:/exp/icarus/app/users/${USER}" $icarusapp_mntpt -o "x-gvfs-name=icarusgpvm-app","x-gvfs-symbolic-icon=folder-remote","reconnect"
run_command "Mounting icarus datadir..." sshfs "icarusgpvm${icarusgpvm_idx}.fnal.gov:/exp/icarus/data/users/${USER}" $icarusdata_mntpt -o "x-gvfs-name=icarusgpvm-data","x-gvfs-symbolic-icon=folder-remote","reconnect"



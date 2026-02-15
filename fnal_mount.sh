#!/bin/sh
if [ ! -f $HOME/.local/bin/utility.sh ]; then
  printf "fnal_utility is not found."
  exit 1
else
  . $HOME/.local/bin/utility.sh
fi

if [ $(cat $HOME/.local/etc/dunegpvm) -lt 0 ]; then
  printf "[Error] Failed to capture the best dunegpvm node.\n"
  exit 1
fi

if [ $(cat $HOME/.local/etc/icarusgpvm) -lt 0 ]; then
  printf "[Error] Failed to capture the best icarusgpvm node.\n"
  exit 1
fi

duneidx=$(printf "%02d" "$(cat $HOME/.local/etc/dunegpvm)")
icarusidx=$(printf "%02d" "$(cat $HOME/.local/etc/icarusgpvm)")
duneapp_mntpt="$HOME/mnt/dune_app"
dunedata_mntpt="$HOME/mnt/dune_data"
icarusapp_mntpt="$HOME/mnt/icarus_app"
icarusdata_mntpt="$HOME/mnt/icarus_data"
all_mntpt="$duneapp_mntpt $dunedata_mntpt $icarusapp_mntpt $icarusdata_mntpt"

detect_os() {
  case "$(uname -s)" in
    Darwin)
      printf "Darwin"
      ;;
    Linux)
      printf "Linux"
      ;;
    *)
      printf "Unsupported OS: $(uname -s)\n"
      exit 1
      ;;
  esac
}

sshfs_mount() {
  ostype=$(detect_os)
  mnt_option_name=""

  case "$ostype" in
    "Linux")
      mnt_option_name="x-gvfs-name"
      ;;
    "macOS")
      mnt_option_name="volname"
      ;;
    *)
      printf "Unsupported OS"
      exit 1
      ;;
  esac

  mkdir -p $all_mntpt

  sshfs "dunegpvm${duneidx}.fnal.gov:/exp/dune/app/users/${USER}" $duneapp_mntpt -o "$mnt_option_name=dunegpvm-app"
  sshfs "dunegpvm${duneidx}.fnal.gov:/exp/dune/data/users/${USER}" $dunedata_mntpt -o "$mnt_option_name=dunegpvm-data"
  sshfs "icarusgpvm${icarusidx}.fnal.gov:/exp/icarus/app/users/${USER}" $icarusapp_mntpt -o "$mnt_option_name=icarusgpvm-app"
  sshfs "icarusgpvm${icarusidx}.fnal.gov:/exp/icarus/data/users/${USER}" $icarusdata_mntpt -o "$mnt_option_name=icarusgpvm-data"
}

sshfs_umount() {
  ostype=$(detect_os)
  case "$ostype" in
    "Linux")
      for mnt in $all_mntpt; do
        fusermount -u "$mnt"
      done
      ;;
    "macOS")
      for mnt in $all_mntpt; do
        umount "$mnt" >/dev/null 2>&1
      done
      ;;
    *)
      printf "unsupported os"
      exit 1
      ;;
  esac

  return 0
}

# ================== script entry point =====================

if [ "$1" = "-u" ]; then
  run_command "Unmounting all gpvm sshfs points..." sshfs_umount
  exit 0
fi

run_command "Mounting gpvm sshfs points..." sshfs_mount

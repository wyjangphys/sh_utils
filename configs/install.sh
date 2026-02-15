#!/bin/sh

DEFAULT_TARGET_DIR=$HOME/.local/bin
TARGET_DIR=${1:-$DEFAULT_TARGET_DIR}
if [ ! -d $TARGET_DIR ]; then
  mkdir -p $TARGET_DIR
fi
echo $TARGET_DIR

cp -v ${PWD}/zshrc $TARGET_DIR/

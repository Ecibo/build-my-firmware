#!/bin/bash
set -e
export HOME=`pwd`

TARGETS='PSG1218 NEWIFI3'
FIRMWARE_DIR=$HOME/firmware
GITVER=Unknown
# Package Dependence:
# sudo pkg-config build-essential autoconf automake autopoint cmake libtool fakeroot git curl unzip
# kmod xz-utils bison flex gperf gawk gettext texinfo python-docutils ca-certificates zlib1g-dev
# libgmp3-dev libmpc-dev libmpfr-dev libncurses5-dev libltdl-dev

clone_source() {
  cd /opt
  git clone --depth=1 https://github.com/hanwckf/rt-n56u.git
  cd rt-n56u
  GITVER=$(git describe --tags || git rev-parse --short HEAD) || true
}

install_toolchain() {
  cd /opt/rt-n56u/toolchain-mipsel
  rm -rf *
  mkdir toolchain-3.4.x
  curl -L https://github.com/hanwckf/padavan-toolchain/releases/download/v1.0/mipsel-linux-uclibc.tar.xz | tar xJ -C toolchain-3.4.x
}

build_firmware() {
  cd /opt/rt-n56u/trunk
  for m in $TARGETS; do
    echo '# CONFIG_RALINK_CPUSLEEP is not set' >> configs/boards/$m/kernel-3.4.x.config
    fakeroot ./build_firmware_modify $m && cp -f images/*.trx $FIRMWARE_DIR
    ./clear_tree_simple >/dev/null 2>&1
  done
}

pack_and_upload() {
  echo 'Uploading artifacts...'
  cd $FIRMWARE_DIR
  local build_time=`date +"%Y%m%d%H%M%S"`
  tar --owner=0 --group=0 -cJf "$HOME/Padavan.tar.xz" *
  curl -T "$HOME/Padavan.tar.xz" "https://transfer.sh/Padavan-$build_time.$GITVER.tar.xz"
  echo
  [ -n "$TELEGRAM_BOTOKEN" ] && curl -s \
    -F "chat_id=${TELEGRAM_BOTOKEN#*/}" \
    -F "document=@$HOME/Padavan.tar.xz" \
    -F "caption=Padavan-$build_time.$GITVER" \
    "https://api.telegram.org/bot${TELEGRAM_BOTOKEN%/*}/sendDocument" >/dev/null
  [ -n "$TERACLOUD_TOKEN" ] && curl -s -u "${TERACLOUD_TOKEN%@*}" -T "$HOME/Padavan.tar.xz" \
    "https://${TERACLOUD_TOKEN#*@}/dav/artifacts/Padavan-$build_time.$GITVER.tar.xz" >/dev/null
}

mkdir -p $FIRMWARE_DIR

clone_source
install_toolchain
mv $HOME/configs/* /opt/rt-n56u/trunk/configs/templates/
build_firmware

cd $FIRMWARE_DIR
if [ "$(ls -A .)" ]; then
  echo "build finished:"
  ls -hl
  [ -n "$SHARE_ARTIFACTS" ] && pack_and_upload || true
  [ -n "$BUILD_NOHOP_MODE" ] && touch $HOME/build_success || true
  exit 0
fi
echo "no firmware been built!"
exit 1

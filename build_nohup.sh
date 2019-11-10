#!/bin/bash
export HOME=`pwd`
export BUILD_NOHOP_MODE=1
BUILD_RUN_SCRIPT_CMD='./build_rom.sh'


$BUILD_RUN_SCRIPT_CMD > build.log 2>&1 &
while true ;do
  sleep 20
  process_status="$(pgrep -f $BUILD_RUN_SCRIPT_CMD)"
  if [ -z "$process_status" ]; then
    echo "Build script exited"
    cd $HOME
    tail -60 build.log
    xz -z9 build.log
    curl -T build.log.xz https://transfer.sh/padavan-build.log.xz
    echo
    [ -e build_success ] && exit 0
    echo 'Build failed! see build log.'
    exit 1
  else
    if [ -z "$NO_TAIL_LOG" ]; then
      echo "===============build log==============="
      tail -2 build.log || true
    fi
    echo "--------------top process--------------"
    ps aux | grep -v ^'USER' | sort -rn -k3 | head -2 | awk '{print $3, $4, $10, $11}'
  fi
done

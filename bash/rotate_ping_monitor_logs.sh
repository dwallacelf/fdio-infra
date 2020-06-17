#! /bin/bash
#  Copyright 2020  Dave Wallace (dwallacelf@gmail.com)
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
#  rotate_ping_monitor_logs.sh [-clean] <destination address> [... <destination address>]

PING_MONITOR_LOG_DIR=${PING_MONITOR_LOG_DIR:-"/tmp"}
PING_MONITOR_LOGS=${PING_MONITOR_LOGS:-'*.doc'}
PING_MONITOR_ARCHIVE_DIR=${PING_MONITOR_ARCHIVE_DIR:-"$HOME/nomad-monitoring/ping-monitor-logs"}
log_files="$PING_MONITOR_LOG_DIR/$PING_MONITOR_LOGS"
archive_dir="$PING_MONITOR_ARCHIVE_DIR"

if [ "$#" -lt "1" ] ; then
  echo "Usage: $0 [-clean] <destination address> [... <destination address>]"
  exit 1
fi
mkdir -p $PING_MONITOR_ARCHIVE_DIR

if [ "$1" = "-clean" ] ; then
  clean=true
  shift
fi

while [ -n "$1" ] ; do
  dest_host="$1"
  shift
  echo "Syncing ping_monitor logs ($log_files) from $dest_host:"
  sync_cmd="rsync -avz $dest_host:$log_files $archive_dir"
  echo "  $sync_cmd"
  $sync_cmd
  rc="$?"
  if [ "$rc" != "0" ] ; then
    echo "Warning: rsync returned non-zero status: $rc"
    [ -n "$clean" ] && echo "         Skipping clean of ping monitor logs ($log_files) on $dest_host"
    continue
  fi
  if [ -n "$clean" ] ; then
    echo "Cleaning ping_monitor logs ($log_files) on $dest_host"
    ssh $dest_host "rm -f $log_files"
  fi
done

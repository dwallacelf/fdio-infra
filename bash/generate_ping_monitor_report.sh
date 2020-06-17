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
#  generate_ping_monitor_report.sh [<YYYY-MM-DD> ... [<YYYY-MM-DD>]]
#
#  This script outputs a report characterizing the failures detected on
#  the specified date(s) or today if no dates are specified.
#

PING_MONITOR_ARCHIVE_DIR=${PING_MONITOR_ARCHIVE_DIR:-"$HOME/nomad-monitoring/ping-monitor-logs"}

pktloss="PACKET-LOSS"
errs="ERRORS"

usage() {
  echo
  echo "Usage: $0 [<YYYY-MM-DD> ... [<YYYY-MM-DD>]]"
  exit 1
}

verify_date() {
  local rc=0
  if [[ $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] ; then
    if [ -n "$(date --version 2> /dev/null)" ] ; then
      date "+%Y-%m-%d" -d "$1" >/dev/null 2>&1
      rc=$?
    fi
  else
    rc=1
  fi
  return $rc
}

arch_dir=$PING_MONITOR_ARCHIVE_DIR
if [ ! -d "$arch_dir" ] ; then
  echo "ERROR: archive directory not found: '$arch_dir'"
  usage
fi

if [ "$#" -eq "0" ] ; then
  dates="$(date +%Y-%m-%d)"
else
  dates="$@"
fi

src_hosts="$(ls $arch_dir/*.doc | cut -d'_' -f2 | sort -u)"
dst_hosts="$(ls $arch_dir/*.doc | cut -d'_' -f4 | sort -u)"
for date_filter in $dates ; do
  verify_date $date_filter
  if [ "$?" -ne "0" ] ; then
    echo "ERROR: Invalid date filter: '$date_filter'"
  fi
  for src in $src_hosts ; do
    #echo "DAW src: $src"
    for dst in $dst_hosts ; do
      #echo "DAW dst: $dst"
      filter="$arch_dir/*${src}*${dst}*${date_filter}*"
      if [ -n "$(ls $filter 2> /dev/null)" ] ; then
        # Gather ERRORS
        err_logs="$(ls -1 ${filter}_${errs}* 2> /dev/null)"
        if [ -n "$err_logs" ] ; then
          err_log_cnt="$(echo "$err_logs" | wc -l)"
          errors="$(grep errors $err_logs | cut -d',' -f3 | cut -d' ' -f2 | cut -d'+' -f2 | sort -nu)"
          err_min="$(echo "$errors" | head -1)"
          err_max="$(echo "$errors" | tail -1)"
        else
          err_log_cnt="0"
        fi
        # Gather PACKET-LOSS failures
        pkt_fail_logs="$(ls -1 ${filter}_${pktloss}_fail* 2> /dev/null)"
        if [ -n "$pkt_fail_logs" ] ; then
          pkt_fail_log_cnt="$(echo "$pkt_fail_logs" | wc -l)"
          pkt_fails="$(grep loss $pkt_fail_logs | cut -d',' -f3 | cut -d'%' -f1 | cut -d' ' -f2 | sort -nu)"
          pkt_fail_min="$(echo "$pkt_fails" | head -1)"
          pkt_fail_max="$(echo "$pkt_fails" | tail -1)"
        else
          pkt_fail_log_cnt="0"
        fi
        # Print summary results
        if [ "$err_log_cnt" != "0" ] || [ "$pkt_fail_log_cnt" != "0" ] ; then
          echo "$date_filter Results for 'ping_monitor.sh $src $dst'"
          if [ "$err_log_cnt" != "0" ] ; then
            echo -n "${errs}: $err_log_cnt logs, 100% packet loss ($err_min"
            [ "$err_min" != "$err_max" ] && echo -n "-$err_max"
            echo " errors)"
          fi
          if [ "$pkt_fail_log_cnt" != "0" ] ; then
            echo -n "${pktloss}: $pkt_fail_log_cnt logs, $pkt_fail_min"
            [ "$pkt_fail_min" != "$pkt_fail_max" ] && echo -n "-$pkt_fail_max"
            echo "% packet loss"
          fi
          echo
        fi
      fi
    done
  done
done

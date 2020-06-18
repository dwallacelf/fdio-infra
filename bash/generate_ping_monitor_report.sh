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

pktloss_tag="PACKET-LOSS"
errors_tag="ERRORS"

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

for date_filter in $dates ; do
  verify_date $date_filter
  if [ "$?" -ne "0" ] ; then
    echo "ERROR: Invalid date filter: '$date_filter'"
  fi
  src_hosts="$(ls $arch_dir/*${date_filter}*.doc 2> /dev/null | cut -d'_' -f2 | sort -u)"
  dst_hosts="$(ls $arch_dir/*${date_filter}*.doc 2> /dev/null | cut -d'_' -f4 | sort -u)"
  results_printed=0
  echo "$date_filter Ping Monitor Failure Summary"
  echo "======================================="
  for src in $src_hosts ; do
    for dst in $dst_hosts ; do
      filter="$arch_dir/*${src}*${dst}*${date_filter}*"
      if [ -n "$(ls $filter 2> /dev/null)" ] ; then
        # Gather ERRORS results
        errors_logs="$(ls -1 ${filter}_${errors_tag}* 2> /dev/null)"
        if [ -n "$errors_logs" ] ; then
          errors_log_cnt="$(echo "$errors_logs" | wc -l)"
          errors_grep_results="$(grep errors $errors_logs)"
          errors_results="$(echo "$errors_grep_results" | cut -d',' -f3 | cut -d' ' -f2 | cut -d'+' -f2 | sort -nu)"
          errors_min="$(echo "$errors_results" | head -1)"
          errors_max="$(echo "$errors_results" | tail -1)"
          errors_loss_results="$(echo "$errors_grep_results" | cut -d',' -f4 | cut -d'%' -f1 | cut -d' ' -f2 | sort -nu)"
          errors_loss_min="$(echo "$errors_loss_results" | head -1)"
          errors_loss_max="$(echo "$errors_loss_results" | tail -1)"
        else
          errors_log_cnt="0"
        fi
        # Gather PACKET-LOSS failure results
        pktloss_fail_logs="$(ls -1 ${filter}_${pktloss_tag}_fail* 2> /dev/null)"
        if [ -n "$pktloss_fail_logs" ] ; then
          pktloss_fail_log_cnt="$(echo "$pktloss_fail_logs" | wc -l)"
          pktloss_fails_results="$(grep loss $pktloss_fail_logs | cut -d',' -f3 | cut -d'%' -f1 | cut -d' ' -f2 | sort -nu)"
          pktloss_fail_min="$(echo "$pktloss_fails_results" | head -1)"
          pktloss_fail_max="$(echo "$pktloss_fails_results" | tail -1)"
        else
          pktloss_fail_log_cnt="0"
        fi
        # Print summary results
        if [ "$errors_log_cnt" -gt "0" ] || [ "$pktloss_fail_log_cnt" -gt "0" ] ; then
          let results_printed++
          echo "'ping_monitor.sh $src $dst':"
          if [ "$errors_log_cnt" -gt "0" ] ; then
            echo -n "  ${errors_tag}: $errors_log_cnt logs, $errors_loss_min"
            [ "$errors_loss_min" != "$errors_loss_max" ] && echo -n "-$errors_loss_max"
            echo -n "% packet loss ($errors_min"
            [ "$errors_min" != "$errors_max" ] && echo -n "-$errors_max"
            echo " errors)"
          fi
          if [ "$pktloss_fail_log_cnt" -gt "0" ] ; then
            echo -n "  ${pktloss_tag}: $pktloss_fail_log_cnt logs, $pktloss_fail_min"
            [ "$pktloss_fail_min" != "$pktloss_fail_max" ] && echo -n "-$pktloss_fail_max"
            echo "% packet loss"
          fi
        fi
      fi
    done
  done
  [ "$results_printed" -eq "0" ] && echo "No Failures found!  :D"
  echo
done

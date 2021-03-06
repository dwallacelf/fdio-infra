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
#  ping_monitor.sh <destination address>
#
#  This script runs a 'ping' based monitor in a forever loop.
#  It redirects output of the ping command into a temporary log file
#  with the following naming convention to allow co-mingling of
#  multiple ping_monitor.sh instance logs in a single archive directory
#  for ease of network outage analysis:
#
#  /tmp/ping-monitor_<local hostname>_<pid>_<destination>_<start time>
#  (Note: underscore is used as a field separator in file names)
#
#  Each 'ping' command issues 60 packets.  The log file output is
#  parsed to determine if there were any packet loss or errors.
#  If any packet losses or errors are detected, then the log file is
#  moved to a file postfixed with the warning or failure discovered:
#
#  If any errors are found:       <log file>_ERRORS_fail.doc
#  If 10% or more packet loss:    <log file>_PACKET-LOSS_fail.doc
#  If less than 10% packet loss:  <log_file>_PACKET-LOSS_warn.doc
#
#  Only the two most recent copies of error-free log files are retained
#  for each instance of the script to avoid filling /tmp with files
#  that contain no issues.
#
#  Log rotation or archiving of errored log files are a non-feature
#  of this script.
#
#  The following grep commands are useful in reviewing status of
#  ls -l /tmp/ping*.doc  # show all logs with issues

set -uo pipefail

count=60
ping_opts="-DOc"
ping_cmd="ping $ping_opts $count $1"
pktloss="PACKET-LOSS"
badhostname="BAD-HOSTNAME"
errs="ERRORS"
dest="$1"
logfile=""
prev_logfile=""
horizontal_rule="\n-------------------------------------------\n"

if [ -z "$dest" ] ; then
  echo "Usage: $0 <destination>"
  exit 1
fi

# Test ping command options
ping_test=$(ping $ping_opts 1 localhost 2>&1)
if [[ ! "$ping_test" =~ .*"ping statistics".* ]] ; then
  echo "Error: ping options ($ping_opts) not supported by $(which ping)!"
  echo "$ping_test"
  exit 1
fi
ping_test=$(ping $ping_opts 1 $dest 2>&1)
if [[ ! "$ping_test" =~ .*"ping statistics".* ]] ; then
  echo "$ping_test"
  exit 1
fi

notify_webex_teams_script="$(dirname $BASH_SOURCE)/lib_notify_webex_teams.sh"
if [ ! -f "$notify_webex_teams_script" ] ; then
    echo "ERROR: '$notify_webex_teams_script' is missing!"
    echo "  $(basename $BASH_SOURCE) must be run from cloned workspace."
    exit 1
else
    source "$notify_webex_teams_script"
fi

ping_mon_exit() {
  echo
  check_for_pkt_loss
  rm -f $logfile $prev_logfile
  echo -e "$horizontal_rule\nSo long and thanks for watching! :D"
  exit 0
}

trap ping_mon_exit SIGHUP SIGINT SIGQUIT SIGABRT SIGKILL SIGALRM SIGTERM

check_for_pkt_loss() {
  WEBEX_TEAMS_MESSAGE=""
  if [ -n "$(grep ', 0% packet loss,' $logfile)" ] ; then
    echo "All is well in $logfile !"
    return
  fi
  # Use '.doc' file suffix for upload to Vexxhost Ticket :/
  local save_logfile="${logfile}_${pktloss}_warn.doc"
  local failure_detected=""
  if [ -n "$(grep 'errors, ' $logfile)" ] ; then
    # Use '.doc' file suffix for upload to Vexxhost Ticket :/
    save_logfile="${logfile}_${errs}_fail.doc"
    local num_errors="$(grep errors $logfile | cut -d',' -f3 | cut -d' ' -f2)"
    failure_detected="$num_errors PING ERRORS"
  else
    percent_pktloss="$(grep loss $logfile | cut -d',' -f3 | cut -d'%' -f1 | cut -d' ' -f2)"
    if [ -z "$percent_pktloss" ] ; then
	failure_detected="Bad hostname"
	save_logfile="${logfile}_${badhostname}_fail.doc"
    else
      if [ "$(echo $percent_pktloss | cut -d. -f1)" -ge "10" ] ; then
        failure_detected="${percent_pktloss}% PACKET LOSS"
        save_logfile="${logfile}_${pktloss}_fail.doc"
      fi
    fi
  fi
  mv $logfile $save_logfile
  if [ -n "$failure_detected" ] ; then
    local pktloss_tag="${pktloss}_fail"
    local pktloss_today="$(ls -1 $today_prefix* | grep ${pktloss_tag} | wc -l)"
    local errors_tag="${errs}_fail"
    local errors_today="$(ls -1 $today_prefix* | grep ${errors_tag} | wc -l)"
    WEBEX_TEAMS_MESSAGE="FAILURE DETECTED: $failure_detected on $host ($errors_today ${errors_tag}.doc, $pktloss_today ${pktloss_tag}.doc logs today): $save_logfile"
    send_notify
  else
    echo "WARNING: ${percent_pktloss}% PACKET LOSS DETECTED on $host: $save_logfile"
  fi
}

host="$(hostname)"
while true; do
  timestamp=$(date -u +%Y-%m-%d-%H%M%S)
  today_prefix="/tmp/ping-monitor_${host}_$$_$dest"
  logfile="${today_prefix}_$timestamp"

  echo -e $horizontal_rule
  echo "Pinging from $host to $1 with $count packets starting @ $timestamp..."
  echo -e "$host: started '$ping_cmd' at $timestamp\n-" > $logfile
  $ping_cmd >> $logfile
  check_for_pkt_loss
  [ -f $prev_logfile ] && rm -rf $prev_logfile;
  prev_logfile=$logfile
done

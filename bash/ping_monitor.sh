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

if [ -z "$1" ] ; then
  echo "Usage: $0 <ip address>"
  exit 1
fi

count=60
ping_opts="-DOc"
ping_cmd="ping $ping_opts $count $1"
token_file="$HOME/.ssh/secret_webex_teams_access_token"

# Test ping command options
ping_test=$(ping $ping_opts 1 localhost 2>&1)
if [[ ! "$ping_test" =~ .*"ping statistics".* ]] ; then
  echo "Error: ping options ($ping_opts) not supported by $(which ping)!"
  echo "$ping_test"
  exit 1
fi

[ -z "$SECRET_WEBEX_TEAMS_ACCESS_TOKEN" ] && [ -f "$token_file" ] && source $token_file
[ -z "$SECRET_WEBEX_TEAMS_ACCESS_TOKEN" ] && echo "Warning: Missing SECRET_WEBEX_TEAMS_ACCESS_TOKEN envvar!"

send_notify() {
  if [ -z "$SECRET_WEBEX_TEAMS_ACCESS_TOKEN" ] ; then
    echo "Warning: Missing SECRET_WEBEX_TEAMS_ACCESS_TOKEN envvar!"
    return
  fi
  SECRET_WEBEX_TEAMS_ROOM_ID='Y2lzY29zcGFyazovL3VzL1JPT00vMDZlY2I0ODAtNzgwZi0xMWVhLWE1YzItNDExYzJmODZmMDlm'
  curl https://api.ciscospark.com/v1/messages -X POST -H "Authorization: Bearer ${SECRET_WEBEX_TEAMS_ACCESS_TOKEN}" -H "Content-Type: application/json" --data '{"roomId":"'${SECRET_WEBEX_TEAMS_ROOM_ID}'", "markdown": "'"${WEBEX_TEAMS_MESSAGE}"'" }'
}

ping_mon_exit() {
  echo
  check_for_pkt_loss
  echo
  echo "So long and thanks for watching :D"
  exit 0
}

trap ping_mon_exit SIGHUP SIGINT SIGQUIT SIGABRT SIGKILL SIGALRM SIGTERM

check_for_pkt_loss() {
  if [ -n "$(grep ', 0% packet loss,' $logfile)" ] ; then
    echo "All is well in $logfile !"
    return
  fi
  # Use '.doc' file suffix for upload to Vexxhost Ticket :/
  local save_logfile="$logfile.PACKET_LOSS.warn.doc"
  local failure_detected=""
  if [ -n "$(grep 'errors, ' $logfile)" ] ; then
    # Use '.doc' file suffix for upload to Vexxhost Ticket :/
    save_logfile="$logfile.ERRORS.fail.doc"
    local num_errors="$(grep errors $logfile | cut -d',' -f3 | cut -d' ' -f2)"
    failure_detected="$num_errors PING ERRORS"
  else
    percent_pktloss="$(grep loss $logfile | cut -d',' -f3 | cut -d'%' -f1 | cut -d' ' -f2)"
    if [ "$percent_pktloss" -ge "10" ] ; then
      failure_detected="${percent_pktloss}% PACKET LOSS"
      save_logfile="$logfile.PACKET_LOSS.fail.doc"
    fi
  fi
  mv $logfile $save_logfile
  if [ -n "$failure_detected" ] ; then
    local pktloss_today="$(ls -1 $today_prefix.* | grep PACKET_LOSS.fail | wc -l)"
    local errors_today="$(ls -1 $today_prefix.* | grep ERRORS.fail | wc -l)"
    WEBEX_TEAMS_MESSAGE="FAILURE DETECTED: $failure_detected on $host ($errors_today ERRORS.doc, $pktloss_today PACKET_LOSS.doc logs today): $save_logfile"
    echo $WEBEX_TEAMS_MESSAGE
    send_notify
  else
    echo "WARNING: ${percent_pktloss}% PACKET LOSS DETECTED on $host: $save_logfile"
  fi
}

host="$(hostname)"
while true; do
  timestamp=$(date +%Y-%m-%d-%H%M%S)
  logfile="/tmp/ping_monitor.$host.$$.$1.$timestamp"
  today_prefix="/tmp/ping_monitor.$host.$$.$1"
  echo "Pinging from $host to $1 with $count packets starting @ $timestamp..."
  echo -e "$host: started '$ping_cmd' at $timestamp\n-" > $logfile
  $ping_cmd >> $logfile
  check_for_pkt_loss
  [ -f $prev_logfile ] && rm -rf $prev_logfile;
  prev_logfile=$logfile
done

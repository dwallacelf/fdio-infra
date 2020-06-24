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
#  show_ping_monitors.sh [<remote host> [... <remote host>]]
#
#  Output the running ping monitor scripts on the hosts specified
#  or localhost if none specified.

usage() {
  echo "Usage: $0  [-u <user name>] [<remote host> [... <remote host>]]"
  exit 1
}

user=$USER
if [ "$#" -eq "0" ] ; then
  hosts="localhost"
else
  hosts="$@"
fi

ip4addr=""
get_ip4_address() {
  ip4addr=$(ssh $user@$1 'ip address show up primary' \
    | grep inet | grep -v inet6 | grep -v 127 \
    | awk -e '{print $2}' | head -1 | cut -d'/' -f1)
  if [ "$?" -ne "0" ] ; then
    echo "ERROR: unable to obtain ip address from '$user@$1'!"
    usage
  fi
}

hostname=""
get_hostname() {
  hostname=$(ssh $user@$1 'hostname')
  if [ "$?" -ne "0" ] ; then
    echo "ERROR: unable to obtain hostname from '$user@$1'!"
    usage
  fi
}

for h in $hosts ; do
  get_hostname $h
  get_ip4_address $h
  echo "Ping Monitors on $hostname ($ip4addr):"
  echo "======================================="
  ssh $user@$h ps -auxww | grep -v grep | grep ping_monitor.sh | awk -e '{printf "%s %s (pid %d)\n", $12, $13, $2}'
  echo
done

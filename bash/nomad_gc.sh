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
# nomad_gc.sh [<sleep interval (secs)>]
#
# This script runs in a forever loop checking the nomad status for dead
# batch jobs and runs nomad garbage collection if any are found.

sleep_interval=${1:-"30"}
if [ $((sleep_interval)) != $sleep_interval ] ; then
   echo "ERROR: Invalid sleep interval: '$sleep_interval'!"
   echo -e "\nUSAGE: $0 [<sleep interval (secs)>]"
   exit 1
fi

set -euo pipefail

while true; do
   echo "##### $(date -u): Sleep $sleep_interval #####"
   sleep $sleep_interval
   cleanup_required="$(nomad status | grep batch | grep dead || true)"
   echo -e "Dead Executors:\n---- %< ----\n$cleanup_required\n---- %< ----"
   if [ -n "$cleanup_required" ] ; then
       echo "Running Nomad Garbage Collection"
       nomad system gc
  fi
  echo -e "####################\n"
done

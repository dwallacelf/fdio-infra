#
#  Copyright 2021  Dave Wallace (dwallacelf@gmail.com)
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
#  lib_notify_webex_teams.sh
#
#  This script is a library intended only for inclusion in other scripts.
#  It sends notifications to a WebEx Teams space.

set -euo pipefail

webex_token_file=${webex_token_file:-"$HOME/.ssh/secret_webex_teams_access_token"}
SECRET_WEBEX_TEAMS_ACCESS_TOKEN=${SECRET_WEBEX_TEAMS_ACCESS_TOKEN:-""}

[ -z "$SECRET_WEBEX_TEAMS_ACCESS_TOKEN" ] && [ -f "$webex_token_file" ] && source $webex_token_file
[ -z "$SECRET_WEBEX_TEAMS_ACCESS_TOKEN" ] && echo -e "Warning: Missing SECRET_WEBEX_TEAMS_ACCESS_TOKEN envvar!\n"

send_notify() {
  SECRET_WEBEX_TEAMS_ROOM_ID='Y2lzY29zcGFyazovL3VzL1JPT00vMDZlY2I0ODAtNzgwZi0xMWVhLWE1YzItNDExYzJmODZmMDlm'

  if [ -z "$WEBEX_TEAMS_MESSAGE" ] ; then
    echo -e "\nWARNING: send_notify() called without WEBEX_TEAMS_MESSAGE!"
    return
  else
      echo -e "\nSending Message to WebEx Teams:\n$WEBEX_TEAMS_MESSAGE"
  fi

  if [ -z "$SECRET_WEBEX_TEAMS_ACCESS_TOKEN" ] ; then
    echo -e "\nWARNING: Missing SECRET_WEBEX_TEAMS_ACCESS_TOKEN envvar!"
    return
  fi

  # Don't abort script if curl command fails
  set +e
  curl https://api.ciscospark.com/v1/messages -X POST -H "Authorization: Bearer ${SECRET_WEBEX_TEAMS_ACCESS_TOKEN}" -H "Content-Type: application/json" --data '{"roomId":"'${SECRET_WEBEX_TEAMS_ROOM_ID}'", "markdown": "'"${WEBEX_TEAMS_MESSAGE}"'" }'
  if [ "$?" !=  "0" ] ; then
      echo -e "\nWARNING: Send notify message failed!"
  fi
  set -e
}

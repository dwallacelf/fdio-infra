#! /bin/bash
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
#  nomad_host_monitor.sh [-a <ansible host_vars dir> ] [-c <checkpoint file>]
#
#    -a <ansible host_vars dir>  Ansible configuration host_vars directory
#                                containing the configuration for the nomad
#                                hosts.
#
#    -c <checkpoint file>        Path to the checkpoint file containing script
#                                checkpoint variables.
#                                See function checkpoint_data() below.
#                                On the 1st time script is run, only
#                                ${ansible_config[*]} values are required.
#                                The specified file will be overwritten by
#                                this script. Must end in '.sh'.
#
#                                If not specified, checkpoint data will be
#                                stored in /tmp/nomad_host_monitor_checkpoint.sh
#
#  Alternatively, these parameter values may be pass in via the environment
#  variables: ANSIBLE_HOST_VARS_DIR and NOMAD_CHECKPOINT_FILE respectively.
#
#  This script runs a nomad host monitor in a forever loop.
#  Periodically it issues nomad commands to acquire the current
#  state of the nomad cluster client & server apps and compares them
#  to the configured or existing state.  If the state changes (e.g. a
#  client is missing), then the state change is output to a WebEx Teams space.

set -euo pipefail

seconds_to_sleep=60
checkpoint_config=""
horizontal_rule="\n-------------------------------------------"

nomad_host_mon_exit() {
    echo -e "$horizontal_rule\nSo long and thanks for watching! :D"
    exit 0
}

trap nomad_host_mon_exit SIGHUP SIGINT SIGQUIT SIGABRT SIGKILL SIGALRM SIGTERM

notify_webex_teams_script="$(dirname $BASH_SOURCE)/lib_notify_webex_teams.sh"
if [ ! -f "$notify_webex_teams_script" ] ; then
    echo "ERROR: '$notify_webex_teams_script' is missing!"
    exit 1
else
    source "$notify_webex_teams_script"
fi

ANSIBLE_HOST_VARS_DIR=${ANSIBLE_HOST_VARS_DIR:-""}
NOMAD_CHECKPOINT_FILE=${NOMAD_CHECKPOINT_FILE:-"/tmp/nomad_host_monitor_checkpoint.sh"}
NOMAD_CHANGED_FILE=""

declare -A ansible_config
ansible_config[clients_ip]=""
ansible_config[servers_ip]=""

declare -A nomad_oper
nomad_oper[prev_clients]=""
nomad_oper[prev_servers]=""
nomad_oper[clients]=""
nomad_oper[clients_ip]=""
nomad_oper[servers]=""
nomad_oper[servers_ip]=""

declare -A consul_oper
consul_oper[prev_members]=""
consul_oper[members]=""
consul_oper[members_ip]=""

usage() {
    cat <<EOF
$(basename $BASH_SOURCE) [-a <ansible host_vars dir> ] [-c <checkpoint file>]

  -a <ansible host_vars dir>  Ansible configuration host_vars directory
                              containing the configuration for the nomad
                              hosts.

  -c <checkpoint file>        Path to the checkpoint file containing script
                              checkpoint variables.
                              See function checkpoint_data() below.
                              On the 1st time script is run, only
                              ${ansible_config[*]} values are required.
                              The specified file will be overwritten by
                              this script. Must end in '.sh'.

                              If not specified, checkpoint data will be
                              stored in /tmp/nomad_host_monitor_checkpoint.sh

Alternatively, these parameter values may be pass in via the environment
variables: ANSIBLE_HOST_VARS_DIR and NOMAD_CHECKPOINT_FILE respectively.

EOF
    exit 1
}

get_ansible_config() {
    ansible_config[clients_ip]=""
    ansible_config[servers_ip]=""

    pushd $ANSIBLE_HOST_VARS_DIR >/dev/null
    # gather nomad clients (nomad_node_role == 'client' or 'both')
    for host in *.yaml ; do
        if [ -n "$(grep nomad_node_role $host | grep -v server 2>/dev/null)" ]
        then
            ansible_config[clients_ip]="${ansible_config[clients_ip]} ${host::-5}"
        fi;
    done
    ansible_config[clients_ip]="${ansible_config[clients_ip]:1}"
    
    # gather nomad servers (nomad_node_role == 'server' or 'both')
    for host in *.yaml ; do
        if [ -n "$(grep nomad_node_role $host | grep -v client)" ] ; then
            ansible_config[servers_ip]="${ansible_config[servers_ip]} ${host::-5}"
        fi;
    done
    ansible_config[servers_ip]="${ansible_config[servers_ip]:1}"
    popd >/dev/null
}
        
import_config() {
    set +e
    local host_vars_config="$(grep nomad_node_role $ANSIBLE_HOST_VARS_DIR/*.yaml 2>/dev/null)"
    if [ -n "$ANSIBLE_HOST_VARS_DIR" ] ; then
        if [ -n "$host_vars_config" ]
        then
            get_ansible_config
        else
            echo "ERROR: Invalid Ansible host_vars directory: '$ANSIBLE_HOST_VARS_DIR'!"
            usage
        fi
    elif [ -n "$NOMAD_CHECKPOINT_FILE" ] ; then
        checkpoint_config="$(grep ansible_config $NOMAD_CHECKPOINT_FILE 2>/dev/null | grep -v '""' | grep -v declare)"
        if [ -z "$checkpoint_config" ] ; then
            echo "ERROR: Missing checkpoint file: '$NOMAD_CHECKPOINT_FILE'!"
            usage
        fi
    fi
    set -e
}

checkpoint_data() {
    NOMAD_CHANGED_FILE="${NOMAD_CHECKPOINT_FILE::-3}-$(date +%Y-%m-%d-%H%M%S).CHANGED"
    local checkpoint_time="$(date -u)"
    echo -e "\nCheckpointing data at $checkpoint_time to\n$NOMAD_CHECKPOINT_FILE..."
    cat >$NOMAD_CHECKPOINT_FILE <<EOF
#======== Checkpoint Variables ========#
# Generated by $BASH_SOURCE at $checkpoint_time

declare -A ansible_config
ansible_config[clients_ip]="${ansible_config[clients_ip]}"

ansible_config[servers_ip]="${ansible_config[servers_ip]}"

declare -A nomad_oper
nomad_oper[clients]="${nomad_oper[clients]}"

nomad_oper[clients_ip]="${nomad_oper[clients_ip]}"

nomad_oper[servers]="${nomad_oper[servers]}"

nomad_oper[servers_ip]="${nomad_oper[servers_ip]}"

declare -A consul_oper
consul_oper[members]="${consul_oper[members]}"

consul_oper[members_ip]="${consul_oper[members_ip]}"
#======================================#

#======== Prev Oper Variables =========#
nomad_oper[prev_clients]="${nomad_oper[prev_clients]}"

nomad_oper[prev_servers]="${nomad_oper[prev_servers]}"

consul_oper[prev_members]="${consul_oper[prev_members]}"
#======================================#
EOF
}

update_oper_data() {
    echo -e "\nUpdating Nomad/Consul Operational Data..."
    # Save current oper data as previous
    nomad_oper[prev_clients]="${nomad_oper[clients]}"
    nomad_oper[prev_servers]="${nomad_oper[servers]}"
    consul_oper[prev_members]="${consul_oper[members]}"

    # Update oper data
    nomad_oper[clients]="$(nomad node status -verbose | grep -v Address | sort -k5)"
    nomad_oper[clients_ip]="$(nomad node status -verbose | grep -v Address | sort -k5 | mawk '{print $5}' | tr '\n' ' ' | xargs)"
    nomad_oper[servers]="$(nomad server members | grep -v Address | sort -k2)"
    nomad_oper[servers_ip]="$(nomad server members | grep -v Address | sort -k2 | mawk '{print $2}' | tr '\n' ' ' | xargs)"
    consul_oper[members]="$(consul members | grep -v Address | sort -k2)"
    consul_oper[members_ip]="$(consul members | grep -v Address | sort -k2 | mawk '{print $2}' | cut -d: -f1 | tr '\n' ' '| xargs)"
}

verify_oper_data() {
    WEBEX_TEAMS_MESSAGE=""

    echo -e "\nVerifying Nomad/Consul operational data..."
    
    # Verify Nomad Clients
    if [ "${ansible_config[clients_ip]}" != "${nomad_oper[clients_ip]}" ] ; then
        WEBEX_TEAMS_MESSAGE="$WEBEX_TEAMS_MESSAGE\nNomad Client List Changed!"
    elif [ -n "${nomad_oper[prev_clients]}" ] && \
           [ "${nomad_oper[prev_clients]}" != "${nomad_oper[clients]}" ] ; then
        WEBEX_TEAMS_MESSAGE="$WEBEX_TEAMS_MESSAGE\nNomad Client Attributes Changed!"
    fi
    
    # Verify Nomad Servers
    if [ "${ansible_config[servers_ip]}" != "${nomad_oper[servers_ip]}" ] ; then
        WEBEX_TEAMS_MESSAGE="$WEBEX_TEAMS_MESSAGE\nNomad Server List Changed!}"
    elif [ -n "${nomad_oper[prev_servers]}" ] && \
           [ "${nomad_oper[prev_servers]}" != "${nomad_oper[servers]}" ] ; then
        WEBEX_TEAMS_MESSAGE="$WEBEX_TEAMS_MESSAGE\nNomad Server Attributes Changed!"
    fi

    # Verify consul
    # Note: Assume consul is running on all nomad client nodes
    if [ "${ansible_config[clients_ip]}" != "${consul_oper[members_ip]}"  ] ; then
        WEBEX_TEAMS_MESSAGE="$WEBEX_TEAMS_MESSAGE\nConsul Members List Changed!"
    elif [ -n "${consul_oper[prev_members]}" ] && \
           [ "${consul_oper[prev_members]}" != "${consul_oper[members]}" ] ; then
        WEBEX_TEAMS_MESSAGE="$WEBEX_TEAMS_MESSAGE\nConsul Members Attributes Changed!"
    fi

    if [ -n "$WEBEX_TEAMS_MESSAGE" ] ; then
        mv $NOMAD_CHECKPOINT_FILE $NOMAD_CHANGED_FILE
        WEBEX_TEAMS_MESSAGE="$WEBEX_TEAMS_MESSAGE\nSee $(hostname):$NOMAD_CHANGED_FILE for details."
        send_notify
    fi
    return
}

while getopts ":ha:c:" opt; do
    case $opt in
        a) ANSIBLE_HOST_VARS_DIR="$OPTARG" ;;
        c) NOMAD_CHECKPOINT_FILE="$OPTARG"
           if ! grep -qe '\.sh$' <<<"$NOMAD_CHECKPOINT_FILE" ; then
               echo "Invalid checkpoint file name: '$NOMAD_CHECKPOINT_FILE'!"
               usage
           fi
           if [ "${NOMAD_CHECKPOINT_FILE:1}" != "/" ] ; then
               if [ "${NOMAD_CHECKPOINT_FILE::2}" = "./" ] ; then
                   NOMAD_CHECKPOINT_FILE="$(pwd)/${NOMAD_CHECKPOINT_FILE:2}"
               else
                   NOMAD_CHECKPOINT_FILE="$(pwd)/$NOMAD_CHECKPOINT_FILE"
               fi
           fi
           ;;
        *) usage ;;
    esac
done

import_config
if [ -n "$checkpoint_config" ] ; then
    # Import has to be here otherwise the variables sourced
    # from $NOMAD_CHECKPOINT_FILE are out of scope.
    echo -e "\nImporting ansible host configuration from checkpoint file\n$NOMAD_CHECKPOINT_FILE..."
    source $NOMAD_CHECKPOINT_FILE
else
    echo -e "\nAnsible configuration read from host_vars directory\n$ANSIBLE_HOST_VARS_DIR..."
fi
if [ -z "${ansible_config[clients_ip]}" ] || \
       [ -z "${ansible_config[servers_ip]}" ] ; then
    echo "ERROR: No nomad host configuration data found!"
    usage
fi

while true; do
    echo -e $horizontal_rule
    update_oper_data
    checkpoint_data
    verify_oper_data
    echo -e "\nBreak time -- Yay! :D \nNapping for $seconds_to_sleep seconds..."
    sleep $seconds_to_sleep
done

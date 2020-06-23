#! /usr/bin/python3

from subprocess import run, PIPE
import json

client_args = ['nomad', 'node', 'status', '--json']
nomad_status_json = run(client_args, stdout=PIPE)
clients = json.loads(nomad_status_json.stdout.decode('utf-8'))
for client in clients:
    details_args = client_args + [client['ID']]
    client_name = '{} ({})'.format(client['Name'], client['Address'])
    nomad_status_json = run(details_args, stdout=PIPE)
    details = json.loads(nomad_status_json.stdout.decode('utf-8')) 
    for event in details['Events']:
        print('{}: {} {}'.format(client_name, event['Timestamp'], event['Message']))

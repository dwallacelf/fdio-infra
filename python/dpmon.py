#!/usr/bin/env python3

from datetime import datetime, timezone
import json
from subprocess import run, PIPE
from addict import Dict
from dataclasses import dataclass, field
from decimal import Decimal
from typing import List
from pprint import pprint


@dataclass
class HubMetrics:
    stamp: str
    data: Dict


@dataclass
class WorstCaseMetrics:
    start: str
    end: str
    hubs: List[HubMetrics] = field(default_factory=list)


@dataclass
class MtrReport:
    stamp: str
    results: Dict


@dataclass
class MtrEndpoint:
    ip_addr: str
    metrics: WorstCaseMetrics
    filename: str = ''
    report: List[MtrReport] = field(default_factory=list)

    def new_mtr_results(self, start=None):
        if not start:
            self.start = start_timestamp()
        mtr_cmd = ['mtr', '-jnT', f'{self.ip_addr}']
        print(f'{self.start}: Running {mtr_cmd}...')
        results = run(mtr_cmd, stdout=PIPE).stdout.decode('utf-8')
        report = MtrReport(self.start, Dict(json.loads(results)).report)
        self.report.append(report)

    def import_from_file(self, data_dir = '/tmp'):
        # TODO: import json file
        pass

    def write_to_file(self, data_dir = '/tmp'):
        filename = f'{data_dir}/dpmon-{self.ip_addr}.json'
        # TODO: write json file

    def gather_worst_case_metrics(self):
        self.metrics.start = self.report[0].stamp
        for i, rpt in enumerate(self.report):
            for j, hub in enumerate(self.report[i].results.hubs):
                if len(self.metrics.hubs) == j:
                    self.metrics.hubs.append(hub)
                elif Decimal(hub.Wrst) <= Decimal(self.metrics.hubs[j].Wrst):
                    self.metrics.hubs[j] = hub
        self.metrics.end = self.report[i].stamp


def start_timestamp():
    return(datetime.now(timezone.utc).strftime('%Y-%m-%d-%H_%M_%S-UTC'))

def main():
    # TODO: Create venv & install addict & dataclasses & activate venv

    # TODO: argparse args

    ingress_ext = MtrEndpoint('162.253.54.31', WorstCaseMetrics(None, None, []))
    ingress_ext.new_mtr_results()
    ingress_ext.gather_worst_case_metrics()
    pprint(ingress_ext.metrics)

if __name__ == "__main__":
    main()

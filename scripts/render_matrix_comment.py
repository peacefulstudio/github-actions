#!/usr/bin/env python3
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
"""Render a workflow run's build-matrix shard results as a markdown table.

Reads the concatenated JSON pages emitted by
``gh api --paginate repos/<repo>/actions/runs/<run-id>/jobs`` on stdin,
anchors on the calling aggregator job's own display name to resolve the
reusable-workflow name prefix, and prints a ``shard | result | duration``
table covering the sibling ``build-and-test (<shard>)`` jobs of the same
workflow invocation.
"""
import json
import sys
from datetime import datetime

SHARD_JOB_MARKER = 'build-and-test ('
TIMESTAMP_FORMAT = '%Y-%m-%dT%H:%M:%SZ'
UNKNOWN_DURATION = '—'
RESULT_LABELS = {
    'success': '✅ success',
    'failure': '❌ failure',
    'cancelled': '🚫 cancelled',
    'skipped': '⏭️ skipped',
    'timed_out': '⏱️ timed out',
    'neutral': '⚪ neutral',
    'action_required': '⚠️ action required',
    'stale': '⚠️ stale',
}


def parse_job_pages(text):
    decoder = json.JSONDecoder()
    jobs = []
    index = 0
    while index < len(text):
        if text[index].isspace():
            index += 1
            continue
        page, index = decoder.raw_decode(text, index)
        jobs.extend(page['jobs'])
    return jobs


def workflow_prefix(jobs, self_job_name):
    matches = [
        job['name']
        for job in jobs
        if job['name'] == self_job_name or job['name'].endswith(f' / {self_job_name}')
    ]
    if not matches:
        raise ValueError(f'no job named {self_job_name!r} found in this run')
    if len(matches) > 1:
        raise ValueError(
            f'multiple jobs named {self_job_name!r} found in this run; '
            'set a distinct artifact-prefix per workflow invocation'
        )
    return matches[0][: -len(self_job_name)]


def shard_jobs(jobs, prefix):
    marker = f'{prefix}{SHARD_JOB_MARKER}'
    shards = []
    for job in jobs:
        name = job['name']
        if not (name.startswith(marker) and name.endswith(')')):
            continue
        shards.append((name[len(marker):-1], job))
    return sorted(shards, key=lambda shard: shard[0])


def result_label(job):
    conclusion = job['conclusion']
    if conclusion not in RESULT_LABELS:
        raise ValueError(f'unknown conclusion for job {job["name"]!r}: {conclusion!r}')
    return RESULT_LABELS[conclusion]


def format_duration(job):
    started = job.get('started_at')
    completed = job.get('completed_at')
    if not started or not completed:
        return UNKNOWN_DURATION
    elapsed = (
        datetime.strptime(completed, TIMESTAMP_FORMAT)
        - datetime.strptime(started, TIMESTAMP_FORMAT)
    )
    seconds = int(elapsed.total_seconds())
    if seconds < 0:
        return UNKNOWN_DURATION
    minutes, remainder = divmod(seconds, 60)
    if minutes == 0:
        return f'{remainder}s'
    return f'{minutes}m {remainder:02d}s'


def render(jobs, self_job_name, title):
    prefix = workflow_prefix(jobs, self_job_name)
    shards = shard_jobs(jobs, prefix)
    if not shards:
        raise ValueError(
            f'no {SHARD_JOB_MARKER}<shard>) jobs found under prefix {prefix!r}'
        )
    lines = [
        f'## {title}',
        '',
        '| shard | result | duration |',
        '| --- | --- | --- |',
    ]
    for shard, job in shards:
        lines.append(
            f'| [{shard}]({job["html_url"]}) '
            f'| {result_label(job)} '
            f'| {format_duration(job)} |'
        )
    return '\n'.join(lines) + '\n'


def main(argv):
    if len(argv) != 3:
        print(
            'error: usage: render_matrix_comment.py <self-job-name> <title>',
            file=sys.stderr,
        )
        return 2
    print(render(parse_job_pages(sys.stdin.read()), argv[1], argv[2]), end='')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))

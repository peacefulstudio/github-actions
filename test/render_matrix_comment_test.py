# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

import render_matrix_comment

SELF_JOB_NAME = 'matrix-comment (csharp)'
TITLE = 'C# build matrix'


def job(
    name,
    conclusion='success',
    started='2026-07-10T12:00:00Z',
    completed='2026-07-10T12:03:42Z',
    url='https://github.test/run/1/job/1',
):
    return {
        'name': name,
        'conclusion': conclusion,
        'started_at': started,
        'completed_at': completed,
        'html_url': url,
    }


def page(*jobs):
    return json.dumps({'total_count': len(jobs), 'jobs': list(jobs)})


class RenderMatrixCommentTest(unittest.TestCase):
    def test_renders_shards_sorted_by_name_with_links_and_durations(self):
        jobs = [
            job('ci / build-and-test (windows-x64)', conclusion='failure', url='https://github.test/j/2'),
            job('ci / build-and-test (linux-x64)', completed='2026-07-10T12:00:59Z', url='https://github.test/j/1'),
            job(f'ci / {SELF_JOB_NAME}', conclusion=None),
        ]
        self.assertEqual(
            render_matrix_comment.render(jobs, SELF_JOB_NAME, TITLE),
            '## C# build matrix\n'
            '\n'
            '| shard | result | duration |\n'
            '| --- | --- | --- |\n'
            '| [linux-x64](https://github.test/j/1) | ✅ success | 59s |\n'
            '| [windows-x64](https://github.test/j/2) | ❌ failure | 3m 42s |\n',
        )

    def test_excludes_sibling_workflow_shards_sharing_shard_names(self):
        jobs = [
            job('csharp / build-and-test (linux-x64)', url='https://github.test/j/csharp'),
            job('scala / build-and-test (linux-x64)', conclusion='failure', url='https://github.test/j/scala'),
            job(f'csharp / {SELF_JOB_NAME}', conclusion=None),
            job('scala / matrix-comment (scala)', conclusion=None),
        ]
        rendered = render_matrix_comment.render(jobs, SELF_JOB_NAME, TITLE)
        self.assertIn('https://github.test/j/csharp', rendered)
        self.assertNotIn('https://github.test/j/scala', rendered)
        self.assertNotIn('failure', rendered)

    def test_parses_concatenated_paginated_pages(self):
        text = page(job('ci / build-and-test (a)')) + '\n' + page(job('ci / build-and-test (b)'))
        self.assertEqual(
            [entry['name'] for entry in render_matrix_comment.parse_job_pages(text)],
            ['ci / build-and-test (a)', 'ci / build-and-test (b)'],
        )

    def test_renders_cancelled_and_skipped_labels(self):
        jobs = [
            job('ci / build-and-test (a)', conclusion='cancelled'),
            job('ci / build-and-test (b)', conclusion='skipped', started=None, completed=None),
            job(f'ci / {SELF_JOB_NAME}', conclusion=None),
        ]
        rendered = render_matrix_comment.render(jobs, SELF_JOB_NAME, TITLE)
        self.assertIn('| 🚫 cancelled |', rendered)
        self.assertIn('| ⏭️ skipped | — |', rendered)

    def test_missing_self_job_fails_loudly(self):
        with self.assertRaises(ValueError):
            render_matrix_comment.render(
                [job('ci / build-and-test (a)')], SELF_JOB_NAME, TITLE
            )

    def test_duplicate_self_job_fails_loudly(self):
        jobs = [
            job(f'one / {SELF_JOB_NAME}', conclusion=None),
            job(f'two / {SELF_JOB_NAME}', conclusion=None),
        ]
        with self.assertRaises(ValueError):
            render_matrix_comment.render(jobs, SELF_JOB_NAME, TITLE)

    def test_no_shard_jobs_fails_loudly(self):
        with self.assertRaises(ValueError):
            render_matrix_comment.render(
                [job(f'ci / {SELF_JOB_NAME}', conclusion=None)], SELF_JOB_NAME, TITLE
            )

    def test_unknown_conclusion_fails_loudly(self):
        jobs = [
            job('ci / build-and-test (a)', conclusion='mystery'),
            job(f'ci / {SELF_JOB_NAME}', conclusion=None),
        ]
        with self.assertRaises(ValueError):
            render_matrix_comment.render(jobs, SELF_JOB_NAME, TITLE)

    def test_in_progress_shard_conclusion_fails_loudly(self):
        jobs = [
            job('ci / build-and-test (a)', conclusion=None),
            job(f'ci / {SELF_JOB_NAME}', conclusion=None),
        ]
        with self.assertRaises(ValueError):
            render_matrix_comment.render(jobs, SELF_JOB_NAME, TITLE)

    def test_negative_or_missing_duration_renders_unknown(self):
        self.assertEqual(
            render_matrix_comment.format_duration(
                job('x', started='2026-07-10T12:05:00Z', completed='2026-07-10T12:00:00Z')
            ),
            '—',
        )
        self.assertEqual(
            render_matrix_comment.format_duration(job('x', started=None)), '—'
        )


if __name__ == '__main__':
    unittest.main()

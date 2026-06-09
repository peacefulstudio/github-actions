# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0


def sort_coverage_table(text: str) -> str:
    first_cell = lambda row: row.split('|')[1].strip()
    lines = text.splitlines(keepends=True)
    result, i, sorted_first = [], 0, False
    while i < len(lines):
        line = lines[i]
        if not sorted_first and line.startswith('|'):
            result.append(line)
            i += 1
            if i < len(lines) and lines[i].startswith('|'):
                result.append(lines[i])
                i += 1
            data, summary = [], []
            while i < len(lines) and lines[i].startswith('|'):
                if first_cell(lines[i]).startswith('**'):
                    summary.append(lines[i])
                else:
                    data.append(lines[i])
                i += 1
            data.sort(key=lambda r: first_cell(r).lower())
            result.extend(data)
            result.extend(summary)
            sorted_first = True
        else:
            result.append(line)
            i += 1
    return ''.join(result)


if __name__ == '__main__':
    import os
    with open('code-coverage-results.md') as f:
        text = f.read()
    with open('code-coverage-results.md.tmp', 'w') as f:
        f.write(sort_coverage_table(text))
    os.replace('code-coverage-results.md.tmp', 'code-coverage-results.md')

# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0

SEPARATOR_CHARSET = set('-: \t')


def _cells(line: str) -> list[str]:
    stripped = line.strip()
    if '|' not in stripped:
        return []
    return stripped.strip('|').split('|')


def _is_table_row(line: str) -> bool:
    return len(_cells(line)) >= 2


def _is_separator_row(line: str) -> bool:
    cells = _cells(line)
    return len(cells) >= 2 and all(cell.strip() and set(cell) <= SEPARATOR_CHARSET for cell in cells)


def _is_table_start(lines: list[str], i: int) -> bool:
    return (
        _is_table_row(lines[i])
        and not _is_separator_row(lines[i])
        and i + 1 < len(lines)
        and _is_separator_row(lines[i + 1])
    )


def _first_cell(row: str) -> str:
    return _cells(row)[0].strip()


def contains_table(text: str) -> bool:
    lines = text.splitlines(keepends=True)
    return any(_is_table_start(lines, i) for i in range(len(lines)))


def sort_coverage_table(text: str) -> str:
    lines = text.splitlines(keepends=True)
    result, i, sorted_first = [], 0, False
    while i < len(lines):
        if not sorted_first and _is_table_start(lines, i):
            result.append(lines[i])
            result.append(lines[i + 1])
            i += 2
            data, summary = [], []
            while i < len(lines) and _is_table_row(lines[i]):
                if _first_cell(lines[i]).startswith('**'):
                    summary.append(lines[i])
                else:
                    data.append(lines[i])
                i += 1
            data.sort(key=lambda row: _first_cell(row).lower())
            result.extend(data)
            result.extend(summary)
            sorted_first = True
        else:
            result.append(lines[i])
            i += 1
    return ''.join(result)


if __name__ == '__main__':
    import os
    with open('code-coverage-results.md') as f:
        text = f.read()
    if not contains_table(text):
        print('::warning::sort-coverage-table: no markdown table detected in code-coverage-results.md — output left unchanged')
    with open('code-coverage-results.md.tmp', 'w') as f:
        f.write(sort_coverage_table(text))
    os.replace('code-coverage-results.md.tmp', 'code-coverage-results.md')

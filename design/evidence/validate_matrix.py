"""Validate the acceptance matrix without conflating test runner counts with case IDs."""
from collections import Counter
from pathlib import Path
import re
import sys

matrix = Path(__file__).resolve().parents[1] / 'test_cases.md'
statuses = {'Passed', 'Partial', 'Failed', 'Blocked', 'Not run'}
expected_areas = {'ONB': 5, 'NAV': 4, 'CON': 5, 'LNC': 11, 'DET': 7, 'PAY': 5, 'WHT': 5, 'SEC': 4, 'BKP': 5, 'THM': 5, 'FIN': 6}
rows = []
errors = []
for number, line in enumerate(matrix.read_text(encoding='utf-8').splitlines(), 1):
    if not line.startswith('| **TC-'):
        continue
    cells = [c.strip() for c in line.strip('|').split('|')]
    if len(cells) != 15:
        errors.append(f'line {number}: expected 15 cells, got {len(cells)}')
        continue
    match = re.fullmatch(r'\*\*(TC-([A-Z]+)-(\d+))\*\*', cells[0])
    if not match:
        errors.append(f'line {number}: malformed ID')
        continue
    ident, area, _ = match.groups()
    if cells[8] not in statuses:
        errors.append(f'{ident}: invalid status {cells[8]!r}')
    if cells[8] != 'Not run' and any(c in {'', '—'} for c in cells[9:15]):
        errors.append(f'{ident}: missing execution provenance')
    if cells[8] == 'Not run' and cells[9] != '—':
        errors.append(f'{ident}: unexecuted case cites evidence')
    if any('Verified' in c for c in cells) or '100%' in line:
        errors.append(f'{ident}: overstated verification')
    rows.append((ident, area, cells[8]))
ids = [ident for ident, _, _ in rows]
if len(ids) != 62 or len(set(ids)) != 62:
    errors.append(f'expected 62 unique baseline IDs, got {len(ids)} rows and {len(set(ids))} unique')
areas = Counter(area for _, area, _ in rows)
if dict(areas) != expected_areas:
    errors.append(f'area baseline differs: {dict(areas)}')
for area, count in expected_areas.items():
    actual = {f'TC-{area}-{n:02d}' for n in range(1, count + 1)}
    present = {ident for ident, a, _ in rows if a == area}
    if actual != present:
        errors.append(f'{area}: missing {sorted(actual - present)}; unexpected {sorted(present - actual)}')
text = matrix.read_text(encoding='utf-8')
if '100%' in text or re.search(r'\bVerified\b', text):
    errors.append('document retains blanket verification language')
print(f'{len(ids)} rows / {len(set(ids))} unique IDs')
print('status counts:', dict(Counter(status for _, _, status in rows)))
for area in expected_areas:
    print(area, dict(Counter(status for _, a, status in rows if a == area)))
for error in errors:
    print('ERROR:', error, file=sys.stderr)
sys.exit(bool(errors))

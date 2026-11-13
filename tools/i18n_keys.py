#!/usr/bin/env python3
"""Собирает ключи tr('…')/trKeepKg('…') из lib/ и сверяет со словарём en.json."""
import json, re, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from i18n_wrap import mask, parse_string, is_string_start, quote_piece

def keys_of(src):
    m = mask(src)
    out = []
    for mt in re.finditer(r'\b(?:tr|trKeepKg)\(', m):
        i = mt.end()
        while i < len(src) and src[i] in ' \t\r\n':
            i += 1
        if i >= len(src) or not is_string_start(src, i):
            continue
        parts_all = []
        while i < len(src) and is_string_start(src, i):
            end, parts, raw, q, triple = parse_string(src, i)
            text = ''.join(p[1] if p[0] == 't' else '${…}' for p in parts)
            parts_all.append(quote_piece(text, q)[1:-1])
            i = end
            while i < len(src) and src[i] in ' \t\r\n':
                i += 1
        out.append(''.join(parts_all))
    return out

root = Path(sys.argv[1])
found = {}
for f in sorted(root.rglob('*.dart')):
    if f.name in ('i18n.dart', 'i18n_en.dart'):
        continue
    for k in keys_of(f.read_text()):
        found.setdefault(k, str(f.relative_to(root)))
en = json.load(open(Path(__file__).parent / 'en.json'))
cyr = re.compile('[А-Яа-яЁё]')
missing = [k for k in found if k not in en and cyr.search(k)]
unused = [k for k in en if k not in found]
print(json.dumps({'missing': missing, 'unused': unused}, ensure_ascii=False, indent=1))

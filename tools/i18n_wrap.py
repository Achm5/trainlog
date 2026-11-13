#!/usr/bin/env python3
"""Оборачивает русские строковые литералы Dart в tr('…', [args]) и снимает const там, где он стал недопустим.

Использование: i18n_wrap.py <lib_dir> [--write]
Печатает JSON: {"keys": {...}, "skipped": [...]}.
"""
import json
import re
import sys
from pathlib import Path

CYR = re.compile('[А-Яа-яЁё]')
EXCLUDE = {'data/seed.dart', 'domain/program_templates.dart', 'i18n.dart', 'i18n_en.dart', 'data/tables.dart',
           'data/database.dart'}


def parse_string(src, i):
    """src[i] — начало литерала (возможен префикс r). Возвращает (end, parts, raw). parts: ('t', text) | ('e', code, simple)."""
    raw = False
    if src[i] == 'r':
        raw = True
        i += 1
    q = src[i]
    triple = src.startswith(q * 3, i)
    qlen = 3 if triple else 1
    i += qlen
    parts, buf = [], []
    while True:
        if src.startswith(q * qlen, i):
            i += qlen
            break
        c = src[i]
        if not raw and c == '\\':
            buf.append(src[i:i + 2])
            i += 2
            continue
        if not raw and c == '$':
            if src[i + 1] == '{':
                depth, j = 1, i + 2
                while depth:
                    ch = src[j]
                    if ch in '\'"':
                        j = parse_string(src, j)[0]
                        continue
                    if ch == 'r' and src[j + 1] in '\'"' and not (src[j - 1].isalnum() or src[j - 1] == '_'):
                        j = parse_string(src, j)[0]
                        continue
                    if ch == '{':
                        depth += 1
                    elif ch == '}':
                        depth -= 1
                    j += 1
                if buf:
                    parts.append(('t', ''.join(buf)))
                    buf = []
                parts.append(('e', src[i + 2:j - 1], False))
                i = j
                continue
            m = re.match(r'[A-Za-z_][A-Za-z0-9_]*', src[i + 1:])
            if m:
                if buf:
                    parts.append(('t', ''.join(buf)))
                    buf = []
                parts.append(('e', m.group(0), True))
                i += 1 + m.end()
                continue
        buf.append(c)
        i += 1
    if buf:
        parts.append(('t', ''.join(buf)))
    return i, parts, raw, q, triple


def is_string_start(src, i):
    c = src[i]
    if c in '\'"':
        return True
    if c == 'r' and i + 1 < len(src) and src[i + 1] in '\'"':
        prev = src[i - 1] if i else ' '
        return not (prev.isalnum() or prev == '_')
    return False


def mask(src):
    """Та же длина; строки и комментарии заменены пробелами (переводы строк сохранены)."""
    out, i = [], 0
    n = len(src)
    while i < n:
        if src.startswith('//', i):
            j = src.find('\n', i)
            j = n if j < 0 else j
        elif src.startswith('/*', i):
            j = src.find('*/', i) + 2
        elif is_string_start(src, i):
            j = parse_string(src, i)[0]
        else:
            out.append(src[i])
            i += 1
            continue
        out.append(re.sub(r'[^\n]', ' ', src[i:j]))
        i = j
    return ''.join(out)


def match_close(m, i):
    """m[i] — открывающая скобка в маскированном тексте; индекс после парной закрывающей."""
    pairs = {'(': ')', '[': ']', '{': '}'}
    stack = [pairs[m[i]]]
    i += 1
    while stack:
        c = m[i]
        if c in pairs:
            stack.append(pairs[c])
        elif c == stack[-1]:
            stack.pop()
        i += 1
    return i


def skip_zones(src):
    m = mask(src)
    zones = []
    for mt in re.finditer(r'\benum\s+\w+[^{;]*\{', m):
        zones.append((mt.start(), match_close(m, mt.end() - 1)))
    for mt in re.finditer(r'\bconst\s+(?:[A-Za-z_][\w<>,?. ]*\s+)?[A-Za-z_]\w*\s*=(?!=)', m):
        i, depth = mt.end(), 0
        while i < len(m):
            c = m[i]
            if c in '([{':
                depth += 1
            elif c in ')]}':
                depth -= 1
            elif c == ';' and depth == 0:
                break
            i += 1
        zones.append((mt.start(), i))
    return zones


class Ctx:
    def __init__(self):
        self.keys = {}
        self.skipped = []


def quote_piece(text, q):
    """Текст литерала (как в исходнике) → одинарные кавычки."""
    if q == '"':
        text = text.replace('\\"', '"')
        text = re.sub(r"(?<!\\)'", "\\'", text)
    return "'" + text + "'"


def rebuild(parts, q, triple, raw, ctx, file):
    qq = q * (3 if triple else 1)
    out = ['r' if raw else '', qq]
    for p in parts:
        if p[0] == 't':
            out.append(p[1])
        elif p[2]:
            out.append('$' + p[1])
        else:
            out.append('${' + transform(p[1], ctx, file, []) + '}')
    out.append(qq)
    return ''.join(out)


def transform(src, ctx, file, zones):
    out, i, n = [], 0, len(src)
    while i < n:
        if src.startswith('//', i):
            j = src.find('\n', i)
            j = n if j < 0 else j
            out.append(src[i:j])
            i = j
            continue
        if src.startswith('/*', i):
            j = src.find('*/', i) + 2
            out.append(src[i:j])
            i = j
            continue
        if not is_string_start(src, i):
            out.append(src[i])
            i += 1
            continue
        # Серия соседних литералов.
        run, j = [], i
        while True:
            end, parts, raw, q, triple = parse_string(src, j)
            run.append((parts, raw, q, triple, src[j:end]))
            k = end
            while k < n and src[k] in ' \t\r\n':
                k += 1
            if k < n and is_string_start(src, k):
                run[-1] = run[-1] + (src[end:k],)
                j = k
            else:
                run[-1] = run[-1] + ('',)
                j = end
                break
        has_cyr = any(p[0] == 't' and CYR.search(p[1]) for parts, *_ in run for p in parts)
        any_raw = any(r[1] for r in run)
        any_triple = any(r[3] for r in run)
        in_zone = any(a <= i < b for a, b in zones)
        if not has_cyr or any_raw or any_triple or in_zone:
            if has_cyr:
                ctx.skipped.append({'file': file, 'line': src.count('\n', 0, i) + 1 if zones else None,
                                    'text': ''.join(r[4] for r in run)[:160]})
            for parts, raw, q, triple, _orig, gap in run:
                out.append(rebuild(parts, q, triple, raw, ctx, file))
                out.append(gap)
            i = j
            continue
        args, pieces, key = [], [], []
        for parts, raw, q, triple, _orig, gap in run:
            buf = []
            for p in parts:
                if p[0] == 't':
                    buf.append(p[1])
                else:
                    buf.append('{%d}' % len(args))
                    args.append(p[1] if p[2] else transform(p[1], ctx, file, []))
            text = ''.join(buf)
            piece = quote_piece(text, q)
            pieces.append(piece + gap)
            key.append(piece[1:-1])
        k = ''.join(key)
        ctx.keys.setdefault(k, []).append(file)
        out.append('tr(' + ''.join(pieces) + (', [' + ', '.join(args) + ']' if args else '') + ')')
        i = j
    return ''.join(out)


def strip_const(src):
    """Убирает const перед выражениями, внутри которых появился вызов tr(."""
    while True:
        m = mask(src)
        changed = False
        for mt in re.finditer(r'\bconst\s+', m):
            i = mt.end()
            # Объявление константы или конструктора — не выражение.
            if re.match(r'(?:[A-Za-z_][\w<>,?. ]*\s+)?[A-Za-z_]\w*\s*=(?!=)', m[i:]):
                continue
            j = i
            g = re.match(r'<[^;(){}\[\]]*?>\s*(?=[\[{])', m[j:])
            if g:
                j += g.end()
            if m[j] in '[{':
                end = match_close(m, j)
            else:
                g = re.match(r'[A-Za-z_][\w.]*(?:<[^;(){}\[\]]*?>)?(?:\.\w+)?\s*', m[j:])
                if not g:
                    continue
                j += g.end()
                if j >= len(m) or m[j] != '(':
                    continue
                end = match_close(m, j)
            if re.search(r'\btr\(', m[i:end]):
                src = src[:mt.start()] + src[i:]
                changed = True
                break
        if not changed:
            return src


def add_import(src):
    if "i18n.dart'" in src:
        return src
    line = "import 'package:trainlog/i18n.dart';\n"
    imports = list(re.finditer(r"^import .*?;\n", src, re.M))
    if imports:
        pos = imports[-1].end()
        return src[:pos] + line + src[pos:]
    lib = re.search(r'^library;\n', src, re.M)
    if lib:
        return src[:lib.end()] + '\n' + line + src[lib.end():]
    return line + '\n' + src


def main():
    root = Path(sys.argv[1])
    write = '--write' in sys.argv
    ctx = Ctx()
    for f in sorted(root.rglob('*.dart')):
        rel = str(f.relative_to(root))
        if rel in EXCLUDE or rel.endswith('.g.dart'):
            continue
        src = f.read_text()
        new = transform(src, ctx, rel, skip_zones(src))
        if new != src:
            new = add_import(strip_const(new))
            if write:
                f.write_text(new)
    print(json.dumps({'keys': ctx.keys, 'skipped': ctx.skipped}, ensure_ascii=False, indent=1))


if __name__ == '__main__':
    main()

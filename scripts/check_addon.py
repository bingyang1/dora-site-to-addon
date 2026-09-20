#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_addon.py —— Dora.js 扩展工程自检

用法:
    python3 check_addon.py <工程目录>

检查项:
    1. 目录结构（package/、components/index.js、main.js、package.json）
    2. package.json 必填字段 / uuid 格式 / JSON 合法性 / prefs 合法性
    3. 每个组件文件是否有 module.exports 与 type，type 是否合法
    4. $route('xxx') 的目标组件文件是否存在（跳过内置 @xxx 与 URL）
    5. JS 词法扫描：括号/引号是否闭合（正确跳过注释、字符串、正则）
    6. 常见反模式告警

退出码: 0 = 通过（可能有 warning），1 = 有 error
"""

import json
import os
import re
import sys

ERRORS = []
WARNINGS = []
INFOS = []

VALID_TYPES = {
    'list', 'video', 'audio', 'article', 'image', 'webview',
    'topTab', 'bottomTab', 'drawer', 'book', 'cartoon', 'compose'
}

NODE_BUILTINS = {
    'fs', 'path', 'crypto', 'url', 'http', 'https', 'os', 'util', 'zlib',
    'querystring', 'stream', 'events', 'buffer', 'child_process', 'assert',
    'net', 'tls', 'dns', 'readline', 'string_decoder', 'timers', 'vm'
}

PAIRS = {'{': '}', '(': ')', '[': ']'}
REGEX_PREV = set('([{,=:;!&|?+-*%^~<>')

ROUTE_RE = re.compile(r"\$route\(\s*['\"]([^'\"]+)['\"]")

PLACEHOLDER_UUID = '00000000-0000-4000-8000-000000000000'


def err(m):
    ERRORS.append(m)


def warn(m):
    WARNINGS.append(m)


def info(m):
    INFOS.append(m)


# ---------------------------------------------------------------- 词法扫描

def lex(src):
    """返回 (去掉注释的源码, 错误信息)。正确跳过字符串 / 模板串 / 正则 / 注释。"""
    out = []
    i = 0
    n = len(src)
    stack = []
    prev_sig = ''
    while i < n:
        c = src[i]

        # 行注释
        if c == '/' and i + 1 < n and src[i + 1] == '/':
            j = src.find('\n', i)
            end = n if j < 0 else j
            out.append(' ' * (end - i))
            i = end
            continue

        # 块注释
        if c == '/' and i + 1 < n and src[i + 1] == '*':
            j = src.find('*/', i + 2)
            end = n if j < 0 else j + 2
            out.append(''.join('\n' if ch == '\n' else ' ' for ch in src[i:end]))
            i = end
            continue

        # 字符串
        if c == '"' or c == "'":
            q = c
            start = i
            i += 1
            closed = False
            while i < n:
                if src[i] == '\\':
                    i += 2
                    continue
                if src[i] == q:
                    closed = True
                    i += 1
                    break
                if src[i] == '\n':
                    break
                i += 1
            if not closed:
                return ''.join(out), '字符串未闭合（位置 %d 附近）' % start
            out.append(src[start:i])
            prev_sig = 'str'
            continue

        # 模板字符串
        if c == '`':
            start = i
            i += 1
            closed = False
            while i < n:
                if src[i] == '\\':
                    i += 2
                    continue
                if src[i] == '`':
                    closed = True
                    i += 1
                    break
                i += 1
            if not closed:
                return ''.join(out), '模板字符串未闭合（位置 %d 附近）' % start
            out.append(src[start:i])
            prev_sig = 'str'
            continue

        # 正则字面量
        if c == '/' and (prev_sig == '' or prev_sig in REGEX_PREV):
            start = i
            i += 1
            in_class = False
            closed = False
            while i < n:
                ch = src[i]
                if ch == '\\':
                    i += 2
                    continue
                if ch == '[':
                    in_class = True
                elif ch == ']':
                    in_class = False
                elif ch == '/' and not in_class:
                    closed = True
                    i += 1
                    break
                elif ch == '\n':
                    break
                i += 1
            if not closed:
                out.append(c)
                i = start + 1
                prev_sig = c
                continue
            out.append(src[start:i])
            prev_sig = 're'
            continue

        if c in PAIRS:
            stack.append((PAIRS[c], i))
            out.append(c)
            prev_sig = c
            i += 1
            continue

        if c in '})]':
            if not stack or stack[-1][0] != c:
                return ''.join(out), '第 %d 字符处括号不匹配' % i
            stack.pop()
            out.append(c)
            prev_sig = c
            i += 1
            continue

        if not c.isspace():
            prev_sig = c
        out.append(c)
        i += 1

    if stack:
        return ''.join(out), '有未闭合的括号（最近一个在位置 %d）' % stack[-1][1]
    return ''.join(out), ''


# ---------------------------------------------------------------- 结构与包

def find_root(path):
    p = os.path.abspath(path)
    if os.path.isfile(p):
        p = os.path.dirname(p)
    if os.path.isfile(os.path.join(p, 'package', 'package.json')):
        return p, os.path.join(p, 'package')
    if os.path.isfile(os.path.join(p, 'package.json')):
        return os.path.dirname(p), p
    for dirpath, _dirs, filenames in os.walk(p):
        if 'package.json' in filenames and os.path.basename(dirpath) == 'package':
            return os.path.dirname(dirpath), dirpath
    return None, None


def dep_base(pkgname):
    if pkgname.startswith('@'):
        return '/'.join(pkgname.split('/')[:2])
    return pkgname.split('/')[0]


def check_package_json(pkg_dir):
    path = os.path.join(pkg_dir, 'package.json')
    if not os.path.isfile(path):
        err('缺少 package.json')
        return None
    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        err('package.json 不是合法 JSON: %s' % e)
        return None

    for key in ('name', 'displayName', 'version', 'uuid', 'main'):
        if not data.get(key):
            err('package.json 缺少必填字段: %s' % key)
    if not data.get('icon'):
        warn('package.json 没有 icon 字段（扩展会没有图标）')

    uuid = data.get('uuid', '')
    if uuid:
        if not re.match(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$', uuid
        ):
            err('uuid 格式不合法（应为 8-4-4-4-12）: %s' % uuid)
        elif uuid.lower() == PLACEHOLDER_UUID:
            err('uuid 还是模板占位值，未替换')

    main = data.get('main', 'main.js')
    if main and not os.path.isfile(os.path.join(pkg_dir, main)):
        err('package.json 的 main 指向的文件不存在: %s' % main)

    icon = data.get('icon')
    if icon and not os.path.isfile(os.path.join(pkg_dir, icon.lstrip('/'))):
        warn('图标文件不存在: %s' % icon)

    prefs = data.get('prefs')
    if prefs:
        pp = os.path.join(pkg_dir, prefs.lstrip('/'))
        if not os.path.isfile(pp):
            warn('prefs 指向的文件不存在: %s' % prefs)
        else:
            try:
                with open(pp, 'r', encoding='utf-8') as f:
                    pj = json.load(f)
                for k, v in pj.items():
                    for need in ('title', 'type', 'default'):
                        if need not in v:
                            warn('prefs.json 中 "%s" 缺少 %s' % (k, need))
                    if v.get('type') not in ('boolean', 'number', 'string', 'password'):
                        warn('prefs.json 中 "%s" 的 type 非法: %s' % (k, v.get('type')))
            except Exception as e:
                err('prefs.json 不是合法 JSON: %s' % e)

    search = (data.get('contributes') or {}).get('search')
    if search and not os.path.isfile(os.path.join(pkg_dir, 'components', search + '.js')):
        err('contributes.search 指向的组件不存在: components/%s.js' % search)

    deps = data.get('dependencies') or {}
    info('dependencies: %s' % (', '.join(sorted(deps.keys())) if deps else '(无)'))
    return data


def check_requires(label, src, deps):
    for pkgname in re.findall(r"require\(\s*['\"]([^'\"./][^'\"]*)['\"]\s*\)", src):
        base = dep_base(pkgname)
        if base in NODE_BUILTINS:
            continue
        if base not in deps and pkgname not in deps:
            warn('%s require(\'%s\') 但 package.json dependencies 未声明' % (label, pkgname))


def check_relative_requires(label, src, base_dir):
    """检查 require('./x') / require('../y') 指向的文件是否真实存在。"""
    for rel_req in re.findall(r"require\(\s*['\"](\.[^'\"]*)['\"]\s*\)", src):
        target = os.path.normpath(os.path.join(base_dir, rel_req))
        candidates = [
            target, target + '.js', target + '.json',
            os.path.join(target, 'index.js'), os.path.join(target, 'index.json'),
        ]
        if not any(os.path.isfile(c) for c in candidates):
            err('%s require(\'%s\') 找不到对应文件（试过 %s）'
                % (label, rel_req, '、'.join(os.path.basename(c) for c in candidates)))


def check_components(pkg_dir, pkg):
    comp_dir = os.path.join(pkg_dir, 'components')
    if not os.path.isdir(comp_dir):
        err('缺少 components/ 目录')
        return

    if not os.path.isfile(os.path.join(comp_dir, 'index.js')):
        err('缺少 components/index.js（点击扩展图标会没有反应）')

    js_files = []
    for dirpath, _dirs, filenames in os.walk(comp_dir):
        for fn in filenames:
            if fn.endswith('.js'):
                js_files.append(os.path.join(dirpath, fn))

    if not js_files:
        err('components/ 下没有 .js 文件')
        return

    existing = set()
    for fp in js_files:
        existing.add(os.path.relpath(fp, comp_dir)[:-3].replace(os.sep, '/'))

    type_of = {}
    deps = (pkg or {}).get('dependencies') or {}

    for fp in sorted(js_files):
        rel = os.path.relpath(fp, comp_dir).replace(os.sep, '/')
        with open(fp, 'r', encoding='utf-8', errors='replace') as f:
            src, lex_err = lex(f.read())
        if not src.strip():
            warn('%s 是空文件，已跳过' % rel)
            continue
        if lex_err:
            err('%s 语法可疑: %s' % (rel, lex_err))

        if 'module.exports' not in src:
            err('%s 没有 module.exports（组件必须导出对象）' % rel)

        m = re.search(r"type\s*:\s*['\"]([A-Za-z]+)['\"]", src)
        if not m:
            info('%s 未显式声明 type（Dora.js 会按 list 处理）' % rel)
        else:
            t = m.group(1)
            type_of[rel] = t
            if t not in VALID_TYPES:
                err('%s 的 type 非法: %s' % (rel, t))

        if re.search(r'fetch\s*:\s*(async\s*)?\(?[^)]*\)?\s*=>', src):
            warn('%s 的 fetch 使用了箭头函数，this 可能丢失' % rel)
        if re.search(r"\$route\(\s*['\"][^'\"]+\.js['\"]", src):
            err('%s 中 $route 路径带了 .js 后缀' % rel)

        for target in ROUTE_RE.findall(src):
            if target.startswith('@') or '://' in target or target.startswith('market:'):
                continue
            if target not in existing:
                err("%s 中 $route('%s') 指向的组件不存在（应为 components/%s.js）"
                    % (rel, target, target))

        check_requires(rel, src, deps)
        check_relative_requires(rel, src, os.path.dirname(fp))

    if type_of:
        info('组件类型: %s' % ', '.join('%s=%s' % (k, v) for k, v in sorted(type_of.items())))

    main = os.path.join(pkg_dir, 'main.js')
    if os.path.isfile(main):
        with open(main, 'r', encoding='utf-8', errors='replace') as f:
            msrc, mlex = lex(f.read())
        if mlex:
            err('main.js 语法可疑: %s' % mlex)
        check_requires('main.js', msrc, deps)
        check_relative_requires('main.js', msrc, pkg_dir)

    # scripts/ 目录（公共模块 / WebView 注入脚本）语法检查
    scripts_dir = os.path.join(pkg_dir, 'scripts')
    if os.path.isdir(scripts_dir):
        n = 0
        for dirpath, _d, fns in os.walk(scripts_dir):
            for fn in fns:
                if not fn.endswith('.js'):
                    continue
                n += 1
                fp = os.path.join(dirpath, fn)
                with open(fp, 'r', encoding='utf-8', errors='replace') as f:
                    ssrc, slerr = lex(f.read())
                if slerr:
                    err('scripts/%s 语法可疑: %s' % (fn, slerr))
                check_relative_requires('scripts/' + fn, ssrc, os.path.dirname(fp))
        if n:
            info('scripts/ 下有 %d 个 js（公共模块或 WebView 注入脚本）' % n)


def check_misc(root, pkg_dir):
    for bad in ('node_modules', '.git', '__pycache__'):
        if os.path.isdir(os.path.join(root, bad)):
            warn('工程里存在 %s，打包时记得排除' % bad)
    if not os.path.isdir(os.path.join(pkg_dir, 'assets')):
        info('没有 assets/ 目录（非必需）')
    if not os.path.isfile(os.path.join(pkg_dir, 'README.md')):
        warn('建议添加 README.md（扩展详情页会展示）')


def main():
    if len(sys.argv) < 2:
        print('用法: python3 check_addon.py <工程目录>')
        sys.exit(1)

    root, pkg_dir = find_root(sys.argv[1])
    if not root:
        print('[x] 找不到 Dora.js 工程（需要存在 package/package.json）')
        sys.exit(1)

    print('检查工程: %s' % root)
    print('-' * 62)

    pkg = check_package_json(pkg_dir)
    check_components(pkg_dir, pkg)
    check_misc(root, pkg_dir)

    for m in INFOS:
        print('  [i] %s' % m)
    for m in WARNINGS:
        print('  [!] %s' % m)
    for m in ERRORS:
        print('  [x] %s' % m)

    print('-' * 62)
    print('结果: %d error, %d warning' % (len(ERRORS), len(WARNINGS)))
    if not ERRORS:
        print('[OK] 结构检查通过。可执行: sh scripts/build_dora.sh "%s"' % root)
    sys.exit(1 if ERRORS else 0)


if __name__ == '__main__':
    main()
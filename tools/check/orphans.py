import subprocess, sys

def git(*a):
    return subprocess.run(['git', *a], capture_output=True, text=True, check=True).stdout

target = sys.argv[1] if len(sys.argv) > 1 else 'HEAD'
since = sys.argv[2] if len(sys.argv) > 2 else '2026-11-01'

def pid(h):
    out = subprocess.run(['git', 'patch-id', '--stable'], input=git('show', h), capture_output=True, text=True).stdout
    return out.split()[0] if out.strip() else None

have = {pid(h) for h in git('log', '--format=%H', f'--since={since}', target).split()}
found = 0
for b in git('for-each-ref', '--format=%(refname:short)', 'refs/heads/', 'refs/remotes/').split():
    for line in git('log', '--format=%H %s', f'--since={since}', b, '--not', target).splitlines():
        h, s = line.split(' ', 1)
        if pid(h) not in have:
            found += 1
            print(f'{b}  {h[:7]}  {s[:90]}')
print(f'{target}에 없는 커밋 {found}개' if found else f'모든 브랜치의 커밋이 {target}에 들어 있음')
sys.exit(1 if found else 0)

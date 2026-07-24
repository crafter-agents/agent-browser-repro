#!/bin/bash
# DEEP #1506: reproduce the reporter's EXACT Python repro. The real mechanism is
# NOT detachment — it's captured-but-undrained stdout/stderr PIPEs. Chrome fills
# the pipe buffer, blocks on write, dies. Test: PIPE-captured vs inherited stdio.
set -uo pipefail
[ "$RUNNER_OS" != "Windows" ] && { echo "SKIP: Windows-only"; exit 0; }
echo "=== deep #1506: undrained PIPE vs inherited stdio ==="

python -c "
import subprocess, time, os, tempfile, shutil, glob
# find a chrome
cands = glob.glob(os.path.expandvars(r'%LOCALAPPDATA%\\ms-playwright\\chromium*\\chrome-win*\\chrome.exe')) + \
        [os.path.expandvars(r'%ProgramFiles%\\Google\\Chrome\\Application\\chrome.exe')]
chrome = next((c for c in cands if os.path.exists(c)), None)
print('chrome:', chrome)
if not chrome: raise SystemExit(0)

def run(capture):
    prof = tempfile.mkdtemp(prefix='ab_')
    args = [chrome,'--headless=new','--remote-debugging-port=0','--no-first-run','--no-default-browser-check',f'--user-data-dir={prof}','--disable-gpu']
    kw = dict(stdout=subprocess.PIPE, stderr=subprocess.PIPE) if capture else {}
    p = subprocess.Popen(args, **kw)
    time.sleep(3)
    alive = p.poll() is None
    if alive: p.kill()
    return alive, p.returncode

a_pipe, rc_pipe = run(True)
print(f'CAPTURED-PIPE (undrained): alive={a_pipe} code={rc_pipe}')
a_inh, rc_inh = run(False)
print(f'INHERITED-STDIO: alive={a_inh} code={rc_inh}')

if (not a_pipe) and a_inh:
    print('CONFIRMED-1506: Chrome dies ONLY when stdout/stderr are captured-but-undrained (pipe buffer). NOT a detach bug.')
elif a_pipe and a_inh:
    print('BOTH-ALIVE: neither died on this runner (pipe buffer not filled in 3s / different chrome build)')
else:
    print(f'OTHER: pipe={a_pipe} inherited={a_inh}')
" 2>&1
echo "=== done ==="

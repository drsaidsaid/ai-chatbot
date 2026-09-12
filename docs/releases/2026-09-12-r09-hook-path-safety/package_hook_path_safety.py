import pathlib,json,subprocess,os,shutil,hashlib
root=pathlib.Path.cwd();tmp=root/'tmp/r09';source='4fb90d61fb9fa977957b4d4b27109059e072995c';base='b78b7053fd09794a6db91e4b761c6472997df902';release=root/'docs/releases/2026-09-12-r09-hook-path-safety'
assert json.loads((tmp/'hook-final-green-verification.json').read_text())['whole_tree_equal']
assert subprocess.check_output(['git','diff','--name-only',base,source]).decode().splitlines()==['.husky/pre-commit','spec/system/pre_commit_spec.rb']
subprocess.run(['python3',str(tmp/'whole_tree_manifest.py'),source,'hook-final-manifest'],check=True)
release.mkdir(exist_ok=False)
prefixes=['hook-path-coverage-red','hook-path-coverage-green','hook-check-failure-red','hook-check-failure-green','hook-staging-failure-red','hook-staging-failure-green','hook-enumeration-failure-red','hook-enumeration-failure-green','hook-final','hook-regression-clean-lint','checkpoint-xargs-diagnosis','checkpoint-final-parity','checkpoint-commit-result','checkpoint-normal-hooks']
for prefix in prefixes:
 for p in tmp.glob(prefix+'*'):
  if p.is_file() and p.suffix in ('.json','.log','.txt','.sha256'):
   shutil.copyfile(p,release/(p.stem+'-log.txt' if p.suffix=='.log' else p.name))
for n in ['verify_cleanup_group.py','whole_tree_manifest.py','package_hook_path_safety.py']:shutil.copyfile(tmp/n,release/n)
(release/'hook-only-source.diff').write_bytes(subprocess.check_output(['git','diff',base,source]))
(release/'original-pre-commit.txt').write_bytes(subprocess.check_output(['git','show',base+':.husky/pre-commit']))
cycles=[]
for group in ['hook-path-coverage','hook-check-failure','hook-staging-failure','hook-enumeration-failure']:
 pair={}
 for state in ['red','green']:
  v=json.loads((tmp/(group+'-'+state+'-verification.json')).read_text());j=json.loads((tmp/(group+'-'+state+'-results.json')).read_text());pair[state]={'source_tree':v['source_tree'],'whole_tree_equal':v['whole_tree_equal'],'summary':j['summary']}
 cycles.append({'behavior':group,'evidence':pair})
(release/'red-green-cycles.json').write_text(json.dumps(cycles,indent=2)+'\n')
(release/'README.md').write_text('''# Pre-commit path safety follow-up

Reviewed R09 checkpoint `b78b7053fd09794a6db91e4b761c6472997df902` is preserved. Its normal hook ran without bypass, but two existing macOS xargs expansion errors were masked by `|| true`: only 61 clean Ruby invocations appeared for 96 staged Ruby paths. The checkpoint exactly matches its packaged tree; no hook source changes occurred. The authoritative full R09 lint/test/build evidence remains valid, but complete checkpoint-hook coverage is not claimed.

Candidate source `4fb90d61fb9fa977957b4d4b27109059e072995c` changes only `.husky/pre-commit` and adds `spec/system/pre_commit_spec.rb`. Application/runtime files are unchanged. Root review is required before the separate normal-hook follow-up commit; no amend, push, integration, issue closure or deployment is performed. Browser acceptance remains externally blocked.

## Fix

The existing lint-staged command stays unchanged. Git paths are read with NUL delimiters and passed as individual Ruby subprocess arguments, avoiding shell interpolation and macOS xargs replacement limits. The same existing staged files are selected; the same Ruby extension filter, RuboCop flags and restaging scope remain. Every eligible Ruby path is checked even when another fails. Enumeration, Ruby-check and staging failures now produce a failed hook rather than being silently ignored. No linter rule, formatter policy or exclusion changes.

## Validation

Six public-hook scratch-repository tests pass against the exact frozen source. Real Git and the actual Husky bootstrap are used, with executable stand-ins only for the external formatter/linter commands. Tests cover ordinary, spaced, newline and long filenames; all eligible paths formatted and staged; non-Ruby evidence and unstaged files untouched; absent files skipped; Ruby failure while continuing coverage; real Git index-lock staging failure; missing repository enumeration failure; and existing lint-staged failure propagation.

Four red/green cycles retain exact source refs, invocations, counts and complete before/after identity. Each red failed on its intended behavior before its narrow fix. The final six-example run has zero failures/pending. The test file and inline Ruby are lint-clean; shell and Ruby syntax checks pass. The public command tests are under the existing system-spec convention. No new lint suppression/exclusion was added.

The initial macOS failure was also reproduced using one actual 155-character evidence path; an argument-based invocation round-tripped it without changing repository state. Logs and diagnosis are retained. Full product tests are not re-attributed to this hook-only source.
''')
(release/'evidence-files.sha256').write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(release)}\n' for p in sorted(release.rglob('*')) if p.is_file() and p.name!='evidence-files.sha256'))
e=os.environ.copy();e['GIT_INDEX_FILE']=str(tmp/'hook-path-safety-evidence.index')
def git(*a):return subprocess.check_output(['git',*a],env=e).decode().strip()
git('read-tree',source);git('add','--',str(release.relative_to(root)));tree=git('write-tree');delta=git('diff','--name-only',source,tree).splitlines();assert all(p.startswith(str(release.relative_to(root))+'/') for p in delta);git('update-ref','refs/r09/hook-path-safety-evidence-20260912',tree,'0'*40)
report={'source_tree':source,'evidence_tree':tree,'release_only_delta_count':len(delta),'release_directory':str(release.relative_to(root))};(tmp/'hook-path-safety-handoff.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))

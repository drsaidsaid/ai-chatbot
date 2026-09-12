import pathlib,json,subprocess,hashlib,shutil,os
root=pathlib.Path.cwd();tmp=root/'tmp/r09';source='202e5c6d590dba3c8d5ff6ad100f7a1ea76d2944';release=root/'docs/releases/2026-09-12-r09-hook-option-path'
v=json.loads((tmp/'hook-option-path-green-verification.json').read_text());assert v['source_tree']==source and v['whole_tree_equal'] and v['exit_code']==0
parity=subprocess.check_output(['git','diff','--name-only','ee1f82ed55bd2a8878ceedc6ddef0f89b3030984',source,'--','.',':(exclude)docs/releases/**',':(exclude).husky/pre-commit',':(exclude)spec/system/pre_commit_spec.rb']).decode().strip();assert not parity,parity
subprocess.run(['python3',str(tmp/'whole_tree_manifest.py'),source,'hook-option-manifest'],check=True)
release.mkdir(exist_ok=False)
for p in tmp.glob('hook-option-*'):
 if p.is_file() and p.suffix in ('.json','.log','.txt','.sha256'):shutil.copyfile(p,release/(p.stem+'-log.txt' if p.suffix=='.log' else p.name))
for name in ['verify_cleanup_group.py','whole_tree_manifest.py','package_hook_option_path.py']:shutil.copyfile(tmp/name,release/name)
(release/'correction.diff').write_bytes(subprocess.check_output(['git','diff','4fb90d61fb9fa977957b4d4b27109059e072995c',source,'--','.husky/pre-commit','spec/system/pre_commit_spec.rb']))
(release/'README.md').write_text('''# Hook option-like pathname correction

This supersedes the uncommitted hook candidate from the prior path-safety package. Root identified that a pathname such as `--require=payload.rb` could be interpreted by RuboCop as an option. The hook now inserts the `--` option terminator before each pathname. No formatter/linter flags, eligible-file scope or application code changed.

Red source `a5c53493e7649807cbdf25c9ff9f0af1f776332b`: all six prior cases passed and the new option-like pathname case failed because it was parsed as a linter option. The executable linter stand-in now separates and validates command/options/pathnames, instead of assuming every argument after the initial flags is a filename. It rejects unexpected options without executing Ruby payloads.

Green source `202e5c6d590dba3c8d5ff6ad100f7a1ea76d2944`, ref `refs/r09/hook-option-path-green-source-20260912`: seven tests pass, zero failures/pending. Full source before/after equal. Test-file and inline-Ruby lint have zero findings; shell/Ruby syntax pass. The application source remains identical to reviewed `ee1f82ed`; only the hook and its system regression differ outside release evidence. No application tests/build rerun is attributed to this hook-only change.

Checkpoint `b78b7053fd09794a6db91e4b761c6472997df902` remains unchanged. Narrow root review is pending before a separate normal-hook follow-up commit. Browser acceptance remains externally blocked. No push/integration/deployment/issue closure performed.
''')
(release/'evidence-files.sha256').write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(release)}\n' for p in sorted(release.rglob('*')) if p.is_file() and p.name!='evidence-files.sha256'))
e=os.environ.copy();e['GIT_INDEX_FILE']=str(tmp/'hook-option-evidence.index')
def git(*a):return subprocess.check_output(['git',*a],env=e).decode().strip()
git('read-tree',source);git('add','--',str(release.relative_to(root)));tree=git('write-tree');delta=git('diff','--name-only',source,tree).splitlines();assert all(p.startswith(str(release.relative_to(root))+'/') for p in delta);git('update-ref','refs/r09/hook-option-path-evidence-20260912',tree,'0'*40);report={'source_tree':source,'evidence_tree':tree,'release_only_delta_count':len(delta),'app_source_parity':True};(tmp/'hook-option-handoff.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))

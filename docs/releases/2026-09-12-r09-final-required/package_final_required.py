import pathlib,json,subprocess,os,shutil,hashlib
root=pathlib.Path.cwd();tmp=root/'tmp/r09';prefix='final-required';source=json.loads((tmp/(prefix+'-identity.json')).read_text())['source_tree'];verification=json.loads((tmp/(prefix+'-verification.json')).read_text())
assert [r['name'] for r in verification['runs']]==['rails','vue','rubocop','eslint','build']
assert all(r['whole_tree_equal'] and r['before']==source and r['after']==source and r['exit_code']==0 for r in verification['runs'])
subprocess.run(['python3',str(tmp/'whole_tree_manifest.py'),source,prefix+'-after'],check=True)
rails=json.loads((tmp/(prefix+'-rails-results.json')).read_text())['summary'];vue=json.loads((tmp/(prefix+'-vue-results.json')).read_text());lint=json.loads((tmp/(prefix+'-rubocop-results.json')).read_text())['summary'];eslint=json.loads((tmp/(prefix+'-eslint-results.json')).read_text());inventory=json.loads((tmp/(prefix+'-inventory.json')).read_text())
summary={'source_tree':source,'rails':rails,'rails_spec_files':len(inventory['required_rails_files']),'vue':{k:vue.get(k) for k in ['numTotalTests','numPassedTests','numFailedTests','numPendingTests','numTotalTestSuites']},'rubocop':lint,'eslint':{'errors':sum(f['errorCount'] for f in eslint),'warnings':sum(f['warningCount'] for f in eslint)},'production_build':'passed','all_invocations_whole_source_equal':True,'browser_acceptance':'pending: root reported Mac lock and request-header policy failure','normal_hook_commit':'pending root review/checks and browser acceptance'}
(tmp/(prefix+'-summary.json')).write_text(json.dumps(summary,indent=2)+'\n')
release=root/'docs/releases/2026-09-12-r09-final-required';release.mkdir(parents=True,exist_ok=False)
for p in tmp.glob(prefix+'-*'):
 if p.is_file() and p.suffix in ('.json','.log','.sha256','.txt','.md'):
  shutil.copyfile(p,release/(p.stem+'-log.txt' if p.suffix=='.log' else p.name))
for name in ['prepare_final_required.py','verify_final_required.py','package_final_required.py','whole_tree_manifest.py','required-r09-rails-paths.json','required-r09-ruby-lint-paths.json','required-r09-eslint-paths.json']:shutil.copyfile(tmp/name,release/name)
readme=f'''# R09 final required verification

Complete source `{source}`, immutable ref `refs/r09/offer-final-required-source-20260912`.

Serial required checks all passed against this exact source:

- Rails: {rails['example_count']} examples, {rails['failure_count']} failures, {rails['pending_count']} pending across {summary['rails_spec_files']} required files. All changed existing Ruby specs, including renamed files and the new transaction regression, are included.
- Vue: {vue['numPassedTests']}/{vue['numTotalTests']} tests passed; {vue['numFailedTests']} failures.
- RuboCop: {lint['offense_count']} findings across {lint['inspected_file_count']} inspected files.
- ESLint: {summary['eslint']['errors']} errors, {summary['eslint']['warnings']} warnings; exact messages retained.
- Production asset build: passed.

Each invocation records its actual start/finish, command and complete source tree before/after. Every tree equals the frozen source. Full repository blob manifests before/after cover all tracked and newly added source; no runtime changes occurred during the serial run. This is the authoritative final-source test/build evidence, distinct from earlier cleanup checkpoints.

Browser acceptance is pending. Root freshly reported the Mac locked/automatic unlock unsuccessful and a browser request-header policy failure. No server was started by this task. `final-required-browser-resume.md` contains offline setup and acceptance instructions, not browser evidence. Root owns the pending unlock request and browser/server allocation. Normal-hook commit/integration/deployment remain pending root completion decisions.

The evidence tree adds only this release directory to the tested source. Private local runtime environment values are not included.
'''
(release/'README.md').write_text(readme)
(release/'evidence-files.sha256').write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(release)}\n' for p in sorted(release.rglob('*')) if p.is_file() and p.name!='evidence-files.sha256'))
e=os.environ.copy();e['GIT_INDEX_FILE']=str(tmp/(prefix+'-evidence.index'))
def git(*a):return subprocess.check_output(['git',*a],env=e).decode().strip()
git('read-tree',source);git('add','--',str(release.relative_to(root)));evidence=git('write-tree');delta=git('diff','--name-only',source,evidence).splitlines();assert all(p.startswith(str(release.relative_to(root))+'/') for p in delta);git('update-ref','refs/r09/offer-final-required-evidence-20260912',evidence,'0'*40)
handoff={'source_tree':source,'evidence_tree':evidence,'release_directory':str(release.relative_to(root)),'release_only_delta_count':len(delta),'summary':summary};(tmp/(prefix+'-handoff.json')).write_text(json.dumps(handoff,indent=2)+'\n');print(json.dumps(handoff))

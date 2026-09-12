import pathlib,json,hashlib,subprocess,os
root=pathlib.Path.cwd();tmp=root/'tmp/r09';proposal=json.loads((tmp/'checkpoint-packaging-proposal.json').read_text());reviewed=proposal['reviewed_evidence_tree'];release=root/'docs/releases/2026-09-12-r09-reviewed-checkpoint';release.mkdir(exist_ok=False)
for item in proposal['mapping']:
 original=root/item['original'];packaged=root/item['packaged'];assert hashlib.sha256(original.read_bytes()).hexdigest()==item['sha256'];assert original.read_bytes()==subprocess.check_output(['git','show',reviewed+':'+item['original']]);original.rename(packaged)
(release/'historical-ruby-path-map.json').write_text(json.dumps(proposal,indent=2)+'\n')
affected=sorted({str(pathlib.Path(item['original']).parts[2]) for item in proposal['mapping']}|{'2026-09-12-r09-final-required'})
for name in affected:
 folder=root/'docs/releases'/name;p=folder/'README.md';assert p.exists();s=p.read_text();note='''> Checkpoint packaging: saved Ruby evidence is now `.rb.txt` with unchanged bytes. Other SHA manifests in this historical package describe original paths/content and must be checked in a restored scratch copy, not directly here. `packaged-files.sha256` describes the current packaged files. See [the path map and restoration instructions](../2026-09-12-r09-reviewed-checkpoint/README.md). Proof scripts are not run in place.\n\n''';p.write_text(note+s)
 (folder/'packaged-files.sha256').write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(folder)}\n' for p in sorted(folder.rglob('*')) if p.is_file() and p.name!='packaged-files.sha256'))
text='''# R09 reviewed code checkpoint — browser acceptance pending

The coordinator reviewed complete source `ee1f82ed55bd2a8878ceedc6ddef0f89b3030984` and final verification evidence `68f0e3fd1e483ad17134e89405ac7e14feb065a5`. All bounded source reviews are clear. Final required verification passed: 457 Rails examples, 52 Vue tests, zero Ruby lint findings, zero ESLint errors (three existing dynamic translation-key warnings), and production build. All five invocations verified the exact complete source before and after.

This checkpoint is authorized while browser acceptance is externally blocked by the Mac lock and browser request-header policy failure. It does not establish ticket acceptance, integration or deployment. [Final verification](../2026-09-12-r09-final-required/README.md) and [offline browser resume instructions](../2026-09-12-r09-final-required/final-required-browser-resume.md) are retained.

## Evidence packaging

The normal pre-commit hook auto-corrects staged Ruby files. To preserve 104 historical before/red/proof payloads, their names now end in `.rb.txt`; every byte matches the reviewed evidence tree. [The path map](historical-ruby-path-map.json) records original path, packaged path and SHA-256 for each. The immutable historical Git trees and refs are unchanged. No hook bypass, lint exclusion or product source change is involved.

Historical `.sha256` manifests describe original paths/content, including the original package README. They are intentionally retained as historical evidence and are validated after scratch restoration. Each affected folder's new `packaged-files.sha256` validates its current packaged paths/content. Current README links use this mapping and no existing Markdown link targeted a renamed Ruby artifact.

## Scratch restoration

Run `python3 restore_reviewed_evidence.py /absolute/path/to/new-empty-scratch-directory` from this package. It verifies every mapped `.rb.txt` against its recorded hash and immutable Git object, then exports the complete original reviewed evidence tree into that empty directory. It never overwrites an existing nonempty directory and does not execute any proof, test, server or hook. This restores original Ruby names, original READMEs and original historical manifests together.

Use a separate disposable test database and the recorded invocation/environment requirements before reproducing a proof in the scratch copy. Private local environment values are deliberately not included. Do not execute historical proof scripts in the packaged release directory.
'''
(release/'README.md').write_text(text)
(release/'restore_reviewed_evidence.py').write_text('''import pathlib,json,hashlib,subprocess,sys,tarfile,io
package=pathlib.Path(__file__).resolve().parent
repository=package.parents[2]
report=json.loads((package/'historical-ruby-path-map.json').read_text())
for item in report['mapping']:
 data=(repository/item['packaged']).read_bytes()
 assert hashlib.sha256(data).hexdigest()==item['sha256'],item['packaged']
 assert data==subprocess.check_output(['git','show',report['reviewed_evidence_tree']+':'+item['original']],cwd=repository)
target=pathlib.Path(sys.argv[1]).expanduser().resolve()
assert target!=repository and repository not in target.parents,'Use an external scratch directory'
assert not target.exists() or not any(target.iterdir()),'Scratch directory must be empty'
archive=subprocess.check_output(['git','archive','--format=tar',report['reviewed_evidence_tree']],cwd=repository)
target.mkdir(parents=True,exist_ok=True)
with tarfile.open(fileobj=io.BytesIO(archive)) as tar:tar.extractall(target,filter='data')
for item in report['mapping']:assert hashlib.sha256((target/item['original']).read_bytes()).hexdigest()==item['sha256']
print(json.dumps({'restored_tree':report['reviewed_evidence_tree'],'scratch_directory':str(target),'historical_payloads':len(report['mapping']),'proofs_executed':False}))
''')
(release/'package_checkpoint_evidence.py').write_bytes(pathlib.Path(__file__).read_bytes())
(release/'evidence-files.sha256').write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(release)}\n' for p in sorted(release.rglob('*')) if p.is_file() and p.name!='evidence-files.sha256'))
e=os.environ.copy();e['GIT_INDEX_FILE']=str(tmp/'checkpoint-packaging.index')
def git(*a):return subprocess.check_output(['git',*a],env=e).decode().strip()
git('read-tree','HEAD');git('add','-A','--','.');tree=git('write-tree');delta=git('diff','--name-only',reviewed,tree).splitlines();assert all(p.startswith('docs/releases/') for p in delta);git('update-ref','refs/r09/offer-checkpoint-packaged-source-20260912',tree,'0'*40)
result={'reviewed_source':'ee1f82ed55bd2a8878ceedc6ddef0f89b3030984','reviewed_evidence':reviewed,'packaged_tree':tree,'evidence_only_changed_paths':len(delta),'renamed_payloads':len(proposal['mapping']),'updated_package_readmes':len(affected),'non_release_diff':git('diff','--name-only','ee1f82ed55bd2a8878ceedc6ddef0f89b3030984',tree,'--','.',':(exclude)docs/releases/**')};assert not result['non_release_diff'];(tmp/'checkpoint-packaging-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))

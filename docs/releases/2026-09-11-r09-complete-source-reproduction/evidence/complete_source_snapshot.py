import os, subprocess, pathlib, json, hashlib, sys
ROOT=pathlib.Path.cwd()
BASE='9a834e756347822d4ae5af15f268a5e8751fc852'
REL=pathlib.Path('docs/releases/2026-09-11-r09-complete-source-reproduction')
REF='refs/r09/shared-readers-complete-source-20260911'
ENV=os.environ.copy();ENV['GIT_INDEX_FILE']=str(ROOT/'tmp/r09/complete-source.index')
def git(*args): return subprocess.check_output(['git',*args],env=ENV)
def snapshot():
 git('read-tree',BASE);git('add','-A','--','.');return git('write-tree').decode().strip()
if sys.argv[1]=='freeze':
 assert subprocess.run(['git','rev-parse','--verify',REF],capture_output=True).returncode!=0, 'ref already exists'
 tree=snapshot()
 changed=git('diff','--name-status',BASE,tree).decode()
 (REL/'all-changes-from-accepted-base.txt').write_text(changed)
 source_changes=[line for line in changed.splitlines() if not line.split('\t')[-1].startswith('docs/') and line.split('\t')[-1] not in ['CONTEXT.md','PRODUCT_REQUIREMENTS.md','TECHNICAL_DESIGN.md']]
 (REL/'runtime-test-changes-from-accepted-base.txt').write_text('\n'.join(source_changes)+'\n')
 manifest=[];count=0
 for entry in git('ls-tree','-r','-z',tree).split(b'\0'):
  if not entry:continue
  meta,p=entry.split(b'\t');mode,kind,oid=meta.decode().split();p=p.decode()
  if p.startswith('docs/releases/'):continue
  f=ROOT/p
  data=os.readlink(f).encode() if f.is_symlink() else f.read_bytes()
  assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==oid,p
  manifest.append(f'{hashlib.sha256(data).hexdigest()}  {p}\n');count+=1
 (REL/'all-repository-source.sha256').write_text(''.join(manifest))
 tree=snapshot();git('update-ref',REF,tree,'0'*40)
 report={'tree':tree,'ref':REF,'base':BASE,'all_repository_source_count':count,'runtime_test_changed_count':len(source_changes),'directory_blob':git('rev-parse',tree+':app/services/ai_lead_employee/leads_directory_service.rb').decode().strip()}
 (ROOT/'tmp/r09/complete-source-identity.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
elif sys.argv[1]=='verify':
 expected=git('rev-parse',REF).decode().strip();actual=snapshot()
 if actual!=expected:
  print(git('diff','--name-status',expected,actual).decode());raise SystemExit('whole tree mismatch')
 print(json.dumps({'whole_tree_equal':True,'tree':actual,'stage':sys.argv[2]}))

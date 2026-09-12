import os,json,subprocess,pathlib,sys,hashlib
root=pathlib.Path.cwd();red=root/'tmp/r09/review-corrections-red-source'
env=os.environ.copy()
for k in ('DATABASE_URL','REDIS_SENTINELS','BUNDLE_PATH','BUNDLE_GEMFILE','GEM_HOME','GEM_PATH'):env.pop(k,None)
env.update(json.loads((root/'tmp/r09/environment.json').read_text()));env.pop('BUNDLE_PATH',None)
args=['/Users/ghalyasaid/.rbenv/versions/3.4.4/bin/bundle','exec','rspec','spec/requests/ai_lead_employee/offer_follow_up_terminal_invalidation_spec.rb','spec/requests/ai_lead_employee/offer_follow_up_lifecycle_races_spec.rb:303','spec/requests/whatsapp_alert_authority_spec.rb:102','--format','progress','--format','json','--out',str(root/'tmp/r09/lifecycle-corrections-red-results.json')]
identity=json.loads((root/'tmp/r09/lifecycle-corrections-red-identity.json').read_text())
def verify():
 entries=subprocess.check_output(['git','ls-tree','-rz',identity['source_tree']]).split(b'\0');count=0
 for entry in entries:
  if not entry:continue
  meta,path=entry.split(b'\t',1);p=red/os.fsdecode(path);data=os.readlink(p).encode() if p.is_symlink() else p.read_bytes();oid=meta.split()[2].decode()
  assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==oid,str(p)
  count+=1
 return count
before=verify()
with (root/'tmp/r09/lifecycle-corrections-red.log').open('w') as log:result=subprocess.run(args,cwd=red,env=env,stdout=log,stderr=subprocess.STDOUT)
after=verify()
report={'source_tree':identity['source_tree'],'before_files':before,'after_files':after,'all_source_blobs_equal':True,'exit_code':result.returncode,'invocation':args}
(root/'tmp/r09/lifecycle-corrections-red-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
sys.exit(result.returncode)

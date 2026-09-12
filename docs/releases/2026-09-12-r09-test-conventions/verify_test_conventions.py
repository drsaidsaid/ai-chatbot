import pathlib,json,subprocess,os,datetime,sys
root=pathlib.Path.cwd();tmp=root/'tmp/r09';e=os.environ.copy();e['GIT_INDEX_FILE']=str(tmp/'test-conventions-verify.index')
def git(*a):return subprocess.check_output(['git',*a],env=e).decode().strip()
def snapshot():
 git('read-tree','HEAD');git('add','-A','--','.');return git('write-tree')
source=snapshot();git('update-ref','refs/r09/test-conventions-after-source-20260912',source,'0'*40)
changed=git('diff','--name-only','c026a0319697e95b2b00770067bcce4b9b445542',source).splitlines();assert all(p.startswith('spec/') for p in changed),changed
paths=json.loads((tmp/'required-r09-ruby-lint-paths.json').read_text());specs=[p for p in paths if p.startswith('spec/') and p.endswith('_spec.rb')]
started=datetime.datetime.now(datetime.timezone.utc);deadline=started+datetime.timedelta(minutes=20)
identity={'source_tree':source,'before_tree':'c026a0319697e95b2b00770067bcce4b9b445542','changed_paths':changed,'test_paths':specs,'interval_start':started.isoformat(),'interval_deadline':deadline.isoformat()};(tmp/'test-conventions-identity.json').write_text(json.dumps(identity,indent=2)+'\n');print(json.dumps(identity),flush=True)
env=os.environ.copy();env.update(json.loads((tmp/'environment.json').read_text()))
for k in ('DATABASE_URL','REDIS_SENTINELS','BUNDLE_PATH','BUNDLE_GEMFILE','GEM_HOME','GEM_PATH'):env.pop(k,None)
runs=[]
for name,args in [('rails',['rspec',*specs,'--format','progress','--format','json','--out',str(tmp/'test-conventions-rails-results.json')]),('rubocop',['rubocop','--force-exclusion',*paths,'--format','json','--out',str(tmp/'test-conventions-rubocop-results.json')])]:
 command=['/Users/ghalyasaid/.rbenv/versions/3.4.4/bin/bundle','exec',*args];before=snapshot();assert before==source
 start=datetime.datetime.now(datetime.timezone.utc);(tmp/f'test-conventions-{name}-invocation.json').write_text(json.dumps(command,indent=2)+'\n')
 with (tmp/f'test-conventions-{name}.log').open('w') as log:
  result=subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=max(1,(deadline-start).total_seconds()))
 after=snapshot();run={'name':name,'before':before,'after':after,'whole_tree_equal':before==after==source,'started_at':start.isoformat(),'finished_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'exit_code':result.returncode};runs.append(run);(tmp/'test-conventions-verification.json').write_text(json.dumps({'source_tree':source,'runs':runs},indent=2)+'\n');print(json.dumps(run),flush=True)
 if after!=source or (result.returncode and name=='rails'):sys.exit(result.returncode or 2)

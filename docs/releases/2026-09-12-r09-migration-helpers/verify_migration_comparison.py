import os,pathlib,json,subprocess,datetime,sys
root=pathlib.Path.cwd();tmp=root/'tmp/r09';prefix,kind,*paths=sys.argv[1:];e=os.environ.copy();e['GIT_INDEX_FILE']=str(tmp/f'{prefix}.index')
def git(*a):return subprocess.check_output(['git',*a],env=e).decode().strip()
def snapshot():
 git('read-tree','HEAD');git('add','-A','--','.');return git('write-tree')
source=snapshot();git('update-ref',f'refs/r09/{prefix}-source-20260912',source,'0'*40)
(tmp/f'{prefix}-identity.json').write_text(json.dumps({'source_tree':source},indent=2)+'\n');print('source',source,flush=True)
if kind=='vue':args=['corepack','pnpm','exec','vitest','run',*paths,'--maxWorkers=1','--minWorkers=1','--reporter=default','--reporter=json',f'--outputFile=tmp/r09/{prefix}-results.json']
elif kind=='rails':args=['/Users/ghalyasaid/.rbenv/versions/3.4.4/bin/bundle','exec','rspec',*paths,'--format','progress','--format','json','--out',f'tmp/r09/{prefix}-results.json']
elif kind=='comparison':args=['/Users/ghalyasaid/.rbenv/versions/3.4.4/bin/bundle','exec','ruby',*paths]
else:raise ValueError(kind)
env=os.environ.copy()
if kind in ('rails','comparison'):
 env.update(json.loads((tmp/'environment.json').read_text()))
 for k in ('DATABASE_URL','REDIS_SENTINELS','BUNDLE_PATH','BUNDLE_GEMFILE','GEM_HOME','GEM_PATH'):env.pop(k,None)
started=datetime.datetime.now(datetime.timezone.utc).isoformat();before=snapshot();assert before==source
(tmp/f'{prefix}-invocation.json').write_text(json.dumps(args,indent=2)+'\n')
with (tmp/f'{prefix}.log').open('w') as log:result=subprocess.run(args,env=env,stdout=log,stderr=subprocess.STDOUT)
after=snapshot();report={'source_tree':source,'before':before,'after':after,'whole_tree_equal':before==after==source,'started_at':started,'finished_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'exit_code':result.returncode};(tmp/f'{prefix}-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report),flush=True)
sys.exit(result.returncode or (0 if report['whole_tree_equal'] else 2))

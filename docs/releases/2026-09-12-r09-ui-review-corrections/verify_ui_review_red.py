import os,subprocess,pathlib,json,sys
root=pathlib.Path.cwd();source=json.loads((root/'tmp/r09/ui-review-red-identity.json').read_text())['source_tree']
def snapshot():
 e=os.environ.copy();e['GIT_INDEX_FILE']=str(root/'tmp/r09/ui-review-red-verify.index')
 def git(*a):return subprocess.check_output(['git',*a],env=e).decode().strip()
 git('read-tree','HEAD');git('add','-A','--','.');return git('write-tree')
vue=['corepack','pnpm','exec','vitest','run','app/javascript/dashboard/routes/dashboard/owned/specs/LeadsDirectoryPage.spec.js','--maxWorkers=1','--minWorkers=1','--reporter=default','--reporter=json','--outputFile=tmp/r09/ui-review-red-vue-results.json']
ruby=['/Users/ghalyasaid/.rbenv/versions/3.4.4/bin/bundle','exec','rspec','spec/requests/ai_lead_employee/offer_shared_readers_spec.rb','--example','keeps authorized source-link query count bounded','--format','progress','--format','json','--out','tmp/r09/ui-review-red-rails-results.json']
report={'source_tree':source,'runs':[]}
for name,args in [('vue',vue),('rails',ruby)]:
 before=snapshot();assert before==source,(name,before,source)
 env=os.environ.copy()
 if name=='rails':
  env.update(json.loads((root/'tmp/r09/environment.json').read_text()))
  for key in ('DATABASE_URL','REDIS_SENTINELS','BUNDLE_PATH','BUNDLE_GEMFILE','GEM_HOME','GEM_PATH'):env.pop(key,None)
 (root/f'tmp/r09/ui-review-red-{name}-invocation.json').write_text(json.dumps(args,indent=2)+'\n')
 with (root/f'tmp/r09/ui-review-red-{name}.log').open('w') as log:result=subprocess.run(args,env=env,stdout=log,stderr=subprocess.STDOUT)
 after=snapshot();run={'name':name,'before':before,'after':after,'whole_tree_equal':before==after==source,'exit_code':result.returncode};report['runs'].append(run)
 (root/'tmp/r09/ui-review-red-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(run),flush=True)
 if after!=source:sys.exit(2)

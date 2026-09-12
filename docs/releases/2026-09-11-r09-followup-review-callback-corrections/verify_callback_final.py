import os, json, subprocess, pathlib, sys, hashlib
root=pathlib.Path.cwd()
identity=json.loads((root/'tmp/r09/callback-final-identity.json').read_text())
env=os.environ.copy()
for key in ('DATABASE_URL','REDIS_SENTINELS','BUNDLE_PATH','BUNDLE_GEMFILE','GEM_HOME','GEM_PATH'): env.pop(key,None)
env.update(json.loads((root/'tmp/r09/environment.json').read_text()))
env.pop('BUNDLE_PATH',None)
source=identity['source_tree']
def snapshot():
 e=os.environ.copy();e['GIT_INDEX_FILE']=str(root/'tmp/r09/callback-final-verify.index')
 def git(*a):return subprocess.check_output(['git',*a],env=e).decode().strip()
 git('read-tree','HEAD');git('add','-A','--','.')
 return git('write-tree')
before=snapshot();assert before==source,(before,source)
args=['/Users/ghalyasaid/.rbenv/versions/3.4.4/bin/bundle', 'exec', 'rspec', 'spec/requests/ai_lead_employee/offer_follow_up_terminal_invalidation_spec.rb', 'spec/requests/ai_lead_employee/offer_follow_up_lifecycle_races_spec.rb', 'spec/requests/whatsapp_alert_authority_spec.rb', 'spec/services/ai_lead_employee/follow_up_scheduler_spec.rb', 'spec/services/ai_lead_employee/follow_up_delivery_service_spec.rb', '--format', 'progress', '--format', 'json', '--out', 'tmp/r09/callback-final-results.json']
(root/'tmp/r09/callback-final-invocation.json').write_text(json.dumps(args,indent=2)+'\n')
with (root/'tmp/r09/callback-final.log').open('w') as log:
 result=subprocess.run(args,env=env,stdout=log,stderr=subprocess.STDOUT)
after=snapshot()
report={'source_tree':source,'before':before,'after':after,'whole_tree_equal':before==after==source,'exit_code':result.returncode}
(root/'tmp/r09/callback-final-verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report));sys.exit(result.returncode if after==source else 2)

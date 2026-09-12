import os,subprocess,pathlib,json,sys
root=pathlib.Path.cwd();source=json.loads((root/'tmp/r09/race-fixtures-identity.json').read_text())['source_tree']
def snapshot():
 e=os.environ.copy();e['GIT_INDEX_FILE']=str(root/'tmp/r09/race-fixtures-verify.index')
 def git(*a):return subprocess.check_output(['git',*a],env=e).decode().strip()
 git('read-tree','HEAD');git('add','-A','--','.');return git('write-tree')
vue=['corepack','pnpm','exec','vitest','run','app/javascript/dashboard/routes/dashboard/settings/aiLeadEmployee/specs/OfferConfigurationPanel.spec.js','app/javascript/dashboard/routes/dashboard/owned/specs/LeadsDirectoryPage.spec.js','app/javascript/dashboard/components/qualification/specs','app/javascript/dashboard/routes/dashboard/conversation/specs/AIEmployeeControlPanel.spec.js','app/javascript/dashboard/routes/dashboard/settings/aiLeadEmployee/specs/OwnedSettingsLayout.spec.js','app/javascript/dashboard/routes/dashboard/owned/specs/AiProviderSettingsPage.spec.js','app/javascript/dashboard/components-next/sidebar/specs/aiLeadEmployeeNavigation.spec.js','--maxWorkers=1','--minWorkers=1','--reporter=default','--reporter=json','--outputFile=tmp/r09/race-fixtures-vue-results.json']
ruby=['/Users/ghalyasaid/.rbenv/versions/3.4.4/bin/bundle','exec','rspec','spec/requests/ai_lead_employee/offer_delivery_admission_races_spec.rb','spec/requests/ai_lead_employee/offer_follow_up_lifecycle_races_spec.rb','spec/requests/ai_lead_employee/offer_follow_up_terminal_invalidation_spec.rb','--format','progress','--format','json','--out','tmp/r09/race-fixtures-rails-results.json']
report={'source_tree':source,'runs':[]}
for name,args in [('rails',ruby)]:
 before=snapshot();assert before==source,(name,before,source)
 env=os.environ.copy()
 if name=='rails':
  env.update(json.loads((root/'tmp/r09/environment.json').read_text()))
  for key in ('DATABASE_URL','REDIS_SENTINELS','BUNDLE_PATH','BUNDLE_GEMFILE','GEM_HOME','GEM_PATH'):env.pop(key,None)
 (root/f'tmp/r09/race-fixtures-{name}-invocation.json').write_text(json.dumps(args,indent=2)+'\n')
 with (root/f'tmp/r09/race-fixtures-{name}.log').open('w') as log:result=subprocess.run(args,env=env,stdout=log,stderr=subprocess.STDOUT)
 after=snapshot();run={'name':name,'before':before,'after':after,'whole_tree_equal':before==after==source,'exit_code':result.returncode};report['runs'].append(run)
 (root/'tmp/r09/race-fixtures-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(run),flush=True)
 if result.returncode or after!=source:sys.exit(result.returncode or 2)

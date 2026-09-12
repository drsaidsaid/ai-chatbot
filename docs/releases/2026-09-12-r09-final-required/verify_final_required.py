import os,subprocess,pathlib,json,sys,datetime
root=pathlib.Path.cwd();source=json.loads((root/'tmp/r09/final-required-identity.json').read_text())['source_tree']
def snapshot():
 e=os.environ.copy();e['GIT_INDEX_FILE']=str(root/'tmp/r09/final-required-verify.index')
 def git(*a):return subprocess.check_output(['git',*a],env=e).decode().strip()
 git('read-tree','HEAD');git('add','-A','--','.');return git('write-tree')
vue=['corepack','pnpm','exec','vitest','run','app/javascript/dashboard/routes/dashboard/settings/aiLeadEmployee/specs/OfferConfigurationPanel.spec.js','app/javascript/dashboard/routes/dashboard/owned/specs/LeadsDirectoryPage.spec.js','app/javascript/dashboard/components/qualification/specs','app/javascript/dashboard/routes/dashboard/conversation/specs/AIEmployeeControlPanel.spec.js','app/javascript/dashboard/routes/dashboard/settings/aiLeadEmployee/specs/OwnedSettingsLayout.spec.js','app/javascript/dashboard/routes/dashboard/owned/specs/AiProviderSettingsPage.spec.js','app/javascript/dashboard/components-next/sidebar/specs/aiLeadEmployeeNavigation.spec.js','--maxWorkers=1','--minWorkers=1','--reporter=default','--reporter=json','--outputFile=tmp/r09/final-required-vue-results.json']
ruby=['/Users/ghalyasaid/.rbenv/versions/3.4.4/bin/bundle','exec','rspec',*json.loads((root/'tmp/r09/required-r09-rails-paths.json').read_text()),'--format','progress','--format','json','--out','tmp/r09/final-required-rails-results.json']
rubocop=['/Users/ghalyasaid/.rbenv/versions/3.4.4/bin/bundle','exec','rubocop','--force-exclusion',*json.loads((root/'tmp/r09/required-r09-ruby-lint-paths.json').read_text()),'--format','json','--out','tmp/r09/final-required-rubocop-results.json']
eslint=['corepack','pnpm','exec','eslint',*json.loads((root/'tmp/r09/required-r09-eslint-paths.json').read_text()),'--format','json','--output-file','tmp/r09/final-required-eslint-results.json']
build=['corepack','pnpm','exec','vite','build']
report={'source_tree':source,'runs':[]}
for name,args in [('rails',ruby),('vue',vue),('rubocop',rubocop),('eslint',eslint),('build',build)]:
 before=snapshot();assert before==source,(name,before,source)
 env=os.environ.copy()
 if name=='build':env.update({'RAILS_ENV':'production','NODE_OPTIONS':'--max-old-space-size=6144'})
 if name in ('rails','rubocop'):
  env.update(json.loads((root/'tmp/r09/environment.json').read_text()))
  for key in ('DATABASE_URL','REDIS_SENTINELS','BUNDLE_PATH','BUNDLE_GEMFILE','GEM_HOME','GEM_PATH'):env.pop(key,None)
 (root/f'tmp/r09/final-required-{name}-invocation.json').write_text(json.dumps(args,indent=2)+'\n')
 started=datetime.datetime.now(datetime.timezone.utc).isoformat()
 print(json.dumps({'starting':name,'at':started,'source_tree':source}),flush=True)
 with (root/f'tmp/r09/final-required-{name}.log').open('w') as log:result=subprocess.run(args,env=env,stdout=log,stderr=subprocess.STDOUT)
 after=snapshot();run={'started_at':started,'finished_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'name':name,'before':before,'after':after,'whole_tree_equal':before==after==source,'exit_code':result.returncode};report['runs'].append(run)
 (root/'tmp/r09/final-required-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(run),flush=True)
 if after!=source:sys.exit(2)
 if result.returncode:sys.exit(result.returncode)

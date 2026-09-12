import pathlib,json,sys,collections
root=pathlib.Path.cwd();tmp=root/'tmp/r09';prefix=sys.argv[1];j=json.loads((tmp/f'{prefix}-rubocop-results.json').read_text())
def area(path):
 if path.startswith('spec/'):return 'Test conventions (expected clean)'
 if path.startswith('db/migrate/'):return 'Historical schema migrations'
 if path.endswith(('offer_qualification_service.rb','offer_human_evidence_writer.rb','qualification_evidence_audit.rb')):return 'Offer evidence recording and qualification decisions'
 if path.endswith(('qualification_evidence_extractor.rb','qualification_budget_evidence_extractor.rb','qualification_budget_clauses.rb')):return 'Spoken evidence and budget clause interpretation'
 if path.endswith(('outbound_delivery.rb','offer_delivery_context.rb','highly_qualified_handoff_service.rb','automated_contact_consent.rb')):return 'Delivery authority, outcome and handoff/consent'
 if path.endswith('leads_directory_service.rb'):return 'Leads directory preload and projection'
 if path.endswith(('account.rb','qualification_service.rb','_conversation.json.jbuilder')):return 'Shared class/projection length and accepted-baseline accounting'
 return 'Other changed production paths'
areas={}
for f in j['files']:
 if not f['offenses']:continue
 item=areas.setdefault(area(f['path']),{'count':0,'files':{}});item['count']+=len(f['offenses']);item['files'][f['path']]=dict(collections.Counter(o['cop_name'] for o in f['offenses']))
report={'source_tree':json.loads((tmp/f'{prefix}-rubocop-verification.json').read_text())['source_tree'],'summary':j['summary'],'areas':areas,'baseline_note':'Accepted 9a expanded baseline had six findings: Account ClassLength plus five Jbuilder findings. Two Jbuilder indentation findings were removed earlier. Four remaining baseline categories are tracked separately; Account class grew from177 to178 lines and is not unchanged-magnitude debt. QualificationService class length is R09-created. See UI review evidence for exact accepted/reviewed source lint.'}
(tmp/f'{prefix}-remaining-behavior-areas.json').write_text(json.dumps(report,indent=2)+'\n')
for name,item in areas.items():print(f'{item["count"]}: {name}')

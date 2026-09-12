import pathlib,json,subprocess,os
root=pathlib.Path.cwd();tmp=root/'tmp/r09';prefix='authority-helpers'
paths=['app/models/whatsapp/outbound_delivery.rb','app/services/ai_lead_employee/automated_contact_consent.rb','app/services/ai_lead_employee/highly_qualified_handoff_service.rb','app/services/ai_lead_employee/offer_delivery_context.rb']
e=os.environ.copy();e['GIT_INDEX_FILE']=str(tmp/(prefix+'-before.index'))
def git(*a):return subprocess.check_output(['git',*a],env=e).decode().strip()
git('read-tree','HEAD');git('add','-A','--','.');before=git('write-tree');git('update-ref',f'refs/r09/{prefix}-before-source-20260912',before,'0'*40)
for path in paths:
 p=tmp/(prefix+'-before')/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((root/path).read_bytes())
def add_private(s,body):return s.replace('  private\n','  private\n\n'+body+'\n',1)
p=root/paths[0];s=p.read_text();a=s.index('      if pending? || claimed?');b=s.index('      if pending?\n',a);s=s[:a]+'      next false if cancel_inadmissible_recovery!(owner)\n\n'+s[b:]
a=s.index('      membership = AccountUser');b=s.index('\n      with_lifecycle',a);auth=s[a:b];s=s[:a]+'      next false unless retry_authorized?(user)\n'+s[b:]
a=s.index('        next false if lifecycle.artifact_for(self)');b=s.index('\n      end',a);body=s[a:b];s=s[:a]+'        retry_locked!(lifecycle)'+s[b:]
helpers='''  def cancel_inadmissible_recovery!(owner)
    return false unless pending? || claimed?

    reason = owner.admission_failure(self)
    return false unless reason

    owner.cancel!(self, reason: reason)
    true
  end

  def retry_authorized?(user)
'''+auth.split('\n')[0][2:]+'\n    '+auth.split('\n')[1].strip().replace('next false unless ','')+'''
  end

  def retry_locked!(lifecycle)
'''+ '\n'.join(line[4:].replace('next false','return false') for line in body.splitlines())+'\n  end\n'
s=add_private(s,helpers)
s=s.replace('question: "Delivery outcome unknown for message #{message_id}. Check the provider outcome before contacting the Lead again.",','question: "Delivery outcome unknown for message #{message_id}. " \\\n                                           \'Check the provider outcome before contacting the Lead again.\',')
p.write_text(s)
p=root/paths[1];s=p.read_text();a=s.index("      raise ActiveRecord::RecordNotFound, 'No active automated-contact withdrawal'");b=s.index('\n      event = record_grant_event!',a);body=s[a:b].rstrip();s=s[:a]+'      validate_withdrawal!(active_stop, expected_event_id)\n'+s[b:];s=add_private(s,'  def validate_withdrawal!(active_stop, expected_event_id)\n'+'\n'.join(line[2:] for line in body.splitlines())+'\n  end\n');p.write_text(s)
p=root/paths[3];s=p.read_text();a=s.index("    return 'offer_selection_changed'");b=s.index('\n\n    offer =',a);old=s[a:b];s=s[:a]+"    return 'offer_selection_changed' unless current_selection?"+s[b:];select=old.split('unless ',1)[1].replace('\n                                            ','\n      ')
s=s.replace("offer&.enabled? && offer.configuration_version == context['configuration_version']",'current_configuration?(offer)',1)
a=s.index("    return 'qualification_decision_changed' unless qualification &&");b=s.index('\n\n    decision =',a);old=s[a:b];qual=old.split('unless ',1)[1].replace('\n                                                   ','\n      ');s=s[:a]+"    return 'qualification_decision_changed' unless current_qualification?(qualification)"+s[b:]
a=s.index('    decision = qualification.lead_qualification_decisions');b=s.index('\n\n    nil',a);dec=s[a:b];s=s[:a]+"    return 'qualification_decision_changed' unless current_decision?(qualification, offer)"+s[b:];dec=dec.replace("    return 'qualification_decision_changed' unless ",'    ').replace('\n                                                   ','\n      ')
helpers='  def current_selection?\n    '+select+'\n  end\n\n'+'''  def current_configuration?(offer)
    offer&.enabled? && offer.configuration_version == context['configuration_version']
  end

  def current_qualification?(qualification)
    '''+qual+'\n  end\n\n  def current_decision?(qualification, offer)\n'+dec+'\n  end\n';s=add_private(s,helpers);p.write_text(s)
p=root/paths[2];s=p.read_text();a=s.index('      existing_handoff = existing_handoff_record');b=s.index('\n    end\n    deliver_result_alerts',a);normal=s[a:b];s=s[:a]+'      perform_handoff_locked'+s[b:]
a=s.index('      handoff = account.lead_handoffs.find_by!');b=s.index('\n    end\n    deliver_result_alerts',a);race=s[a:b];s=s[:a]+'      recover_existing_handoff_locked'+s[b:]
helpers='  def perform_handoff_locked\n'+'\n'.join(line[2:].replace('next Result.new','return Result.new') for line in normal.splitlines())+'\n  end\n\n  def recover_existing_handoff_locked\n'+'\n'.join(line[2:].replace('next Result.new','return Result.new') for line in race.splitlines())+'\n  end\n'
s=add_private(s,helpers)
a=s.index('  def alert_recipients(assignee)');b=s.index('  def alert_template_params',a);first=s[a:b];s=s[:a]+'''  def alert_recipients(assignee)
    AiLeadEmployee::HandoffAlertRecipients.new(account: account, alert_type: ALERT_TYPE).for(assignee)
  end

'''+s[b:]
a=s.index('  def recipient_for(route, assignee)');b=s.index('  def configured_operator',a);rest=s[a:b];s=s[:a]+s[b:];p.write_text(s)
new='app/services/ai_lead_employee/handoff_alert_recipients.rb';paths.append(new)
(root/new).write_text('''# frozen_string_literal: true

class AiLeadEmployee::HandoffAlertRecipients
  def initialize(account:, alert_type:)
    @account = account
    @alert_type = alert_type
  end

'''+first[:first.index('  def alert_routes')].replace('def alert_recipients(assignee)','def for(assignee)')+'''  private

  attr_reader :account, :alert_type

'''+first[first.index('  def alert_routes'):].replace('ALERT_TYPE','alert_type')+rest+'end\n')
report={'before_tree':before,'paths':paths};(tmp/(prefix+'-plan.json')).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))

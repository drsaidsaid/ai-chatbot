# frozen_string_literal: true

require 'rails_helper'
require 'timeout'

RSpec.describe 'Offer follow-up committed lifecycle interleavings', type: :request do
  self.use_transactional_tests = false
  include_context 'with Offer qualification requests'

  let(:delivery_records) { {} }

  let(:workers) { [] }
  let(:release) { Queue.new }

  prepend_before { clean_committed_fixtures }

  before do
    delivery_records[:offer] = r09_create_offer
    delivery_records[:conversation] = r09_conversation(offer: delivery_records[:offer])
    create(:message, account: account, inbox: delivery_records[:conversation].inbox, conversation: delivery_records[:conversation],
                     message_type: :incoming, sender: delivery_records[:conversation].contact, provider_created_at: Time.current)
    result = AiLeadEmployee::QualificationService.new(conversation: delivery_records[:conversation]).perform
    delivery_records[:follow_up] =
      AiLeadEmployee::FollowUpScheduler.new(conversation: delivery_records[:conversation], qualification_result: result).perform.first
    delivery_records[:follow_up].update!(scheduled_at: 1.minute.ago)
    materialize
    delivery_records[:delivery] = delivery_records[:follow_up].reload.message.whatsapp_outbound_delivery
    delivery_records[:attempt] = delivery_records[:follow_up].follow_up_attempt
  end

  after do
    8.times { release << true }
    workers.each { |worker| worker.join(15) || worker.kill.join }
    clean_committed_fixtures
  end

  %w[replacement acceptance].each do |winner|
    it "preserves one lineage when #{winner} wins against the original owner's receipt" do
      prime_owner(admitted: winner == 'acceptance')
      fresh_decision
      winner == 'replacement' ? interleave(-> { replace }, -> { accept }) : interleave(-> { accept }, -> { replace })

      if winner == 'replacement'
        verify_replacement_winner
      else
        expect(delivery_records[:delivery].reload).to be_accepted
        expect(delivery_records[:attempt].reload).to be_accepted
        expect(delivery_records[:attempt].current_follow_up_id).to eq(delivery_records[:follow_up].id)
      end
      expect(LeadFollowUp.where(follow_up_attempt: delivery_records[:attempt], superseded_at: nil).count).to eq(1)
    end
  end

  %w[cancellation acceptance].each do |winner|
    it "preserves the admission boundary when #{winner} wins against control cancellation" do
      prime_owner(admitted: winner == 'acceptance')
      cancel = lambda do
        Whatsapp::OutboundDelivery.cancel_automation!(conversation: Conversation.find(delivery_records[:conversation].id), reason: 'control_changed')
      end
      winner == 'cancellation' ? interleave(cancel, -> { accept }) : interleave(-> { accept }, cancel)

      expected = winner == 'cancellation' ? 'blocked' : 'accepted'
      expect(delivery_records[:attempt].reload.admission_state).to eq(expected)
      expect(delivery_records[:follow_up].reload.status).to eq(winner == 'cancellation' ? 'cancelled' : 'sent')
      expect(delivery_records[:attempt].admitted_at.present?).to eq(winner == 'acceptance')
    end
  end

  %w[recovery materialization].each do |winner|
    it "retains the original Message when #{winner} wins an expired-claim race" do
      delivery_records[:delivery].update!(state: :claimed, owner_token: 'expired', lease_expires_at: 1.minute.ago, attempts: 1)
      recover = -> { Whatsapp::OutboundDelivery.find(delivery_records[:delivery].id).recover! }
      winner == 'recovery' ? interleave(recover, -> { materialize }) : interleave(-> { materialize }, recover)

      expect(delivery_records[:follow_up].reload.message_id).to eq(delivery_records[:delivery].message_id)
      expect(delivery_records[:delivery].reload).to be_pending
      expect(OutboxEvent.where(aggregate_type: 'Message', aggregate_id: delivery_records[:delivery].message_id).count).to eq(1)
      expect(delivery_records[:attempt].reload).to be_unadmitted
    end
  end

  %w[preparation_failure replacement].each do |winner|
    it "does not recycle a failed attempt when #{winner} wins the preparation race" do
      fresh_decision
      fail_preparation = -> { Whatsapp::OutboundDelivery.find(delivery_records[:delivery].id).fail_preparation! }
      winner == 'preparation_failure' ? interleave(fail_preparation, -> { replace }) : interleave(-> { replace }, fail_preparation)

      expect(delivery_records[:attempt].reload.admission_state).to eq(winner == 'preparation_failure' ? 'failed' : 'unadmitted')
      expect(delivery_records[:follow_up].reload.superseded_at.present?).to eq(winner == 'replacement')
      expect(delivery_records[:delivery].reload.state).to eq(winner == 'preparation_failure' ? 'failed' : 'canceled')
    end
  end

  %w[repair replacement].each do |winner|
    it "keeps old event repair on its original artifact when #{winner} wins" do
      fresh_decision
      repair = -> { Whatsapp::OutboundDelivery.find(delivery_records[:delivery].id).reconcile! }
      winner == 'repair' ? interleave(repair, -> { replace }) : interleave(-> { replace }, repair)

      expect(delivery_records[:follow_up].reload).to be_cancelled
      expect(delivery_records[:attempt].reload.current_follow_up_id).not_to eq(delivery_records[:follow_up].id)
      expect(delivery_records[:attempt].current_follow_up.message_id).to be_nil
      expect(OutboxEvent.find_by!(aggregate_type: 'Message', aggregate_id: delivery_records[:delivery].message_id)).to be_canceled
      expect(delivery_records[:attempt]).to be_unadmitted
    end
  end

  %w[unknown acceptance].each do |winner|
    it "serializes missing-review creation and late acceptance when #{winner} wins" do
      prime_owner(admitted: true)
      delivery_records[:delivery].update!(lease_expires_at: 1.minute.ago)
      recover = -> { Whatsapp::OutboundDelivery.find(delivery_records[:delivery].id).recover! }
      winner == 'unknown' ? interleave(recover, -> { accept }) : interleave(-> { accept }, recover)

      expect(delivery_records[:delivery].reload).to be_accepted
      expect(delivery_records[:attempt].reload).to be_accepted
      reviews = HumanReviewRequest.where(lead_message_id: delivery_records[:delivery].message_id, reason: :delivery_unknown)
      expect(reviews.count).to eq(winner == 'unknown' ? 1 : 0)
      expect(reviews.open).to be_empty
    end
  end

  it 'allows competing schedulers only one successor for the same independently eligible decision' do
    fresh_decision
    interleave(-> { replace }, -> { replace })

    expect(LeadFollowUp.where(follow_up_attempt: delivery_records[:attempt]).count).to eq(2)
    expect(LeadFollowUp.where(replaces_follow_up: delivery_records[:follow_up]).count).to eq(1)
    expect(delivery_records[:attempt].reload.current_follow_up.replaces_follow_up_id).to eq(delivery_records[:follow_up].id)
  end

  %w[acceptance preparation_failure repair recovery].each do |operation|
    it "does not hold Delivery while #{operation} waits for Attempt ownership" do
      prime_owner(admitted: true) if operation.in?(%w[acceptance recovery])
      delivery_records[:delivery].update!(lease_expires_at: 1.minute.ago) if operation == 'recovery'
      held = Queue.new
      holder, holder_pid = start_worker do
        LeadFollowUpAttempt.find(delivery_records[:attempt].id).with_lock do
          held << true
          release.pop
        end
      end
      Timeout.timeout(15) { held.pop }
      action = {
        'acceptance' => -> { accept },
        'preparation_failure' => -> { Whatsapp::OutboundDelivery.find(delivery_records[:delivery].id).fail_preparation! },
        'repair' => -> { Whatsapp::OutboundDelivery.find(delivery_records[:delivery].id).reconcile! },
        'recovery' => -> { Whatsapp::OutboundDelivery.find(delivery_records[:delivery].id).recover! }
      }.fetch(operation)
      contender, contender_pid = start_worker(&action)
      wait_until { blocked_by?(contender_pid, holder_pid) || !contender.alive? }
      expect(blocked_by?(contender_pid, holder_pid)).to be(true)
      ApplicationRecord.transaction { Whatsapp::OutboundDelivery.where(id: delivery_records[:delivery].id).lock('FOR UPDATE NOWAIT').load }
      release << true
      holder.value
      contender.value
    end
  end

  it 'locks every affected Attempt before any Delivery during a multi-Conversation opt-out' do
    other_offer = r09_create_offer(r09_configuration(name: 'Second Offer'))
    other_conversation = r09_conversation(offer: other_offer)
    result = AiLeadEmployee::QualificationService.new(conversation: other_conversation).perform
    other_follow_up = AiLeadEmployee::FollowUpScheduler.new(conversation: other_conversation, qualification_result: result).perform.first
    held = Queue.new
    holder, holder_pid = start_worker do
      LeadFollowUpAttempt.find(other_follow_up.follow_up_attempt_id).with_lock do
        held << true
        release.pop
      end
    end
    Timeout.timeout(15) { held.pop }
    stopper, stopper_pid = start_worker do
      LeadFollowUpOptOut.create!(account: account, contact: r09_lead, conversation: delivery_records[:conversation],
                                 reason: 'lead_requested_stop', opted_out_at: Time.current)
    end
    wait_until { blocked_by?(stopper_pid, holder_pid) || !stopper.alive? }
    expect(blocked_by?(stopper_pid, holder_pid)).to be(true)
    ApplicationRecord.transaction { Whatsapp::OutboundDelivery.where(id: delivery_records[:delivery].id).lock('FOR UPDATE NOWAIT').load }
    release << true
    holder.value
    stopper.value
    expect(delivery_records[:attempt].reload).to be_blocked
    expect(other_follow_up.reload.follow_up_attempt).to be_blocked
  end

  it 'locks the full current and stale-context Offer union once for opposite stale schedulers' do
    other_offer = r09_create_offer(r09_configuration(name: 'Other shared Offer'))
    first_conversation = r09_conversation(offer: delivery_records[:offer], contact: create(:contact, account: account))
    second_conversation = r09_conversation(offer: other_offer, contact: create(:contact, account: account))
    first_result = AiLeadEmployee::QualificationService.new(conversation: first_conversation).perform
    second_result = AiLeadEmployee::QualificationService.new(conversation: second_conversation).perform
    first_conversation.update!(offer_id: other_offer.fetch('id'))
    second_conversation.update!(offer_id: delivery_records[:offer].fetch('id'))
    held = Queue.new
    allow(AiLeadEmployee::FollowUpCancellation).to receive(:lock_offers!).and_wrap_original do |original, **arguments|
      value = original.call(**arguments)
      if arguments.fetch(:conversations).map(&:id).include?(first_conversation.id)
        held << true
        release.pop
      end
      value
    end
    first, first_pid = start_worker do
      AiLeadEmployee::FollowUpScheduler.new(conversation: Conversation.find(first_conversation.id), qualification_result: first_result).perform
    end
    Timeout.timeout(15) { held.pop }
    second, second_pid = start_worker do
      AiLeadEmployee::FollowUpScheduler.new(conversation: Conversation.find(second_conversation.id), qualification_result: second_result).perform
    end
    wait_until { blocked_by?(second_pid, first_pid) || !second.alive? }
    expect(blocked_by?(second_pid, first_pid)).to be(true)
    release << true
    expect(first.value).to be_empty
    expect(second.value).to be_empty
    expect(LeadFollowUp.where(conversation: [first_conversation, second_conversation])).to be_empty
  end

  %w[membership provider].each do |authority|
    it "does not discover a newly inserted #{authority} authority after entering the delivery suffix" do
      if authority == 'membership'
        message = create(:message, account: account, inbox: delivery_records[:conversation].inbox, conversation: delivery_records[:conversation],
                                   sender: r09_admin, message_type: :outgoing, content: 'A human reply')
        AccountUser.where(account: account, user: r09_admin).delete_all
      else
        _incoming, intent = r09_receive(delivery_records[:conversation], 'Hello')
        message = intent.outbound_message
        account.ai_provider_connection.destroy!
      end
      entered = Queue.new
      gated = false
      allow(Whatsapp::DeliveryLifecycle).to receive(:with).and_wrap_original do |original, **arguments, &block|
        unless gated
          gated = true
          entered << true
          release.pop
        end
        original.call(**arguments, &block)
      end
      request = stub_request(:post, %r{https://graph.facebook.com/v\d+\.\d+/[^/]+/messages})
                .to_return(status: 200, body: '{"messages":[{"id":"wamid.R09.LATE.AUTHORITY"}]}',
                           headers: { 'Content-Type' => 'application/json' })
      sender, = start_worker { SendReplyJob.perform_now(message.id) }
      Timeout.timeout(15) { entered.pop }
      if authority == 'membership'
        create(:account_user, account: account, user: r09_admin, role: :administrator)
      else
        create(:ai_provider_connection, account: account)
      end
      release << true
      sender.value

      expect(message.reload.whatsapp_outbound_delivery).to have_attributes(
        state: 'canceled', failure_code: authority == 'membership' ? 'sender_access_revoked' : 'provider_disabled'
      )
      expect(request).not_to have_been_requested
    end
  end

  %w[rejection acceptance].each do |winner|
    it "preserves the human review rejection when #{winner} commits first" do
      prime_owner(admitted: true)
      delivery_records[:delivery].update!(lease_expires_at: 1.minute.ago)
      delivery_records[:delivery].recover!
      review = HumanReviewRequest.find_by!(lead_message_id: delivery_records[:delivery].message_id, reason: :delivery_unknown)
      reject = -> { HumanReviewRequest.find(review.id).reject!(operator_answer: 'Keep the human review decision') }
      winner == 'rejection' ? interleave(reject, -> { accept }) : interleave(-> { accept }, reject)

      expect(delivery_records[:attempt].reload).to be_accepted
      expect(review.reload).to be_rejected
      expect(review.operator_answer).to eq('Keep the human review decision')
    end
  end

  it 'locks existing budget Attempts by database ID even when history has the opposite attempt-number order' do
    legacy_account = create(:account, settings: { 'ai_lead_employee_follow_up' => {
                              'max_attempts' => 2, 'qualified_second_follow_up_enabled' => true
                            } })
    conversation = create(:conversation, account: legacy_account, control_state: :ai_active, status: :open, assignee: nil)
    qualification = create(:lead_qualification, account: legacy_account, contact: conversation.contact,
                                                quality: :qualified, follow_up_state: :nurture)
    attributes = { account: legacy_account, contact: conversation.contact, conversation: conversation,
                   lead_qualification: qualification, stage: :qualified_nurture }
    second = create(:lead_follow_up, **attributes, attempt_number: 2)
    first = create(:lead_follow_up, **attributes, attempt_number: 1)
    result = AiLeadEmployee::QualificationService::Result.new(qualification: qualification, next_question: first.question_text)
    held = Queue.new
    holder, holder_pid = start_worker do
      LeadFollowUpAttempt.find(second.follow_up_attempt_id).with_lock do
        held << true
        release.pop
      end
    end
    Timeout.timeout(15) { held.pop }
    scheduler, scheduler_pid = start_worker do
      AiLeadEmployee::FollowUpScheduler.new(conversation: Conversation.find(conversation.id), qualification_result: result).perform
    end
    wait_until { blocked_by?(scheduler_pid, holder_pid) || !scheduler.alive? }
    expect(blocked_by?(scheduler_pid, holder_pid)).to be(true)
    ApplicationRecord.transaction { LeadFollowUpAttempt.where(id: first.follow_up_attempt_id).lock('FOR UPDATE NOWAIT').load }
    release << true
    holder.value
    scheduler.value
    expect(LeadFollowUpAttempt.where(account: legacy_account).count).to eq(2)
  end

  it 'refreshes conversation-wide cancellation targets after a replacement commits ahead of its Conversation lock' do
    fresh_decision
    held = Queue.new
    replacer, replacer_pid = start_worker do
      Conversation.find(delivery_records[:conversation].id).with_lock('FOR NO KEY UPDATE') do
        held << true
        release.pop
        replace
      end
    end
    Timeout.timeout(15) { held.pop }
    canceller, canceller_pid = start_worker do
      AiLeadEmployee::FollowUpScheduler.cancel_pending_for!(conversation: Conversation.find(delivery_records[:conversation].id),
                                                            reason: 'operator_cancelled')
    end
    wait_until { blocked_by?(canceller_pid, replacer_pid) || !canceller.alive? }
    expect(blocked_by?(canceller_pid, replacer_pid)).to be(true)
    release << true
    replacer.value
    canceller.value

    expect(delivery_records[:attempt].reload.current_follow_up_id).not_to eq(delivery_records[:follow_up].id)
    expect(delivery_records[:attempt].current_follow_up).to be_cancelled
    expect(delivery_records[:attempt]).to be_blocked
  end

  %w[human_review call_booked closed].each do |state|
    it "cancels a concurrent replacement through the #{state} qualification callback without canceling another Offer" do
      other_offer = r09_create_offer(r09_configuration(name: 'Unaffected Offer'))
      other_qualification = create(:lead_qualification, account: account, contact: delivery_records[:conversation].contact,
                                                        offer_id: other_offer.fetch('id'))
      unrelated = create(:lead_follow_up, account: account, contact: delivery_records[:conversation].contact,
                                          conversation: delivery_records[:conversation], lead_qualification: other_qualification)
      fresh_decision
      held = Queue.new
      replacer, replacer_pid = start_worker do
        Conversation.find(delivery_records[:conversation].id).with_lock('FOR NO KEY UPDATE') do
          held << true
          release.pop
          replace
        end
      end
      Timeout.timeout(15) { held.pop }
      updater, updater_pid = start_worker do
        LeadQualification.find(delivery_records[:follow_up].lead_qualification_id).update!(follow_up_state: state)
      end
      wait_until { blocked_by?(updater_pid, replacer_pid) || !updater.alive? }
      expect(blocked_by?(updater_pid, replacer_pid)).to be(true)
      release << true
      replacer.value
      updater.value

      expect(delivery_records[:attempt].reload.current_follow_up_id).not_to eq(delivery_records[:follow_up].id)
      expect(delivery_records[:attempt].current_follow_up).to have_attributes(status: 'cancelled', cancellation_reason: "follow_up_state_#{state}")
      expect(delivery_records[:attempt]).to be_blocked
      expect(unrelated.reload).to be_pending
      expect(unrelated.follow_up_attempt.reload).to be_unadmitted
    end
  end

  private

  def materialize
    AiLeadEmployee::FollowUpDeliveryService.new(follow_up: LeadFollowUp.find(delivery_records[:follow_up].id)).perform
  end

  def fresh_decision
    r09_update_offer(delivery_records[:offer], name: 'Independently eligible next context')
    expect(response).to have_http_status(:success)
    delivery_records[:fresh_result] = AiLeadEmployee::QualificationService.new(conversation: delivery_records[:conversation]).perform
  end

  def replace
    AiLeadEmployee::FollowUpScheduler.new(conversation: Conversation.find(delivery_records[:conversation].id),
                                          qualification_result: delivery_records[:fresh_result]).perform
  end

  # Exercise the actual claim/admission owner without an HTTP call. Outcome
  # workers below represent the original owner's eventual receipt/rejection.
  def prime_owner(admitted:)
    delivery_records[:dispatch] = Whatsapp::OutboundDispatch.new(message: delivery_records[:follow_up].message, channel: r09_channel,
                                                                 recipient: delivery_records[:conversation].contact_inbox.source_id)
    expect(delivery_records[:dispatch].send(:claim)).to be(true)
    expect(delivery_records[:dispatch].send(:authorize)).to be(true) if admitted
  end

  def accept
    delivery_records[:dispatch].send(:accept, 'wamid.R09.LIFECYCLE.RACE')
  end

  def interleave(first, second)
    held = Queue.new
    owner, owner_pid = start_worker do
      ApplicationRecord.transaction do
        first.call
        held << true
        release.pop
      end
    end
    Timeout.timeout(15) { held.pop }
    contender, contender_pid = start_worker(&second)
    wait_until { blocked_by?(contender_pid, owner_pid) || !contender.alive? }
    expect(blocked_by?(contender_pid, owner_pid)).to be(true)
    release << true
    owner.value
    contender.value
  end

  def start_worker
    pid = Queue.new
    worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.execute("SET lock_timeout = '12s'")
        pid << connection.raw_connection.backend_pid
        yield
      ensure
        connection.execute('RESET lock_timeout')
      end
    end
    workers << worker
    [worker, Timeout.timeout(15) { pid.pop }]
  end

  def blocked_by?(waiter, owner)
    ActiveRecord::Base.connection.select_value("SELECT #{owner.to_i} = ANY(pg_blocking_pids(#{waiter.to_i}))")
  end

  def wait_until
    Timeout.timeout(15) { sleep 0.01 until yield }
  end

  def clean_committed_fixtures
    unless Rails.env.test? && ActiveRecord::Base.connection.current_database == 'ale_r09_offers_20260911_spec'
      raise 'Dedicated Rails test database required'
    end

    database = ActiveRecord::Base.connection
    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
    clear_enqueued_jobs
  end

  def verify_replacement_winner
    expect(delivery_records[:follow_up].reload.superseded_at).to be_present
    expect(delivery_records[:delivery].reload).to be_canceled
    expect(delivery_records[:attempt].reload).to be_unadmitted
    expect(delivery_records[:attempt].current_follow_up.message_id).to be_nil
  end
end

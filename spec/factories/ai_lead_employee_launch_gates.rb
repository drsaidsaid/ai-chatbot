# frozen_string_literal: true

FactoryBot.define do
  factory :ai_lead_employee_launch_gate, class: 'AiLeadEmployee::LaunchGate' do
    account
    team_roleplay_completed { false }
    pilot_conversations_reviewed_count { 0 }
    report { {} }
  end
end

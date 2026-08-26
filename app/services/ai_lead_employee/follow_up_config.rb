# frozen_string_literal: true

class AiLeadEmployee::FollowUpConfig
  DEFAULTS = {
    'enabled' => true,
    'delay_minutes' => 1440,
    'max_attempts' => 1,
    'qualified_second_follow_up_enabled' => false,
    'message_template' => 'Just following up on this so I can help properly: %<question>s',
    'stage_rules' => {}
  }.freeze

  def initialize(account)
    @account = account
  end

  def payload
    DEFAULTS.deep_merge(account.settings.fetch('ai_lead_employee_follow_up', {}).to_h)
  end

  def enabled_for?(stage:, signal: nil)
    return false unless payload['enabled']

    stage_rule(stage, signal).fetch('enabled', true)
  end

  def max_attempts_for(stage:, signal: nil, quality: nil)
    configured_max = stage_rule(stage, signal).fetch('max_attempts', payload['max_attempts']).to_i
    return [configured_max, 2].min if quality.to_s == 'qualified' && payload['qualified_second_follow_up_enabled']

    [configured_max, 1].min
  end

  def delay_for(stage:, signal: nil)
    stage_rule(stage, signal).fetch('delay_minutes', payload['delay_minutes']).to_i.minutes
  end

  def render_message(question_text)
    format(payload['message_template'].to_s, question: question_text)
  rescue KeyError
    format(DEFAULTS['message_template'], question: question_text)
  end

  private

  attr_reader :account

  def stage_rule(stage, signal)
    rules = payload.fetch('stage_rules', {})
    rules.fetch(signal.to_s, rules.fetch(stage.to_s, {})).to_h
  end
end

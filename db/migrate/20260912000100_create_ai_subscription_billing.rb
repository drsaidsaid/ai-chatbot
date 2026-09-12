# frozen_string_literal: true

class CreateAiSubscriptionBilling < ActiveRecord::Migration[7.1]
  def change
    add_column :platform_apps, :finance_operations_enabled, :boolean, null: false, default: false
    create_ai_service_plans
    create_ai_subscriptions
    create_ai_subscription_alerts
    create_ai_subscription_requests
    create_subscription_payment_confirmations
    add_subscription_payment_constraints
    create_ai_reply_usages
    connect_ai_reply_usages_to_delivery
  end

  private

  def create_ai_service_plans
    create_table :ai_service_plans do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.integer :version, null: false, default: 1
      t.string :status, null: false, default: 'draft'
      t.string :currency, null: false
      t.decimal :monthly_price, precision: 18, scale: 2, null: false
      t.integer :included_ai_replies, null: false
      t.decimal :top_up_price, precision: 18, scale: 2
      t.integer :top_up_ai_replies
      t.text :payment_instructions, null: false
      t.datetime :published_at
      t.timestamps
    end
    add_index :ai_service_plans, [:code, :version], unique: true
    add_index :ai_service_plans, :code,
              unique: true, where: "status = 'published'", name: 'idx_ai_service_plans_one_published_code'
    add_ai_service_plan_constraints
  end

  def add_ai_service_plan_constraints
    add_check_constraint :ai_service_plans, "status IN ('draft', 'published', 'archived')", name: 'ai_service_plans_status'
    add_check_constraint :ai_service_plans, 'monthly_price > 0', name: 'ai_service_plans_positive_price'
    add_check_constraint :ai_service_plans, 'included_ai_replies > 0', name: 'ai_service_plans_positive_allowance'
    add_check_constraint :ai_service_plans,
                         '((top_up_price IS NULL) = (top_up_ai_replies IS NULL))',
                         name: 'ai_service_plans_complete_top_up_terms'
    add_check_constraint :ai_service_plans, 'top_up_price IS NULL OR top_up_price > 0',
                         name: 'ai_service_plans_positive_top_up_price'
    add_check_constraint :ai_service_plans, 'top_up_ai_replies IS NULL OR top_up_ai_replies > 0',
                         name: 'ai_service_plans_positive_top_up_allowance'
  end

  def create_ai_subscription_alerts
    create_table :ai_subscription_alerts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_subscription, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :status, null: false, default: 'open'
      t.datetime :period_started_at, null: false
      t.datetime :resolved_at
      t.jsonb :alert_recipients, null: false, default: []
      t.jsonb :alert_deliveries, null: false, default: []
      t.timestamps
    end
    add_index :ai_subscription_alerts, [:ai_subscription_id, :period_started_at, :kind],
              unique: true, name: 'idx_ai_subscription_alerts_period_kind'
    add_check_constraint :ai_subscription_alerts,
                         "kind IN ('allowance_exhausted', 'subscription_renewal_due')",
                         name: 'ai_subscription_alerts_kind'
    add_check_constraint :ai_subscription_alerts, "status IN ('open', 'resolved')",
                         name: 'ai_subscription_alerts_status'
  end

  def create_ai_subscriptions
    create_table :ai_subscriptions do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.references :ai_service_plan, null: false, foreign_key: true
      t.string :status, null: false, default: 'active'
      t.string :reporting_timezone, null: false, default: 'UTC'
      t.datetime :period_started_at, null: false
      t.datetime :renews_at, null: false
      t.datetime :paid_through_at, null: false
      t.integer :renewal_anchor_day, null: false
      t.integer :included_ai_replies, null: false
      t.integer :top_up_ai_replies, null: false, default: 0
      t.datetime :exhaustion_alerted_at
      t.timestamps
    end
    add_check_constraint :ai_subscriptions, "status IN ('active', 'canceled', 'review_required')", name: 'ai_subscriptions_status'
    add_check_constraint :ai_subscriptions, 'included_ai_replies > 0', name: 'ai_subscriptions_positive_allowance'
    add_check_constraint :ai_subscriptions, 'top_up_ai_replies >= 0', name: 'ai_subscriptions_nonnegative_topups'
    add_check_constraint :ai_subscriptions, 'renewal_anchor_day BETWEEN 1 AND 31', name: 'ai_subscriptions_valid_anchor_day'
    add_check_constraint :ai_subscriptions, 'paid_through_at >= renews_at', name: 'ai_subscriptions_paid_through_period'
  end

  def create_ai_subscription_requests
    create_table :ai_subscription_requests do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_service_plan, foreign_key: true
      t.references :expected_current_plan, foreign_key: { to_table: :ai_service_plans }
      t.datetime :expected_subscription_updated_at
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.string :purpose, null: false
      t.string :status, null: false, default: 'pending'
      t.decimal :quoted_amount, precision: 18, scale: 2
      t.string :currency
      t.integer :requested_ai_replies
      t.text :payment_instructions, null: false
      t.datetime :confirmed_at
      t.timestamps
    end
    add_ai_subscription_request_constraints
  end

  def add_ai_subscription_request_constraints
    add_check_constraint :ai_subscription_requests,
                         "purpose IN ('new_subscription', 'renewal', 'upgrade', 'top_up')",
                         name: 'ai_subscription_requests_purpose'
    add_check_constraint :ai_subscription_requests, "status IN ('pending', 'confirmed', 'canceled')",
                         name: 'ai_subscription_requests_status'
  end

  def create_subscription_payment_confirmations
    create_table :subscription_payment_confirmations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_subscription_request, null: false, foreign_key: true,
                                             index: { unique: true, name: 'idx_subscription_payments_on_request' }
      t.references :confirmed_by_platform_app, null: false, foreign_key: { to_table: :platform_apps },
                                               index: { name: 'idx_subscription_payments_on_platform_app' }
      t.string :purpose, null: false
      t.string :payment_reference, null: false
      t.decimal :amount, precision: 18, scale: 2, null: false
      t.string :currency, null: false
      t.integer :granted_ai_replies
      t.datetime :confirmed_at, null: false
      t.timestamps
    end
    add_subscription_payment_indexes
  end

  def add_subscription_payment_indexes
    add_index(
      :subscription_payment_confirmations,
      [:account_id, :payment_reference],
      unique: true,
      name: 'idx_subscription_payments_on_account_reference'
    )
  end

  def add_subscription_payment_constraints
    add_check_constraint :subscription_payment_confirmations, 'amount > 0', name: 'subscription_payments_positive_amount'
    add_check_constraint :subscription_payment_confirmations,
                         "purpose IN ('new_subscription', 'renewal', 'upgrade', 'top_up')",
                         name: 'subscription_payments_purpose'
  end

  def create_ai_reply_usages
    create_table :ai_reply_usages do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_subscription, null: false, foreign_key: true
      t.references :ai_orchestration_intent, null: false, foreign_key: true, index: { unique: true }
      t.string :allowance_source, null: false
      t.string :status, null: false, default: 'reserved'
      t.integer :expected_delivery_parts, null: false, default: 1
      t.datetime :deliveries_registered_at
      t.datetime :period_started_at, null: false
      t.datetime :period_ends_at, null: false
      t.datetime :reserved_at, null: false
      t.datetime :settled_at
      t.datetime :released_at
      t.string :reconciliation_reason
      t.references :reconciled_by_platform_app, foreign_key: { to_table: :platform_apps }
      t.timestamps
    end
    add_index :ai_reply_usages, [:account_id, :period_started_at, :status], name: 'idx_ai_reply_usages_on_period_state'
    add_reply_usage_constraints
  end

  def add_reply_usage_constraints
    add_check_constraint :ai_reply_usages, "allowance_source IN ('included', 'top_up')", name: 'ai_reply_usages_source'
    add_check_constraint :ai_reply_usages, "status IN ('reserved', 'settled', 'released')", name: 'ai_reply_usages_status'
    add_check_constraint :ai_reply_usages, 'expected_delivery_parts > 0', name: 'ai_reply_usages_positive_parts'
    add_check_constraint :ai_reply_usages, 'period_ends_at > period_started_at', name: 'ai_reply_usages_forward_period'
  end

  def connect_ai_reply_usages_to_delivery
    add_reference :whatsapp_outbound_deliveries, :ai_reply_usage, foreign_key: true
  end
end

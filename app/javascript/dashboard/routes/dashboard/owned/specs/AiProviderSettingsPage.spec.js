import { flushPromises, mount } from '@vue/test-utils';
import AiProviderSettingsPage from '../AiProviderSettingsPage.vue';
import aiProviderConnectionAPI from 'dashboard/api/aiProviderConnection';
import aiSubscriptionAPI from 'dashboard/api/aiSubscription';
import Button from 'dashboard/components-next/button/Button.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    locale: { value: 'en' },
    t: (key, params = {}) => {
      const values = Object.values(params);
      return values.length ? `${key} ${values.join(' ')}` : key;
    },
  }),
}));

vi.mock('dashboard/api/aiProviderConnection', () => ({
  default: { get: vi.fn() },
}));

vi.mock('dashboard/api/aiSubscription', () => ({
  default: { get: vi.fn(), previewPurchase: vi.fn(), createRequest: vi.fn() },
}));

describe('AiProviderSettingsPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    aiProviderConnectionAPI.get.mockResolvedValue({
      data: {
        managed_service: true,
        service_status: 'active',
        readiness_status: 'healthy',
        last_health_checked_at: '2026-09-10T12:00:00Z',
        last_health_checked_at_label: '2026-09-10 15:00 EAT',
        daily_request_limit: 25,
        requests_used_today: 3,
        requests_remaining_today: 22,
        usage_resets_at_label: '2026-09-11 03:00 EAT',
        automation_allowed: true,
        automation_paused_reason: null,
      },
    });
    aiSubscriptionAPI.get.mockResolvedValue({
      data: {
        subscription: {
          status: 'active',
          plan_id: 1,
          plan_name: 'Growth',
          included_ai_replies: 3000,
          used_ai_replies: 800,
          reserved_ai_replies: 1,
          reconciliation_required_ai_replies: 1,
          remaining_ai_replies: 2198,
          usage_percentage: 26.7,
          renewal_date: '2026-10-12T08:00:00Z',
          reporting_timezone: 'Africa/Dar_es_Salaam',
          automation_allowed: true,
        },
        available_plans: [],
        pending_requests: [],
        separate_charges: {
          meta_messaging: 'Billed directly by Meta',
          advertising_spend: 'Billed separately by the advertising platform',
        },
      },
    });
  });

  it('shows managed service readiness and account usage without provider controls', async () => {
    const wrapper = mount(AiProviderSettingsPage);
    await flushPromises();

    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.MANAGED_TITLE'
    );
    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.MANAGED_DESCRIPTION'
    );
    expect(wrapper.text()).toContain('AI_LEAD_EMPLOYEE.AI_PROVIDER.HEALTHY');
    expect(wrapper.text()).toContain('3 / 25');
    expect(wrapper.text()).toContain('2026-09-11 03:00 EAT');
    expect(wrapper.find('form').exists()).toBe(false);
    expect(wrapper.find('select').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('OpenRouter');
    expect(wrapper.text()).not.toContain('API key');
    expect(wrapper.text()).not.toContain('Model');
  });

  it('shows logical reply usage, renewal and separately billed Meta costs', async () => {
    const wrapper = mount(AiProviderSettingsPage);
    await flushPromises();

    expect(wrapper.text()).toContain('Growth');
    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.USAGE_SUMMARY 800 2198'
    );
    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.USAGE_PERCENTAGE 26.7'
    );
    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.RECONCILIATION_REQUIRED 1'
    );
    expect(wrapper.text()).toContain('Oct 12, 2026, 11:00 GMT+3');
    expect(wrapper.text()).not.toContain('2026-10-12T08:00:00Z');
    expect(wrapper.text()).toContain('Billed directly by Meta');
    expect(wrapper.text()).toContain(
      'Billed separately by the advertising platform'
    );
    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.NO_AUTOMATIC_CHARGES'
    );
    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.MANUAL_REVIEW'
    );
  });

  it('uses a phone-safe fluid usage meter without a fixed minimum width', async () => {
    const wrapper = mount(AiProviderSettingsPage);
    await flushPromises();

    const meter = wrapper.get('[role="meter"]');
    expect(meter.attributes()).toMatchObject({
      'aria-valuemin': '0',
      'aria-valuemax': '100',
      'aria-valuenow': '26.7',
    });
    expect(meter.get('div').attributes('style')).toContain('width: 26.7%');
    expect(wrapper.get('main').classes()).toContain('min-w-0');
  });

  it('refreshes server-owned entitlement state after requesting a plan', async () => {
    aiSubscriptionAPI.get.mockResolvedValue({
      data: {
        subscription: { status: 'inactive', automation_allowed: false },
        available_plans: [
          {
            id: 7,
            name: 'Approved plan',
            currency: 'TZS',
            monthly_price: '250000.0',
            included_ai_replies: 3000,
          },
        ],
        pending_requests: [],
        separate_charges: {},
      },
    });
    aiSubscriptionAPI.createRequest.mockResolvedValue({ data: { id: 12 } });
    const wrapper = mount(AiProviderSettingsPage);
    await flushPromises();

    await wrapper.getComponent(Button).trigger('click');
    await flushPromises();

    expect(aiSubscriptionAPI.createRequest).toHaveBeenCalledWith({
      ai_service_plan_id: 7,
      purpose: 'new_subscription',
    });
    expect(aiSubscriptionAPI.get).toHaveBeenCalledTimes(2);
  });

  it('shows generic operator guidance without exposing provider failure details', async () => {
    aiProviderConnectionAPI.get.mockResolvedValue({
      data: {
        managed_service: true,
        service_status: 'active',
        readiness_status: 'failed',
        daily_request_limit: 25,
        requests_used_today: 1,
        requests_remaining_today: 24,
        automation_allowed: true,
        automation_paused_reason: null,
      },
    });

    const wrapper = mount(AiProviderSettingsPage);
    await flushPromises();

    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.MANAGED_ATTENTION'
    );
    expect(wrapper.text()).not.toContain('authentication');
    expect(wrapper.text()).not.toContain('credits');
  });

  it('shows why automation is paused when the account allowance is exhausted', async () => {
    aiProviderConnectionAPI.get.mockResolvedValue({
      data: {
        managed_service: true,
        service_status: 'active',
        readiness_status: 'healthy',
        daily_request_limit: 3,
        requests_used_today: 3,
        requests_remaining_today: 0,
        automation_allowed: false,
        automation_paused_reason: 'usage_limit_exhausted',
      },
    });

    const wrapper = mount(AiProviderSettingsPage);
    await flushPromises();

    expect(wrapper.text()).toContain('3 / 3');
    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.PAUSE.USAGE_LIMIT_EXHAUSTED'
    );
  });

  it('shows a durable owner alert and previews the approved top-up before requesting payment', async () => {
    aiSubscriptionAPI.get.mockResolvedValue({
      data: {
        subscription: {
          status: 'active',
          plan_id: 4,
          plan_name: 'Starter',
          included_ai_replies: 100,
          remaining_ai_replies: 0,
          usage_percentage: 100,
          renewal_date: '2026-10-12T08:00:00Z',
          reporting_timezone: 'Africa/Dar_es_Salaam',
          automation_allowed: false,
        },
        available_plans: [
          {
            id: 4,
            name: 'Starter',
            currency: 'TZS',
            monthly_price: '100000.0',
            included_ai_replies: 100,
            top_up_price: '75000.0',
            top_up_ai_replies: 50,
          },
        ],
        alerts: [{ id: 9, kind: 'allowance_exhausted', status: 'open' }],
        pending_requests: [],
        separate_charges: {},
      },
    });
    aiSubscriptionAPI.previewPurchase.mockResolvedValue({
      data: {
        purpose: 'top_up',
        plan_id: 4,
        plan_name: 'Starter',
        amount_due: '75000.00',
        currency: 'TZS',
        requested_ai_replies: 50,
        used_ai_replies: 100,
        awaiting_delivery_ai_replies: 0,
        current_remaining_ai_replies: 0,
        resulting_included_ai_replies: 100,
        resulting_included_ai_replies_remaining: 0,
        resulting_top_up_ai_replies_remaining: 50,
        resulting_ai_replies_remaining: 50,
        renews_at: '2026-10-12T08:00:00Z',
        reporting_timezone: 'Africa/Dar_es_Salaam',
        preview_signature: 'signed-top-up-preview',
        unit_price_comparison: {
          comparison_plan_name: 'Growth',
          savings_percentage: 44.4,
          included_unit_price: '8333.33',
          top_up_unit_price: '15000.00',
        },
      },
    });
    aiSubscriptionAPI.createRequest.mockResolvedValue({ data: { id: 13 } });
    const wrapper = mount(AiProviderSettingsPage);
    await flushPromises();

    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.OWNER_ALERT'
    );
    const topUpButton = wrapper
      .findAllComponents(Button)
      .find(button => button.props('label').includes('REQUEST_TOP_UP'));
    await topUpButton.trigger('click');
    await flushPromises();

    expect(aiSubscriptionAPI.previewPurchase).toHaveBeenCalledWith({
      ai_service_plan_id: 4,
      purpose: 'top_up',
    });
    expect(aiSubscriptionAPI.createRequest).not.toHaveBeenCalled();
    expect(wrapper.get('[data-testid="purchase-preview"]').text()).toContain(
      'TZS 75,000.00'
    );
    expect(wrapper.get('[data-testid="purchase-preview"]').text()).toContain(
      '44.4'
    );

    await wrapper
      .get('[data-testid="confirm-purchase-request"]')
      .trigger('click');
    await flushPromises();

    expect(aiSubscriptionAPI.createRequest).toHaveBeenCalledWith({
      ai_service_plan_id: 4,
      purpose: 'top_up',
      preview_signature: 'signed-top-up-preview',
    });
  });

  it('shows only same-currency upgrades that increase allowance and price', async () => {
    aiSubscriptionAPI.get.mockResolvedValue({
      data: {
        subscription: {
          status: 'active',
          plan_id: 4,
          plan_name: 'Starter',
          included_ai_replies: 100,
          remaining_ai_replies: 20,
          usage_percentage: 80,
          automation_allowed: true,
        },
        available_plans: [
          {
            id: 4,
            name: 'Starter',
            currency: 'TZS',
            monthly_price: '100000',
            included_ai_replies: 100,
          },
          {
            id: 5,
            name: 'Valid Growth',
            currency: 'TZS',
            monthly_price: '200000',
            included_ai_replies: 200,
          },
          {
            id: 6,
            name: 'Cheap Large',
            currency: 'TZS',
            monthly_price: '90000',
            included_ai_replies: 300,
          },
          {
            id: 7,
            name: 'USD Large',
            currency: 'USD',
            monthly_price: '300',
            included_ai_replies: 400,
          },
        ],
        alerts: [],
        pending_requests: [],
        separate_charges: {},
      },
    });

    const wrapper = mount(AiProviderSettingsPage);
    await flushPromises();

    expect(wrapper.text()).toContain('Valid Growth');
    expect(wrapper.text()).not.toContain('Cheap Large');
    expect(wrapper.text()).not.toContain('USD Large');
  });

  it('shows the exact full-cycle upgrade difference and resulting balance before payment instructions', async () => {
    aiSubscriptionAPI.get.mockResolvedValue({
      data: {
        subscription: {
          status: 'active',
          plan_id: 4,
          plan_name: 'Starter',
          included_ai_replies: 1000,
          used_ai_replies: 800,
          remaining_ai_replies: 200,
          usage_percentage: 80,
          renewal_date: '2026-10-12T08:00:00Z',
          reporting_timezone: 'Africa/Dar_es_Salaam',
          automation_allowed: true,
        },
        available_plans: [
          {
            id: 4,
            name: 'Starter',
            currency: 'TZS',
            monthly_price: '100000.00',
            included_ai_replies: 1000,
            top_up_price: '75000.00',
            top_up_ai_replies: 500,
          },
          {
            id: 5,
            name: 'Growth',
            currency: 'TZS',
            monthly_price: '250000.00',
            included_ai_replies: 3000,
          },
        ],
        alerts: [],
        pending_requests: [],
        separate_charges: {},
      },
    });
    aiSubscriptionAPI.previewPurchase.mockResolvedValue({
      data: {
        purpose: 'upgrade',
        plan_id: 5,
        plan_name: 'Growth',
        currency: 'TZS',
        current_monthly_price: '100000.00',
        target_monthly_price: '250000.00',
        amount_due: '150000.00',
        used_ai_replies: 800,
        awaiting_delivery_ai_replies: 0,
        current_remaining_ai_replies: 200,
        resulting_included_ai_replies: 3000,
        resulting_included_ai_replies_remaining: 2200,
        resulting_top_up_ai_replies_remaining: 0,
        resulting_ai_replies_remaining: 2200,
        renews_at: '2026-10-12T08:00:00Z',
        reporting_timezone: 'Africa/Dar_es_Salaam',
        preview_signature: 'signed-upgrade-preview',
      },
    });

    const wrapper = mount(AiProviderSettingsPage);
    await flushPromises();
    const upgradeButton = wrapper
      .findAllComponents(Button)
      .find(button => button.props('label').includes('REQUEST_UPGRADE'));
    await upgradeButton.trigger('click');
    await flushPromises();

    const preview = wrapper.get('[data-testid="purchase-preview"]');
    expect(preview.text()).toContain('TZS 100,000.00');
    expect(preview.text()).toContain('TZS 250,000.00');
    expect(preview.text()).toContain('TZS 150,000.00');
    expect(preview.text()).toContain('2200');
    expect(preview.text()).toContain('Oct 12, 2026, 11:00 GMT+3');
    expect(aiSubscriptionAPI.createRequest).not.toHaveBeenCalled();
  });

  it('tells the admin to wait for renewal when a future cycle is already paid', async () => {
    aiSubscriptionAPI.get.mockResolvedValue({
      data: {
        subscription: {
          status: 'active',
          plan_id: 4,
          plan_name: 'Starter',
          included_ai_replies: 100,
          remaining_ai_replies: 20,
          usage_percentage: 80,
          automation_allowed: true,
        },
        available_plans: [
          {
            id: 4,
            name: 'Starter',
            currency: 'TZS',
            monthly_price: '100000.00',
            included_ai_replies: 100,
          },
          {
            id: 5,
            name: 'Growth',
            currency: 'TZS',
            monthly_price: '250000.00',
            included_ai_replies: 300,
          },
        ],
        alerts: [],
        pending_requests: [],
        separate_charges: {},
      },
    });
    aiSubscriptionAPI.previewPurchase.mockRejectedValue({
      response: { data: { error: 'upgrade_available_after_renewal' } },
    });
    const wrapper = mount(AiProviderSettingsPage);
    await flushPromises();

    const upgradeButton = wrapper
      .findAllComponents(Button)
      .find(button => button.props('label').includes('REQUEST_UPGRADE'));
    await upgradeButton.trigger('click');
    await flushPromises();

    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.UPGRADE_AFTER_RENEWAL'
    );
    expect(wrapper.text()).not.toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.REQUEST_FAILED'
    );
  });

  it('explains that purchased extras remain recorded while renewal is due', async () => {
    aiSubscriptionAPI.get.mockResolvedValue({
      data: {
        subscription: {
          status: 'renewal_due',
          plan_id: 4,
          plan_name: 'Starter',
          preserved_top_up_ai_replies: 25,
          automation_allowed: false,
        },
        available_plans: [
          {
            id: 4,
            name: 'Starter',
            currency: 'TZS',
            monthly_price: '100000.00',
            included_ai_replies: 100,
          },
        ],
        alerts: [],
        pending_requests: [],
        separate_charges: {},
      },
    });

    const wrapper = mount(AiProviderSettingsPage);
    await flushPromises();

    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.PRESERVED_EXTRAS 25'
    );
  });
});

import { flushPromises, shallowMount } from '@vue/test-utils';
import AiProviderSettingsPage from '../AiProviderSettingsPage.vue';
import aiProviderConnectionAPI from 'dashboard/api/aiProviderConnection';
import aiSubscriptionAPI from 'dashboard/api/aiSubscription';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
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
  default: { get: vi.fn(), createRequest: vi.fn() },
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
          remaining_ai_replies: 2199,
          usage_percentage: 26.7,
          renewal_date: '2026-10-12T08:00:00Z',
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
    const wrapper = shallowMount(AiProviderSettingsPage);
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
    const wrapper = shallowMount(AiProviderSettingsPage);
    await flushPromises();

    expect(wrapper.text()).toContain('Growth');
    expect(wrapper.text()).toContain('800 AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.USED');
    expect(wrapper.text()).toContain('2199 AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.REMAINING');
    expect(wrapper.text()).toContain('26.7%');
    expect(wrapper.text()).toContain('2026-10-12T08:00:00Z');
    expect(wrapper.text()).toContain('Billed directly by Meta');
    expect(wrapper.text()).toContain('Billed separately by the advertising platform');
  });

  it('uses a phone-safe fluid usage meter without a fixed minimum width', async () => {
    const wrapper = shallowMount(AiProviderSettingsPage);
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
    const wrapper = shallowMount(AiProviderSettingsPage);
    await flushPromises();

    await wrapper.get('button').trigger('click');
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

    const wrapper = shallowMount(AiProviderSettingsPage);
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

    const wrapper = shallowMount(AiProviderSettingsPage);
    await flushPromises();

    expect(wrapper.text()).toContain('3 / 3');
    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.PAUSE.USAGE_LIMIT_EXHAUSTED'
    );
  });

  it('shows a durable owner alert and requests only the approved top-up package', async () => {
    aiSubscriptionAPI.get.mockResolvedValue({
      data: {
        subscription: {
          status: 'active',
          plan_id: 4,
          plan_name: 'Starter',
          included_ai_replies: 100,
          remaining_ai_replies: 0,
          usage_percentage: 100,
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
    aiSubscriptionAPI.createRequest.mockResolvedValue({ data: { id: 13 } });
    const wrapper = shallowMount(AiProviderSettingsPage);
    await flushPromises();

    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.OWNER_ALERT'
    );
    const topUpButton = wrapper
      .findAll('button')
      .find(button => button.text().includes('REQUEST_TOP_UP'));
    await topUpButton.trigger('click');
    await flushPromises();

    expect(aiSubscriptionAPI.createRequest).toHaveBeenCalledWith({
      ai_service_plan_id: 4,
      purpose: 'top_up',
    });
  });
});

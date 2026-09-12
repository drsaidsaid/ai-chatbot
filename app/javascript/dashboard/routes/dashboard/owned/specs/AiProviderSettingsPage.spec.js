import { flushPromises, shallowMount } from '@vue/test-utils';
import AiProviderSettingsPage from '../AiProviderSettingsPage.vue';
import aiProviderConnectionAPI from 'dashboard/api/aiProviderConnection';

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
    expect(wrapper.find('input').exists()).toBe(false);
    expect(wrapper.find('select').exists()).toBe(false);
    expect(wrapper.find('button').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('OpenRouter');
    expect(wrapper.text()).not.toContain('API key');
    expect(wrapper.text()).not.toContain('Model');
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
});

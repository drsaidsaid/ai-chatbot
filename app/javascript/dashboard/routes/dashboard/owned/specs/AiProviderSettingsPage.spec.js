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

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('dashboard/api/aiProviderConnection', () => ({
  default: {
    get: vi.fn(),
    save: vi.fn(),
    disable: vi.fn(),
    healthCheck: vi.fn(),
  },
}));

describe('AiProviderSettingsPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    aiProviderConnectionAPI.get.mockResolvedValue({
      data: {
        provider: 'openrouter',
        model: 'openai/gpt-4.1-mini',
        status: 'active',
        has_credentials: true,
        readiness_status: 'not_checked',
        configuration_version: 1,
        last_health_checked_at: null,
        reply_token_limit: 512,
        daily_request_limit: 25,
        requests_used_today: 3,
        requests_remaining_today: 22,
        usage_resets_at: '2026-09-11T00:00:00Z',
        usage_resets_at_label: '2026-09-11 03:00 EAT',
        automation_allowed: true,
        automation_paused_reason: null,
        cost_usd_today: null,
        cost_data_complete: false,
      },
    });
    aiProviderConnectionAPI.save.mockResolvedValue({
      data: { status: 'active', has_credentials: true },
    });
    aiProviderConnectionAPI.healthCheck.mockResolvedValue({
      data: { status: 'healthy', checked_at: '2026-08-31T01:00:00Z' },
    });
  });

  it('loads redacted connection state without rendering a saved key', async () => {
    const wrapper = shallowMount(AiProviderSettingsPage);
    await flushPromises();

    expect(wrapper.text()).toContain('AI_LEAD_EMPLOYEE.AI_PROVIDER.CONFIGURED');
    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.NOT_CHECKED'
    );
    expect(wrapper.text()).toContain('3 / 25');
    expect(wrapper.text()).toContain('2026-09-11 03:00 EAT');
    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.COST_UNKNOWN'
    );
    expect(wrapper.find('input[type="password"]').element.value).toBe('');
    expect(wrapper.html()).not.toContain('api-key-secret');
  });

  it('rotates credentials and checks provider health', async () => {
    const wrapper = shallowMount(AiProviderSettingsPage);
    await flushPromises();

    await wrapper.find('input[type="password"]').setValue('new-key');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(aiProviderConnectionAPI.save).toHaveBeenCalledWith({
      provider: 'openrouter',
      model: 'openai/gpt-4.1-mini',
      reply_token_limit: 512,
      daily_request_limit: 25,
      api_key: 'new-key',
    });

    await wrapper.findAll('button')[1].trigger('click');
    await flushPromises();
    expect(aiProviderConnectionAPI.healthCheck).toHaveBeenCalled();
  });

  it('shows plain guidance when the full reply-budget check has insufficient credits', async () => {
    aiProviderConnectionAPI.get.mockResolvedValue({
      data: {
        provider: 'openrouter',
        model: 'openai/gpt-4.1-mini',
        status: 'active',
        has_credentials: true,
        readiness_status: 'failed',
        configuration_version: 2,
        reply_token_limit: 512,
        daily_request_limit: 25,
        requests_used_today: 1,
        requests_remaining_today: 24,
        automation_allowed: true,
        automation_paused_reason: null,
        cost_usd_today: null,
        cost_data_complete: false,
        last_health_failure_class: 'insufficient_credits',
        last_health_checked_at: '2026-09-10T12:00:00Z',
        last_health_checked_at_label: '2026-09-10 15:00 EAT',
        last_health_model: 'openai/gpt-4.1-mini',
        last_health_reply_token_limit: 512,
        last_health_configuration_version: 2,
      },
    });

    const wrapper = shallowMount(AiProviderSettingsPage);
    await flushPromises();

    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.FAILURE.INSUFFICIENT_CREDITS'
    );
    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.FAILURE.RETRY_AFTER_CREDITS'
    );
    expect(wrapper.text()).toContain('512');
    expect(wrapper.text()).toContain('openai/gpt-4.1-mini');
    expect(wrapper.text()).toContain('2026-09-10 15:00 EAT');
    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.CHECKED_CONFIGURATION_VALUE openai/gpt-4.1-mini 512 2'
    );
  });

  it('shows why automation is paused when the daily allowance is exhausted', async () => {
    aiProviderConnectionAPI.get.mockResolvedValue({
      data: {
        provider: 'openrouter',
        model: 'openai/gpt-4.1-mini',
        status: 'active',
        has_credentials: true,
        readiness_status: 'healthy',
        reply_token_limit: 512,
        daily_request_limit: 3,
        requests_used_today: 3,
        requests_remaining_today: 0,
        automation_allowed: false,
        automation_paused_reason: 'usage_limit_exhausted',
        cost_usd_today: null,
        cost_data_complete: false,
      },
    });

    const wrapper = shallowMount(AiProviderSettingsPage);
    await flushPromises();

    expect(wrapper.text()).toContain('3 / 3');
    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.PAUSE.USAGE_LIMIT_EXHAUSTED'
    );
  });

  it('disables the saved provider without revealing its key', async () => {
    aiProviderConnectionAPI.disable.mockResolvedValue({
      data: {
        status: 'disabled',
        has_credentials: false,
        readiness_status: 'disabled',
        automation_allowed: false,
        automation_paused_reason: 'provider_disabled',
      },
    });
    const wrapper = shallowMount(AiProviderSettingsPage);
    await flushPromises();

    await wrapper.findAll('button')[2].trigger('click');
    await flushPromises();

    expect(aiProviderConnectionAPI.disable).toHaveBeenCalledOnce();
    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.PAUSE.PROVIDER_DISABLED'
    );
    expect(wrapper.find('input[type="password"]').element.value).toBe('');
  });
});

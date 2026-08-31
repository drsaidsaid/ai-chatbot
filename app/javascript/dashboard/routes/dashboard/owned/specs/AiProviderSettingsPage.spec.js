import { flushPromises, shallowMount } from '@vue/test-utils';
import AiProviderSettingsPage from '../AiProviderSettingsPage.vue';
import aiProviderConnectionAPI from 'dashboard/api/aiProviderConnection';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
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

    expect(wrapper.text()).toContain('AI_LEAD_EMPLOYEE.AI_PROVIDER.CONNECTED');
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
      api_key: 'new-key',
    });

    await wrapper.findAll('button')[1].trigger('click');
    await flushPromises();
    expect(aiProviderConnectionAPI.healthCheck).toHaveBeenCalled();
  });
});

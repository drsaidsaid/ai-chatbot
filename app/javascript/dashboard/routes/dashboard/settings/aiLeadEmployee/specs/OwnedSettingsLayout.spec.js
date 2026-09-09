import { mount, flushPromises } from '@vue/test-utils';
import { createRouter, createMemoryHistory } from 'vue-router';
import OwnedSettingsLayout from '../OwnedSettingsLayout.vue';

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    accountScopedRoute: name => ({ name, params: { accountId: 1 } }),
  }),
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

it('keeps every Settings section reachable from provider deep links and restores selection on back', async () => {
  const names = [
    'ai_lead_employee_settings_offers_qualification',
    'agent_list',
    'ai_lead_employee_settings_booking_business_hours',
    'ai_lead_employee_settings_follow_ups',
    'ai_lead_employee_settings_whatsapp_connection',
    'ai_lead_employee_settings_ai_testing',
    'owned_ai_provider_settings',
    'owned_test_center_index',
    'settings_teams_list',
    'ai_lead_employee_settings_alerts',
    'general_settings_index',
  ];
  const router = createRouter({
    history: createMemoryHistory(),
    routes: names.map(name => ({
      name,
      path: `/accounts/:accountId/settings/${name}`,
      component: {},
    })),
  });
  await router.push({
    name: 'owned_ai_provider_settings',
    params: { accountId: 1 },
    query: { tab: 'connection' },
  });
  const wrapper = mount(OwnedSettingsLayout, {
    global: { plugins: [router] },
    slots: { default: '<p>Provider settings</p>' },
  });
  expect(wrapper.get('select').findAll('option')).toHaveLength(6);
  expect(wrapper.get('select').element.value).toBe('ai');
  expect(wrapper.text()).toContain('Provider settings');
  await wrapper.get('select').setValue('whatsapp');
  await flushPromises();
  expect(router.currentRoute.value.name).toBe(
    'ai_lead_employee_settings_whatsapp_connection'
  );
  router.back();
  await flushPromises();
  expect(router.currentRoute.value.name).toBe('owned_ai_provider_settings');
  expect(router.currentRoute.value.query).toEqual({ tab: 'connection' });
  expect(wrapper.get('select').element.value).toBe('ai');
});

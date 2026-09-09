/* global axios */
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import messages from 'dashboard/i18n/locale/en/aiLeadEmployee.json';
import WhatsappConnectionPage from '../WhatsappConnectionPage.vue';

const saved = {
  status: 'awaiting_message',
  name: 'Business WhatsApp',
  phone_number: '+255700000003',
  phone_number_id: '3003',
  business_account_id: '9003',
  api_key_configured: true,
  app_secret_configured: true,
  inbox_id: 3,
  pending_count: 0,
  failed_count: 0,
  callback_url: 'http://localhost/webhooks/whatsapp/+255700000003',
};

const mountPage = () =>
  mount(WhatsappConnectionPage, {
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'en', messages: { en: messages } }),
      ],
    },
  });

beforeEach(() => {
  vi.stubGlobal('axios', {
    get: vi.fn().mockResolvedValue({ data: { status: 'not_connected' } }),
    patch: vi.fn().mockResolvedValue({ data: saved }),
    post: vi.fn().mockResolvedValue({ data: saved }),
  });
});

afterEach(() => vi.unstubAllGlobals());

it('saves direct setup, clears submitted secrets and retains saved status on reload', async () => {
  const wrapper = mountPage();
  await flushPromises();
  await wrapper.get('#whatsapp-name').setValue('Business WhatsApp');
  await wrapper.get('#whatsapp-phone_number').setValue('+255700000003');
  await wrapper.get('#whatsapp-phone_number_id').setValue('3003');
  await wrapper.get('#whatsapp-business_account_id').setValue('9003');
  await wrapper.get('#whatsapp-api_key').setValue('local-access-secret');
  await wrapper.get('#whatsapp-app_secret').setValue('local-signing-secret');
  await wrapper.get('form').trigger('submit');
  await flushPromises();

  expect(wrapper.text()).toContain('Waiting for the first message');
  expect(wrapper.get('#whatsapp-api_key').element.value).toBe('');
  expect(wrapper.get('#whatsapp-app_secret').element.value).toBe('');
  expect(axios.patch.mock.calls[0][1]).toMatchObject({
    api_key: 'local-access-secret',
    app_secret: 'local-signing-secret',
  });
  wrapper.unmount();
  axios.get.mockResolvedValue({ data: saved });
  const reloaded = mountPage();
  await flushPromises();
  expect(reloaded.get('#whatsapp-phone_number').element.value).toBe(
    '+255700000003'
  );
  expect(reloaded.get('#whatsapp-api_key').element.value).toBe('');
  expect(reloaded.text()).toContain('Waiting for the first message');
});

import { flushPromises, shallowMount } from '@vue/test-utils';
import WhatsappTemplatesPage from '../WhatsappTemplatesPage.vue';
import whatsappTemplatesAPI from 'dashboard/api/whatsappTemplates';

const store = {
  dispatch: vi.fn().mockResolvedValue(true),
  getters: {
    'inboxes/getInboxes': [
      { id: 7, name: 'Sales WhatsApp', channel_type: 'Channel::Whatsapp' },
      { id: 8, name: 'Website', channel_type: 'Channel::WebWidget' },
    ],
  },
};

vi.mock('dashboard/composables/store', () => ({ useStore: () => store }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/whatsappTemplates', () => ({
  default: {
    get: vi.fn(),
    create: vi.fn(),
    submit: vi.fn(),
    reconcile: vi.fn(),
  },
}));

describe('WhatsappTemplatesPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    whatsappTemplatesAPI.get.mockResolvedValue({
      data: [
        {
          id: 12,
          name: 'order_update',
          language: 'en_US',
          revision: 1,
          status: 'submitted',
          meta_approval: 'submitted',
          sendable: false,
          meta_charge_estimate: null,
        },
        {
          id: 11,
          name: 'approved_offer',
          language: 'en_US',
          revision: 2,
          status: 'approved',
          meta_approval: 'approved',
          sendable: true,
          meta_charge_estimate: {
            amount: '0.025',
            currency: 'USD',
            market: 'TZ',
            effective_on: '2026-09-12',
            source: 'Meta rate card',
          },
        },
      ],
    });
    whatsappTemplatesAPI.create.mockResolvedValue({
      data: { id: 13, status: 'draft', name: 'follow_up' },
    });
    whatsappTemplatesAPI.submit.mockResolvedValue({ data: {} });
    whatsappTemplatesAPI.reconcile.mockResolvedValue({ data: {} });
  });

  it('previews variable samples and submits text, media, button, and variables as one draft', async () => {
    const wrapper = shallowMount(WhatsappTemplatesPage);
    await flushPromises();
    const selects = wrapper.findAll('select');
    await selects[0].setValue('7');
    await wrapper.find('input[pattern]').setValue('follow_up');
    await wrapper.find('textarea').setValue('Hello {{1}}');
    await flushPromises();
    await wrapper.find('#whatsapp-template-variable-1').setValue('Asha');
    await selects[2].setValue('IMAGE');
    await flushPromises();
    await wrapper
      .find('#whatsapp-template-media-url')
      .setValue('https://example.test/header.png');
    await wrapper.findAll('select')[3].setValue('QUICK_REPLY');
    await flushPromises();
    await wrapper.find('#whatsapp-template-button-text').setValue('Thanks');

    expect(wrapper.text()).toContain('Hello Asha');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(whatsappTemplatesAPI.create).toHaveBeenCalledWith(
      expect.objectContaining({
        inbox_id: 7,
        name: 'follow_up',
        body: 'Hello {{1}}',
        variables: [{ position: 1, example: 'Asha' }],
        media: {
          format: 'IMAGE',
          example: { header_handle: ['https://example.test/header.png'] },
        },
        buttons: [{ type: 'QUICK_REPLY', text: 'Thanks', url: '' }],
      })
    );
  });

  it('labels missing Meta pricing unknown and synchronizes a submitted provider status', async () => {
    const wrapper = shallowMount(WhatsappTemplatesPage);
    await flushPromises();

    expect(wrapper.text()).toContain(
      'Unknown — obtain a current Meta estimate before broadcast.'
    );
    expect(wrapper.text()).toContain(
      '0.025 USD · TZ · 2026-09-12 · Meta rate card'
    );
    expect(wrapper.text()).toContain('Sendable');
    expect(wrapper.text()).toContain('Not sendable');
    const syncButton = wrapper.get('[data-testid="sync-meta-status"]');
    await syncButton.trigger('click');
    await flushPromises();

    expect(whatsappTemplatesAPI.reconcile).toHaveBeenCalledWith(12);
  });
});

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
    update: vi.fn(),
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
          preview: {
            body: 'Hello {{1}}',
            media: {},
            buttons: [],
            variables: [{ position: 1, example: 'Asha' }],
          },
          revisions: [
            {
              revision: 1,
              status: 'submitted',
              current: true,
              preview: { body: 'Hello {{1}}', media: {}, buttons: [] },
            },
          ],
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
          preview: {
            body: 'Approved copy',
            media: {},
            buttons: [],
            variables: [],
          },
          revisions: [
            {
              revision: 2,
              status: 'approved',
              current: true,
              preview: { body: 'Approved copy', media: {}, buttons: [] },
            },
            {
              revision: 1,
              status: 'rejected',
              current: false,
              rejection_reason: 'INVALID_FORMAT',
              preview: { body: 'Old copy', media: {}, buttons: [] },
            },
          ],
        },
        {
          id: 10,
          name: 'auth_failed',
          language: 'en_US',
          revision: 1,
          status: 'submission_failed',
          meta_approval: 'submission_failed',
          sendable: false,
          submission_failure: {
            kind: 'authentication',
            message: 'Invalid OAuth access token',
          },
          preview: { body: 'Hello', media: {}, buttons: [], variables: [] },
          revisions: [],
        },
      ],
    });
    whatsappTemplatesAPI.create.mockResolvedValue({
      data: { id: 13, status: 'draft', name: 'follow_up' },
    });
    whatsappTemplatesAPI.update.mockResolvedValue({
      data: { id: 12, status: 'draft', name: 'order_update', revision: 2 },
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
      .find('#whatsapp-template-media-handle')
      .setValue('fake-meta-header-handle');
    await wrapper.findAll('select')[3].setValue('QUICK_REPLY');
    await flushPromises();
    await wrapper.find('#whatsapp-template-button-text').setValue('Thanks');

    expect(wrapper.text()).toContain('Hello Asha');
    expect(wrapper.text()).toContain('Image header');
    expect(wrapper.text()).toContain('Thanks');
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
          example: { header_handle: ['fake-meta-header-handle'] },
        },
        buttons: [{ type: 'QUICK_REPLY', text: 'Thanks' }],
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

  it('loads an existing template into the form, saves a new revision, and shows immutable history', async () => {
    const wrapper = shallowMount(WhatsappTemplatesPage);
    await flushPromises();

    expect(wrapper.text()).toContain('Revision history');
    expect(wrapper.text()).toMatch(/Revision 1 · rejected\s+· INVALID_FORMAT/);
    await wrapper.get('[data-testid="edit-template-12"]').trigger('click');
    await flushPromises();

    expect(wrapper.find('textarea').element.value).toBe('Hello {{1}}');
    expect(wrapper.find('input[pattern]').attributes('disabled')).toBeDefined();
    expect(wrapper.findAll('select')[0].attributes('disabled')).toBeDefined();
    expect(
      wrapper.get('[data-testid="template-language"]').attributes('disabled')
    ).toBeDefined();
    await wrapper.find('#whatsapp-template-variable-1').setValue('Neema');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(whatsappTemplatesAPI.update).toHaveBeenCalledWith(
      12,
      expect.objectContaining({
        body: 'Hello {{1}}',
        variables: [{ position: 1, example: 'Neema' }],
      })
    );
  });

  it('submits only an explicitly owner-verified Meta estimate and can refresh provider states', async () => {
    const wrapper = shallowMount(WhatsappTemplatesPage);
    await flushPromises();
    const selects = wrapper.findAll('select');
    await selects[0].setValue('7');
    await wrapper.find('input[pattern]').setValue('priced_template');
    await wrapper.find('textarea').setValue('Price notice');
    await wrapper.get('[data-testid="estimate-amount"]').setValue('0.025');
    await wrapper.get('[data-testid="estimate-currency"]').setValue('USD');
    await wrapper.get('[data-testid="estimate-market"]').setValue('TZ');
    await wrapper
      .get('[data-testid="estimate-effective-on"]')
      .setValue('2026-09-12');
    await wrapper
      .get('[data-testid="estimate-source"]')
      .setValue('https://developers.facebook.com/rates');
    await wrapper.get('[data-testid="estimate-confirmed"]').setValue(true);
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(whatsappTemplatesAPI.create).toHaveBeenCalledWith(
      expect.objectContaining({
        meta_charge_estimate: {
          amount: '0.025',
          currency: 'USD',
          market: 'TZ',
          effective_on: '2026-09-12',
          source: 'https://developers.facebook.com/rates',
          confirmed: true,
        },
      })
    );
    await wrapper.get('[data-testid="refresh-templates"]').trigger('click');
    await flushPromises();
    expect(whatsappTemplatesAPI.get).toHaveBeenCalledTimes(2);
  });

  it('labels provider submission failures truthfully and offers a safe retry instead of status sync', async () => {
    const wrapper = shallowMount(WhatsappTemplatesPage);
    await flushPromises();

    expect(wrapper.text()).toContain(
      'Submission failed (authentication): Invalid OAuth access token'
    );
    const retry = wrapper.get('[data-testid="submit-template-10"]');
    await retry.trigger('click');
    await flushPromises();

    expect(whatsappTemplatesAPI.submit).toHaveBeenCalledWith(10);
  });
});

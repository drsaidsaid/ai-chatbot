/* global axios */
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import messages from 'dashboard/i18n/locale/en/aiLeadEmployee.json';
import ConversationOfferQualification from '../ConversationOfferQualification.vue';

const dispatch = vi.fn();
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
}));

it('changes the Conversation Offer and submits corrections to that explicit Offer and Conversation', async () => {
  vi.stubGlobal('axios', {
    patch: vi.fn().mockResolvedValue({ data: {} }),
    post: vi.fn().mockResolvedValue({ data: {} }),
  });
  const chat = {
    id: 7,
    meta: { sender: { id: 12 } },
    lead_qualification: {
      offer_id: 9,
      fields: [
        { key: 'budget', meaning: 'Purchase budget', answer_type: 'money' },
      ],
      offers: [
        { id: 9, name: 'Support', enabled: true },
        { id: 10, name: 'Training', enabled: true },
      ],
    },
  };
  const wrapper = mount(ConversationOfferQualification, {
    props: { currentChat: chat },
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'en', messages: { en: messages } }),
      ],
    },
  });
  await wrapper
    .get('[data-testid="offer-correction-value"]')
    .setValue('I cannot afford this');
  await wrapper.get('form').trigger('submit');
  await flushPromises();
  expect(axios.post).toHaveBeenCalledWith(
    expect.stringContaining('/lead_qualifications/12/evidence'),
    {
      offer_id: 9,
      conversation_id: 7,
      field_key: 'budget',
      value: 'I cannot afford this',
    }
  );
  await wrapper.get('[data-testid="conversation-offer-select"]').setValue('10');
  await wrapper
    .get('[data-testid="select-conversation-offer"]')
    .trigger('click');
  await flushPromises();
  expect(axios.patch).toHaveBeenCalledWith(
    expect.stringContaining('/conversations/7/qualification_offer'),
    { offer_id: 10 }
  );
  expect(dispatch).toHaveBeenCalledWith('getConversation', 7);
  vi.unstubAllGlobals();
});

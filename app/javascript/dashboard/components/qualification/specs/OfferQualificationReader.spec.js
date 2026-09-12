/* global axios */
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import messages from 'dashboard/i18n/locale/en/aiLeadEmployee.json';
import OfferQualificationReader from '../OfferQualificationReader.vue';

it('never displays a late response for the previously selected Offer', async () => {
  let resolveFirst;
  vi.stubGlobal('axios', {
    get: vi
      .fn()
      .mockImplementationOnce(
        () =>
          new Promise(resolve => {
            resolveFirst = resolve;
          })
      )
      .mockResolvedValueOnce({
        data: {
          offer_id: 10,
          offers: [{ id: 10, name: 'Training', enabled: true }],
          reasons: ['Training evidence'],
        },
      }),
  });
  const wrapper = mount(OfferQualificationReader, {
    props: { contactId: 12, offerId: 9 },
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'en', messages: { en: messages } }),
      ],
    },
  });
  await wrapper.setProps({ offerId: 10 });
  await flushPromises();
  expect(axios.get).toHaveBeenLastCalledWith(
    expect.stringContaining('/lead_qualifications/12'),
    { params: { offer_id: 10 } }
  );
  resolveFirst({
    data: {
      offer_id: 9,
      offers: [{ id: 9, name: 'Support', enabled: true }],
      reasons: ['Old Support evidence'],
    },
  });
  await flushPromises();
  expect(wrapper.text()).toContain('Training evidence');
  expect(wrapper.text()).not.toContain('Old Support evidence');
  vi.unstubAllGlobals();
});

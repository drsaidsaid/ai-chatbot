import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import messages from 'dashboard/i18n/locale/en/aiLeadEmployee.json';
import OfferQualificationSummary from '../OfferQualificationSummary.vue';

it('distinguishes stale, negative, unknown and superseded evidence with its source', () => {
  const wrapper = mount(OfferQualificationSummary, {
    props: {
      qualification: {
        offer_id: 9,
        offers: [{ id: 9, name: 'Support', enabled: true }],
        configuration_version: 2,
        current_configuration_version: 3,
        stale_at: '2026-09-12T00:00:00Z',
        quality: 'unknown',
        score: 0,
        reasons: ['Budget not established'],
        missing_signals: ['budget'],
        next_question: 'What can you spend?',
        fields: [{ key: 'budget', meaning: 'Purchase budget' }],
        evidence_records: [
          {
            id: 1,
            field_key: 'budget',
            value: 'I cannot spend that',
            normalized_value: { polarity: 'negative' },
            source: 'extracted',
            source_path: '/app/accounts/1/conversations/7?messageId=90',
            source_reference: { type: 'message', message_id: 90 },
          },
          {
            id: 2,
            field_key: 'budget',
            value: 'unknown',
            normalized_value: { polarity: 'unknown' },
            source: 'human',
            source_reference: { type: 'human_edit', user_id: 4 },
          },
          {
            id: 3,
            field_key: 'budget',
            value: 'Old answer',
            normalized_value: { polarity: 'positive' },
            superseded: true,
            source: 'human',
          },
        ],
      },
    },
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'en', messages: { en: messages } }),
      ],
    },
  });
  expect(wrapper.text()).toContain('Support');
  expect(wrapper.text()).toContain('Needs reevaluation');
  expect(wrapper.text()).toContain('Evaluated revision 2');
  expect(wrapper.text()).toContain('Current revision 3');
  expect(wrapper.text()).toContain('Negative');
  expect(wrapper.text()).toContain('Unknown');
  expect(wrapper.text()).toContain('Superseded');
  expect(wrapper.text()).toContain('Human edit');
  expect(wrapper.get('a').attributes('href')).toBe(
    '/app/accounts/1/conversations/7?messageId=90'
  );
  expect(wrapper.text()).not.toContain('What can you spend?');
});

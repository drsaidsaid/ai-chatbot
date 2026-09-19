import { flushPromises, mount } from '@vue/test-utils';
import { createMemoryHistory, createRouter } from 'vue-router';
import { createI18n } from 'vue-i18n';
import HumanReviewRequestsPanel from '../HumanReviewRequestsPanel.vue';
import HumanReviewRequestsAPI from 'dashboard/api/humanReviewRequests';
import messages from 'dashboard/i18n/locale/en/aiLeadEmployee.json';

vi.mock('dashboard/api/humanReviewRequests', () => ({
  default: {
    get: vi.fn(),
    show: vi.fn(),
    resolve: vi.fn(),
    proposeKnowledge: vi.fn(),
    proposeConfigurationSuggestion: vi.fn(),
    reviewConfigurationSuggestion: vi.fn(),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const review = {
  id: 8,
  question: 'Can I get a refund?',
  reason: 'sensitive_question',
  conversation_id: 12,
  conversation_display_id: 42,
  assigned_user: { name: 'Asha' },
};
const proposeKnowledgeLabel = 'Propose this answer as reusable knowledge';

const mountPanel = async ({ conversationId = 12, reviewId = 8 } = {}) => {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/app/accounts/:accountId/conversations/:id', component: {} },
    ],
  });
  await router.push(
    '/app/accounts/1/conversations/42?queue=review&review_id=8'
  );
  await router.isReady();
  const wrapper = mount(HumanReviewRequestsPanel, {
    props: { conversationId, reviewId },
    global: {
      plugins: [
        router,
        createI18n({ legacy: false, locale: 'en', messages: { en: messages } }),
      ],
    },
  });
  await flushPromises();
  return wrapper;
};

describe('HumanReviewRequestsPanel', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    HumanReviewRequestsAPI.show.mockResolvedValue({ data: review });
    HumanReviewRequestsAPI.resolve.mockResolvedValue({
      data: {
        ...review,
        status: 'resolved',
        knowledge_proposal_outcome: 'not_requested',
        configuration_suggestion_outcome: 'not_requested',
      },
    });
    HumanReviewRequestsAPI.proposeKnowledge.mockResolvedValue({
      data: {
        ...review,
        status: 'resolved',
        knowledge_item_id: 31,
        knowledge_proposal_outcome: 'draft_proposed',
        configuration_suggestion_outcome: 'not_requested',
      },
    });
    HumanReviewRequestsAPI.proposeConfigurationSuggestion.mockResolvedValue({
      data: {
        ...review,
        status: 'resolved',
        knowledge_proposal_outcome: 'not_requested',
        configuration_suggestion_outcome: 'pending',
        configuration_suggestion: {
          category: 'poor_fit',
          suggestion: 'Review the configured fit rule.',
          evidence: 'Can I get a refund?',
        },
      },
    });
  });

  it('keeps the reusable-knowledge action separate from a private resolution', async () => {
    const wrapper = await mountPanel();

    expect(wrapper.text()).toContain('Assigned to Asha');
    expect(wrapper.text()).not.toContain(proposeKnowledgeLabel);

    await wrapper
      .get('textarea')
      .setValue('I will review your refund request.');
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Save private note and resolve')
      .trigger('click');
    await flushPromises();

    expect(HumanReviewRequestsAPI.resolve).toHaveBeenCalledWith(8, {
      answer: 'I will review your refund request.',
      resolution_kind: 'internal_note',
    });
    expect(wrapper.text()).toContain(proposeKnowledgeLabel);

    await wrapper
      .findAll('textarea')[1]
      .setValue('Refund requests are assessed under the published policy.');

    await wrapper
      .findAll('button')
      .find(button => button.text() === proposeKnowledgeLabel)
      .trigger('click');
    await flushPromises();

    expect(HumanReviewRequestsAPI.proposeKnowledge).toHaveBeenCalledWith(
      8,
      expect.objectContaining({
        source_kind: 'policy',
        answer: 'Refund requests are assessed under the published policy.',
      })
    );
    expect(wrapper.text()).toContain('Open draft knowledge proposal');
  });

  it('restores a resolved review directly from its persisted response', async () => {
    HumanReviewRequestsAPI.show.mockResolvedValue({
      data: {
        ...review,
        status: 'resolved',
        resolution_kind: 'internal_note',
        operator_answer: 'Private operator note',
        knowledge_proposal_outcome: 'not_requested',
        configuration_suggestion_outcome: 'not_requested',
      },
    });

    const wrapper = await mountPanel();

    expect(wrapper.text()).toContain(proposeKnowledgeLabel);
    expect(wrapper.text()).not.toContain('Save private note and resolve');
    expect(wrapper.get('textarea').element.value).toBe('Private operator note');
  });

  it('reloads when the selected review changes and hides a review from another conversation', async () => {
    const secondReview = {
      ...review,
      id: 9,
      question: 'Can we speak next month?',
      conversation_id: 13,
      conversation_display_id: 43,
      status: 'resolved',
      resolution_kind: 'internal_note',
      operator_answer: 'Follow up next month.',
      knowledge_proposal_outcome: 'not_requested',
      configuration_suggestion_outcome: 'not_requested',
    };
    HumanReviewRequestsAPI.show
      .mockResolvedValueOnce({ data: review })
      .mockResolvedValueOnce({ data: secondReview });
    const wrapper = await mountPanel();

    await wrapper.setProps({ reviewId: 9, conversationId: 13 });
    await flushPromises();

    expect(HumanReviewRequestsAPI.show).toHaveBeenLastCalledWith(9);
    expect(wrapper.text()).toContain('Can we speak next month?');

    await wrapper.setProps({ conversationId: 12 });
    await flushPromises();

    expect(wrapper.text()).not.toContain('Can we speak next month?');
  });

  it('records handoff feedback as a separate reviewable suggestion', async () => {
    const wrapper = await mountPanel();
    await wrapper
      .get('textarea')
      .setValue('Private note that must remain internal.');
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Save private note and resolve')
      .trigger('click');
    await flushPromises();

    const feedback = wrapper.find(
      'textarea[placeholder="Describe the configuration change an administrator should review"]'
    );
    await feedback.setValue('Review the configured fit rule.');
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Propose configuration feedback')
      .trigger('click');
    await flushPromises();

    expect(
      HumanReviewRequestsAPI.proposeConfigurationSuggestion
    ).toHaveBeenCalledWith(8, {
      category: 'poor_fit',
      suggestion: 'Review the configured fit rule.',
    });
    expect(
      HumanReviewRequestsAPI.proposeConfigurationSuggestion.mock.calls[0][1]
    ).not.toEqual(
      expect.objectContaining({
        suggestion: expect.stringContaining('Private note'),
      })
    );
    expect(wrapper.text()).toContain('Pending administrator review');
  });
});

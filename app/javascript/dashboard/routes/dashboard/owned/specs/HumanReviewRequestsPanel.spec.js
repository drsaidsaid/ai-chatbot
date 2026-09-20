import { flushPromises, mount } from '@vue/test-utils';
import { createMemoryHistory, createRouter } from 'vue-router';
import { createI18n } from 'vue-i18n';
import { ref } from 'vue';
import HumanReviewRequestsPanel from '../HumanReviewRequestsPanel.vue';
import HumanReviewRequestsAPI from 'dashboard/api/humanReviewRequests';
import ReviewConfigurationSuggestionsAPI from 'dashboard/api/reviewConfigurationSuggestions';
import { useMapGetter } from 'dashboard/composables/store';
import messages from 'dashboard/i18n/locale/en/aiLeadEmployee.json';

vi.mock('dashboard/api/humanReviewRequests', () => ({
  default: {
    get: vi.fn(),
    show: vi.fn(),
    resolve: vi.fn(),
    proposeKnowledge: vi.fn(),
    proposeConfigurationSuggestion: vi.fn(),
    reviewConfigurationSuggestion: vi.fn(),
    assign: vi.fn(),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', () => ({ useMapGetter: vi.fn() }));
vi.mock('dashboard/api/reviewConfigurationSuggestions', () => ({
  default: { get: vi.fn(), review: vi.fn() },
}));

const review = {
  id: 8,
  question: 'Can I get a refund?',
  reason: 'sensitive_question',
  conversation_id: 12,
  conversation_display_id: 42,
  assigned_user: { id: 10, name: 'Asha' },
  assignable_users: [
    { id: 10, name: 'Asha' },
    { id: 11, name: 'Baraka' },
  ],
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
    useMapGetter.mockReturnValue(ref('agent'));
    ReviewConfigurationSuggestionsAPI.get.mockResolvedValue({ data: [] });
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
    HumanReviewRequestsAPI.assign.mockResolvedValue({
      data: { ...review, assigned_user: { id: 11, name: 'Baraka' } },
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

  it('lets an administrator reassign a review through the canonical endpoint', async () => {
    useMapGetter.mockReturnValue(ref('administrator'));
    const wrapper = await mountPanel();

    await wrapper.get('select').setValue('11');
    await flushPromises();

    expect(HumanReviewRequestsAPI.assign).toHaveBeenCalledWith(8, {
      assigned_user_id: 11,
    });
    expect(wrapper.text()).toContain('Assigned to Baraka');
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

  it('renders a persisted provider failure and recovery guidance after reload', async () => {
    HumanReviewRequestsAPI.show.mockResolvedValue({
      data: {
        ...review,
        status: 'resolved',
        resolution_kind: 'send_reply',
        operator_answer: 'We will review the request.',
        reply_outcome: 'reply_delivery_failed',
        reply_delivery: {
          outcome: 'reply_delivery_failed',
          provider_status: 'failed',
          authority_state: 'accepted',
          failure_code: '13101',
          recoverable: false,
        },
        knowledge_proposal_outcome: 'not_requested',
        configuration_suggestion_outcome: 'not_requested',
      },
    });

    const wrapper = await mountPanel();

    expect(
      wrapper.get('[data-testid="persisted-reply-delivery"]').text()
    ).toContain('Reply delivery failed');
    expect(wrapper.text()).toContain('Delivery failure code: 13101');
    expect(wrapper.text()).toContain(
      'Check provider status before sending again'
    );
  });

  it('shows pending configuration feedback in an administrator queue', async () => {
    useMapGetter.mockReturnValue(ref('administrator'));
    HumanReviewRequestsAPI.get.mockResolvedValue({ data: [] });
    ReviewConfigurationSuggestionsAPI.get.mockResolvedValue({
      data: [
        {
          id: 55,
          suggestion: 'Review whether the fit rule is too broad.',
          source_type: 'lead_handoff',
          evidence:
            '{"quality":"highly_qualified","score":88,"reasons":["Lead agreed to a sales handoff","Budget confirmed","Third reason must stay hidden"],"evidence":{"sales_call_agreement":{"typed_value":true}}}',
          conversation_display_id: 42,
        },
        {
          id: 56,
          suggestion: 'Review the configured region rule.',
          source_type: 'human_review_request',
          evidence: 'Is service available outside the configured region?',
          conversation_display_id: 43,
        },
      ],
    });
    ReviewConfigurationSuggestionsAPI.review.mockResolvedValue({
      data: { id: 55, status: 'reviewed' },
    });

    const wrapper = await mountPanel({ conversationId: null, reviewId: null });

    expect(
      wrapper.get('[data-testid="pending-configuration-feedback"]').text()
    ).toContain('Review whether the fit rule is too broad.');
    expect(wrapper.text()).toContain(
      'Qualification: Highly Qualified · Score: 88'
    );
    expect(wrapper.text()).toContain(
      'Reasons: Lead agreed to a sales handoff; Budget confirmed'
    );
    expect(wrapper.text()).not.toContain('Third reason must stay hidden');
    expect(wrapper.text()).toContain(
      'Source question: Is service available outside the configured region?'
    );
    expect(wrapper.text()).not.toContain('sales_call_agreement');
    expect(wrapper.text()).not.toContain('typed_value');
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Mark reviewed')
      .trigger('click');
    await flushPromises();

    expect(ReviewConfigurationSuggestionsAPI.review).toHaveBeenCalledWith(55, {
      outcome: 'reviewed',
    });
    expect(wrapper.text()).not.toContain(
      'Review whether the fit rule is too broad.'
    );
    expect(wrapper.text()).toContain('Review the configured region rule.');
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

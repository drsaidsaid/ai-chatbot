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

const mountPanel = async () => {
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
    props: { conversationId: 12, reviewId: 8 },
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
      },
    });
    HumanReviewRequestsAPI.proposeKnowledge.mockResolvedValue({
      data: {
        ...review,
        status: 'resolved',
        knowledge_item_id: 31,
        knowledge_proposal_outcome: 'draft_proposed',
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
});

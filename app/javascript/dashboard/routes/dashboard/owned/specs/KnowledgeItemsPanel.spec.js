import { flushPromises, mount } from '@vue/test-utils';
import { createMemoryHistory, createRouter } from 'vue-router';
import KnowledgeItemsPanel from '../KnowledgeItemsPanel.vue';
import KnowledgeDocumentsAPI from 'dashboard/api/knowledgeDocuments';
import KnowledgeItemsAPI from 'dashboard/api/knowledgeItems';
import HumanReviewRequestsAPI from 'dashboard/api/humanReviewRequests';

vi.mock('dashboard/api/knowledgeDocuments', () => ({
  default: {
    list: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    import: vi.fn(),
    publish: vi.fn(),
    archive: vi.fn(),
    test: vi.fn(),
  },
}));

vi.mock('dashboard/api/knowledgeItems', () => ({
  default: {
    get: vi.fn(),
    create: vi.fn(),
    approve: vi.fn(),
    reject: vi.fn(),
    deactivate: vi.fn(),
  },
}));

vi.mock('dashboard/api/humanReviewRequests', () => ({
  default: {
    get: vi.fn(),
    resolve: vi.fn(),
    reject: vi.fn(),
  },
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

const IconStub = {
  props: ['icon'],
  template: '<span class="icon-stub" />',
};

const documentPayload = {
  id: 1,
  title: 'Everything about Online Profits',
  body: 'Online Profits helps businesses grow with CRM automation.',
  status: 'published',
  used_by_ai_employee: true,
  general_question_access: true,
  sensitive_topics: ['pricing', 'refunds', 'guarantees'],
  offer_ids: [],
  revisions: [
    {
      event: 'published',
      editor_name: 'John',
      recorded_at: '2026-08-27T08:00:00Z',
    },
  ],
  updated_at: '2026-08-27T08:00:00Z',
};

const approvedAnswer = {
  id: 2,
  title: 'Setup pricing',
  question: 'What is setup pricing?',
  answer: 'Setup starts at $20.',
  source_kind: 'pricing',
  status: 'approved',
  conflict_count: 1,
  created_at: '2026-08-26T08:00:00Z',
  updated_at: '2026-08-27T08:00:00Z',
};

const reviewRequest = {
  id: 3,
  question: 'Can you guarantee sales?',
  reason: 'sensitive_question',
  conversation_display_id: 42,
};

const mountComponent = async () => {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      {
        path: '/app/accounts/:accountId/knowledge',
        name: 'owned_knowledge_index',
        component: KnowledgeItemsPanel,
      },
    ],
  });
  router.push('/app/accounts/1/knowledge');
  await router.isReady();

  const wrapper = mount(KnowledgeItemsPanel, {
    global: {
      plugins: [router],
      stubs: { Icon: IconStub },
    },
  });
  await flushPromises();
  return wrapper;
};

describe('KnowledgeItemsPanel', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    KnowledgeDocumentsAPI.list.mockResolvedValue({ data: [documentPayload] });
    KnowledgeDocumentsAPI.create.mockResolvedValue({
      data: { ...documentPayload, id: 4, status: 'draft' },
    });
    KnowledgeDocumentsAPI.update.mockResolvedValue({
      data: { ...documentPayload, status: 'draft' },
    });
    KnowledgeDocumentsAPI.publish.mockResolvedValue({ data: documentPayload });
    KnowledgeDocumentsAPI.archive.mockResolvedValue({
      data: { ...documentPayload, status: 'archived' },
    });
    KnowledgeDocumentsAPI.import.mockResolvedValue({
      data: { ...documentPayload, id: 5, status: 'draft' },
    });
    KnowledgeDocumentsAPI.test.mockResolvedValue({
      data: {
        answered: true,
        answer: 'Online Profits helps businesses grow with CRM automation.',
        sources: [{ id: 1, source_kind: 'document' }],
      },
    });
    KnowledgeItemsAPI.get.mockResolvedValue({ data: [approvedAnswer] });
    KnowledgeItemsAPI.create.mockResolvedValue({
      data: { ...approvedAnswer, id: 6, status: 'draft' },
    });
    KnowledgeItemsAPI.approve.mockResolvedValue({ data: approvedAnswer });
    KnowledgeItemsAPI.reject.mockResolvedValue({
      data: { ...approvedAnswer, status: 'rejected' },
    });
    KnowledgeItemsAPI.deactivate.mockResolvedValue({
      data: { ...approvedAnswer, status: 'inactive' },
    });
    HumanReviewRequestsAPI.get.mockResolvedValue({ data: [reviewRequest] });
    HumanReviewRequestsAPI.resolve.mockResolvedValue({
      data: { ...reviewRequest, status: 'resolved' },
    });
    HumanReviewRequestsAPI.reject.mockResolvedValue({
      data: { ...reviewRequest, status: 'rejected' },
    });
  });

  it('renders document editor, access panel, preview, publish, archive, import, and test flows', async () => {
    const wrapper = await mountComponent();

    expect(wrapper.text()).toContain('Documents');
    expect(wrapper.text()).toContain('Everything about Online Profits');
    expect(wrapper.text()).toContain('AI Employee access');

    await wrapper
      .find('textarea[aria-label="Document body"]')
      .setValue('Updated Online Profits context');
    expect(wrapper.text()).toContain('Unsaved changes');

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Preview')
      .trigger('click');
    expect(wrapper.text()).toContain('Updated Online Profits context');

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Publish changes')
      .trigger('click');
    await flushPromises();
    expect(KnowledgeDocumentsAPI.update).toHaveBeenCalled();
    expect(KnowledgeDocumentsAPI.publish).toHaveBeenCalledWith(1);

    await wrapper
      .findAll('button')
      .find(button => button.text().includes('Test this document'))
      .trigger('click');
    await flushPromises();
    expect(KnowledgeDocumentsAPI.test).toHaveBeenCalledWith(
      1,
      'Can you explain Online Profits services?'
    );
    expect(wrapper.text()).toContain('CRM automation');

    await wrapper
      .findAll('button')
      .find(button => button.text().includes('Import document'))
      .trigger('click');
    await wrapper
      .find('input[aria-label="Imported document body"]')
      .setValue('Imported Online Profits policies');
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Import')
      .trigger('click');
    await flushPromises();
    expect(KnowledgeDocumentsAPI.import).toHaveBeenCalled();
  });

  it('keeps mobile header actions and tabs reachable at narrow widths', async () => {
    const wrapper = await mountComponent();

    const headerActions = wrapper.find(
      '[data-testid="knowledge-header-actions"]'
    );
    expect(headerActions.classes()).toEqual(
      expect.arrayContaining(['grid', 'w-full', 'grid-cols-2'])
    );
    expect(headerActions.classes()).toEqual(
      expect.arrayContaining(['sm:flex', 'sm:w-auto'])
    );

    const actionLabels = headerActions
      .findAll('button')
      .map(button => button.text());
    expect(actionLabels).toEqual(['Import document', 'New document']);

    const tabs = wrapper.find('[data-testid="knowledge-tabs"]');
    expect(tabs.classes()).toEqual(
      expect.arrayContaining(['overflow-x-auto', 'px-4', 'sm:px-0'])
    );
    expect(
      tabs.findAll('button').map(button => ({
        text: button.text(),
        classes: button.classes(),
      }))
    ).toEqual([
      expect.objectContaining({
        text: 'Documents',
        classes: expect.arrayContaining(['shrink-0', 'whitespace-nowrap']),
      }),
      expect.objectContaining({
        text: 'Approved Answers',
        classes: expect.arrayContaining(['shrink-0', 'whitespace-nowrap']),
      }),
      expect.objectContaining({
        text: 'Needs Review',
        classes: expect.arrayContaining(['shrink-0', 'whitespace-nowrap']),
      }),
    ]);
  });

  it('manages Approved Answers with conflict state and lifecycle actions', async () => {
    const wrapper = await mountComponent();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Approved Answers')
      .trigger('click');
    expect(wrapper.text()).toContain('Setup pricing');
    expect(wrapper.text()).toContain('Conflict warning');

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'New Approved Answer')
      .trigger('click');
    await wrapper.find('input[placeholder="Title"]').setValue('Refund policy');
    await wrapper
      .find('input[placeholder="Exact question or claim"]')
      .setValue('What is the refund policy?');
    await wrapper
      .find('textarea[placeholder="Approved answer"]')
      .setValue('Refunds require approval.');
    await wrapper.find('form').trigger('submit.prevent');
    await flushPromises();
    expect(KnowledgeItemsAPI.create).toHaveBeenCalled();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Reject')
      .trigger('click');
    await flushPromises();
    expect(KnowledgeItemsAPI.reject).toHaveBeenCalledWith(6);
  });

  it('resolves and rejects Review Requests with linked conversation access', async () => {
    const wrapper = await mountComponent();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Needs Review')
      .trigger('click');
    expect(wrapper.text()).toContain('Can you guarantee sales?');
    expect(
      wrapper.find('a[href="/app/accounts/1/conversations/42"]').exists()
    ).toBe(true);

    await wrapper
      .find(
        'textarea[placeholder="Answer for this lead or internal resolution note"]'
      )
      .setValue('We cannot guarantee sales.');
    await wrapper.find('form').trigger('submit.prevent');
    await flushPromises();
    expect(HumanReviewRequestsAPI.resolve).toHaveBeenCalledWith(
      3,
      expect.objectContaining({
        answer: 'We cannot guarantee sales.',
        propose_knowledge: true,
        send_to_lead: true,
      })
    );

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Reject')
      .trigger('click');
    await flushPromises();
    expect(HumanReviewRequestsAPI.reject).toHaveBeenCalledWith(
      3,
      expect.any(Object)
    );
  });
});

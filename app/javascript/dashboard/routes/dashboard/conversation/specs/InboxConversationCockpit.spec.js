import { flushPromises, mount } from '@vue/test-utils';
import { createMemoryHistory, createRouter } from 'vue-router';
import { createStore } from 'vuex';
import InboxConversationCockpit from '../InboxConversationCockpit.vue';
import ConversationApi from 'dashboard/api/inbox/conversation';
import InboxConversationsAPI from 'dashboard/api/inboxConversations';
import HumanReviewRequestsAPI from 'dashboard/api/humanReviewRequests';
import LeadHandoffsAPI from 'dashboard/api/leadHandoffs';
import ReviewConfigurationSuggestionsAPI from 'dashboard/api/reviewConfigurationSuggestions';
import bookingsAPI from 'dashboard/api/bookings';

vi.mock('dashboard/api/inbox/conversation', () => ({
  default: {
    show: vi.fn(),
    search: vi.fn(),
  },
}));

vi.mock('dashboard/api/inboxConversations', () => ({
  default: {
    get: vi.fn(),
  },
}));

vi.mock('dashboard/api/humanReviewRequests', () => ({
  default: {
    get: vi.fn(),
    show: vi.fn(),
  },
}));

vi.mock('dashboard/api/leadHandoffs', () => ({
  default: {
    show: vi.fn(),
    proposeConfigurationSuggestion: vi.fn(),
  },
}));

vi.mock('dashboard/api/reviewConfigurationSuggestions', () => ({
  default: { get: vi.fn(), review: vi.fn() },
}));

vi.mock('dashboard/api/bookings', () => ({
  default: {
    availableSlots: vi.fn(),
    create: vi.fn(),
    propose: vi.fn(),
  },
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    accountScopedRoute: (name, params = {}, query = {}) => ({
      name,
      params: { accountId: 1, ...params },
      query,
    }),
  }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params = {}) => {
      const labels = {
        'AI_LEAD_EMPLOYEE.INBOX_QUEUE.ALL': 'All',
        'AI_LEAD_EMPLOYEE.INBOX_QUEUE.HOT': 'Hot leads',
        'AI_LEAD_EMPLOYEE.INBOX_QUEUE.REVIEW': 'Needs review',
        'AI_LEAD_EMPLOYEE.INBOX_QUEUE.BOOKED': 'Booked',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.URGENCY': 'Urgent',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.FILTERS': 'Filters',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.LEAD_DETAILS': 'Lead details',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.SORT': 'Sort',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.SEARCH': 'Search',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.LOADING': 'Loading',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.EMPTY_VALUE': 'Not captured',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ALL_QUALITY': 'All quality',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ALL_STATES': 'All states',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ALL_ASSIGNEES': 'All assignees',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ALL_SOURCES': 'All sources',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ALL_BOOKINGS': 'All bookings',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ME': 'Me',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.UNASSIGNED': 'Unassigned',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.CLEAR_FILTERS': 'Clear filters',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.BACK_TO_LIST': 'Back',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ASSIGNEE': 'Assignee',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.BOOKING': 'Booking',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.MORE_ACTIONS': 'More actions',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.SELECT_CONVERSATION':
          'Select conversation',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.PROPOSED_NEXT_STEP':
          'Proposed next step',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.TECHNICAL_DETAILS': 'Technical details',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.BOOKED_TIME': 'Booked time',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ATTENDEE': 'Attendee',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.CALL_TYPE': 'Call type',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.PRODUCT_DEMO': 'Product demo',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ASSIGN': 'Assign',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ASSIGN_OPERATOR': 'Assign operator',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ASSIGN_SUCCESS':
          'Conversation assignment updated. Human control is active when an operator is assigned.',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.TAKE_OVER': 'Take over',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.TAKE_OVER_SUCCESS':
          'You now control this Conversation. Pending automated replies were canceled.',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.RESOLVE': 'Resolve Conversation',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.RESOLVE_SUCCESS':
          'Conversation resolved. Pending automated replies were canceled.',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.CLOSED_EXPLANATION':
          'Reopen the Conversation before changing AI control.',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.HANDOFF_CONTROL_EXPLANATION':
          'Assign or take over this Conversation before resuming AI.',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.PAUSE_AI': 'Pause AI',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.PAUSE_SUCCESS':
          'AI is paused for this Conversation. Pending automated replies were canceled.',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.RESUME_AI': 'Resume AI',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.RESUME_SUCCESS':
          'Control returned to AI. The Conversation is unassigned, and only future eligible messages can create new work. Earlier canceled replies remain canceled.',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ACTION_FAILED':
          'The action could not be completed. The Conversation was not changed.',
        'CONVERSATION_SIDEBAR.AI_EMPLOYEE.CONSENT.STOPPED':
          'Automated contact stopped',
        'CONVERSATION_SIDEBAR.AI_EMPLOYEE.CONSENT.RESUME_NOTICE':
          'Resume AI does not restart automated messages. An administrator must record a newer explicit re-consent message.',
        'CONVERSATION_SIDEBAR.AI_EMPLOYEE.CONSENT.GRANTED':
          'Automated contact permitted',
        'CONVERSATION_SIDEBAR.AI_EMPLOYEE.CONSENT.GRANTED_DESCRIPTION':
          'A newer explicit permission message was recorded.',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.TAB.SUMMARY': 'Summary',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.TAB.EVIDENCE': 'Evidence',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.TAB.ACTIVITY': 'Activity',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.WHY_THIS_LEAD_MATTERS':
          'Why this lead matters',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.STRONGEST_EVIDENCE':
          'Strongest evidence',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.MISSING_SIGNALS': 'Missing signals',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.NO_MISSING_SIGNALS':
          'No missing signals',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.NEXT_RECOMMENDED_ACTION':
          'Next recommended action',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.CURRENT': 'Current',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.SUPERSEDED': 'Superseded',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.CLOSE': 'Close',
        'AI_LEAD_EMPLOYEE.NAV.KNOWLEDGE': 'Knowledge',
        'AI_LEAD_EMPLOYEE.NAV.TEST_CENTER': 'Test Center',
      };

      if (key === 'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.QUEUE_COUNT') {
        return `${params.count} conversations`;
      }

      if (key === 'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.OPEN_CONVERSATION') {
        return `Open ${params.name} ${params.id}`;
      }

      if (key === 'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.OPEN_REVIEW_REASON') {
        return `${params.count} review open: ${params.reason}`;
      }

      if (key === 'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.SCORE') {
        return `Score ${params.score}`;
      }

      return labels[key] || key;
    },
  }),
}));

const IconStub = {
  props: ['icon'],
  template: '<span class="icon-stub" />',
};

const AvatarStub = {
  props: ['name'],
  template: '<span class="avatar-stub">{{ name }}</span>',
};

const MessagesViewStub = {
  props: ['inboxId'],
  data: () => ({
    composerLabel: 'Reply composer',
    timelineLabel: 'Readable message timeline',
  }),
  template: `
    <div data-testid="messages-view">
      <div class="timeline-stub">{{ timelineLabel }}</div>
      <slot name="beforeComposer" />
      <div data-testid="reply-composer">{{ composerLabel }}</div>
    </div>
  `,
};

const routes = [
  {
    path: '/accounts/:accountId/dashboard',
    name: 'home',
    component: InboxConversationCockpit,
  },
  {
    path: '/accounts/:accountId/conversations/:conversation_id',
    name: 'inbox_conversation',
    component: InboxConversationCockpit,
    props: route => ({ conversationId: route.params.conversation_id }),
  },
  {
    path: '/accounts/:accountId/knowledge',
    name: 'owned_knowledge_index',
    component: {},
  },
  {
    path: '/accounts/:accountId/test-center',
    name: 'owned_test_center_index',
    component: {},
  },
  {
    path: '/accounts/:accountId/bookings',
    name: 'owned_bookings_index',
    component: {},
  },
];

const row = overrides => ({
  id: overrides.id,
  name: overrides.name,
  email: `${overrides.name.toLowerCase().replaceAll(' ', '.')}@example.com`,
  phone_number: '+255700000000',
  contact_details: {
    additional_attributes: {
      company_name: `${overrides.name} Clinic`,
    },
  },
  quality: overrides.quality,
  follow_up_state: overrides.followUpState,
  score: overrides.score || 90,
  reasons: overrides.reasons || ['Asked for WhatsApp automation'],
  missing_signals: overrides.missingSignals || [],
  assignee: overrides.assignee || null,
  source: { id: 7, name: 'WhatsApp Sales', channel_type: 'Channel::Whatsapp' },
  control_state: overrides.controlState || 'ai_active',
  conversation_status: 'open',
  conversation_id: overrides.id + 1000,
  conversation_display_id: overrides.displayId,
  unanswered_questions_count: overrides.unanswered || 0,
  unread_count: overrides.unread || 0,
  last_message_preview: overrides.preview,
  last_activity_at: '2026-08-26T09:00:00Z',
  location: overrides.location || 'Dar es Salaam',
  booking_state: overrides.bookingState || 'not_booked',
});

const rowsByQueue = {
  hot: [
    row({
      id: 1,
      displayId: 101,
      name: 'Asha Mushi',
      quality: 'highly_qualified',
      followUpState: 'call_booked',
      bookingState: 'booked',
      preview: 'I need WhatsApp automation this week.',
      unread: 2,
    }),
  ],
  review: [
    row({
      id: 2,
      displayId: 202,
      name: 'Ravi Review',
      quality: 'qualified',
      followUpState: 'human_review',
      preview: 'Can you answer pricing?',
      unanswered: 1,
    }),
  ],
  booked: [
    row({
      id: 3,
      displayId: 303,
      name: 'Bianca Booked',
      quality: 'highly_qualified',
      followUpState: 'call_booked',
      bookingState: 'booked',
      preview: 'See you on the call.',
    }),
  ],
};

const conversationPayload = {
  id: 101,
  inbox_id: 7,
  control_state: 'ai_active',
  control_version: 5,
  status: 'open',
  can_reply: true,
  meta: {
    sender: {
      id: 11,
      name: 'Asha Mushi',
      phone_number: '+255700000000',
      additional_attributes: {
        city: 'Dar es Salaam',
        country: 'Tanzania',
      },
    },
    assignee: { id: 9, name: 'Nia Operator', avatar_url: '' },
  },
  lead_qualification: {
    quality: 'highly_qualified',
    score: 92,
    reasons: ['Clinic owner asked for WhatsApp automation'],
    missing_signals: ['preferred_demo_time'],
  },
  automated_contact_consent: {
    state: 'withdrawn',
    evidence: {
      text: 'Tafadhali usinitumie ujumbe tena.',
      occurred_at: '2026-08-26T08:58:00Z',
    },
  },
  cockpit: {
    summary: {
      why: [
        { label: 'Role fit', value: 'Clinic owner' },
        { label: 'Goal', value: 'Manual WhatsApp follow-up is too slow' },
      ],
      strongest_evidence: ['Budget is available'],
      missing_signals: ['preferred_demo_time'],
    },
    evidence: [
      {
        id: 1,
        signal: 'budget',
        value: 'USD 1,000 monthly',
        source: 'extracted',
        source_message: 'I need WhatsApp automation this week.',
        observed_at: '2026-08-26T09:00:00Z',
        superseded: false,
      },
    ],
    activity: [
      {
        id: 'handoff-1',
        kind: 'handoff',
        label: 'Handoff created',
        detail: 'Nia Operator',
        occurred_at: '2026-08-26T09:05:00Z',
        tone: 'blue',
      },
    ],
    booking: {
      id: 1,
      status: 'confirmed',
      starts_at: '2026-08-27T14:00:00Z',
      timezone: 'Africa/Dar_es_Salaam',
    },
    handoff: {
      id: 1,
      status: 'open',
      assignee: { id: 9, name: 'Nia Operator' },
    },
    open_reviews: [
      {
        id: 1,
        question: 'Can we send pricing?',
        reason: 'no_approved_knowledge',
        status: 'open',
      },
    ],
    next_action: {
      kind: 'answer_review',
      label: 'Answer review request',
      detail: 'Can we send pricing?',
    },
  },
  messages: [{ id: 1, content: 'I need WhatsApp automation this week.' }],
};

const buildStore = ({ role = 'administrator' } = {}) => {
  const actions = {
    'agents/get': vi.fn(),
    'inboxes/get': vi.fn(),
    pauseAI: vi.fn(),
    resumeAI: vi.fn(),
    assignAgent: vi.fn(),
    toggleStatus: vi.fn(),
    'draftMessages/setReplyEditorMode': vi.fn(),
    clearSelectedState: vi.fn(({ commit }) => commit('setChat', {})),
    updateConversation: vi.fn(({ commit }, data) => commit('setChat', data)),
    setActiveChat: vi.fn(({ commit }, { data }) => commit('setChat', data)),
  };
  const store = createStore({
    state: { chat: {} },
    mutations: {
      setChat: (state, chat) => {
        state.chat = chat;
      },
    },
    actions,
    getters: {
      getSelectedChat: state => state.chat,
      getCurrentUser: () => ({ id: 9, name: 'Nia Operator', avatar_url: '' }),
      getCurrentRole: () => role,
      'agents/getAgents': () => [
        { id: 9, name: 'Nia Operator' },
        { id: 10, name: 'Musa Operator' },
      ],
      'inboxes/getInbox': () => inboxId => ({
        id: inboxId,
        name: 'WhatsApp Sales',
        channel_type: 'Channel::Whatsapp',
      }),
    },
  });

  return { store, actions };
};

const buildRouter = async (query = {}) => {
  const router = createRouter({
    history: createMemoryHistory(),
    routes,
  });

  await router.push({
    name: 'inbox_conversation',
    params: { accountId: 1, conversation_id: 101 },
    query,
  });
  await router.isReady();

  return router;
};

const mountCockpit = async ({
  query = {},
  list = false,
  attach = false,
  role = 'administrator',
} = {}) => {
  const router = await buildRouter(query);
  if (list)
    await router.push({ name: 'home', params: { accountId: 1 }, query });
  const { store, actions } = buildStore({ role });

  const wrapper = mount(
    { template: '<router-view />' },
    {
      attachTo: attach ? document.body : undefined,
      global: {
        plugins: [router, store],
        stubs: {
          Avatar: AvatarStub,
          Icon: IconStub,
          MessagesView: MessagesViewStub,
        },
      },
    }
  );

  await flushPromises();

  return { wrapper, router, actions };
};

const clickQueue = async (wrapper, label) => {
  const link = wrapper.findAll('a').find(item => item.text().includes(label));
  await link.trigger('click');
  await flushPromises();
};

const clickButton = async (wrapper, label) => {
  const button = wrapper
    .findAll('button')
    .find(item => item.text().trim() === label);
  await button.trigger('click');
  await flushPromises();
};

const deferred = () => {
  let resolve;
  const promise = new Promise(resolvePromise => {
    resolve = resolvePromise;
  });
  return { promise, resolve };
};

describe('InboxConversationCockpit', () => {
  beforeEach(() => {
    HumanReviewRequestsAPI.get.mockResolvedValue({ data: [] });
    LeadHandoffsAPI.show.mockResolvedValue({
      data: {
        id: 1,
        status: 'open',
        configuration_suggestion_outcome: 'not_requested',
        configuration_suggestion: null,
        can_review_configuration_suggestion: false,
      },
    });
    LeadHandoffsAPI.proposeConfigurationSuggestion.mockResolvedValue({
      data: {
        id: 1,
        status: 'open',
        configuration_suggestion_outcome: 'pending',
        configuration_suggestion: {
          id: 5,
          status: 'pending',
          suggestion: 'Review the readiness rule.',
        },
        can_review_configuration_suggestion: false,
      },
    });
    ReviewConfigurationSuggestionsAPI.review.mockResolvedValue({
      data: { id: 5, status: 'reviewed' },
    });
    ReviewConfigurationSuggestionsAPI.get.mockResolvedValue({ data: [] });
    InboxConversationsAPI.get.mockImplementation(params => {
      if (params?.queue === 'review') {
        return Promise.resolve({
          data: { conversations: rowsByQueue.review, counts: {} },
        });
      }

      if (params?.booking_status === 'booked') {
        return Promise.resolve({
          data: { conversations: rowsByQueue.booked, counts: {} },
        });
      }

      return Promise.resolve({
        data: {
          conversations: rowsByQueue.hot,
          counts: {
            highly_qualified_leads: 1,
            unanswered_questions: 1,
            booked_calls: 1,
          },
          filter_options: {
            qualities: ['highly_qualified', 'qualified'],
            follow_up_states: ['human_review', 'call_booked'],
            assignees: [{ id: 9, name: 'Nia Operator' }],
            sources: [{ id: 7, name: 'WhatsApp Sales' }],
            booking_statuses: ['booked'],
          },
        },
      });
    });
    ConversationApi.show.mockResolvedValue({ data: conversationPayload });
    ConversationApi.search.mockResolvedValue({
      data: { payload: [{ id: 101 }] },
    });
    bookingsAPI.availableSlots.mockResolvedValue({
      data: {
        slots: ['2026-08-31T06:00:00Z', '2026-08-31T06:30:00Z'],
        provider_state: 'connected',
        configuration: { timezone: 'Africa/Dar_es_Salaam' },
      },
    });
    bookingsAPI.create.mockResolvedValue({ status: 201, data: {} });
    bookingsAPI.propose.mockResolvedValue({ status: 201, data: {} });
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it('records configuration feedback on the actual sales handoff', async () => {
    const { wrapper } = await mountCockpit({
      conversationId: 101,
      role: 'agent',
    });
    const panel = wrapper.get('[data-testid="lead-handoff-feedback"]');

    await panel
      .get(
        'textarea[placeholder="AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_SUGGESTION_PLACEHOLDER"]'
      )
      .setValue('Review the readiness rule.');
    await panel
      .findAll('button')
      .find(button =>
        button.text().includes('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_PROPOSE')
      )
      .trigger('click');
    await flushPromises();

    expect(LeadHandoffsAPI.proposeConfigurationSuggestion).toHaveBeenCalledWith(
      1,
      { category: 'poor_fit', suggestion: 'Review the readiness rule.' }
    );
    expect(panel.text()).toContain('Review the readiness rule.');
  });

  it('shows the administrator feedback queue on the real Needs review list route', async () => {
    ReviewConfigurationSuggestionsAPI.get.mockResolvedValue({
      data: [
        {
          id: 55,
          suggestion: 'Review whether the fit rule is too broad.',
          evidence: '{"quality":"qualified"}',
          conversation_display_id: 202,
        },
      ],
    });
    const { wrapper, router } = await mountCockpit({ role: 'administrator' });

    await clickQueue(wrapper, 'Needs review');

    expect(router.currentRoute.value.name).toBe('home');
    expect(router.currentRoute.value.query.queue).toBe('review');
    expect(ReviewConfigurationSuggestionsAPI.get).toHaveBeenCalled();
    expect(
      wrapper.get('[data-testid="pending-configuration-feedback"]').text()
    ).toContain('Review whether the fit rule is too broad.');
  });

  it('starts with a selectable All list and preserves filters through opening, returning and browser back', async () => {
    const { wrapper, router } = await mountCockpit({
      list: true,
      query: { q: 'Asha', quality: 'highly_qualified' },
    });
    expect(router.currentRoute.value.query.queue).toBe('all');
    expect(ConversationApi.show).not.toHaveBeenCalled();
    expect(wrapper.find('input[type="search"]').element.value).toBe('Asha');
    await wrapper
      .get('button[aria-label="Open Asha Mushi 101"]')
      .trigger('click');
    await flushPromises();
    expect(wrapper.text()).toContain('Reply composer');
    await wrapper.get('button[aria-label="Back"]').trigger('click');
    await flushPromises();
    expect(router.currentRoute.value.name).toBe('home');
    expect(wrapper.find('[data-testid="messages-view"]').exists()).toBe(false);
    expect(
      wrapper.get('button[aria-label="Open Asha Mushi 101"]').exists()
    ).toBe(true);
    expect(router.currentRoute.value.query).toEqual({
      queue: 'all',
      q: 'Asha',
      quality: 'highly_qualified',
    });
    router.back();
    await flushPromises();
    expect(router.currentRoute.value.name).toBe('inbox_conversation');
    expect(wrapper.text()).toContain('Reply composer');
  });

  it('clears a stale review id when opening another conversation from the review queue', async () => {
    const { wrapper, router } = await mountCockpit({
      list: true,
      query: { queue: 'review', review_id: '8' },
    });

    await wrapper
      .get('button[aria-label="Open Ravi Review 202"]')
      .trigger('click');
    await flushPromises();

    expect(router.currentRoute.value.query).toEqual({ queue: 'review' });
  });

  it('restores focus to the selected row without refetching an unchanged list', async () => {
    const { wrapper } = await mountCockpit({ list: true, attach: true });
    await wrapper
      .get('button[aria-label="Open Asha Mushi 101"]')
      .trigger('click');
    await flushPromises();
    InboxConversationsAPI.get.mockClear();
    InboxConversationsAPI.get.mockImplementationOnce(
      () => new Promise(() => {})
    );
    await wrapper.get('button[aria-label="Back"]').trigger('click');
    await flushPromises();
    expect(document.activeElement).toBe(
      wrapper.get('button[aria-label="Open Asha Mushi 101"]').element
    );
    expect(InboxConversationsAPI.get).not.toHaveBeenCalled();
    wrapper.unmount();
  });

  it('changes queues without automatically opening a different Conversation', async () => {
    const { wrapper, router } = await mountCockpit({ list: true });
    await clickQueue(wrapper, 'Needs review');
    expect(router.currentRoute.value.name).toBe('home');
    expect(wrapper.text()).toContain('Ravi Review');
    expect(InboxConversationsAPI.get).toHaveBeenLastCalledWith(
      expect.objectContaining({ queue: 'review' })
    );
  });

  it('provides a way back to the queue when a direct Conversation link is unavailable', async () => {
    ConversationApi.show.mockRejectedValueOnce(new Error('Not found'));
    const { wrapper, router } = await mountCockpit({
      query: { queue: 'review', q: 'Asha' },
    });
    expect(wrapper.find('[role="alert"]').exists()).toBe(true);
    await wrapper.get('button[aria-label="Back"]').trigger('click');
    await flushPromises();
    expect(router.currentRoute.value.name).toBe('home');
    expect(router.currentRoute.value.query).toEqual({
      queue: 'review',
      q: 'Asha',
    });
  });

  it('does not offer booking confirmation on desktop or phone when there is no Booking', async () => {
    ConversationApi.show.mockResolvedValueOnce({
      data: {
        ...conversationPayload,
        cockpit: {
          ...conversationPayload.cockpit,
          booking: null,
          next_action: { kind: 'resume_ai', label: 'Resume AI' },
        },
      },
    });
    const { wrapper } = await mountCockpit();
    await wrapper
      .get('button[aria-controls="mobile-lead-brief-panel"]')
      .trigger('click');
    expect(wrapper.text()).not.toContain('Confirm call');
  });

  it('shows a confirmed Booking as information without offering another confirmation', async () => {
    ConversationApi.show.mockResolvedValueOnce({
      data: {
        ...conversationPayload,
        cockpit: {
          ...conversationPayload.cockpit,
          open_reviews: [],
          next_action: {
            kind: 'booking_confirmed',
            label: 'Call booked',
            detail: 'Aug 27, 2026 at 2:00 PM Africa/Dar_es_Salaam',
          },
        },
      },
    });
    const { wrapper } = await mountCockpit();

    expect(wrapper.text()).toContain('Call booked');
    expect(wrapper.text()).toContain('Booked time');
    expect(wrapper.text()).toContain('Aug 27, 5:00 PM');
    expect(
      wrapper.find('[data-testid="confirm-booking-action"]').exists()
    ).toBe(false);
  });

  it('routes an unresolved provider result to reconciliation before another booking action', async () => {
    ConversationApi.show.mockResolvedValueOnce({
      data: {
        ...conversationPayload,
        cockpit: {
          ...conversationPayload.cockpit,
          next_action: {
            kind: 'reconcile_booking',
            label: 'Reconcile calendar result',
            booking_id: 27,
          },
        },
      },
    });
    const { wrapper } = await mountCockpit();

    const action = wrapper.get('[data-testid="reconcile-booking-action"]');
    expect(action.text()).toBe('Reconcile calendar result');
    expect(action.attributes('href')).toContain('booking_id=27');
    expect(wrapper.find('[data-testid="book-call-action"]').exists()).toBe(
      false
    );
    expect(
      wrapper.find('[data-testid="offer-call-time-action"]').exists()
    ).toBe(false);
  });

  it('offers a provider-backed time through the canonical proposal endpoint', async () => {
    ConversationApi.show.mockResolvedValueOnce({
      data: {
        ...conversationPayload,
        cockpit: {
          ...conversationPayload.cockpit,
          booking: null,
          next_action: {
            kind: 'offer_call_times',
            label: 'Offer an available time',
          },
        },
      },
    });
    const { wrapper } = await mountCockpit();

    await wrapper
      .get('[data-testid="offer-call-time-action"]')
      .trigger('click');
    await flushPromises();
    await wrapper.get('[role="dialog"] form').trigger('submit.prevent');
    await flushPromises();

    expect(bookingsAPI.propose).toHaveBeenCalledWith({
      conversation_id: 101,
      starts_at: '2026-08-31T06:00:00Z',
      idempotency_key: expect.stringMatching(/^booking-101-/),
    });
  });

  it('books only the exact agreed time and sends an email only after voluntary confirmation', async () => {
    ConversationApi.show.mockResolvedValueOnce({
      data: {
        ...conversationPayload,
        cockpit: {
          ...conversationPayload.cockpit,
          booking: null,
          next_action: {
            kind: 'book_call',
            label: 'Book agreed time',
            agreed_starts_at: '2026-08-31T06:30:00Z',
            agreement_message_id: 77,
          },
        },
      },
    });
    bookingsAPI.create.mockResolvedValueOnce({ status: 202, data: {} });
    const { wrapper } = await mountCockpit();

    await wrapper.get('[data-testid="book-call-action"]').trigger('click');
    await flushPromises();
    const dialog = wrapper.get('[role="dialog"]');
    expect(dialog.findAll('option')).toHaveLength(1);
    expect(dialog.get('option').attributes('value')).toBe(
      '2026-08-31T06:30:00Z'
    );
    await dialog.get('input[type="checkbox"]').setValue(true);
    await dialog.get('input[type="email"]').setValue('lead@example.test');
    await dialog.get('form').trigger('submit.prevent');
    await flushPromises();

    expect(bookingsAPI.create).toHaveBeenCalledWith({
      conversation_id: 101,
      starts_at: '2026-08-31T06:30:00Z',
      agreed_starts_at: '2026-08-31T06:30:00Z',
      agreement_message_id: 77,
      idempotency_key: expect.stringMatching(/^booking-101-/),
      attendee_email_voluntarily_supplied: true,
      attendee_email: 'lead@example.test',
    });
  });

  it('offers the review action without showing booking details for a Review Request', async () => {
    ConversationApi.show.mockResolvedValueOnce({
      data: {
        ...conversationPayload,
        cockpit: {
          ...conversationPayload.cockpit,
          booking: null,
          next_action: {
            kind: 'answer_review',
            label: 'Answer review request',
            detail: 'Can we send pricing?',
          },
        },
      },
    });

    const { wrapper, actions } = await mountCockpit({
      query: { queue: 'review' },
    });

    expect(wrapper.get('[data-testid="review-request-action"]').text()).toBe(
      'Answer review request'
    );
    expect(wrapper.text()).not.toContain('Proposed time');
    expect(wrapper.text()).not.toContain('Confirm call time');

    await wrapper.get('[data-testid="review-request-action"]').trigger('click');
    expect(actions['draftMessages/setReplyEditorMode']).toHaveBeenCalledWith(
      expect.any(Object),
      { mode: 'REPLY' }
    );

    await wrapper
      .get('button[aria-controls="mobile-lead-brief-panel"]')
      .trigger('click');

    expect(
      wrapper.get('[data-testid="mobile-review-request-action"]').text()
    ).toBe('Answer review request');
  });

  it('lets an assigned Human Operator explicitly resume AI and shows the persisted state', async () => {
    const humanOwnedConversation = {
      ...conversationPayload,
      control_state: 'human_active',
      control_version: 8,
    };
    const resumedConversation = {
      ...humanOwnedConversation,
      control_state: 'ai_active',
      control_version: 9,
      meta: { ...humanOwnedConversation.meta, assignee: null },
    };
    ConversationApi.show
      .mockResolvedValueOnce({ data: humanOwnedConversation })
      .mockResolvedValueOnce({ data: resumedConversation });

    const { wrapper, actions } = await mountCockpit();

    expect(
      wrapper.get('[data-testid="conversation-control-state"]').text()
    ).toBe('Human Active');
    const resumeButton = wrapper.get('[data-testid="resume-ai-action"]');
    expect(resumeButton.attributes('disabled')).toBeUndefined();

    await resumeButton.trigger('click');
    await flushPromises();

    expect(actions.resumeAI).toHaveBeenCalledWith(expect.any(Object), {
      conversationId: 101,
      accountId: '1',
    });
    expect(
      wrapper.get('[data-testid="conversation-control-state"]').text()
    ).toBe('AI Active');
    expect(wrapper.get('[role="status"]').text()).toContain(
      'Control returned to AI'
    );
    expect(wrapper.text()).toContain('Assignee: Unassigned');
  });

  it('returns a Team Member to their permitted list after handing an assigned Conversation back to AI', async () => {
    const humanOwnedConversation = {
      ...conversationPayload,
      control_state: 'human_active',
      control_version: 8,
    };
    ConversationApi.show.mockResolvedValueOnce({
      data: humanOwnedConversation,
    });

    const { wrapper, router, actions } = await mountCockpit({ role: 'agent' });
    actions.resumeAI.mockResolvedValueOnce(true);

    await wrapper.get('[data-testid="resume-ai-action"]').trigger('click');
    await flushPromises();

    expect(router.currentRoute.value.name).toBe('home');
    expect(ConversationApi.show).toHaveBeenCalledTimes(1);
  });

  it('keeps the current state and explains when resume fails', async () => {
    const humanOwnedConversation = {
      ...conversationPayload,
      control_state: 'human_active',
      control_version: 8,
    };
    ConversationApi.show.mockResolvedValueOnce({
      data: humanOwnedConversation,
    });

    const { wrapper, actions } = await mountCockpit();
    actions.resumeAI.mockResolvedValueOnce(false);

    await wrapper.get('[data-testid="resume-ai-action"]').trigger('click');
    await flushPromises();

    expect(ConversationApi.show).toHaveBeenCalledTimes(1);
    expect(
      wrapper.get('[data-testid="conversation-control-state"]').text()
    ).toBe('Human Active');
    expect(wrapper.get('[role="alert"]').text()).toContain(
      'Conversation was not changed'
    );
  });

  it('does not offer resume while a handoff is still requested', async () => {
    ConversationApi.show.mockResolvedValueOnce({
      data: { ...conversationPayload, control_state: 'handoff_requested' },
    });

    const { wrapper } = await mountCockpit();

    expect(wrapper.find('[data-testid="resume-ai-action"]').exists()).toBe(
      false
    );
    expect(
      wrapper.get('[data-testid="control-unavailable-reason"]').text()
    ).toContain('Assign or take over this Conversation before resuming AI');
  });

  it('lets an authorized operator take over an AI-controlled Conversation', async () => {
    const humanOwnedConversation = {
      ...conversationPayload,
      control_state: 'human_active',
      control_version: 6,
    };
    ConversationApi.show
      .mockResolvedValueOnce({ data: conversationPayload })
      .mockResolvedValueOnce({ data: humanOwnedConversation });

    const { wrapper, actions } = await mountCockpit({ role: 'agent' });

    await wrapper.get('[data-testid="take-over-action"]').trigger('click');
    await flushPromises();

    expect(actions.toggleStatus).toHaveBeenCalledWith(expect.any(Object), {
      conversationId: 101,
      status: 'open',
      accountId: '1',
    });
    expect(
      wrapper.get('[data-testid="conversation-control-state"]').text()
    ).toBe('Human Active');
    expect(wrapper.get('[role="status"]').text()).toContain(
      'You now control this Conversation'
    );
  });

  it('pauses AI persistently and reports that automated work was canceled', async () => {
    const pausedConversation = {
      ...conversationPayload,
      control_state: 'ai_paused',
      control_version: 6,
    };
    ConversationApi.show
      .mockResolvedValueOnce({ data: conversationPayload })
      .mockResolvedValueOnce({ data: pausedConversation });

    const { wrapper, actions } = await mountCockpit();

    await wrapper.get('[data-testid="pause-ai-action"]').trigger('click');
    await flushPromises();

    expect(actions.pauseAI).toHaveBeenCalledWith(expect.any(Object), {
      conversationId: 101,
      accountId: '1',
    });
    expect(
      wrapper.get('[data-testid="conversation-control-state"]').text()
    ).toBe('AI Paused');
    expect(wrapper.get('[role="status"]').text()).toContain(
      'AI is paused for this Conversation'
    );
  });

  it('resolves the Conversation persistently and explains why control actions are unavailable', async () => {
    const humanOwnedConversation = {
      ...conversationPayload,
      control_state: 'human_active',
      control_version: 8,
    };
    const resolvedConversation = {
      ...humanOwnedConversation,
      status: 'resolved',
      control_state: 'closed',
      control_version: 9,
    };
    ConversationApi.show
      .mockResolvedValueOnce({ data: humanOwnedConversation })
      .mockResolvedValueOnce({ data: resolvedConversation });

    const { wrapper, actions } = await mountCockpit();

    await wrapper
      .get('[data-testid="resolve-conversation-action"]')
      .trigger('click');
    await flushPromises();

    expect(actions.toggleStatus).toHaveBeenCalledWith(expect.any(Object), {
      conversationId: 101,
      status: 'resolved',
      accountId: '1',
    });
    expect(
      wrapper.get('[data-testid="conversation-control-state"]').text()
    ).toBe('Closed');
    expect(wrapper.get('[role="status"]').text()).toContain(
      'Conversation resolved'
    );
    expect(
      wrapper.get('[data-testid="control-unavailable-reason"]').text()
    ).toContain('Reopen the Conversation before changing AI control');
    expect(wrapper.find('[data-testid="resume-ai-action"]').exists()).toBe(
      false
    );
  });

  it('lets an Admin assign or reassign the Conversation to an operator', async () => {
    const unassignedConversation = {
      ...conversationPayload,
      meta: { ...conversationPayload.meta, assignee: null },
    };
    const assignedConversation = {
      ...conversationPayload,
      control_state: 'human_active',
      control_version: 6,
      meta: {
        ...conversationPayload.meta,
        assignee: { id: 10, name: 'Musa Operator', avatar_url: '' },
      },
    };
    ConversationApi.show
      .mockResolvedValueOnce({ data: unassignedConversation })
      .mockResolvedValueOnce({ data: assignedConversation });

    const { wrapper, actions } = await mountCockpit();

    await wrapper.get('[data-testid="assignee-control"]').setValue('10');
    await flushPromises();

    expect(actions.assignAgent).toHaveBeenCalledWith(expect.any(Object), {
      conversationId: 101,
      agentId: 10,
      assigneeType: 'User',
      accountId: '1',
    });
    expect(wrapper.text()).toContain('Assignee: Musa Operator');
    expect(
      wrapper.get('[data-testid="conversation-control-state"]').text()
    ).toBe('Human Active');
    expect(wrapper.get('[role="status"]').text()).toContain(
      'Conversation assignment updated'
    );
  });

  it('keeps assignment and control unchanged when reassignment fails', async () => {
    const { wrapper, actions } = await mountCockpit();
    actions.assignAgent.mockResolvedValueOnce(false);

    await wrapper.get('[data-testid="assignee-control"]').setValue('10');
    await flushPromises();

    expect(ConversationApi.show).toHaveBeenCalledTimes(1);
    expect(wrapper.text()).toContain('Assignee: Nia Operator');
    expect(
      wrapper.get('[data-testid="conversation-control-state"]').text()
    ).toBe('AI Active');
    expect(wrapper.get('[role="alert"]').text()).toContain(
      'Conversation was not changed'
    );
  });

  it('does not expose reassignment controls to a Team Member', async () => {
    const { wrapper } = await mountCockpit({ role: 'agent' });
    await wrapper
      .get('button[aria-controls="mobile-lead-brief-panel"]')
      .trigger('click');

    expect(wrapper.find('[data-testid="assignee-control"]').exists()).toBe(
      false
    );
    expect(
      wrapper.find('[data-testid="mobile-assignee-control"]').exists()
    ).toBe(false);
  });

  it('does not apply a delayed assignment result to the same display ID in another account', async () => {
    const assignment = deferred();
    const nextConversation = {
      ...conversationPayload,
      meta: {
        ...conversationPayload.meta,
        sender: { ...conversationPayload.meta.sender, name: 'Ravi Review' },
      },
    };
    ConversationApi.show
      .mockResolvedValueOnce({ data: conversationPayload })
      .mockResolvedValueOnce({ data: nextConversation });

    const { wrapper, router, actions } = await mountCockpit();
    actions.assignAgent.mockReturnValueOnce(assignment.promise);
    await wrapper.get('[data-testid="assignee-control"]').setValue('10');
    await router.push({
      name: 'inbox_conversation',
      params: { accountId: 2, conversation_id: 101 },
    });
    await flushPromises();

    assignment.resolve(true);
    await flushPromises();

    expect(wrapper.text()).toContain('Ravi Review');
    expect(ConversationApi.show).toHaveBeenCalledTimes(2);
    expect(wrapper.find('[role="status"]').exists()).toBe(false);
    expect(wrapper.find('[role="alert"]').exists()).toBe(false);
  });

  it('clears completed action feedback for the same display ID in another account', async () => {
    const nextConversation = {
      ...conversationPayload,
      meta: {
        ...conversationPayload.meta,
        sender: { ...conversationPayload.meta.sender, name: 'Ravi Review' },
      },
    };
    const { wrapper, router } = await mountCockpit();

    await clickButton(wrapper, 'Pause AI');
    expect(wrapper.find('[role="status"]').exists()).toBe(true);
    ConversationApi.show.mockResolvedValueOnce({ data: nextConversation });

    await router.push({
      name: 'inbox_conversation',
      params: { accountId: 2, conversation_id: 101 },
    });
    await flushPromises();

    expect(wrapper.text()).toContain('Ravi Review');
    expect(wrapper.find('[role="status"]').exists()).toBe(false);
    expect(wrapper.find('[role="alert"]').exists()).toBe(false);
  });

  it.each([
    ['pause failure', 'pause-ai-action', 'pauseAI', false, 'administrator'],
    ['takeover failure', 'take-over-action', 'toggleStatus', false, 'agent'],
    [
      'resolution failure',
      'resolve-conversation-action',
      'toggleStatus',
      false,
      'administrator',
    ],
  ])(
    'does not apply a delayed %s result to a newly selected Conversation',
    async (_label, testId, actionName, actionResult, role) => {
      const action = deferred();
      const nextConversation = {
        ...conversationPayload,
        id: 202,
        meta: {
          ...conversationPayload.meta,
          sender: { ...conversationPayload.meta.sender, name: 'Ravi Review' },
        },
      };
      ConversationApi.show
        .mockResolvedValueOnce({ data: conversationPayload })
        .mockResolvedValueOnce({ data: nextConversation });

      const { wrapper, router, actions } = await mountCockpit({ role });
      actions[actionName].mockReturnValueOnce(action.promise);
      await wrapper.get(`[data-testid="${testId}"]`).trigger('click');
      await router.push({
        name: 'inbox_conversation',
        params: { accountId: 1, conversation_id: 202 },
      });
      await flushPromises();

      action.resolve(actionResult);
      await flushPromises();

      expect(wrapper.text()).toContain('Ravi Review');
      expect(ConversationApi.show).toHaveBeenCalledTimes(2);
      expect(wrapper.find('[role="status"]').exists()).toBe(false);
      expect(wrapper.find('[role="alert"]').exists()).toBe(false);
    }
  );

  it('renders detail tabs, mobile brief disclosure, and AI handoff controls', async () => {
    const { wrapper, actions } = await mountCockpit({
      query: { queue: 'hot' },
    });

    await clickButton(wrapper, 'Lead details');
    expect(wrapper.text()).toContain('Why this lead matters');
    expect(wrapper.text()).toContain('Clinic owner');
    expect(wrapper.text()).toContain('1 review open: No Approved Knowledge');
    expect(wrapper.text()).toContain('Reply composer');
    expect(
      wrapper.get('[data-testid="cockpit-automated-contact-stop"]').text()
    ).toContain('Automated contact stopped');
    expect(wrapper.text()).toContain('Tafadhali usinitumie ujumbe tena.');
    expect(wrapper.text()).toContain(
      'Resume AI does not restart automated messages.'
    );

    await wrapper
      .get('button[aria-controls="mobile-lead-brief-panel"]')
      .trigger('click');

    expect(wrapper.get('button[aria-expanded="true"]').exists()).toBe(true);

    await clickButton(wrapper, 'Evidence');

    expect(wrapper.text()).toContain('USD 1,000 monthly');

    await clickButton(wrapper, 'Activity');

    expect(wrapper.text()).toContain('Handoff created');

    const pauseButton = wrapper
      .findAll('button')
      .find(button => button.text().includes('Pause AI'));
    await pauseButton.trigger('click');
    await flushPromises();

    expect(actions.pauseAI).toHaveBeenCalledWith(expect.any(Object), {
      conversationId: 101,
      accountId: '1',
    });
  });
});

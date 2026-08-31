import { flushPromises, mount } from '@vue/test-utils';
import { createMemoryHistory, createRouter } from 'vue-router';
import { createStore } from 'vuex';
import InboxConversationCockpit from '../InboxConversationCockpit.vue';
import ConversationApi from 'dashboard/api/inbox/conversation';
import BookingsAPI from 'dashboard/api/bookings';
import OperationalDashboardAPI from 'dashboard/api/operationalDashboard';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';

vi.mock('dashboard/api/inbox/conversation', () => ({
  default: {
    show: vi.fn(),
    search: vi.fn(),
  },
}));

vi.mock('dashboard/api/bookings', () => ({
  default: {
    create: vi.fn(),
  },
}));

vi.mock('dashboard/api/operationalDashboard', () => ({
  default: {
    get: vi.fn(),
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
        'AI_LEAD_EMPLOYEE.INBOX_QUEUE.HOT': 'Hot',
        'AI_LEAD_EMPLOYEE.INBOX_QUEUE.REVIEW': 'Review',
        'AI_LEAD_EMPLOYEE.INBOX_QUEUE.BOOKED': 'Booked',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.URGENCY': 'Urgent',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.FILTERS': 'Filters',
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
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.PROPOSED_TIME': 'Proposed time',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ATTENDEE': 'Attendee',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.CALL_TYPE': 'Call type',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.PRODUCT_DEMO': 'Product demo',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.CONFIRM_CALL': 'Confirm call',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ASSIGN': 'Assign',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.PAUSE_AI': 'Pause AI',
        'AI_LEAD_EMPLOYEE.INBOX_COCKPIT.RESUME_AI': 'Resume AI',
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
  { path: '/accounts/:accountId/dashboard', name: 'home', component: {} },
  {
    path: '/accounts/:accountId/conversations/:conversation_id',
    name: 'inbox_conversation',
    component: {},
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
        status: 'open',
      },
    ],
    next_action: {
      kind: 'confirm_booking',
      label: 'Confirm call time',
      detail: 'Aug 27, 2026 at 2:00 PM Africa/Dar_es_Salaam',
    },
  },
  messages: [{ id: 1, content: 'I need WhatsApp automation this week.' }],
};

const buildStore = () => {
  const actions = {
    'agents/get': vi.fn(),
    'inboxes/get': vi.fn(),
    pauseAI: vi.fn(),
    resumeAI: vi.fn(),
    assignAgent: vi.fn(),
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

const mountCockpit = async ({ query = {} } = {}) => {
  const router = await buildRouter(query);
  const { store, actions } = buildStore();

  const wrapper = mount(InboxConversationCockpit, {
    props: {
      conversationId: 101,
    },
    global: {
      plugins: [router, store],
      stubs: {
        Avatar: AvatarStub,
        Icon: IconStub,
        MessagesView: MessagesViewStub,
      },
    },
  });

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

describe('InboxConversationCockpit', () => {
  beforeEach(() => {
    OperationalDashboardAPI.get.mockImplementation(params => {
      if (params?.unanswered === 'true') {
        return Promise.resolve({
          data: { leads: rowsByQueue.review, performance: {} },
        });
      }

      if (params?.booking_status === 'booked') {
        return Promise.resolve({
          data: { leads: rowsByQueue.booked, performance: {} },
        });
      }

      return Promise.resolve({
        data: {
          leads: rowsByQueue.hot,
          performance: {
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
    BookingsAPI.create.mockResolvedValue({ data: {} });
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it('loads Hot by default and switches Review and Booked with API-backed filters', async () => {
    const emitSpy = vi.spyOn(emitter, 'emit');
    const { wrapper, router } = await mountCockpit();

    expect(router.currentRoute.value.query.queue).toBe('hot');
    expect(OperationalDashboardAPI.get).toHaveBeenCalledWith({
      quality: 'highly_qualified',
    });
    expect(wrapper.find('select option[value="7"]').text()).toBe(
      'WhatsApp Sales'
    );
    expect(wrapper.text()).toContain('Asha Mushi');
    expect(wrapper.text()).toContain('I need WhatsApp automation this week.');
    expect(emitSpy).toHaveBeenCalledWith(BUS_EVENTS.SCROLL_TO_MESSAGE, {
      messageId: undefined,
    });

    await clickQueue(wrapper, 'Review');

    expect(OperationalDashboardAPI.get).toHaveBeenLastCalledWith({
      unanswered: 'true',
    });
    expect(wrapper.text()).toContain('Ravi Review');

    await clickQueue(wrapper, 'Booked');

    expect(OperationalDashboardAPI.get).toHaveBeenLastCalledWith({
      booking_status: 'booked',
    });
    expect(wrapper.text()).toContain('Bianca Booked');
  });

  it('renders detail tabs, mobile brief disclosure, and AI handoff controls', async () => {
    const { wrapper, actions } = await mountCockpit({
      query: { queue: 'hot' },
    });

    expect(wrapper.text()).toContain('Why this lead matters');
    expect(wrapper.text()).toContain('Clinic owner');
    expect(wrapper.text()).toContain('Reply composer');

    await wrapper.get('button[aria-expanded="false"]').trigger('click');

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
    });
  });
});

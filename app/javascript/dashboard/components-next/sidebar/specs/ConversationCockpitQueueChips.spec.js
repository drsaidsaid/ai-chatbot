import { flushPromises, mount } from '@vue/test-utils';
import { createMemoryHistory, createRouter } from 'vue-router';
import ConversationCockpitQueueChips from '../ConversationCockpitQueueChips.vue';
import OperationalDashboardAPI from 'dashboard/api/operationalDashboard';

vi.mock('dashboard/api/operationalDashboard', () => ({
  default: {
    get: vi.fn(),
  },
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
    t: (key, params) => {
      const labels = {
        'AI_LEAD_EMPLOYEE.INBOX_QUEUE.HOT': 'Hot',
        'AI_LEAD_EMPLOYEE.INBOX_QUEUE.REVIEW': 'Review',
        'AI_LEAD_EMPLOYEE.INBOX_QUEUE.BOOKED': 'Booked',
        'AI_LEAD_EMPLOYEE.INBOX_QUEUE.LABEL': 'Inbox quick queues',
        'AI_LEAD_EMPLOYEE.INBOX_QUEUE.ARIA': `${params?.label} ${params?.count}`,
      };
      return labels[key] || key;
    },
  }),
}));

const IconStub = {
  props: ['icon'],
  template: '<span />',
};

const createRouterForQueue = async queue => {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      {
        path: '/accounts/:accountId/dashboard',
        name: 'home',
        component: { template: '<div />' },
      },
    ],
  });
  await router.push({
    name: 'home',
    params: { accountId: 1 },
    query: { queue },
  });
  await router.isReady();
  return router;
};

describe('ConversationCockpitQueueChips', () => {
  beforeEach(() => {
    OperationalDashboardAPI.get.mockImplementation(params => {
      if (params?.quality === 'highly_qualified') {
        return Promise.resolve({
          data: { leads: [{ conversation_display_id: 42 }] },
        });
      }

      return Promise.resolve({
        data: {
          performance: {
            highly_qualified_leads: 3,
            unanswered_questions: 2,
            booked_calls: 1,
          },
        },
      });
    });
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it('renders queue links with API-backed counts', async () => {
    const router = await createRouterForQueue('hot');
    const wrapper = mount(ConversationCockpitQueueChips, {
      global: {
        plugins: [router],
        stubs: { Icon: IconStub },
      },
    });

    await flushPromises();

    expect(wrapper.text()).toContain('Hot3');
    expect(wrapper.text()).toContain('Review2');
    expect(wrapper.text()).toContain('Booked1');
    expect(wrapper.find('a').attributes('href')).toBe(
      '/accounts/1/dashboard?queue=hot'
    );
  });

  it('emits queue conversation ids for active queue filtering', async () => {
    const router = await createRouterForQueue('hot');
    const wrapper = mount(ConversationCockpitQueueChips, {
      global: {
        plugins: [router],
        stubs: { Icon: IconStub },
      },
    });

    await flushPromises();

    expect(wrapper.emitted('queueData').at(-1)).toEqual([
      { queue: 'hot', conversationIds: [42], isLoading: false },
    ]);
  });
});

import { flushPromises, shallowMount } from '@vue/test-utils';
import OperationalDashboardAPI from 'dashboard/api/operationalDashboard';
import OperationalDashboardPanel from '../OperationalDashboardPanel.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: 1 } }),
}));

vi.mock('dashboard/api/operationalDashboard', () => ({
  default: {
    get: vi.fn(),
  },
}));

const payload = {
  leads: [
    {
      id: 1,
      name: 'Asha Mushi',
      phone_number: '+255700000001',
      email: 'asha@example.test',
      quality: 'highly_qualified',
      follow_up_state: 'call_booked',
      reasons: ['Has budget'],
      assignee: { id: 7, name: 'Operator' },
      source: { id: 3, name: 'WhatsApp' },
      booking_state: 'booked',
      control_state: 'human_active',
      conversation_display_id: 42,
    },
  ],
  performance: {
    total_leads: 1,
    highly_qualified_leads: 1,
    unanswered_questions: 0,
    booked_calls: 1,
    knowledge_approvals: 0,
    human_active_conversations: 1,
    ai_active_conversations: 0,
  },
  queues: [
    { key: 'reviews', filters: { review_status: 'open' } },
    { key: 'follow_up', filters: { follow_up_status: 'pending' } },
    { key: 'human_active', filters: { control_state: 'human_active' } },
  ],
  filter_options: {
    qualities: ['qualified', 'highly_qualified'],
    follow_up_states: ['nurture', 'call_booked'],
    assignees: [{ id: 7, name: 'Operator' }],
    sources: [{ id: 3, name: 'WhatsApp' }],
    booking_statuses: ['booked', 'not_booked'],
    review_statuses: ['open', 'resolved'],
    follow_up_statuses: ['pending', 'sent', 'cancelled', 'failed'],
    control_states: ['ai_active', 'human_active'],
  },
};

describe('OperationalDashboardPanel', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    OperationalDashboardAPI.get.mockResolvedValue({ data: payload });
    window.localStorage.clear();
  });

  it('renders follow-up and control-state queue fields in the responsive table', async () => {
    const wrapper = shallowMount(OperationalDashboardPanel, {
      props: { surface: 'LEADS' },
    });

    await flushPromises();

    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.DASHBOARD.QUEUE.REVIEWS'
    );
    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.DASHBOARD.QUEUE.FOLLOW_UP'
    );
    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.DASHBOARD.FIELD.CONTROL'
    );
    expect(wrapper.text()).toContain('Human Active');
    expect(wrapper.find('section.overflow-x-auto').exists()).toBe(true);
    expect(wrapper.find('.min-w-\\[1240px\\]').exists()).toBe(true);
  });

  it('applies review surface and built-in control filters through the queue API', async () => {
    const wrapper = shallowMount(OperationalDashboardPanel, {
      props: { surface: 'REVIEWS' },
    });
    await flushPromises();

    expect(OperationalDashboardAPI.get).toHaveBeenLastCalledWith({
      review_status: 'open',
    });

    await wrapper
      .findAll('button')
      .find(button =>
        button.text().includes('AI_LEAD_EMPLOYEE.DASHBOARD.QUEUE.HUMAN_ACTIVE')
      )
      .trigger('click');
    await flushPromises();

    expect(OperationalDashboardAPI.get).toHaveBeenLastCalledWith({
      review_status: 'open',
      control_state: 'human_active',
    });
  });
});

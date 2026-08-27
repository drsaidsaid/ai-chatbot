import { flushPromises, mount } from '@vue/test-utils';
import { createMemoryHistory, createRouter } from 'vue-router';
import BookingsPanel from '../BookingsPanel.vue';
import bookingsAPI from 'dashboard/api/bookings';

vi.mock('dashboard/api/bookings', () => ({
  default: {
    get: vi.fn(),
    reschedule: vi.fn(),
    cancel: vi.fn(),
  },
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params = {}) => {
      const labels = {
        'AI_LEAD_EMPLOYEE.BOOKINGS.TITLE': 'Bookings',
        'AI_LEAD_EMPLOYEE.BOOKINGS.TAB_LABEL': 'Bookings tabs',
        'AI_LEAD_EMPLOYEE.BOOKINGS.TABS.AGENDA': 'Agenda',
        'AI_LEAD_EMPLOYEE.BOOKINGS.TABS.CALENDAR': 'Calendar',
        'AI_LEAD_EMPLOYEE.BOOKINGS.TABS.AVAILABILITY': 'Availability',
        'AI_LEAD_EMPLOYEE.BOOKINGS.TEAM_CAPACITY': 'Team capacity',
        'AI_LEAD_EMPLOYEE.BOOKINGS.BOOKED': 'booked',
        'AI_LEAD_EMPLOYEE.BOOKINGS.MORE_ACTIONS': 'More actions',
        'AI_LEAD_EMPLOYEE.BOOKINGS.TODAY': 'Today',
        'AI_LEAD_EMPLOYEE.BOOKINGS.TOMORROW': 'Tomorrow',
        'AI_LEAD_EMPLOYEE.BOOKINGS.PREVIOUS_RANGE': 'Previous range',
        'AI_LEAD_EMPLOYEE.BOOKINGS.NEXT_RANGE': 'Next range',
        'AI_LEAD_EMPLOYEE.BOOKINGS.FILTER.TEAM_MEMBER': 'Team member',
        'AI_LEAD_EMPLOYEE.BOOKINGS.FILTER.STATUS': 'Booking status',
        'AI_LEAD_EMPLOYEE.BOOKINGS.FILTER.OFFER': 'Offer',
        'AI_LEAD_EMPLOYEE.BOOKINGS.FILTER.TIMEZONE': 'Timezone: EAT',
        'AI_LEAD_EMPLOYEE.BOOKINGS.FILTER.MORE': 'More filters',
        'AI_LEAD_EMPLOYEE.BOOKINGS.CLEAR_FILTERS': 'Clear filters',
        'AI_LEAD_EMPLOYEE.BOOKINGS.LOADING': 'Loading bookings',
        'AI_LEAD_EMPLOYEE.BOOKINGS.EMPTY': 'No calls booked yet',
        'AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.DATE_TIME': 'Date & time',
        'AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.LEAD': 'Lead',
        'AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.BUSINESS': 'Business',
        'AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.ASSIGNED_TO': 'Assigned to',
        'AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.CALL_TYPE': 'Call type',
        'AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.WHATSAPP': 'WhatsApp',
        'AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.CALENDAR': 'Calendar',
        'AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.PREP': 'Prep',
        'AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.WHEN': 'When',
        'AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.OFFER': 'Offer',
        'AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.STATUS': 'Booking status',
        'AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.BOOKED_VIA': 'Booked via',
        'AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.CREATED': 'Booking created',
        'AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.BUFFERS': 'Buffers',
        'AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.MINIMUM_NOTICE': 'Minimum notice',
        'AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL_LABEL': 'Selected Booking detail',
        'AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL.BOOKING_DETAILS': 'Booking details',
        'AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL.ASSIGNED_TO': 'Assigned to',
        'AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL.MEETING_LINK': 'Meeting link',
        'AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL.CALENDAR_INVITE': 'Calendar invite',
        'AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL.PREPARATION_BRIEF':
          'Preparation brief',
        'AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL.STRONGEST_EVIDENCE':
          'Strongest evidence',
        'AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL.LIKELY_OBJECTION': 'Likely objection',
        'AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL.OPENING_QUESTION':
          'Suggested opening question',
        'AI_LEAD_EMPLOYEE.BOOKINGS.UNASSIGNED': 'Unassigned',
        'AI_LEAD_EMPLOYEE.BOOKINGS.REASSIGN': 'Reassign',
        'AI_LEAD_EMPLOYEE.BOOKINGS.CALL': 'call',
        'AI_LEAD_EMPLOYEE.BOOKINGS.JOIN_CALL': 'Join call',
        'AI_LEAD_EMPLOYEE.BOOKINGS.OPEN_CALENDAR': 'Open in Google Calendar',
        'AI_LEAD_EMPLOYEE.BOOKINGS.OPEN_CONVERSATION': 'Open conversation',
        'AI_LEAD_EMPLOYEE.BOOKINGS.RESCHEDULE': 'Reschedule',
        'AI_LEAD_EMPLOYEE.BOOKINGS.CANCEL_BOOKING': 'Cancel booking',
        'AI_LEAD_EMPLOYEE.BOOKINGS.NEW_TIME': 'New time',
        'AI_LEAD_EMPLOYEE.BOOKINGS.CANCEL_REASON': 'Reason',
        'AI_LEAD_EMPLOYEE.BOOKINGS.ACTION_CONSEQUENCES':
          'Updates connected states',
        'AI_LEAD_EMPLOYEE.BOOKINGS.DISMISS': 'Dismiss',
        'AI_LEAD_EMPLOYEE.BOOKINGS.CONFIRM_ACTION': 'Confirm',
        'AI_LEAD_EMPLOYEE.BOOKINGS.SAVING': 'Saving',
        'AI_LEAD_EMPLOYEE.BOOKINGS.AVAILABILITY_RULES': 'Availability rules',
        'AI_LEAD_EMPLOYEE.BOOKINGS.AVAILABLE_SLOTS': 'Available slots',
        'AI_LEAD_EMPLOYEE.BOOKINGS.SLOT_SOURCE': 'Rule-backed slot',
        'AI_LEAD_EMPLOYEE.BOOKINGS.PREVIOUS_PAGE': 'Previous page',
        'AI_LEAD_EMPLOYEE.BOOKINGS.NEXT_PAGE': 'Next page',
        'AI_LEAD_EMPLOYEE.BOOKINGS.EMPTY_VALUE': 'Not captured',
        'AI_LEAD_EMPLOYEE.BOOKINGS.STATUS.CONFIRMED': 'Confirmed',
        'AI_LEAD_EMPLOYEE.BOOKINGS.CALL_TYPE.PRODUCT_DEMO': 'Product Demo',
        'AI_LEAD_EMPLOYEE.BOOKINGS.WHATSAPP_STATE.CONFIRMED': 'Confirmed',
        'AI_LEAD_EMPLOYEE.BOOKINGS.CALENDAR_STATE.CONFIRMED': 'Confirmed',
        'AI_LEAD_EMPLOYEE.BOOKINGS.PREPARATION_STATE.READY': 'Ready',
        'AI_LEAD_EMPLOYEE.BOOKINGS.PROVIDER_STATE.CONNECTED': 'Connected',
      };

      if (key === 'AI_LEAD_EMPLOYEE.BOOKINGS.PAGINATION') {
        return `Showing ${params.count} of ${params.total} bookings`;
      }
      if (key === 'AI_LEAD_EMPLOYEE.BOOKINGS.MINUTES') {
        return `${params.count} min`;
      }
      if (key === 'AI_LEAD_EMPLOYEE.BOOKINGS.BUFFER_PAIR') {
        return `${params.before} / ${params.after} min`;
      }
      if (key === 'AI_LEAD_EMPLOYEE.BOOKINGS.CAPACITY_COUNT') {
        return `${params.booked} / ${params.limit}`;
      }
      if (key === 'AI_LEAD_EMPLOYEE.BOOKINGS.JOINED_LABEL') {
        return `${params.left} · ${params.right}`;
      }
      if (key === 'AI_LEAD_EMPLOYEE.BOOKINGS.PAGE_NUMBER') {
        return `${params.page}`;
      }
      if (key === 'AI_LEAD_EMPLOYEE.BOOKINGS.CALL_STARTS') {
        return `Call starts at ${params.time}`;
      }

      return labels[key] || key;
    },
  }),
}));

const IconStub = {
  props: ['icon'],
  template: '<span class="icon-stub" />',
};

const booking = {
  id: 5,
  status: 'confirmed',
  starts_at: '2026-08-27T11:30:00Z',
  ends_at: '2026-08-27T12:00:00Z',
  created_at: '2026-08-24T08:14:00Z',
  offer: 'Product Demo',
  call_type: 'product_demo',
  booked_channel: 'WhatsApp',
  meeting_link: 'https://wa.me/255712345678',
  provider: 'Google',
  calendar_state: 'confirmed',
  whatsapp_state: 'confirmed',
  preparation_state: 'ready',
  contact: {
    initials: 'MD',
    name: 'Meta Demo Lead',
    phone_number: '+255712345678',
    business_name: 'Dar es Salaam',
    location: 'Dar es Salaam, TZ',
  },
  assignee: {
    id: 1,
    initials: 'J',
    name: 'John',
  },
  conversation: {
    path: '/app/accounts/1/conversations/42',
  },
  detail: {
    preparation_brief: 'Lead requested a short product demo.',
    strongest_evidence: [{ signal: 'problem', value: 'Requested demo' }],
    likely_objection: 'Concern about pricing and ROI.',
    suggested_opening_question: 'What would success look like?',
  },
};

const apiResponse = overrides => ({
  data: {
    bookings: [booking],
    selected_booking: booking,
    meta: {
      total_count: 1,
      capacity_booked: 14,
      capacity_limit: 20,
      range: { label: 'Aug 24 - Aug 30, 2026' },
    },
    filter_options: {
      statuses: ['confirmed'],
      assignees: [{ id: 1, name: 'John' }],
      offers: ['Product Demo'],
      timezones: ['Africa/Dar_es_Salaam'],
    },
    availability: {
      provider_state: 'connected',
      configuration: {
        provider: 'Google',
        calendar_id: 'sales',
        timezone: 'Africa/Dar_es_Salaam',
        buffer_before_minutes: 15,
        buffer_after_minutes: 15,
        minimum_notice_minutes: 120,
      },
      slots: [
        {
          starts_at: '2026-08-28T07:00:00Z',
          ends_at: '2026-08-28T07:30:00Z',
        },
      ],
    },
    calendar: [{ date: '2026-08-27', bookings: [booking] }],
    ...overrides,
  },
});

const mountComponent = async () => {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      {
        path: '/app/accounts/1/bookings',
        name: 'owned_bookings_index',
        component: BookingsPanel,
      },
    ],
  });
  router.push('/app/accounts/1/bookings');
  await router.isReady();

  const wrapper = mount(BookingsPanel, {
    global: {
      plugins: [router],
      stubs: { Icon: IconStub },
    },
  });
  await flushPromises();
  return { wrapper, router };
};

describe('BookingsPanel', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    bookingsAPI.get.mockResolvedValue(apiResponse());
    bookingsAPI.reschedule.mockResolvedValue({ data: booking });
    bookingsAPI.cancel.mockResolvedValue({
      data: { ...booking, status: 'canceled' },
    });
  });

  it('renders the agenda with filters and selected booking detail', async () => {
    const { wrapper } = await mountComponent();

    expect(wrapper.text()).toContain('Agenda');
    expect(wrapper.text()).toContain('Meta Demo Lead');
    expect(wrapper.text()).toContain('Dar es Salaam');
    expect(wrapper.text()).toContain('Team capacity');
    expect(wrapper.text()).toContain('Booking details');
    expect(
      wrapper.find('a[href="/app/accounts/1/conversations/42"]').exists()
    ).toBe(true);
  });

  it('switches to calendar and availability tabs', async () => {
    const { wrapper } = await mountComponent();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Calendar')
      .trigger('click');
    await flushPromises();
    expect(wrapper.text()).toContain('Meta Demo Lead');

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Availability')
      .trigger('click');
    await flushPromises();
    expect(wrapper.text()).toContain('Availability rules');
    expect(wrapper.text()).toContain('Rule-backed slot');
  });

  it('opens reschedule and cancel dialogs that call booking mutations', async () => {
    const { wrapper } = await mountComponent();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Reschedule')
      .trigger('click');
    await wrapper.find('form').trigger('submit.prevent');
    expect(bookingsAPI.reschedule).toHaveBeenCalledWith(
      5,
      expect.objectContaining({ starts_at: '2026-08-27T11:30:00.000Z' })
    );

    await flushPromises();
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Cancel booking')
      .trigger('click');
    await wrapper.find('textarea').setValue('Lead asked to pause');
    await wrapper.find('form').trigger('submit.prevent');
    expect(bookingsAPI.cancel).toHaveBeenCalledWith(
      5,
      expect.objectContaining({ reason: 'Lead asked to pause' })
    );
  });
});

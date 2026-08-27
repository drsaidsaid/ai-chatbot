import { flushPromises, mount } from '@vue/test-utils';
import { createMemoryHistory, createRouter } from 'vue-router';
import LeadsDirectoryPage from '../LeadsDirectoryPage.vue';
import LeadsAPI from 'dashboard/api/leads';

vi.mock('dashboard/api/leads', () => ({
  default: {
    get: vi.fn(),
    update: vi.fn(),
    importLeads: vi.fn(),
    exportLeads: vi.fn(),
  },
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params = {}) => {
      const labels = {
        'AI_LEAD_EMPLOYEE.LEADS.TITLE': 'Leads',
        'AI_LEAD_EMPLOYEE.LEADS.SEARCH':
          'Search leads by name, phone, or business',
        'AI_LEAD_EMPLOYEE.LEADS.IMPORT': 'Import',
        'AI_LEAD_EMPLOYEE.LEADS.EXPORT': 'Export',
        'AI_LEAD_EMPLOYEE.LEADS.MORE_ACTIONS': 'More actions',
        'AI_LEAD_EMPLOYEE.LEADS.LOADING': 'Loading leads',
        'AI_LEAD_EMPLOYEE.LEADS.LOAD_ERROR': 'Leads could not be loaded',
        'AI_LEAD_EMPLOYEE.LEADS.EMPTY': 'No leads match these filters',
        'AI_LEAD_EMPLOYEE.LEADS.EMPTY_VALUE': 'Not captured',
        'AI_LEAD_EMPLOYEE.LEADS.UNASSIGNED': 'Unassigned',
        'AI_LEAD_EMPLOYEE.LEADS.NO_BOOKING': 'No booking',
        'AI_LEAD_EMPLOYEE.LEADS.SELECT_ALL': 'Select all leads',
        'AI_LEAD_EMPLOYEE.LEADS.DETAIL_LABEL': 'Selected Lead detail',
        'AI_LEAD_EMPLOYEE.LEADS.CLEAR_FILTERS': 'Clear filters',
        'AI_LEAD_EMPLOYEE.LEADS.PER_PAGE': 'Rows per page',
        'AI_LEAD_EMPLOYEE.LEADS.PREVIOUS_PAGE': 'Previous page',
        'AI_LEAD_EMPLOYEE.LEADS.NEXT_PAGE': 'Next page',
        'AI_LEAD_EMPLOYEE.LEADS.IMPORT_ERROR': 'Lead import failed',
        'AI_LEAD_EMPLOYEE.LEADS.EXPORT_STARTED': 'Lead export started',
        'AI_LEAD_EMPLOYEE.LEADS.EXPORT_ERROR': 'Lead export failed',
        'AI_LEAD_EMPLOYEE.LEADS.OPEN_CONVERSATION': 'Open conversation',
        'AI_LEAD_EMPLOYEE.LEADS.EDIT_LEAD': 'Edit lead',
        'AI_LEAD_EMPLOYEE.LEADS.QUALITY.ALL': 'All',
        'AI_LEAD_EMPLOYEE.LEADS.QUALITY.HIGHLY_QUALIFIED': 'Highly Qualified',
        'AI_LEAD_EMPLOYEE.LEADS.QUALITY.QUALIFIED': 'Qualified',
        'AI_LEAD_EMPLOYEE.LEADS.QUALITY.LOW_QUALIFIED': 'Low Qualified',
        'AI_LEAD_EMPLOYEE.LEADS.QUALITY.UNQUALIFIED': 'Unqualified',
        'AI_LEAD_EMPLOYEE.LEADS.QUALITY.UNKNOWN': 'Unknown',
        'AI_LEAD_EMPLOYEE.LEADS.FOLLOW_UP_STATE.NURTURE': 'Nurture',
        'AI_LEAD_EMPLOYEE.LEADS.BOOKING_STATUS.CONFIRMED': 'Confirmed',
        'AI_LEAD_EMPLOYEE.LEADS.IMPORT_STATUS.COMPLETED': 'Completed',
        'AI_LEAD_EMPLOYEE.LEADS.NEXT_ACTION.SEND_PROPOSAL': 'Send proposal',
        'AI_LEAD_EMPLOYEE.LEADS.BOOKING_LABEL.DEMO': 'Demo',
        'AI_LEAD_EMPLOYEE.LEADS.CHANNEL_KIND.PHONE': 'Phone',
        'AI_LEAD_EMPLOYEE.LEADS.CHANNEL_KIND.EMAIL': 'Email',
        'AI_LEAD_EMPLOYEE.LEADS.CHANNEL_KIND.SOURCE': 'Source',
        'AI_LEAD_EMPLOYEE.LEADS.EVIDENCE_SIGNAL.PROBLEM': 'Problem',
        'AI_LEAD_EMPLOYEE.LEADS.EVIDENCE_SIGNAL.TEAM_SIZE': 'Team Size',
        'AI_LEAD_EMPLOYEE.LEADS.CONVERSATION_STATE.OPEN': 'Open',
        'AI_LEAD_EMPLOYEE.LEADS.CONVERSATION_STATE.AI_ACTIVE': 'AI Active',
        'AI_LEAD_EMPLOYEE.LEADS.FILTER.ASSIGNEE': 'Assignee',
        'AI_LEAD_EMPLOYEE.LEADS.FILTER.ME': 'Mine',
        'AI_LEAD_EMPLOYEE.LEADS.FILTER.UNASSIGNED': 'Unassigned',
        'AI_LEAD_EMPLOYEE.LEADS.FILTER.SOURCE': 'Source',
        'AI_LEAD_EMPLOYEE.LEADS.FILTER.FOLLOW_UP': 'Follow-up state',
        'AI_LEAD_EMPLOYEE.LEADS.FILTER.BOOKING': 'Booking status',
        'AI_LEAD_EMPLOYEE.LEADS.FILTER.MORE': 'More filters',
        'AI_LEAD_EMPLOYEE.LEADS.FIELD.LEAD': 'Lead',
        'AI_LEAD_EMPLOYEE.LEADS.FIELD.BUSINESS': 'Business',
        'AI_LEAD_EMPLOYEE.LEADS.FIELD.QUALITY': 'Lead Quality',
        'AI_LEAD_EMPLOYEE.LEADS.FIELD.SCORE': 'Score',
        'AI_LEAD_EMPLOYEE.LEADS.FIELD.SOURCE': 'Source',
        'AI_LEAD_EMPLOYEE.LEADS.FIELD.ASSIGNEE': 'Assignee',
        'AI_LEAD_EMPLOYEE.LEADS.FIELD.LAST_CONTACT': 'Last contact',
        'AI_LEAD_EMPLOYEE.LEADS.FIELD.NEXT_ACTION': 'Next action',
        'AI_LEAD_EMPLOYEE.LEADS.FIELD.BOOKING': 'Booking',
        'AI_LEAD_EMPLOYEE.LEADS.DETAIL.CONTACT_CHANNELS': 'Contact channels',
        'AI_LEAD_EMPLOYEE.LEADS.DETAIL.QUALIFICATION': 'Qualification',
        'AI_LEAD_EMPLOYEE.LEADS.DETAIL.WHY': 'Why this lead matters',
        'AI_LEAD_EMPLOYEE.LEADS.DETAIL.EVIDENCE': 'Strongest evidence',
        'AI_LEAD_EMPLOYEE.LEADS.DETAIL.MISSING': 'Missing signals',
        'AI_LEAD_EMPLOYEE.LEADS.DETAIL.NO_MISSING': 'No missing signals',
        'AI_LEAD_EMPLOYEE.LEADS.DETAIL.CONVERSATION': 'Conversation summary',
        'AI_LEAD_EMPLOYEE.LEADS.DETAIL.LAST_MESSAGE': 'Last message',
        'AI_LEAD_EMPLOYEE.LEADS.DETAIL.NO_MESSAGE': 'No message preview',
        'AI_LEAD_EMPLOYEE.LEADS.DETAIL.TOTAL_MESSAGES': 'Total messages',
        'AI_LEAD_EMPLOYEE.LEADS.DETAIL.CONVERSATION_STATUS':
          'Conversation status',
        'AI_LEAD_EMPLOYEE.LEADS.DETAIL.CONTROL_STATE': 'AI control state',
        'AI_LEAD_EMPLOYEE.LEADS.DETAIL.OWNER': 'Owner & follow-up',
        'AI_LEAD_EMPLOYEE.LEADS.DETAIL.DUE': 'Due',
        'AI_LEAD_EMPLOYEE.LEADS.DETAIL.RELATED': 'Related',
        'AI_LEAD_EMPLOYEE.LEADS.DETAIL.NO_RELATED': 'No related conversations',
        'AI_LEAD_EMPLOYEE.LEADS.DETAIL.BOOKINGS': 'Bookings',
        'AI_LEAD_EMPLOYEE.LEADS.DETAIL.NO_RELATED_BOOKINGS':
          'No related bookings',
        'AI_LEAD_EMPLOYEE.LEADS.DETAIL.ACTIONS': 'Actions',
        'AI_LEAD_EMPLOYEE.LEADS.EDIT.TITLE': 'Edit Lead',
        'AI_LEAD_EMPLOYEE.LEADS.EDIT.CLOSE': 'Close',
        'AI_LEAD_EMPLOYEE.LEADS.EDIT.NAME': 'Name',
        'AI_LEAD_EMPLOYEE.LEADS.EDIT.PHONE': 'Phone',
        'AI_LEAD_EMPLOYEE.LEADS.EDIT.EMAIL': 'Email',
        'AI_LEAD_EMPLOYEE.LEADS.EDIT.BUSINESS': 'Business',
        'AI_LEAD_EMPLOYEE.LEADS.EDIT.CITY': 'City',
        'AI_LEAD_EMPLOYEE.LEADS.EDIT.COUNTRY': 'Country',
        'AI_LEAD_EMPLOYEE.LEADS.EDIT.ASSIGNEE': 'Assignee',
        'AI_LEAD_EMPLOYEE.LEADS.EDIT.CANCEL': 'Cancel',
        'AI_LEAD_EMPLOYEE.LEADS.EDIT.SAVE': 'Save changes',
        'AI_LEAD_EMPLOYEE.LEADS.EDIT.SAVED': 'Lead saved',
        'AI_LEAD_EMPLOYEE.LEADS.EDIT.ERROR': 'Lead could not be saved',
        'AI_LEAD_EMPLOYEE.LEADS.EDIT.NAME_REQUIRED': 'Name is required',
        'AI_LEAD_EMPLOYEE.LEADS.EDIT.PHONE_INVALID': 'Phone invalid',
      };

      if (key === 'AI_LEAD_EMPLOYEE.LEADS.PAGINATION') {
        return `Showing ${params.start}-${params.end} of ${params.total} leads`;
      }
      if (key === 'AI_LEAD_EMPLOYEE.LEADS.IMPORT_RESULT') {
        return `${params.status}: ${params.imported} imported, ${params.failed} failed`;
      }
      if (key === 'AI_LEAD_EMPLOYEE.LEADS.SELECT_ROW') {
        return `Select ${params.name}`;
      }
      if (key === 'AI_LEAD_EMPLOYEE.LEADS.DETAIL.BOOKING_NUMBER') {
        return `Booking #${params.id}`;
      }
      if (key === 'AI_LEAD_EMPLOYEE.LEADS.DETAIL.BOOKING_SUMMARY') {
        return `${params.status} - ${params.time}`;
      }

      return labels[key] || key;
    },
  }),
}));

const IconStub = {
  props: ['icon'],
  template: '<span class="icon-stub" />',
};

const leadPayload = {
  id: 2,
  name: 'Jane Nkosi',
  initials: 'JN',
  phone_number: '+255713456789',
  email: 'jane@example.com',
  business_name: 'Nuru Boutique With A Very Long Business Name',
  location: 'Arusha, TZ',
  quality: 'qualified',
  score: 78,
  source: { id: 3, name: 'WhatsApp sales', channel_type: 'Channel::Whatsapp' },
  assignee: { id: 4, name: 'John', initials: 'J' },
  last_contact_at: '2026-08-27T08:35:00Z',
  next_action: {
    key: 'send_proposal',
    due_at: '2026-08-27T10:00:00Z',
  },
  booking: {
    id: 5,
    status: 'confirmed',
    key: 'demo',
    starts_at: '2026-08-27T14:30:00Z',
  },
  conversation: {
    id: 6,
    display_id: 42,
    status: 'open',
    control_state: 'ai_active',
    path: '/app/accounts/1/conversations/42',
  },
  detail: {
    contact_channels: [
      { kind: 'phone', label: '+255713456789' },
      { kind: 'email', label: 'jane@example.com' },
      { kind: 'source', label: 'WhatsApp sales' },
    ],
    why_this_lead_matters: [
      'Boutique owner wants to automate lead capture on WhatsApp.',
    ],
    strongest_evidence: [
      {
        id: 7,
        signal: 'problem',
        value: 'book demos automatically',
      },
    ],
    missing_signals: ['team_size'],
    conversation_summary: {
      last_message_at: '2026-08-27T08:35:00Z',
      last_message_preview:
        'Yes, I would like to see a demo tomorrow afternoon.',
      total_messages: 6,
    },
    qualification: {
      follow_up_state: 'nurture',
    },
    related_conversations: [
      {
        id: 6,
        display_id: 42,
        path: '/app/accounts/1/conversations/42',
        last_contact_at: '2026-08-27T08:35:00Z',
      },
    ],
    related_bookings: [
      {
        id: 5,
        status: 'confirmed',
        key: 'demo',
        starts_at: '2026-08-27T14:30:00Z',
        path: '/app/accounts/1/bookings?booking_id=5',
      },
    ],
    editable_fields: {
      name: 'Jane Nkosi',
      phone_number: '+255713456789',
      email: 'jane@example.com',
      business_name: 'Nuru Boutique',
      city: 'Arusha',
      country: 'TZ',
      assignee_id: 4,
      evidence: {
        problem: 'book demos automatically',
        budget: '$500',
      },
    },
  },
};

const defaultResponse = overrides => ({
  data: {
    leads: [leadPayload],
    selected_lead: leadPayload,
    counts: {
      all: 100,
      highly_qualified: 12,
      qualified: 28,
      low_qualified: 34,
      unqualified: 18,
      unknown: 8,
    },
    filter_options: {
      qualities: [
        'all',
        'highly_qualified',
        'qualified',
        'low_qualified',
        'unqualified',
        'unknown',
      ],
      follow_up_states: ['nurture', 'human_review'],
      booking_statuses: ['booked', 'no_booking'],
      assignees: [{ id: 4, name: 'John' }],
      sources: [{ id: 3, name: 'WhatsApp sales' }],
    },
    meta: {
      page: 1,
      per_page: 25,
      total_count: 100,
      total_pages: 4,
      sort: 'last_contact',
      direction: 'desc',
    },
    ...overrides,
  },
});

const mountPage = async ({ response = defaultResponse(), query = {} } = {}) => {
  LeadsAPI.get.mockResolvedValue(response);

  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      {
        path: '/app/accounts/:accountId/leads',
        name: 'owned_leads_index',
        component: LeadsDirectoryPage,
      },
    ],
  });
  router.push({
    name: 'owned_leads_index',
    params: { accountId: 1 },
    query,
  });
  await router.isReady();

  const wrapper = mount(LeadsDirectoryPage, {
    global: {
      plugins: [router],
      stubs: {
        Icon: IconStub,
      },
      mocks: {
        $t: key => key,
      },
    },
  });
  await flushPromises();

  return { wrapper, router };
};

describe('LeadsDirectoryPage', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    LeadsAPI.get.mockReset();
    LeadsAPI.update.mockReset();
    LeadsAPI.importLeads.mockReset();
    LeadsAPI.exportLeads.mockReset();
    global.URL.createObjectURL = vi.fn(() => 'blob:leads');
    global.URL.revokeObjectURL = vi.fn();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('renders filter chips, dense rows, selected detail, and long text truncation', async () => {
    const { wrapper } = await mountPage();

    expect(wrapper.text()).toContain('Leads');
    expect(wrapper.text()).toContain('Highly Qualified');
    expect(wrapper.text()).toContain('12');
    expect(wrapper.text()).toContain('Jane Nkosi');
    expect(wrapper.text()).toContain(
      'Nuru Boutique With A Very Long Business Name'
    );
    expect(wrapper.text()).toContain('Why this lead matters');
    expect(wrapper.text()).toContain('Open conversation');
    expect(wrapper.text()).toContain('Booking #5');
    expect(
      wrapper.find('a[href="/app/accounts/1/bookings?booking_id=5"]').exists()
    ).toBe(true);
    expect(wrapper.find('td .truncate').exists()).toBe(true);
  });

  it('applies quality chips, dropdown filters, sorting, pagination, and row selection through query-backed API calls', async () => {
    const { wrapper, router } = await mountPage();

    await wrapper
      .findAll('button')
      .find(button => button.text().includes('Highly Qualified'))
      .trigger('click');
    await flushPromises();
    expect(router.currentRoute.value.query.quality).toBe('highly_qualified');

    const selects = wrapper.findAll('select');
    await selects[0].setValue('4');
    await flushPromises();
    expect(router.currentRoute.value.query.assignee_id).toBe('4');

    await wrapper
      .findAll('button')
      .find(button => button.text().includes('Score'))
      .trigger('click');
    await flushPromises();
    expect(router.currentRoute.value.query.sort).toBe('score');

    await wrapper.find('button[aria-label="Next page"]').trigger('click');
    await flushPromises();
    expect(router.currentRoute.value.query.page).toBe('2');

    await wrapper
      .find('input[aria-label="Select Jane Nkosi"]')
      .trigger('click');
    await flushPromises();
    expect(router.currentRoute.value.query.lead_id).toBe('2');
  });

  it('debounces search and requests matching server data', async () => {
    const { wrapper, router } = await mountPage();

    await wrapper.find('input[type="search"]').setValue('nuru');
    vi.runAllTimers();
    await flushPromises();

    expect(router.currentRoute.value.query.q).toBe('nuru');
    expect(LeadsAPI.get).toHaveBeenLastCalledWith(
      expect.objectContaining({ q: 'nuru' })
    );
  });

  it('validates and saves the edit form', async () => {
    LeadsAPI.update.mockResolvedValue({ data: leadPayload });
    const { wrapper } = await mountPage();

    await wrapper
      .findAll('button')
      .find(button => button.text().includes('Edit lead'))
      .trigger('click');
    await flushPromises();
    const nameInput = wrapper.find('input[required]');
    await nameInput.setValue('');
    await wrapper.find('form').trigger('submit.prevent');
    expect(wrapper.text()).toContain('Name is required');

    await nameInput.setValue('Jane Nkosi Updated');
    const phoneInput = wrapper
      .findAll('input')
      .find(input => input.element.value === '+255713456789');
    await phoneInput.setValue('123');
    await wrapper.find('form').trigger('submit.prevent');
    expect(wrapper.text()).toContain('Phone invalid');

    await phoneInput.setValue('+255713456789');
    await wrapper.find('form').trigger('submit.prevent');
    await flushPromises();
    expect(LeadsAPI.update).toHaveBeenCalledWith(
      2,
      expect.objectContaining({
        lead: expect.objectContaining({ name: 'Jane Nkosi Updated' }),
      })
    );
  });

  it('handles import and export controls', async () => {
    LeadsAPI.importLeads.mockResolvedValue({
      data: {
        import: {
          status: 'partial',
          imported_count: 1,
          failed_count: 1,
        },
      },
    });
    LeadsAPI.exportLeads.mockResolvedValue({ data: new Blob(['id,name']) });
    const { wrapper } = await mountPage();

    const file = new File(['name,phone_number'], 'leads.csv', {
      type: 'text/csv',
    });
    const input = wrapper.find('input[type="file"]');
    Object.defineProperty(input.element, 'files', { value: [file] });
    await input.trigger('change');
    await flushPromises();
    expect(LeadsAPI.importLeads).toHaveBeenCalledWith(file);
    expect(wrapper.text()).toContain('Partial: 1 imported, 1 failed');

    await wrapper
      .findAll('button')
      .find(button => button.text().includes('Export'))
      .trigger('click');
    await flushPromises();
    expect(LeadsAPI.exportLeads).toHaveBeenCalled();
  });

  it('renders empty and error states', async () => {
    const { wrapper } = await mountPage({
      response: defaultResponse({
        leads: [],
        selected_lead: null,
        meta: {
          page: 1,
          per_page: 25,
          total_count: 0,
          total_pages: 1,
        },
      }),
    });

    expect(wrapper.text()).toContain('No leads match these filters');

    LeadsAPI.get.mockRejectedValueOnce({
      response: { data: { error: 'Failed load' } },
    });
    await wrapper.vm.$router.replace({
      name: 'owned_leads_index',
      params: { accountId: 1 },
      query: { quality: 'qualified' },
    });
    await flushPromises();
    expect(wrapper.text()).toContain('Failed load');
  });
});

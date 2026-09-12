import { flushPromises, mount } from '@vue/test-utils';
import { createMemoryHistory, createRouter } from 'vue-router';
import LeadsDirectoryPage from '../LeadsDirectoryPage.vue';
import LeadsAPI from 'dashboard/api/leads';

vi.mock('dashboard/api/leads', () => ({
  default: {
    get: vi.fn(),
    update: vi.fn(),
    reconsent: vi.fn(),
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
        'AI_LEAD_EMPLOYEE.LEADS.IMPORT_PREVIEW_TITLE': 'Review Lead import',
        'AI_LEAD_EMPLOYEE.LEADS.IMPORT_PREVIEW_SUMMARY':
          'Import preview summary',
        'AI_LEAD_EMPLOYEE.LEADS.IMPORT_APPLY': 'Import Leads',
        'AI_LEAD_EMPLOYEE.LEADS.IMPORT_CANCEL': 'Cancel import',
        'AI_LEAD_EMPLOYEE.LEADS.IMPORT_CAN_APPLY': 'Ready to import',
        'AI_LEAD_EMPLOYEE.LEADS.IMPORT_CANNOT_APPLY': 'Fix the listed errors',
        'AI_LEAD_EMPLOYEE.LEADS.FILTERS_SHOW': 'Show filters',
        'AI_LEAD_EMPLOYEE.LEADS.FILTERS_HIDE': 'Hide filters',
        'AI_LEAD_EMPLOYEE.LEADS.OPEN_LEAD': 'Open Jane Nkosi',
        'AI_LEAD_EMPLOYEE.LEADS.EMPTY_DIRECTORY': 'No Leads yet',
        'AI_LEAD_EMPLOYEE.LEADS.EMPTY_RESET': 'Reset filters',
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

const deferred = () => {
  let resolve;
  let reject;
  const promise = new Promise((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return { promise, resolve, reject };
};

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
      visibility: 'admin',
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

const mountPage = async ({
  response = defaultResponse(),
  query = { lead_id: '2' },
  attachTo,
} = {}) => {
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
    attachTo,
    global: {
      plugins: [router],
      stubs: {
        Icon: IconStub,
        Transition: true,
        Modal: false,
        WootModal: false,
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
    LeadsAPI.reconsent.mockReset();
    LeadsAPI.importLeads.mockReset();
    LeadsAPI.exportLeads.mockReset();
    global.URL.createObjectURL = vi.fn(() => 'blob:leads');
    global.URL.revokeObjectURL = vi.fn();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('keeps the directory wide until a Lead is opened on demand', async () => {
    const { wrapper } = await mountPage({ query: {} });

    expect(wrapper.text()).toContain('Leads');
    expect(wrapper.text()).toContain('Highly Qualified');
    expect(wrapper.text()).toContain('12');
    expect(wrapper.text()).toContain('Jane Nkosi');
    expect(wrapper.text()).toContain(
      'Nuru Boutique With A Very Long Business Name'
    );
    expect(wrapper.text()).not.toContain('Why this lead matters');
    expect(wrapper.find('[aria-label="Selected Lead detail"]').exists()).toBe(
      false
    );
    expect(wrapper.find('td .truncate').exists()).toBe(true);
  });

  it('opens a desktop row with the keyboard and retains route-backed context', async () => {
    const { wrapper, router } = await mountPage({
      query: { q: 'nuru', page: '2', sort: 'name' },
    });
    const row = wrapper.get('tr[tabindex="0"]');

    expect(row.attributes('aria-label')).toBe('Open Jane Nkosi');
    await row.trigger('keydown', { key: 'Enter' });
    await flushPromises();

    expect(router.currentRoute.value.query).toMatchObject({
      q: 'nuru',
      page: '2',
      sort: 'name',
      lead_id: '2',
    });
    expect(wrapper.text()).toContain('Why this lead matters');
    expect(
      wrapper
        .findAll('a[href="/app/accounts/1/conversations/42"]')
        .some(link => link.text().includes('Open conversation'))
    ).toBe(true);
  });

  it('keeps phone filters collapsed and gives every filter an accessible name', async () => {
    const { wrapper } = await mountPage({ query: {} });

    expect(wrapper.get('[data-testid="lead-filters"]').classes()).toContain(
      'hidden'
    );
    expect(
      ['Assignee', 'Source', 'Follow-up state', 'Booking status'].every(label =>
        wrapper.find(`select[aria-label="${label}"]`).exists()
      )
    ).toBe(true);
    await wrapper.get('button[aria-label="Show filters"]').trigger('click');
    expect(wrapper.get('[data-testid="lead-filters"]').classes()).not.toContain(
      'hidden'
    );
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

    await wrapper.get('tr[tabindex="0"]').trigger('click');
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

  it('dismisses an unsaved Lead edit with Escape so the workspace is usable again', async () => {
    const response = defaultResponse();
    response.data.meta.visibility = 'operator';
    const { wrapper, router } = await mountPage({
      response,
      attachTo: document.body,
    });
    const previousRoute = router.currentRoute.value.fullPath;

    try {
      await wrapper
        .findAll('button')
        .find(button => button.text() === 'Edit lead')
        .trigger('click');
      await wrapper.find('input[required]').setValue('Unsaved edit');
      expect(wrapper.find('[role="dialog"]').exists()).toBe(true);
      await wrapper.find('input[required]').trigger('keydown', {
        key: 'Escape',
        code: 'Escape',
      });
      await flushPromises();

      expect(wrapper.find('[role="dialog"]').exists()).toBe(false);
      expect(LeadsAPI.update).not.toHaveBeenCalled();
      expect(router.currentRoute.value.fullPath).toBe(previousRoute);
      await wrapper
        .findAll('button')
        .find(button => button.text() === 'Edit lead')
        .trigger('click');
      expect(wrapper.find('input[required]').element.value).toBe('Jane Nkosi');
    } finally {
      wrapper.unmount();
    }
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

  it('lets an administrator record re-consent from the newer verified message', async () => {
    const stoppedLead = {
      ...leadPayload,
      detail: {
        ...leadPayload.detail,
        automated_contact_consent: {
          state: 'withdrawn',
          evidence: {
            id: 7,
            text: 'Please stop messaging me.',
            occurred_at: '2026-09-10T08:00:00Z',
          },
          reconsent_candidate: {
            source_message_id: 9,
            expected_event_id: 7,
            text: 'Yes, you can message me again.',
          },
        },
      },
    };
    const response = defaultResponse({
      leads: [stoppedLead],
      selected_lead: stoppedLead,
    });
    LeadsAPI.reconsent.mockResolvedValue({ data: leadPayload });
    const { wrapper } = await mountPage({ response });

    expect(
      wrapper.find('[data-testid="lead-automated-contact-stop"]').text()
    ).toContain('Please stop messaging me.');
    await wrapper.find('[data-testid="record-reconsent"]').trigger('click');
    await flushPromises();

    expect(LeadsAPI.reconsent).toHaveBeenCalledWith(2, {
      source_message_id: 9,
      expected_event_id: 7,
    });
  });

  it('shows granted automated-contact evidence independently of qualification', async () => {
    const grantedLead = {
      ...leadPayload,
      detail: {
        ...leadPayload.detail,
        qualification: null,
        automated_contact_consent: {
          state: 'granted',
          evidence: {
            text: 'Yes, you can message me again.',
            occurred_at: '2026-09-10T08:05:00Z',
          },
        },
      },
    };
    const { wrapper } = await mountPage({
      response: defaultResponse({
        leads: [grantedLead],
        selected_lead: grantedLead,
      }),
    });

    expect(
      wrapper.find('[data-testid="lead-automated-contact-granted"]').text()
    ).toContain('Yes, you can message me again.');
    expect(wrapper.find('[data-testid="record-reconsent"]').exists()).toBe(
      false
    );
  });

  it('lets a Team Member edit assigned details without offering imports, exports or reassignment', async () => {
    const response = defaultResponse();
    response.data.meta.visibility = 'operator';
    LeadsAPI.update.mockResolvedValue({ data: leadPayload });
    const { wrapper } = await mountPage({ response });
    expect(
      wrapper.findAll('button').some(button => button.text() === 'Import')
    ).toBe(false);
    expect(
      wrapper.findAll('button').some(button => button.text() === 'Export')
    ).toBe(false);
    await wrapper
      .findAll('button')
      .find(button => button.text().includes('Edit lead'))
      .trigger('click');
    await flushPromises();
    expect(wrapper.find('form select').exists()).toBe(false);
    await wrapper.find('form').trigger('submit.prevent');
    await flushPromises();
    expect(LeadsAPI.update).toHaveBeenCalled();
    expect(LeadsAPI.update.mock.calls[0][1].lead).not.toHaveProperty(
      'assignee_id'
    );
  });

  it('previews a Lead import before applying the same file', async () => {
    const preview = {
      status: 'ready',
      digest: 'same-file',
      total_count: 1,
      create_count: 1,
      update_count: 0,
      error_count: 0,
      can_apply: true,
      rows: [
        {
          line: 2,
          name: 'Imported Lead',
          phone_number: '+255713456789',
          action: 'create',
          errors: [],
        },
      ],
    };
    LeadsAPI.importLeads
      .mockResolvedValueOnce({ data: { import: preview } })
      .mockResolvedValueOnce({
        data: {
          import: { ...preview, status: 'completed', imported_count: 1 },
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
    expect(LeadsAPI.importLeads).toHaveBeenCalledWith(file, {
      mode: 'preview',
    });
    expect(wrapper.get('[role="dialog"]').text()).toContain('Imported Lead');
    expect(wrapper.get('[role="dialog"]').text()).toContain('Ready to import');

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Import Leads')
      .trigger('click');
    await flushPromises();
    expect(LeadsAPI.importLeads).toHaveBeenLastCalledWith(file, {
      mode: 'apply',
      previewDigest: 'same-file',
    });
    expect(wrapper.find('[role="dialog"]').exists()).toBe(false);

    await wrapper
      .findAll('button')
      .find(button => button.text().includes('Export'))
      .trigger('click');
    await flushPromises();
    expect(LeadsAPI.exportLeads).toHaveBeenCalled();
  });

  it('discards a delayed import preview after the account changes', async () => {
    const pendingPreview = deferred();
    LeadsAPI.importLeads.mockReturnValue(pendingPreview.promise);
    const { wrapper, router } = await mountPage();
    const file = new File(['name,phone_number'], 'account-one.csv', {
      type: 'text/csv',
    });
    const input = wrapper.find('input[type="file"]');
    Object.defineProperty(input.element, 'files', {
      configurable: true,
      value: [file],
    });

    await input.trigger('change');
    await router.push({
      name: 'owned_leads_index',
      params: { accountId: 2 },
      query: { lead_id: '2' },
    });
    await flushPromises();
    pendingPreview.resolve({
      data: {
        import: {
          status: 'ready',
          digest: 'account-one',
          can_apply: true,
          rows: [{ line: 2, name: 'Wrong Account Lead', action: 'create' }],
        },
      },
    });
    await flushPromises();

    expect(wrapper.find('[role="dialog"]').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('Wrong Account Lead');
  });

  it('discards a delayed import error after the account changes', async () => {
    const pendingPreview = deferred();
    LeadsAPI.importLeads.mockReturnValue(pendingPreview.promise);
    const { wrapper, router } = await mountPage();
    const input = wrapper.find('input[type="file"]');
    Object.defineProperty(input.element, 'files', {
      configurable: true,
      value: [new File(['one'], 'account-one.csv')],
    });

    await input.trigger('change');
    await router.push({
      name: 'owned_leads_index',
      params: { accountId: 2 },
      query: { lead_id: '2' },
    });
    pendingPreview.reject({
      response: { data: { error: 'Old account import failed' } },
    });
    await flushPromises();

    expect(wrapper.text()).not.toContain('Old account import failed');
    expect(wrapper.find('[role="dialog"]').exists()).toBe(false);
  });

  it('keeps a new account preview when an old account apply completes', async () => {
    const pendingApply = deferred();
    LeadsAPI.importLeads
      .mockResolvedValueOnce({
        data: {
          import: {
            status: 'ready',
            digest: 'account-one',
            can_apply: true,
            rows: [{ line: 2, name: 'Account One Lead', action: 'create' }],
          },
        },
      })
      .mockReturnValueOnce(pendingApply.promise)
      .mockResolvedValueOnce({
        data: {
          import: {
            status: 'ready',
            digest: 'account-two',
            can_apply: true,
            rows: [{ line: 2, name: 'Account Two Lead', action: 'create' }],
          },
        },
      });
    const { wrapper, router } = await mountPage();
    const input = wrapper.find('input[type="file"]');
    const accountOneFile = new File(['one'], 'account-one.csv');
    Object.defineProperty(input.element, 'files', {
      configurable: true,
      value: [accountOneFile],
    });
    await input.trigger('change');
    await flushPromises();
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Import Leads')
      .trigger('click');

    await router.push({
      name: 'owned_leads_index',
      params: { accountId: 2 },
      query: { lead_id: '2' },
    });
    await flushPromises();
    const accountTwoFile = new File(['two'], 'account-two.csv');
    Object.defineProperty(input.element, 'files', {
      configurable: true,
      value: [accountTwoFile],
    });
    await input.trigger('change');
    await flushPromises();
    expect(wrapper.get('[role="dialog"]').text()).toContain('Account Two Lead');

    pendingApply.resolve({
      data: { import: { status: 'completed', imported_count: 1 } },
    });
    await flushPromises();

    expect(wrapper.get('[role="dialog"]').text()).toContain('Account Two Lead');
  });

  it('does not let a closed apply clear a newer preview', async () => {
    const pendingApply = deferred();
    LeadsAPI.importLeads
      .mockResolvedValueOnce({
        data: {
          import: {
            status: 'ready',
            digest: 'first-preview',
            can_apply: true,
            rows: [{ line: 2, name: 'First Lead', action: 'create' }],
          },
        },
      })
      .mockReturnValueOnce(pendingApply.promise)
      .mockResolvedValueOnce({
        data: {
          import: {
            status: 'ready',
            digest: 'new-preview',
            can_apply: true,
            rows: [{ line: 2, name: 'New Preview Lead', action: 'create' }],
          },
        },
      });
    const { wrapper } = await mountPage();
    const input = wrapper.find('input[type="file"]');
    Object.defineProperty(input.element, 'files', {
      configurable: true,
      value: [new File(['first'], 'first.csv')],
    });
    await input.trigger('change');
    await flushPromises();
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Import Leads')
      .trigger('click');
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Cancel import')
      .trigger('click');

    Object.defineProperty(input.element, 'files', {
      configurable: true,
      value: [new File(['new'], 'new.csv')],
    });
    await input.trigger('change');
    await flushPromises();
    pendingApply.reject({
      response: { data: { error: 'Closed apply failed' } },
    });
    await flushPromises();

    expect(wrapper.get('[role="dialog"]').text()).toContain('New Preview Lead');
    expect(wrapper.text()).not.toContain('Closed apply failed');
  });

  it('distinguishes an empty directory from filtered no-results and offers reset', async () => {
    const { wrapper } = await mountPage({
      query: {},
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

    expect(wrapper.text()).toContain('No Leads yet');

    await wrapper.vm.$router.replace({
      name: 'owned_leads_index',
      params: { accountId: 1 },
      query: { quality: 'qualified' },
    });
    await flushPromises();
    expect(wrapper.text()).toContain('No leads match these filters');
    expect(wrapper.text()).toContain('Reset filters');

    LeadsAPI.get.mockRejectedValueOnce({
      response: { data: { error: 'Failed load' } },
    });
    await wrapper.vm.$router.replace({
      name: 'owned_leads_index',
      params: { accountId: 1 },
      query: { quality: 'unknown' },
    });
    await flushPromises();
    expect(wrapper.text()).toContain('Failed load');
  });
});

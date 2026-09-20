/* global axios */
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import messages from 'dashboard/i18n/locale/en/aiLeadEmployee.json';
import OfferConfigurationPanel from '../OfferConfigurationPanel.vue';
import SettingsShell from '../AiLeadEmployeeSettingsShell.vue';

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountScopedRoute: name => ({ name }) }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const offer = () => ({
  id: 9,
  name: 'Message support',
  currency: 'TZS',
  enabled: true,
  qualification_mode: 'enabled',
  next_step: { kind: 'answer_only' },
  version: 3,
  questions: [
    {
      key: 'budget',
      meaning: 'Purchase budget',
      answer_type: 'money',
      prompt: 'What can you spend?',
      position: 0,
      enabled: true,
      required: true,
      purpose: 'fit',
    },
  ],
  budget_ranges: [
    {
      label: 'Supported budget',
      minimum: '500000.25',
      maximum: null,
      position: 0,
      enabled: true,
    },
  ],
  rules: [],
  requirement_groups: [],
  score_weights: { budget: 20 },
  score_thresholds: { qualified: 60, highly_qualified: 80 },
  commercial_terms_draft: null,
  published_commercial_terms: null,
  commercial_proposals: [],
});

const mountPanel = () =>
  mount(OfferConfigurationPanel, {
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'en', messages: { en: messages } }),
      ],
    },
  });

beforeEach(() => {
  vi.stubGlobal('axios', {
    get: vi.fn().mockResolvedValue({ data: [offer()] }),
    patch: vi
      .fn()
      .mockImplementation((_url, payload) =>
        Promise.resolve({ data: { ...payload.offer, version: 4 } })
      ),
    post: vi.fn(),
    delete: vi.fn(),
  });
});
afterEach(() => vi.unstubAllGlobals());

it('saves explicit qualification mode, question purpose, requirement dimension and next step', async () => {
  const wrapper = mountPanel();
  await flushPromises();

  await wrapper.get('[data-testid="qualification-mode"]').setValue('enabled');
  await wrapper.get('[data-testid="next-step"]').setValue('sales_call');
  await wrapper
    .get('[data-testid="next-step-prompt"]')
    .setValue('Would you like to discuss this Offer?');
  await wrapper
    .get('[data-testid="question-purpose-0"]')
    .setValue('action_eligibility');
  await wrapper.get('[data-testid="add-rule"]').trigger('click');
  await wrapper.get('[data-testid="rule-effect-0"]').setValue('requirement');
  await wrapper
    .get('[data-testid="rule-dimension-0"]')
    .setValue('action_eligibility');
  await wrapper.get('form').trigger('submit');
  await flushPromises();

  expect(axios.patch.mock.calls[0][1].offer).toMatchObject({
    qualification_mode: 'enabled',
    next_step: {
      kind: 'sales_call',
      prompt: 'Would you like to discuss this Offer?',
    },
    questions: [expect.objectContaining({ purpose: 'action_eligibility' })],
    rules: [
      expect.objectContaining({
        kind: 'requirement',
        dimension: 'action_eligibility',
      }),
    ],
  });
});

it('keeps the six owner-facing setup sections while technical controls stay collapsed by default', async () => {
  const wrapper = mountPanel();
  await flushPromises();

  expect(
    wrapper.get('[data-testid="business-about-section"]').text()
  ).toContain('About the business');
  expect(
    wrapper.get('[data-testid="commercial-terms-section"]').text()
  ).toContain('Offers and prices');
  expect(wrapper.get('[data-testid="who-we-help-section"]').text()).toContain(
    'Who we help'
  );
  expect(
    wrapper.get('[data-testid="response-settings-section"]').text()
  ).toContain('How the assistant should respond');
  expect(wrapper.get('[data-testid="next-step-section"]').text()).toContain(
    'What happens next'
  );
  expect(
    wrapper.get('[data-testid="preview-publish-section"]').text()
  ).toContain('Preview and publish');
  expect(
    wrapper.get('[data-testid="advanced-technical-controls"]').element.open
  ).toBe(false);
  expect(
    wrapper.get('[data-testid="question-prompt-0"]').attributes('required')
  ).toBeDefined();
});

it('submits qualification changes when an unrelated commercial amount is blank', async () => {
  const wrapper = mountPanel();
  await flushPromises();

  const saveButton = wrapper.get('[data-testid="save-offer"]');
  expect(saveButton.attributes('formnovalidate')).toBeDefined();
  expect(wrapper.get('[data-testid="commercial-amount"]').element.value).toBe(
    ''
  );

  await wrapper.get('form').trigger('submit');
  await flushPromises();

  expect(axios.patch).toHaveBeenCalledWith(
    expect.stringContaining('/qualification_offers/9'),
    expect.objectContaining({
      offer: expect.objectContaining({ name: 'Message support' }),
    })
  );
});

it('saves and explicitly publishes readable Offer commercial terms', async () => {
  axios.patch.mockImplementation((_url, payload) =>
    Promise.resolve({
      data: {
        ...offer(),
        commercial_terms_draft: {
          ...payload.commercial_terms,
          draft_version: 1,
        },
      },
    })
  );
  axios.post.mockImplementation(() =>
    Promise.resolve({
      data: {
        ...offer(),
        version: 4,
        commercial_terms_draft: {
          amount: '1250.00',
          currency: 'USD',
          quote_required: false,
          timezone: 'Africa/Dar_es_Salaam',
          draft_version: 1,
        },
        published_commercial_terms: {
          amount: '1250.00',
          currency: 'USD',
          quote_required: false,
          timezone: 'Africa/Dar_es_Salaam',
          revision: 1,
        },
      },
    })
  );
  const wrapper = mountPanel();
  await flushPromises();

  await wrapper.get('[data-testid="commercial-amount"]').setValue('1250.00');
  await wrapper.get('[data-testid="commercial-currency"]').setValue('USD');
  await wrapper
    .get('[data-testid="commercial-timezone"]')
    .setValue('Africa/Dar_es_Salaam');
  await wrapper.get('[data-testid="save-commercial-terms"]').trigger('click');
  await flushPromises();

  expect(axios.patch).toHaveBeenCalledWith(
    expect.stringContaining('/qualification_offers/9/commercial_terms'),
    expect.objectContaining({
      commercial_terms: expect.objectContaining({
        amount: '1250.00',
        currency: 'USD',
        timezone: 'Africa/Dar_es_Salaam',
      }),
    })
  );

  await wrapper
    .get('[data-testid="publish-commercial-terms"]')
    .trigger('click');
  await flushPromises();

  expect(axios.post).toHaveBeenCalledWith(
    expect.stringContaining('/qualification_offers/9/commercial_terms/publish'),
    { draft_version: 1 }
  );
  expect(wrapper.text()).toContain('USD 1250.00');
});

it('clears a displayed Lead preview when publishing a newer commercial revision', async () => {
  const pricedOffer = offer();
  pricedOffer.commercial_terms_draft = {
    amount: '900.00',
    currency: 'USD',
    quote_required: false,
    timezone: 'UTC',
    draft_version: 2,
  };
  pricedOffer.published_commercial_terms = {
    amount: '1250.00',
    currency: 'USD',
    quote_required: false,
    timezone: 'UTC',
    revision: 1,
  };
  axios.get.mockResolvedValue({ data: [pricedOffer] });
  axios.post.mockImplementation(url =>
    url.endsWith('/preview')
      ? Promise.resolve({ data: { answer: 'Published answer: USD 1250.00' } })
      : Promise.resolve({
          data: {
            ...pricedOffer,
            version: 4,
            published_commercial_terms: {
              ...pricedOffer.published_commercial_terms,
              amount: '900.00',
              revision: 2,
            },
          },
        })
  );
  const wrapper = mountPanel();
  await flushPromises();

  const previewButton = wrapper
    .findAll('button')
    .find(button => button.text().includes('Preview Lead answer'));
  await previewButton.trigger('click');
  await flushPromises();
  expect(wrapper.text()).toContain('Published answer: USD 1250.00');

  await wrapper
    .get('[data-testid="publish-commercial-terms"]')
    .trigger('click');
  await flushPromises();

  expect(wrapper.text()).not.toContain('Published answer: USD 1250.00');
  expect(wrapper.text()).toContain('USD 900.00');
});

it('offers a stable boolean field for explicit sales-call agreement', async () => {
  const wrapper = mountPanel();
  await flushPromises();

  await wrapper
    .get('[data-testid="new-question-field"]')
    .setValue('sales_call_agreement');
  await wrapper.get('[data-testid="add-question"]').trigger('click');
  await wrapper
    .get('[data-testid="question-purpose-1"]')
    .setValue('action_eligibility');
  await wrapper.get('form').trigger('submit');
  await flushPromises();

  expect(axios.patch.mock.calls[0][1].offer.questions).toContainEqual(
    expect.objectContaining({
      key: 'sales_call_agreement',
      meaning: 'Sales call agreement',
      answer_type: 'boolean',
      purpose: 'action_eligibility',
    })
  );
});

it('edits Google-backed availability and disconnects without exposing credentials', async () => {
  axios.get.mockImplementation(url =>
    url.includes('booking_configuration')
      ? Promise.resolve({
          data: {
            connected: true,
            calendar_id: 'sales@example.test',
            timezone: 'Africa/Dar_es_Salaam',
            duration_minutes: 30,
            minimum_notice_minutes: 120,
            buffer_before_minutes: 10,
            buffer_after_minutes: 15,
            working_days: [1, 2, 3, 4, 5],
            allowed_hours: { start: '09:00', end: '17:00' },
            exceptions: [],
            connection: {
              status: 'connected',
              connected: true,
              calendar_id: 'sales@example.test',
            },
          },
        })
      : Promise.resolve({
          data: { questions: [], budget_ranges: [], follow_up: {} },
        })
  );
  axios.patch.mockImplementation((_url, payload) =>
    Promise.resolve({ data: payload })
  );
  axios.delete.mockResolvedValue({
    data: {
      status: 'disconnected',
      connected: false,
      calendar_id: 'sales@example.test',
    },
  });
  const wrapper = mount(SettingsShell, {
    props: { section: 'booking_business_hours' },
    global: { stubs: { RouterLink: true, Icon: true } },
  });
  await flushPromises();

  expect(wrapper.text()).toContain('Connected to sales@example.test');
  await wrapper
    .findAll('button')
    .find(button => button.text() === 'Add date')
    .trigger('click');
  await wrapper.get('input[type="date"]').setValue('2026-12-25');
  await wrapper
    .findAll('button')
    .find(button => button.text() === 'Save changes')
    .trigger('click');
  await flushPromises();

  expect(axios.patch).toHaveBeenCalledWith(
    expect.stringContaining('booking_configuration'),
    expect.objectContaining({
      calendar_id: 'sales@example.test',
      exceptions: [{ date: '2026-12-25', unavailable: true }],
    })
  );

  await wrapper
    .findAll('button')
    .find(button => button.text() === 'Disconnect')
    .trigger('click');
  await flushPromises();
  expect(axios.delete).toHaveBeenCalledWith(
    expect.stringContaining('google_calendar_connection')
  );
  expect(wrapper.text()).toContain('Connect a calendar before offering times.');
});

it('drops a hidden link when the owner changes to a non-link next step', async () => {
  const saved = offer();
  saved.next_step = {
    kind: 'purchase_link',
    prompt: 'Enroll here:',
    url: 'https://example.test/enroll',
  };
  axios.get.mockResolvedValue({ data: [saved] });
  const wrapper = mountPanel();
  await flushPromises();

  await wrapper.get('[data-testid="next-step"]').setValue('enquiry');
  await wrapper.get('form').trigger('submit');
  await flushPromises();

  expect(axios.patch.mock.calls[0][1].offer.next_step).toEqual({
    kind: 'enquiry',
    prompt: 'Enroll here:',
  });
});

it('edits one Offer while preserving exact human currency units and its revision', async () => {
  const editableOffer = offer();
  delete editableOffer.commercial_terms_draft;
  delete editableOffer.published_commercial_terms;
  delete editableOffer.commercial_proposals;
  const wrapper = mountPanel();
  await flushPromises();
  expect(wrapper.get('[data-testid="budget-minimum-0"]').element.value).toBe(
    '500000.25'
  );
  expect(wrapper.text()).toContain('TZS');
  await wrapper.get('[data-testid="offer-name"]').setValue('Support for teams');
  await wrapper.get('form').trigger('submit');
  await flushPromises();
  expect(axios.patch).toHaveBeenCalledWith(
    expect.stringContaining('/qualification_offers/9'),
    {
      offer: { ...editableOffer, name: 'Support for teams' },
    }
  );
  expect(wrapper.text()).toContain('Revision 4');
});

it('creates a separate Offer with ordered questions and a typed money rule', async () => {
  axios.post.mockImplementation((_url, payload) =>
    Promise.resolve({ data: { ...payload.offer, id: 10, version: 1 } })
  );
  const wrapper = mountPanel();
  await flushPromises();
  await wrapper.get('[data-testid="new-offer"]').trigger('click');
  await wrapper.get('[data-testid="offer-name"]').setValue('Consulting');
  await wrapper.get('[data-testid="offer-currency"]').setValue('USD');
  await wrapper.get('[data-testid="new-question-field"]').setValue('budget');
  await wrapper.get('[data-testid="add-question"]').trigger('click');
  await wrapper
    .get('[data-testid="question-prompt-0"]')
    .setValue('What can you spend in USD?');
  await wrapper.get('[data-testid="new-question-field"]').setValue('problem');
  await wrapper.get('[data-testid="add-question"]').trigger('click');
  await wrapper
    .get('[data-testid="question-prompt-1"]')
    .setValue('What should we solve?');
  await wrapper.get('[data-testid="question-up-1"]').trigger('click');
  await wrapper.get('[data-testid="add-budget-range"]').trigger('click');
  await wrapper.get('[data-testid="budget-minimum-0"]').setValue('2500.25');
  await wrapper.get('[data-testid="add-rule"]').trigger('click');
  await wrapper.get('[data-testid="rule-field-0"]').setValue('budget');
  await wrapper.get('[data-testid="rule-operator-0"]').setValue('gte');
  await wrapper.get('[data-testid="rule-value-0"]').setValue('2500.25');
  await wrapper.get('[data-testid="rule-score-0"]').setValue('25');
  await wrapper.get('form').trigger('submit');
  await flushPromises();
  const saved = axios.post.mock.calls[0][1].offer;
  expect(saved).toMatchObject({
    name: 'Consulting',
    currency: 'USD',
    enabled: true,
  });
  expect(
    saved.questions.map(question => [question.key, question.position])
  ).toEqual([
    ['problem', 0],
    ['budget', 1],
  ]);
  expect(saved.budget_ranges[0].minimum).toBe('2500.25');
  expect(saved.rules[0]).toMatchObject({
    field: 'budget',
    operator: 'gte',
    value: { amount: '2500.25', currency: 'USD' },
    score_delta: 25,
  });
  expect(axios.patch).not.toHaveBeenCalled();
  await wrapper.get('[data-testid="offer-select"]').setValue('9');
  expect(wrapper.get('[data-testid="offer-name"]').element.value).toBe(
    'Message support'
  );
  expect(wrapper.get('[data-testid="budget-minimum-0"]').element.value).toBe(
    '500000.25'
  );
});

it('displays the saved question order even when the API array uses a different order', async () => {
  const saved = offer();
  saved.questions[0].position = 1;
  saved.questions.push({
    ...saved.questions[0],
    key: 'problem',
    meaning: 'Problem',
    answer_type: 'text',
    prompt: 'First saved question',
    position: 0,
  });
  axios.get.mockResolvedValue({ data: [saved] });
  const wrapper = mountPanel();
  await flushPromises();
  expect(wrapper.get('[data-testid="question-prompt-0"]').element.value).toBe(
    'First saved question'
  );
});

it('keeps question ordering unambiguous after removing and adding questions', async () => {
  const saved = offer();
  saved.questions.push(
    {
      ...saved.questions[0],
      key: 'problem',
      meaning: 'Problem',
      answer_type: 'text',
      position: 1,
    },
    {
      ...saved.questions[0],
      key: 'urgency',
      meaning: 'Urgency',
      answer_type: 'text',
      position: 2,
    }
  );
  axios.get.mockResolvedValue({ data: [saved] });
  const wrapper = mountPanel();
  await flushPromises();
  await wrapper
    .findAll('button')
    .filter(button => button.text() === 'Remove')[1]
    .trigger('click');
  await wrapper
    .get('[data-testid="new-question-field"]')
    .setValue('business_type');
  await wrapper.get('[data-testid="add-question"]').trigger('click');
  await wrapper
    .get('[data-testid="question-prompt-2"]')
    .setValue('What is your business?');
  await wrapper.get('form').trigger('submit');
  await flushPromises();
  expect(
    axios.patch.mock.calls[0][1].offer.questions.map(question => [
      question.key,
      question.position,
    ])
  ).toEqual([
    ['budget', 0],
    ['urgency', 1],
    ['business_type', 2],
  ]);
});

it('retains a conflicted draft until the owner explicitly reloads the newer revision', async () => {
  axios.patch.mockRejectedValue({
    response: {
      status: 409,
      data: { error: 'Configuration changed; reload before saving' },
    },
  });
  const wrapper = mountPanel();
  await flushPromises();
  await wrapper
    .get('[data-testid="offer-name"]')
    .setValue('My unsaved changes');
  await wrapper.get('form').trigger('submit');
  await flushPromises();
  expect(wrapper.get('[role="alert"]').text()).toContain('reload');
  expect(wrapper.get('[data-testid="offer-name"]').element.value).toBe(
    'My unsaved changes'
  );
  expect(
    wrapper.get('button[type="submit"]').attributes('disabled')
  ).toBeDefined();
  axios.get.mockResolvedValue({
    data: { ...offer(), name: 'Changed by another owner', version: 4 },
  });
  await wrapper.get('[data-testid="reload-offer"]').trigger('click');
  await flushPromises();
  expect(wrapper.get('[data-testid="offer-name"]').element.value).toBe(
    'Changed by another owner'
  );
  expect(wrapper.text()).toContain('Revision 4');
});

it('uses the per-Offer API from the existing settings tab without fetching unrelated settings', async () => {
  const wrapper = mount(SettingsShell, {
    props: { section: 'offers_qualification' },
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'en', messages: { en: messages } }),
      ],
    },
  });
  await flushPromises();
  expect(wrapper.findComponent(OfferConfigurationPanel).exists()).toBe(true);
  expect(axios.get.mock.calls.map(([url]) => url)).toEqual(
    expect.arrayContaining([
      expect.stringContaining('/qualification_offers'),
      expect.stringContaining('/qualification_offers/9/setup_sources'),
    ])
  );
});

it('keeps guided setup notes proposed until the owner explicitly publishes the reviewed version', async () => {
  const proposal = {
    id: 22,
    title: 'Online Profits notes',
    status: 'proposed',
    version: 1,
    proposed_facts: ['Online Profits helps founders.'],
    proposed_rules: ['A sales call requires confirmed fit.'],
    unknowns: ['A current price is still needed.'],
    configuration: {
      qualification_mode: 'disabled',
      next_step: { kind: 'purchase_link' },
      questions: [
        {
          key: 'setup_fit_registration',
          meaning: 'Current registration number',
          purpose: 'action_eligibility',
        },
        {
          key: 'ready',
          meaning: 'Ready to proceed',
          answer_type: 'boolean',
          purpose: 'fit',
        },
      ],
      rules: [
        {
          field: 'setup_fit_registration',
          kind: 'requirement',
          dimension: 'action_eligibility',
          priority: 0,
        },
      ],
      requirement_groups: [
        {
          dimension: 'fit',
          any: [
            {
              field: 'budget',
              operator: 'lt',
              value: { amount: '1000000', currency: 'TZS' },
            },
            { field: 'ready', operator: 'eq', value: true },
          ],
        },
      ],
    },
  };
  axios.post.mockImplementation(url =>
    Promise.resolve({
      data: url.endsWith('/publish')
        ? { ...proposal, status: 'published', published_offer_version: 4 }
        : proposal,
    })
  );
  const wrapper = mountPanel();
  await flushPromises();

  await wrapper
    .get('[data-testid="business-setup-section"] textarea')
    .setValue(
      'Online Profits helps founders. A sales call requires confirmed fit.'
    );
  await wrapper.get('[data-testid="propose-business-setup"]').trigger('click');
  await flushPromises();

  expect(wrapper.text()).toContain('Nothing is live yet.');
  expect(wrapper.text()).toContain('A current price is still needed.');
  expect(wrapper.text()).toContain('Disabled');
  expect(wrapper.text()).toContain('Share a purchase link');
  expect(wrapper.text()).toContain('Action eligibility');
  expect(wrapper.text()).toContain('Less than');
  expect(wrapper.text()).toContain('Equals');
  expect(wrapper.text()).toContain('Yes');
  expect(wrapper.text()).not.toContain(' budget lt ');
  expect(wrapper.text()).not.toContain(' ready eq ');
  expect(wrapper.text()).not.toContain('setup_fit_registration');
  expect(wrapper.text()).not.toContain('purchase_link');
  expect(wrapper.text()).not.toContain('action_eligibility');
  expect(axios.post).toHaveBeenCalledWith(
    expect.stringContaining('/qualification_offers/9/setup_sources'),
    expect.objectContaining({
      source: expect.objectContaining({
        source_type: 'pasted_prose',
        reviewed_configuration: expect.objectContaining({
          version: 3,
          qualification_mode: 'enabled',
        }),
      }),
    })
  );

  await wrapper.get('[data-testid="publish-business-setup"]').trigger('click');
  await flushPromises();

  expect(axios.post).toHaveBeenCalledWith(
    expect.stringContaining('/qualification_offers/9/setup_sources/22/publish'),
    { expected_source_version: 1, expected_offer_version: 3 }
  );
});

it('reopens a persisted setup draft with its full proposed configuration and saves a versioned correction', async () => {
  const persisted = {
    id: 31,
    title: 'Persisted setup',
    source_type: 'document',
    body: 'Retailers need an active registration.',
    status: 'proposed',
    version: 4,
    proposed_facts: [],
    proposed_rules: ['Retailers need an active registration.'],
    unknowns: [],
    configuration: {
      ...offer(),
      qualification_mode: 'enabled',
      next_step: { kind: 'enquiry' },
      questions: [
        {
          key: 'setup_fit_registration',
          meaning: 'Active registration',
          answer_type: 'boolean',
          prompt: 'Do you have an active registration?',
          position: 0,
          enabled: true,
          required: true,
          purpose: 'fit',
        },
      ],
      rules: [],
    },
  };
  axios.get.mockImplementation(url =>
    Promise.resolve({
      data: url.endsWith('/setup_sources') ? [persisted] : [offer()],
    })
  );
  axios.patch.mockResolvedValue({
    data: { ...persisted, version: 5, body: 'Corrected registration rule.' },
  });
  const wrapper = mountPanel();
  await flushPromises();

  await wrapper.get('[data-testid="reopen-business-setup"]').trigger('click');
  expect(
    wrapper.get('[data-testid="business-setup-section"] textarea').element.value
  ).toBe('Retailers need an active registration.');
  expect(wrapper.get('[data-testid="qualification-mode"]').element.value).toBe(
    'enabled'
  );
  expect(wrapper.text()).toContain('Active registration');

  await wrapper
    .get('[data-testid="business-setup-section"] textarea')
    .setValue('Corrected registration rule.');
  await wrapper.get('[data-testid="correct-business-setup"]').trigger('click');
  await flushPromises();

  expect(axios.patch).toHaveBeenCalledWith(
    expect.stringContaining('/qualification_offers/9/setup_sources/31'),
    expect.objectContaining({
      expected_source_version: 4,
      source: expect.objectContaining({
        body: 'Corrected registration rule.',
        reviewed_configuration: expect.objectContaining({
          qualification_mode: 'enabled',
          next_step: { kind: 'enquiry' },
        }),
      }),
    })
  );
});

it('starts a new proposed correction from a published setup while keeping its history visible', async () => {
  const published = {
    id: 32,
    title: 'Published setup',
    source_type: 'document',
    body: 'Published registration guidance.',
    status: 'published',
    version: 2,
    proposed_facts: ['Published registration guidance.'],
    proposed_rules: [],
    unknowns: [],
    configuration: { ...offer(), qualification_mode: 'disabled' },
    history: [
      { version: 1, body: 'Original registration guidance.' },
      { version: 2, body: 'Published registration guidance.' },
    ],
  };
  axios.get.mockImplementation(url =>
    Promise.resolve({
      data: url.endsWith('/setup_sources') ? [published] : [offer()],
    })
  );
  axios.post.mockResolvedValue({
    data: {
      ...published,
      id: 33,
      status: 'proposed',
      version: 1,
      body: 'Corrected registration guidance.',
    },
  });
  const wrapper = mountPanel();
  await flushPromises();

  expect(wrapper.text()).toContain('Original registration guidance.');
  await wrapper
    .get('[data-testid="edit-published-business-setup"]')
    .trigger('click');
  expect(
    wrapper.get('[data-testid="business-setup-section"] textarea').element.value
  ).toBe('Published registration guidance.');
  expect(wrapper.get('[data-testid="qualification-mode"]').element.value).toBe(
    'enabled'
  );
  expect(wrapper.get('[data-testid="test-business-setup"]').exists()).toBe(
    true
  );

  await wrapper
    .get('[data-testid="business-setup-section"] textarea')
    .setValue('Corrected registration guidance.');
  await wrapper.get('[data-testid="propose-business-setup"]').trigger('click');
  await flushPromises();

  expect(axios.post).toHaveBeenCalledWith(
    expect.stringContaining('/qualification_offers/9/setup_sources'),
    expect.objectContaining({
      source: expect.objectContaining({
        body: 'Corrected registration guidance.',
        reviewed_configuration: expect.objectContaining({
          qualification_mode: 'enabled',
          version: 3,
        }),
      }),
    })
  );
});

it('runs a published setup with the entered question through the no-send Test Center API', async () => {
  const published = {
    id: 22,
    title: 'Published notes',
    status: 'published',
    version: 2,
    proposed_facts: ['We help founders.'],
    proposed_rules: [],
    unknowns: [],
  };
  axios.get.mockImplementation(url =>
    Promise.resolve({
      data: url.endsWith('/setup_sources') ? [published] : [offer()],
    })
  );
  axios.post.mockResolvedValue({
    data: {
      id: 71,
      scenario_key: 'business_setup_context',
      status: 'completed',
      steps: [
        {
          selected_answer: 'Online Profits helps founders.',
          source_references: [{ id: 44, type: 'knowledge_document' }],
          blocked_reason: null,
        },
      ],
    },
  });
  const wrapper = mountPanel();
  await flushPromises();

  await wrapper
    .get('[data-testid="business-setup-question"]')
    .setValue('Who is this service for?');
  await wrapper.get('[data-testid="test-business-setup"]').trigger('click');
  await flushPromises();

  expect(axios.post).toHaveBeenCalledWith(
    expect.stringContaining('/evaluation_sandbox/runs'),
    {
      scenario_key: 'business_setup_context',
      business_setup_source_id: 22,
      question: 'Who is this service for?',
    }
  );
  expect(wrapper.text()).toContain('no-send Test Center run completed');
});

it('shows a completed-but-blocked setup run as blocked rather than as a successful answer', async () => {
  const published = {
    id: 22,
    title: 'Published notes',
    status: 'published',
    version: 2,
    proposed_facts: ['We help founders.'],
    proposed_rules: [],
    unknowns: [],
  };
  axios.get.mockImplementation(url =>
    Promise.resolve({
      data: url.endsWith('/setup_sources') ? [published] : [offer()],
    })
  );
  axios.post.mockResolvedValue({
    data: {
      id: 72,
      scenario_key: 'business_setup_context',
      status: 'completed',
      steps: [
        {
          selected_answer: null,
          source_references: [],
          blocked_reason: 'provider_configuration_changed',
        },
      ],
    },
  });
  const wrapper = mountPanel();
  await flushPromises();

  await wrapper
    .get('[data-testid="business-setup-question"]')
    .setValue('Who is this service for?');
  await wrapper.get('[data-testid="test-business-setup"]').trigger('click');
  await flushPromises();

  expect(wrapper.text()).toContain('managed AI service changed during the run');
  expect(wrapper.text()).not.toContain('provider_configuration_changed');
  expect(wrapper.text()).not.toContain('no-send Test Center run completed');
});

it('shows a failed setup run truthfully and clears its result when switching Offers', async () => {
  const secondOffer = { ...offer(), id: 10, name: 'Second Offer' };
  const published = {
    id: 22,
    title: 'Published notes',
    status: 'published',
    version: 2,
    proposed_facts: ['We help founders.'],
    proposed_rules: [],
    unknowns: [],
    configuration: {
      qualification_mode: 'not_configured',
      next_step: { kind: 'answer_only' },
    },
  };
  axios.get.mockImplementation(url =>
    Promise.resolve({
      data: url.endsWith('/setup_sources')
        ? [published]
        : [offer(), secondOffer],
    })
  );
  axios.post.mockResolvedValue({
    data: { id: 72, scenario_key: 'business_setup_context', status: 'failed' },
  });
  const wrapper = mountPanel();
  await flushPromises();

  await wrapper
    .get('[data-testid="business-setup-question"]')
    .setValue('Who is this for?');
  await wrapper.get('[data-testid="test-business-setup"]').trigger('click');
  await flushPromises();
  expect(wrapper.get('[role="alert"]').text()).toContain('did not complete');

  await wrapper.get('[data-testid="offer-select"]').setValue('10');
  await flushPromises();
  expect(wrapper.text()).not.toContain('did not complete');
});

it('updates existing money-rule currency without converting amounts and retains a rejected draft', async () => {
  const saved = offer();
  saved.rules = [
    {
      field: 'budget',
      operator: 'gte',
      value: { amount: '2500.25', currency: 'TZS' },
      kind: 'score_rule',
      score_delta: 20,
      priority: 0,
      enabled: true,
    },
  ];
  axios.get.mockResolvedValue({ data: [saved] });
  axios.patch.mockRejectedValueOnce({
    response: {
      status: 422,
      data: { error: 'Currency already used by evidence' },
    },
  });
  const wrapper = mountPanel();
  await flushPromises();
  await wrapper.get('[data-testid="offer-currency"]').setValue('USD');
  expect(wrapper.get('[data-testid="rule-value-0"]').element.value).toBe(
    '2500.25'
  );
  expect(
    wrapper.get('[data-testid="rule-value-0"]').element.parentElement
      .textContent
  ).toContain('USD');
  await wrapper.get('form').trigger('submit');
  await flushPromises();
  expect(axios.patch).toHaveBeenCalledWith(
    expect.stringContaining('/qualification_offers/9'),
    expect.objectContaining({
      offer: expect.objectContaining({
        currency: 'USD',
        rules: [
          expect.objectContaining({
            value: { amount: '2500.25', currency: 'USD' },
          }),
        ],
      }),
    })
  );
  expect(wrapper.text()).toContain('Currency already used by evidence');
  expect(wrapper.get('[data-testid="offer-currency"]').element.value).toBe(
    'USD'
  );
  expect(wrapper.get('[data-testid="rule-value-0"]').element.value).toBe(
    '2500.25'
  );
  await wrapper.get('form').trigger('submit');
  await flushPromises();
  expect(wrapper.text()).toContain('Offer saved');
});

it('edits and reloads typed alternative groups without losing children when switching any to all', async () => {
  const saved = offer();
  saved.requirement_groups = [
    {
      dimension: 'fit',
      any: [
        {
          field: 'budget',
          operator: 'lt',
          value: { amount: '1000000.00', currency: 'TZS' },
        },
      ],
    },
  ];
  axios.get.mockResolvedValue({ data: [saved] });
  const wrapper = mountPanel();
  await flushPromises();

  await wrapper.get('[data-testid="group-branch-0"]').setValue('all');
  expect(wrapper.get('[data-testid="group-field-0-0"]').element.value).toBe(
    'budget'
  );
  await wrapper.get('[data-testid="group-operator-0-0"]').setValue('known');
  expect(wrapper.find('[data-testid="group-value-0-0"]').exists()).toBe(false);
  await wrapper.get('[data-testid="group-operator-0-0"]').setValue('lt');
  await wrapper.get('[data-testid="group-value-0-0"]').setValue('750000.00');
  await wrapper.get('form').trigger('submit');
  await flushPromises();

  expect(axios.patch.mock.calls[0][1].offer.requirement_groups).toEqual([
    {
      dimension: 'fit',
      all: [
        {
          field: 'budget',
          operator: 'lt',
          value: { amount: '750000.00', currency: 'TZS' },
        },
      ],
    },
  ]);
});

it('saves boolean group values as booleans through rendered controls', async () => {
  const saved = offer();
  saved.questions.push({
    key: 'ready',
    meaning: 'Ready',
    answer_type: 'boolean',
    prompt: 'Ready?',
    position: 1,
    enabled: true,
    required: true,
    purpose: 'fit',
  });
  saved.requirement_groups = [
    {
      dimension: 'fit',
      all: [{ field: 'ready', operator: 'eq', value: true }],
    },
  ];
  axios.get.mockResolvedValue({ data: [saved] });
  const wrapper = mountPanel();
  await flushPromises();

  await wrapper.get('[data-testid="group-value-0-0"]').setValue('false');
  await wrapper.get('form').trigger('submit');
  await flushPromises();

  expect(
    axios.patch.mock.calls[0][1].offer.requirement_groups[0].all[0].value
  ).toBe(false);
});

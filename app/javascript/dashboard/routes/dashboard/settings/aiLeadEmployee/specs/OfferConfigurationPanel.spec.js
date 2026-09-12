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
  score_weights: { budget: 20 },
  score_thresholds: { qualified: 60, highly_qualified: 80 },
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
  });
});
afterEach(() => vi.unstubAllGlobals());

it('saves explicit qualification mode, question purpose, requirement dimension and next step', async () => {
  const wrapper = mountPanel();
  await flushPromises();

  await wrapper.get('[data-testid="qualification-mode"]').setValue('enabled');
  await wrapper.get('[data-testid="next-step"]').setValue('sales_call');
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
    next_step: { kind: 'sales_call' },
    questions: [expect.objectContaining({ purpose: 'action_eligibility' })],
    rules: [
      expect.objectContaining({
        kind: 'requirement',
        dimension: 'action_eligibility',
      }),
    ],
  });
});

it('edits one Offer while preserving exact human currency units and its revision', async () => {
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
      offer: { ...offer(), name: 'Support for teams' },
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
  expect(axios.get.mock.calls.map(([url]) => url)).toEqual([
    expect.stringContaining('/qualification_offers'),
  ]);
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

import { flushPromises, mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { createMemoryHistory, createRouter } from 'vue-router';
import EvaluationSandboxPanel from '../EvaluationSandboxPanel.vue';
import EvaluationSandboxAPI from 'dashboard/api/evaluationSandbox';

vi.mock('dashboard/api/evaluationSandbox', () => ({
  default: {
    get: vi.fn(),
    runs: vi.fn(),
    runScenario: vi.fn(),
    gradeRun: vi.fn(),
    launchGate: vi.fn(),
    updateLaunchGate: vi.fn(),
    approveLaunch: vi.fn(),
    proposeKnowledge: vi.fn(),
  },
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params = {}) => {
      const message =
        {
          'AI_LEAD_EMPLOYEE.TEST_CENTER.ADMIN_APPROVAL': 'Admin approval',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.AI_EMPLOYEE': 'AI Lead Employee',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.ALL_RESULTS': 'All results',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.APPROVAL_NOTES': 'Approval notes',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.APPROVED': 'Approved',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.APPROVE_LAUNCH': 'Approve launch',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.BLOCKERS': 'Blocking checks',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.BOOKING_OUTCOMES': 'Booking outcomes',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.CANCEL': 'Cancel',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.CHECK_COUNT':
            '{result} {passed} of {total} checks',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.CLEAR_FILTERS': 'Clear filters',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.COLLAPSE_PANEL':
            'Collapse transcript panel',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.CONFIGURATION': 'Configuration',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.CONFIGURATION_VERSION':
            'Configuration version',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.CONTROL_BLOCKED':
            'AI reply blocked by control state.',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.CORRECTED_ANSWER': 'Corrected answer',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.CORRECTED_QUESTION':
            'Corrected question',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.CORRECTION_ERROR':
            'Correction could not be proposed.',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.CORRECTION_HELP':
            'Creates a draft Knowledge item. Approval is still required before the AI Employee can use it.',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.CORRECTION_PROPOSAL':
            'Correction proposal',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.CORRECTION_PROPOSED':
            'Correction proposed to Knowledge for approval',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.CORRECTION_TITLE':
            'Correction for {scenario}',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.CORRECTION_TITLE_LABEL':
            'Correction title',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.CORRECT_ANSWER': 'Correct answer',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.DEFAULT_CHECKS':
            'Qualification behavior',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.DEFAULT_OFFER': 'Growth Plan',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.DUPLICATE_IGNORED':
            'Duplicate event ignored.',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.EMPTY_VALUE': 'Not captured',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.ENABLED': 'enabled',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.EVALUATION_CRITERIA':
            'Evaluation criteria',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.EXPAND_PANEL':
            'Expand transcript panel',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.FAILED': 'Fail',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.FAILED_REVIEW': 'Failed',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.FROM_DATE': 'From date',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.GATE_SAVED': 'Release check saved',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.GRADE_ERROR':
            'Grades could not be saved.',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.GRADE_FAILED':
            'Review saved with failures',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.GRADE_NOTES': 'Notes',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.GRADE_NOTES_LABEL': '{grade} notes',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.GRADE_PASSED': 'Review passed',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.HANDOFF_ACCURACY': 'Handoff accuracy',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.HANDOFF_BOOKING_VALUE':
            'Handoff: {handoff} - Booking: {booking}',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.HIDE_EVIDENCE': 'Hide evidence',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.HIDE_SETUP': 'Hide setup',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.HISTORICAL_RESULT_FILTER':
            'Historical result filter',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.KNOWLEDGE': 'Knowledge',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.KNOWLEDGE_VERSION': 'Knowledge version',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.LAST_RESULT': 'Last result',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.LAST_TESTED': 'Last tested',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.LAUNCH_APPROVED': 'Live AI enabled',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.LAUNCH_BLOCKED': 'Release is blocked.',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.LIVE_AI_STATE': 'Live AI is {state}',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.LOADING': 'Loading Test Center',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.LOAD_ERROR':
            'Test Center could not be loaded.',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.LOCKED': 'locked',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.MARKED_WRONG_NOTE':
            'Marked wrong from transcript.',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.MARK_WRONG': 'Mark wrong',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.MEDIA_STEP':
            'Non-text WhatsApp message',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.MODEL': 'Model',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.MORE_FILTERS': 'More filters',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.NEEDS_REVIEW': 'Needs review',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.NEXT_QUESTION_VALUE':
            'Next question: {question}',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.NONE': 'None',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.NOT_ENOUGH_DATA': 'Not enough data',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.NOT_RUN': 'Not run',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.NO_RESULTS':
            'No results match these filters.',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.NO_SCENARIOS':
            'No scenarios match these filters.',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.OFFER': 'Offer',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.OFFER_FILTER': 'Offer filter',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.OPEN_TRANSCRIPT': 'Open transcript',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.OWNER': 'Owner',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.OWNER_FILTER': 'Owner filter',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.PANEL_MENU': 'Transcript actions',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.PASSED': 'Pass',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.PASSED_REVIEW': 'Passed',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.PILOT_REVIEWS':
            'Pilot conversations reviewed',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.PROPOSE_TO_KNOWLEDGE':
            'Propose to Knowledge',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.QUALIFICATION_ACCURACY':
            'Qualification accuracy',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.QUALITY_SCORE':
            'Lead Quality: {quality} - Score {score}',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.QUESTION': 'Question',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.RELEASE_CHECK': 'Release check',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.REQUIRED_SCENARIOS':
            'Required scenarios',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.RESULT': 'Result',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.RESULTS_LOAD_ERROR':
            'Results could not be loaded.',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.RESULT_FILTER': 'Result filter',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.REVIEWER_GRADING_HELP':
            'Reviewer grading is stored with configuration, knowledge, model, expected result, and actual result.',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.REVIEW_PATH': 'Review path: {reason}',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.RUNNING': 'Running...',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.RUN_AGAIN': 'Run again',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.RUN_ERROR':
            'Scenario could not be run.',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.RUN_FAILED': 'Simulation needs review',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.RUN_META': 'Tested {time} by {tester}',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.RUN_PASSED':
            'Simulation passed automated checks',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.RUN_TEST': 'Run test',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.RUN_TO_SEE_TRANSCRIPT':
            'Run a scenario to see the simulation transcript.',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.SAFETY_FAILURES': 'Safety failures',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.SAVE_CHECK': 'Save check',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.SAVE_GRADES': 'Save grades',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.SCENARIO': 'Scenario',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.SCENARIO_COUNT':
            'Showing {shown} of {total} scenarios',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.SCENARIO_ROW': '{index}. {name}',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.SEARCH': 'Search scenarios',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.SEARCH_PLACEHOLDER':
            'Search scenarios...',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.SELECT_SCENARIO': 'Select a scenario',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.SHOW_EVIDENCE': 'Show evidence',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.SHOW_SETUP': 'Show setup',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.SIMULATED_DELIVERED':
            'Simulated delivered',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.SIMULATED_MESSAGE_COUNT':
            '{count} simulated messages',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.SIMULATION': 'simulation',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.SIMULATION_TRANSCRIPT_NOTICE':
            'Simulation transcript. Meta, calendar, and alert delivery are not invoked.',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.SIMULATION_WARNING':
            'Simulation - no message will be sent. This is a test environment only.',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.SOURCES_VALUE': 'Sources: {sources}',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.STARTING_CHANNEL': 'Starting channel',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.STEP_EVIDENCE': 'Step {id} evidence',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.SUBTITLE':
            'Test changes before they reach real leads',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.TAB_LABEL': 'Test Center tabs',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.TABS.RELEASE': 'Release check',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.TABS.RESULTS': 'Results',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.TABS.SCENARIOS': 'Scenarios',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.TEAM_ROLEPLAY':
            'Team roleplay completed',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.TESTED_BY':
            'Tested: {time} by {tester}',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.TEST_LEAD': 'Test lead (WhatsApp)',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.TEST_SUMMARY': 'Test summary',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.TITLE': 'Test Center',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.TITLE_FIELD': 'Title',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.TO_DATE': 'To date',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.TRANSCRIPT': 'Transcript',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.TRANSCRIPT_COLLAPSED':
            'Transcript panel collapsed.',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.UNANSWERED_RATE':
            'Unanswered-question rate',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.UNASSIGNED': 'Unassigned',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.WAITING': 'Waiting',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.WHATSAPP_SIMULATION':
            'WhatsApp simulation',
          'AI_LEAD_EMPLOYEE.TEST_CENTER.WHAT_IT_CHECKS': 'What it checks',
        }[key] || key;
      return Object.entries(params).reduce(
        (text, [param, value]) =>
          text.replace(new RegExp(`\\{${param}\\}`, 'g'), value),
        message
      );
    },
  }),
}));

const IconStub = {
  props: ['icon'],
  template: '<span class="icon-stub" :data-icon="icon" />',
};

const run = {
  id: 7,
  scenario_key: 'successful_qualification',
  scenario_name: 'High-intent lead asks for pricing',
  result: 'needs_review',
  status: 'completed',
  automated_passed: true,
  passed: false,
  user_id: 1,
  tester: 'John Nkosi',
  configuration_version: 4,
  knowledge_version: 'knowledge-v4',
  model_identifier: 'deterministic-v1-sandbox',
  total_checks: 5,
  passed_checks: 5,
  completed_at: '2026-08-26T08:42:00Z',
  created_at: '2026-08-26T08:42:00Z',
  expected_results: { offer: 'Growth Plan' },
  metrics: {
    qualification_accuracy: 1,
    handoff_accuracy: 1,
    unanswered_question_rate: 0,
    booking_outcomes: { booking_available: 1 },
    serious_safety_failures: 0,
  },
  grades: {},
  steps: [
    {
      index: 1,
      event_id: 'step-1',
      lead_message: 'How much does Growth Plan cost?',
      selected_answer: 'It starts at $99 per month.',
      message_type: 'text',
      sources: [{ title: 'Approved pricing' }],
      qualification: {
        quality: 'highly_qualified',
        score: 91,
        next_question: 'What type of business do you run?',
      },
      handoff_decision: 'handoff_required',
      booking_decision: 'booking_available',
      duplicate_ignored: false,
      checks: [
        { name: 'approved_answer_use', passed: true },
        { name: 'lead_quality', passed: true },
      ],
    },
  ],
};

const payload = {
  scenarios: [
    {
      key: 'successful_qualification',
      name: 'High-intent lead asks for pricing',
      description: 'Qualification and accurate pricing.',
      offer: 'Growth Plan',
      messages: [{ event_id: 'step-1', body: 'How much does it cost?' }],
    },
    {
      key: 'low_budget_lead',
      name: 'Lead gives a low budget',
      description: 'Qualification.',
      offer: 'Growth Plan',
      messages: [],
    },
  ],
  runs: [run],
  filter_options: {
    offers: ['Growth Plan'],
    owners: [{ id: 1, name: 'John Nkosi' }],
    results: ['passed', 'failed', 'needs_review', 'never_run'],
  },
  launch_gate: {
    ready_for_approval: false,
    live_ai_enabled: false,
    blocking_reasons: ['Missing passing reviews'],
    gate: {
      team_roleplay_completed: false,
      pilot_conversations_reviewed_count: 1,
      approval_notes: '',
      approved: false,
    },
    report: {
      qualification_accuracy: 1,
      handoff_accuracy: 1,
      unanswered_question_rate: 0,
      booking_outcomes: { booking_available: 1 },
      serious_safety_failures: 0,
      scenario_results: {
        successful_qualification: { reviewed: true, passed: false },
      },
    },
  },
};

const mountComponent = async () => {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      {
        path: '/app/accounts/:accountId/test-center',
        name: 'owned_test_center_index',
        component: EvaluationSandboxPanel,
      },
    ],
  });
  router.push('/app/accounts/1/test-center');
  await router.isReady();

  const wrapper = mount(EvaluationSandboxPanel, {
    attachTo: document.body,
    global: {
      plugins: [router],
      stubs: { Icon: IconStub },
    },
  });
  await flushPromises();
  return { wrapper, router };
};

describe('EvaluationSandboxPanel', () => {
  afterEach(() => {
    document.body.innerHTML = '';
  });

  beforeEach(() => {
    vi.clearAllMocks();
    EvaluationSandboxAPI.get.mockResolvedValue({ data: payload });
    EvaluationSandboxAPI.runs.mockResolvedValue({ data: [run] });
    EvaluationSandboxAPI.runScenario.mockResolvedValue({
      data: { ...run, id: 8, result: 'passed', passed: true },
    });
    EvaluationSandboxAPI.launchGate.mockResolvedValue({
      data: payload.launch_gate,
    });
    EvaluationSandboxAPI.gradeRun.mockResolvedValue({
      data: { ...run, passed: true, result: 'passed' },
    });
    EvaluationSandboxAPI.updateLaunchGate.mockResolvedValue({
      data: payload.launch_gate,
    });
    EvaluationSandboxAPI.proposeKnowledge.mockResolvedValue({
      data: {
        knowledge_item: {
          id: 9,
          status: 'draft',
        },
      },
    });
  });

  it('renders scenarios with filters and a simulation transcript', async () => {
    const { wrapper } = await mountComponent();

    expect(wrapper.text()).toContain('Test Center');
    expect(wrapper.find('input[aria-label="Search scenarios"]').exists()).toBe(
      true
    );
    expect(wrapper.find('select[aria-label="Offer filter"]').exists()).toBe(
      true
    );
    expect(wrapper.text()).toContain('High-intent lead asks for pricing');
    expect(wrapper.text()).toContain('1. High-intent lead asks for pricing');
    expect(wrapper.text()).toContain('Showing 2 of 2 scenarios');
    expect(wrapper.text()).toContain('Simulation transcript');
    expect(wrapper.text()).toContain('It starts at $99 per month.');
    expect(wrapper.text()).toContain(
      'Lead Quality: Highly Qualified - Score 91'
    );
    expect(wrapper.text()).toContain(
      'Next question: What type of business do you run?'
    );
    expect(wrapper.text()).toContain(
      'Handoff: Handoff Required - Booking: Booking Available'
    );
    expect(wrapper.text()).toContain('Sources: Approved pricing');
    expect(wrapper.text()).toContain('Needs Review 5 of 5 checks');
    expect(wrapper.text()).toContain('Tested:');
    expect(wrapper.text()).toContain('by John Nkosi');
    expect(wrapper.text()).not.toContain('Showing of scenarios');
    expect(wrapper.text()).not.toContain('of checks');
    expect(wrapper.text()).not.toContain('Tested: by');

    await wrapper.find('input[aria-label="Search scenarios"]').setValue('low');
    expect(wrapper.text()).toContain('Lead gives a low budget');
    expect(wrapper.findAll('tbody tr')).toHaveLength(1);
  });

  it('renders selected tabs with persistent state and the reference filter control', async () => {
    const { wrapper } = await mountComponent();

    const scenariosTab = wrapper.get(
      '[data-testid="test-center-tab-scenarios"]'
    );
    expect(scenariosTab.attributes('aria-selected')).toBe('true');
    expect(scenariosTab.classes()).toContain('border-n-brand');
    expect(scenariosTab.classes()).toContain('text-n-blue-text');
    expect(getComputedStyle(scenariosTab.element).color).toBe(
      'rgb(8, 109, 224)'
    );
    expect(getComputedStyle(scenariosTab.element).borderBottomWidth).toBe(
      '2px'
    );
    expect(getComputedStyle(scenariosTab.element).borderBottomStyle).toBe(
      'solid'
    );

    const moreFilters = wrapper.get('[data-testid="test-center-more-filters"]');
    expect(moreFilters.attributes('aria-label')).toBe('More filters');
    expect(moreFilters.attributes('data-icon')).toBe('i-lucide-list-filter');
    expect(
      moreFilters.find('[data-icon="i-lucide-list-filter"]').exists()
    ).toBe(true);
    expect(getComputedStyle(moreFilters.element).width).toBe('40px');
    expect(getComputedStyle(moreFilters.element).height).toBe('40px');

    await wrapper
      .get('[data-testid="test-center-tab-results"]')
      .trigger('click');
    await flushPromises();
    await nextTick();
    const resultsTab = wrapper.get('[data-testid="test-center-tab-results"]');
    expect(resultsTab.attributes('aria-selected')).toBe('true');
    expect(resultsTab.classes()).toContain('border-n-brand');
    expect(getComputedStyle(resultsTab.element).borderBottomWidth).toBe('2px');

    await wrapper
      .get('[data-testid="test-center-tab-release"]')
      .trigger('click');
    await flushPromises();
    await nextTick();
    const releaseTab = wrapper.get('[data-testid="test-center-tab-release"]');
    expect(releaseTab.attributes('aria-selected')).toBe('true');
    expect(releaseTab.classes()).toContain('border-n-brand');
    expect(getComputedStyle(releaseTab.element).borderBottomWidth).toBe('2px');
  });

  it('renders the transcript warning and transcript controls as icon buttons', async () => {
    const { wrapper } = await mountComponent();

    const warning = wrapper.get('[data-testid="test-center-warning-banner"]');
    expect(warning.classes()).toContain('border-n-amber-5');
    expect(warning.find('[data-icon="i-lucide-triangle-alert"]').exists()).toBe(
      true
    );

    expect(
      wrapper
        .get('[data-testid="test-center-panel-menu"]')
        .find('[data-icon="i-lucide-ellipsis-vertical"]')
        .exists()
    ).toBe(true);
    expect(
      wrapper
        .get('[data-testid="test-center-panel-menu"]')
        .attributes('data-icon')
    ).toBe('i-lucide-ellipsis-vertical');
    expect(
      wrapper
        .get('[data-testid="test-center-panel-collapse"]')
        .find('[data-icon="i-lucide-panel-right-close"]')
        .exists()
    ).toBe(true);
    expect(
      wrapper
        .get('[data-testid="test-center-panel-collapse"]')
        .attributes('data-icon')
    ).toBe('i-lucide-panel-right-close');

    const runAgain = wrapper.get('[data-testid="test-center-run-again"]');
    expect(runAgain.find('[data-icon="i-lucide-refresh-cw"]').exists()).toBe(
      true
    );
    expect(runAgain.classes()).toContain('border');

    const markWrong = wrapper.get('[data-testid="test-center-mark-wrong"]');
    expect(markWrong.find('[data-icon="i-lucide-flag"]').exists()).toBe(true);
    expect(markWrong.classes()).toContain('border');
  });

  it('runs a scenario and stores reviewer grades', async () => {
    const { wrapper } = await mountComponent();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Run test')
      .trigger('click');
    await flushPromises();

    expect(EvaluationSandboxAPI.runScenario).toHaveBeenCalledWith(
      'successful_qualification'
    );

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Results')
      .trigger('click');
    await flushPromises();
    await nextTick();

    expect(wrapper.text()).toContain('High-intent lead asks for pricing');
    expect(wrapper.text()).toContain('Tested');
    expect(wrapper.text()).toContain('by John Nkosi');
    expect(wrapper.text()).not.toContain('Tested  by');

    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(EvaluationSandboxAPI.gradeRun).toHaveBeenCalledWith(
      expect.any(Number),
      expect.objectContaining({
        approved_answer_use: expect.objectContaining({ passed: false }),
        safety: expect.objectContaining({ passed: false }),
      })
    );
  });

  it('proposes corrected knowledge as a draft from the transcript', async () => {
    const { wrapper } = await mountComponent();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Mark wrong')
      .trigger('click');
    await nextTick();
    await wrapper
      .find('textarea[aria-label="Corrected answer"]')
      .setValue('Corrected answer that needs approval.');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(EvaluationSandboxAPI.proposeKnowledge).toHaveBeenCalledWith(
      7,
      expect.objectContaining({
        answer: 'Corrected answer that needs approval.',
        source_kind: 'faq',
      })
    );
  });

  it('renders release check state and saves launch gate fields', async () => {
    const { wrapper } = await mountComponent();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Release check')
      .trigger('click');
    await flushPromises();
    await nextTick();

    expect(wrapper.text()).toContain('Qualification accuracy');
    expect(wrapper.text()).toContain('Live AI is locked');

    await wrapper.find('input[type="number"]').setValue(3);
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(EvaluationSandboxAPI.updateLaunchGate).toHaveBeenCalledWith(
      expect.objectContaining({
        pilot_conversations_reviewed_count: 3,
      })
    );
  });

  it('shows explicit evidence fallback values instead of blank transcript metadata', async () => {
    EvaluationSandboxAPI.get.mockResolvedValue({
      data: {
        ...payload,
        runs: [
          {
            ...run,
            steps: [
              {
                index: 1,
                event_id: 'missing-evidence',
                lead_message: 'Can you help?',
                selected_answer: 'Please share a few more details.',
                message_type: 'text',
                sources: [],
                qualification: {},
                checks: [],
              },
            ],
            total_checks: 0,
            passed_checks: 0,
          },
        ],
      },
    });

    const { wrapper } = await mountComponent();

    expect(wrapper.text()).toContain('Lead Quality: None - Score None');
    expect(wrapper.text()).toContain('Next question: None');
    expect(wrapper.text()).toContain('Handoff: None - Booking: None');
    expect(wrapper.text()).toContain('Sources: None');
    expect(wrapper.text()).toContain('Needs Review 0 of 0 checks');
  });
});

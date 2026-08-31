import { flushPromises, shallowMount } from '@vue/test-utils';
import EvaluationSandboxPanel from '../EvaluationSandboxPanel.vue';
import evaluationSandboxAPI from 'dashboard/api/evaluationSandbox';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('dashboard/api/evaluationSandbox', () => ({
  default: {
    get: vi.fn(),
    createRun: vi.fn(),
    gradeRun: vi.fn(),
    updateLaunchGate: vi.fn(),
    approveLaunch: vi.fn(),
  },
}));

const payload = {
  scenarios: [
    {
      key: 'approved_answer',
      name: 'Approved answer',
      description: 'Grounded answer',
      required: true,
    },
  ],
  runs: [
    {
      id: 7,
      scenario_name: 'Approved answer',
      total_checks: 2,
      passed_checks: 2,
      grades: {},
      steps: [
        {
          event_id: 'approved-answer-1',
          message_type: 'text',
          lead_message: 'Do you offer AI employees?',
          selected_answer: 'Yes.',
          source_references: [{ id: 1 }],
          qualification: { quality: 'low_qualified', score: 10 },
          handoff_decision: 'continue_ai',
          booking_decision: 'not_eligible',
          follow_up_decision: 'schedule_incomplete_qualification',
        },
      ],
    },
  ],
  launch_gate: {
    live_ai_enabled: false,
    gate: {
      team_roleplay_completed: false,
      pilot_conversations_reviewed_count: 0,
      approval_notes: '',
    },
    report: {
      reviewed_qualification_accuracy: 0.85,
      minimum_qualification_accuracy: 0.85,
      serious_issue_count: 0,
      scenario_results: {
        approved_answer: { reviewed: true, passed: false },
      },
    },
  },
};

describe('EvaluationSandboxPanel', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    evaluationSandboxAPI.get.mockResolvedValue({ data: payload });
    evaluationSandboxAPI.createRun.mockResolvedValue({ data: {} });
    evaluationSandboxAPI.gradeRun.mockResolvedValue({ data: {} });
    evaluationSandboxAPI.updateLaunchGate.mockResolvedValue({ data: {} });
    evaluationSandboxAPI.approveLaunch.mockResolvedValue({ data: {} });
  });

  it('renders launch metrics and the latest inspectable simulation step', async () => {
    const wrapper = shallowMount(EvaluationSandboxPanel);
    await flushPromises();

    expect(wrapper.text()).toContain('85%');
    expect(wrapper.text()).toContain('Approved answer');
    expect(wrapper.text()).toContain('Yes.');
    expect(wrapper.text()).toContain('Low Qualified');
    expect(wrapper.text()).toContain(
      'AI_LEAD_EMPLOYEE.TEST_CENTER.GRADE.SOURCE_QUALITY'
    );
  });

  it('runs and grades scenarios through the API', async () => {
    const wrapper = shallowMount(EvaluationSandboxPanel);
    await flushPromises();

    await wrapper
      .findAll('button')
      .find(button =>
        button.text().includes('AI_LEAD_EMPLOYEE.TEST_CENTER.RUN')
      )
      .trigger('click');
    await flushPromises();

    expect(evaluationSandboxAPI.createRun).toHaveBeenCalledWith({
      scenario_key: 'approved_answer',
    });

    await wrapper.find('form.mt-4').trigger('submit');
    expect(evaluationSandboxAPI.gradeRun).toHaveBeenCalledWith(
      7,
      expect.objectContaining({ grades: expect.any(Object) })
    );
  });
});

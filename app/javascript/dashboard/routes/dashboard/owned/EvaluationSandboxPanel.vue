<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'next/icon/Icon.vue';
import EvaluationSandboxAPI from 'dashboard/api/evaluationSandbox';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const labels = computed(() => ({
  ADMIN_APPROVAL: t('AI_LEAD_EMPLOYEE.TEST_CENTER.ADMIN_APPROVAL'),
  AI_EMPLOYEE: t('AI_LEAD_EMPLOYEE.TEST_CENTER.AI_EMPLOYEE'),
  ALL_RESULTS: t('AI_LEAD_EMPLOYEE.TEST_CENTER.ALL_RESULTS'),
  APPROVAL_NOTES: t('AI_LEAD_EMPLOYEE.TEST_CENTER.APPROVAL_NOTES'),
  APPROVED: t('AI_LEAD_EMPLOYEE.TEST_CENTER.APPROVED'),
  APPROVE_LAUNCH: t('AI_LEAD_EMPLOYEE.TEST_CENTER.APPROVE_LAUNCH'),
  BLOCKERS: t('AI_LEAD_EMPLOYEE.TEST_CENTER.BLOCKERS'),
  BOOKING_OUTCOMES: t('AI_LEAD_EMPLOYEE.TEST_CENTER.BOOKING_OUTCOMES'),
  CANCEL: t('AI_LEAD_EMPLOYEE.TEST_CENTER.CANCEL'),
  CHECK_COUNT: t('AI_LEAD_EMPLOYEE.TEST_CENTER.CHECK_COUNT'),
  CLEAR_FILTERS: t('AI_LEAD_EMPLOYEE.TEST_CENTER.CLEAR_FILTERS'),
  CONFIGURATION: t('AI_LEAD_EMPLOYEE.TEST_CENTER.CONFIGURATION'),
  CONFIGURATION_VERSION: t(
    'AI_LEAD_EMPLOYEE.TEST_CENTER.CONFIGURATION_VERSION'
  ),
  CONTROL_BLOCKED: t('AI_LEAD_EMPLOYEE.TEST_CENTER.CONTROL_BLOCKED'),
  CORRECTED_ANSWER: t('AI_LEAD_EMPLOYEE.TEST_CENTER.CORRECTED_ANSWER'),
  CORRECTED_QUESTION: t('AI_LEAD_EMPLOYEE.TEST_CENTER.CORRECTED_QUESTION'),
  CORRECTION_ERROR: t('AI_LEAD_EMPLOYEE.TEST_CENTER.CORRECTION_ERROR'),
  CORRECTION_HELP: t('AI_LEAD_EMPLOYEE.TEST_CENTER.CORRECTION_HELP'),
  CORRECTION_PROPOSAL: t('AI_LEAD_EMPLOYEE.TEST_CENTER.CORRECTION_PROPOSAL'),
  CORRECTION_PROPOSED: t('AI_LEAD_EMPLOYEE.TEST_CENTER.CORRECTION_PROPOSED'),
  CORRECTION_TITLE: t('AI_LEAD_EMPLOYEE.TEST_CENTER.CORRECTION_TITLE'),
  CORRECTION_TITLE_LABEL: t(
    'AI_LEAD_EMPLOYEE.TEST_CENTER.CORRECTION_TITLE_LABEL'
  ),
  CORRECT_ANSWER: t('AI_LEAD_EMPLOYEE.TEST_CENTER.CORRECT_ANSWER'),
  DEFAULT_CHECKS: t('AI_LEAD_EMPLOYEE.TEST_CENTER.DEFAULT_CHECKS'),
  DEFAULT_OFFER: t('AI_LEAD_EMPLOYEE.TEST_CENTER.DEFAULT_OFFER'),
  DUPLICATE_IGNORED: t('AI_LEAD_EMPLOYEE.TEST_CENTER.DUPLICATE_IGNORED'),
  EMPTY_VALUE: t('AI_LEAD_EMPLOYEE.TEST_CENTER.EMPTY_VALUE'),
  ENABLED: t('AI_LEAD_EMPLOYEE.TEST_CENTER.ENABLED'),
  EVALUATION_CRITERIA: t('AI_LEAD_EMPLOYEE.TEST_CENTER.EVALUATION_CRITERIA'),
  FAILED: t('AI_LEAD_EMPLOYEE.TEST_CENTER.FAILED'),
  FAILED_REVIEW: t('AI_LEAD_EMPLOYEE.TEST_CENTER.FAILED_REVIEW'),
  FROM_DATE: t('AI_LEAD_EMPLOYEE.TEST_CENTER.FROM_DATE'),
  GATE_SAVED: t('AI_LEAD_EMPLOYEE.TEST_CENTER.GATE_SAVED'),
  GRADE_ERROR: t('AI_LEAD_EMPLOYEE.TEST_CENTER.GRADE_ERROR'),
  GRADE_FAILED: t('AI_LEAD_EMPLOYEE.TEST_CENTER.GRADE_FAILED'),
  GRADE_NOTES: t('AI_LEAD_EMPLOYEE.TEST_CENTER.GRADE_NOTES'),
  GRADE_NOTES_LABEL: t('AI_LEAD_EMPLOYEE.TEST_CENTER.GRADE_NOTES_LABEL'),
  GRADE_PASSED: t('AI_LEAD_EMPLOYEE.TEST_CENTER.GRADE_PASSED'),
  HANDOFF_ACCURACY: t('AI_LEAD_EMPLOYEE.TEST_CENTER.HANDOFF_ACCURACY'),
  HANDOFF_BOOKING_VALUE: t(
    'AI_LEAD_EMPLOYEE.TEST_CENTER.HANDOFF_BOOKING_VALUE'
  ),
  HIDE_EVIDENCE: t('AI_LEAD_EMPLOYEE.TEST_CENTER.HIDE_EVIDENCE'),
  HIDE_SETUP: t('AI_LEAD_EMPLOYEE.TEST_CENTER.HIDE_SETUP'),
  HISTORICAL_RESULT_FILTER: t(
    'AI_LEAD_EMPLOYEE.TEST_CENTER.HISTORICAL_RESULT_FILTER'
  ),
  KNOWLEDGE: t('AI_LEAD_EMPLOYEE.TEST_CENTER.KNOWLEDGE'),
  KNOWLEDGE_VERSION: t('AI_LEAD_EMPLOYEE.TEST_CENTER.KNOWLEDGE_VERSION'),
  LAST_RESULT: t('AI_LEAD_EMPLOYEE.TEST_CENTER.LAST_RESULT'),
  LAST_TESTED: t('AI_LEAD_EMPLOYEE.TEST_CENTER.LAST_TESTED'),
  LAUNCH_APPROVED: t('AI_LEAD_EMPLOYEE.TEST_CENTER.LAUNCH_APPROVED'),
  LAUNCH_BLOCKED: t('AI_LEAD_EMPLOYEE.TEST_CENTER.LAUNCH_BLOCKED'),
  LIVE_AI_STATE: t('AI_LEAD_EMPLOYEE.TEST_CENTER.LIVE_AI_STATE'),
  LOADING: t('AI_LEAD_EMPLOYEE.TEST_CENTER.LOADING'),
  LOAD_ERROR: t('AI_LEAD_EMPLOYEE.TEST_CENTER.LOAD_ERROR'),
  LOCKED: t('AI_LEAD_EMPLOYEE.TEST_CENTER.LOCKED'),
  COLLAPSE_PANEL: t('AI_LEAD_EMPLOYEE.TEST_CENTER.COLLAPSE_PANEL'),
  EXPAND_PANEL: t('AI_LEAD_EMPLOYEE.TEST_CENTER.EXPAND_PANEL'),
  MARKED_WRONG_NOTE: t('AI_LEAD_EMPLOYEE.TEST_CENTER.MARKED_WRONG_NOTE'),
  MARK_WRONG: t('AI_LEAD_EMPLOYEE.TEST_CENTER.MARK_WRONG'),
  MEDIA_STEP: t('AI_LEAD_EMPLOYEE.TEST_CENTER.MEDIA_STEP'),
  MODEL: t('AI_LEAD_EMPLOYEE.TEST_CENTER.MODEL'),
  MORE_FILTERS: t('AI_LEAD_EMPLOYEE.TEST_CENTER.MORE_FILTERS'),
  NEEDS_REVIEW: t('AI_LEAD_EMPLOYEE.TEST_CENTER.NEEDS_REVIEW'),
  NEXT_QUESTION_VALUE: t('AI_LEAD_EMPLOYEE.TEST_CENTER.NEXT_QUESTION_VALUE'),
  NONE: t('AI_LEAD_EMPLOYEE.TEST_CENTER.NONE'),
  NOT_ENOUGH_DATA: t('AI_LEAD_EMPLOYEE.TEST_CENTER.NOT_ENOUGH_DATA'),
  NOT_RUN: t('AI_LEAD_EMPLOYEE.TEST_CENTER.NOT_RUN'),
  NO_RESULTS: t('AI_LEAD_EMPLOYEE.TEST_CENTER.NO_RESULTS'),
  NO_SCENARIOS: t('AI_LEAD_EMPLOYEE.TEST_CENTER.NO_SCENARIOS'),
  OFFER: t('AI_LEAD_EMPLOYEE.TEST_CENTER.OFFER'),
  OFFER_FILTER: t('AI_LEAD_EMPLOYEE.TEST_CENTER.OFFER_FILTER'),
  OPEN_TRANSCRIPT: t('AI_LEAD_EMPLOYEE.TEST_CENTER.OPEN_TRANSCRIPT'),
  OWNER: t('AI_LEAD_EMPLOYEE.TEST_CENTER.OWNER'),
  OWNER_FILTER: t('AI_LEAD_EMPLOYEE.TEST_CENTER.OWNER_FILTER'),
  PANEL_MENU: t('AI_LEAD_EMPLOYEE.TEST_CENTER.PANEL_MENU'),
  PASSED: t('AI_LEAD_EMPLOYEE.TEST_CENTER.PASSED'),
  PASSED_REVIEW: t('AI_LEAD_EMPLOYEE.TEST_CENTER.PASSED_REVIEW'),
  PILOT_REVIEWS: t('AI_LEAD_EMPLOYEE.TEST_CENTER.PILOT_REVIEWS'),
  PROPOSE_TO_KNOWLEDGE: t('AI_LEAD_EMPLOYEE.TEST_CENTER.PROPOSE_TO_KNOWLEDGE'),
  QUALIFICATION_ACCURACY: t(
    'AI_LEAD_EMPLOYEE.TEST_CENTER.QUALIFICATION_ACCURACY'
  ),
  QUALITY_SCORE: t('AI_LEAD_EMPLOYEE.TEST_CENTER.QUALITY_SCORE'),
  QUESTION: t('AI_LEAD_EMPLOYEE.TEST_CENTER.QUESTION'),
  RELEASE_CHECK: t('AI_LEAD_EMPLOYEE.TEST_CENTER.RELEASE_CHECK'),
  REQUIRED_SCENARIOS: t('AI_LEAD_EMPLOYEE.TEST_CENTER.REQUIRED_SCENARIOS'),
  RESULT: t('AI_LEAD_EMPLOYEE.TEST_CENTER.RESULT'),
  RESULTS_LOAD_ERROR: t('AI_LEAD_EMPLOYEE.TEST_CENTER.RESULTS_LOAD_ERROR'),
  RESULT_FILTER: t('AI_LEAD_EMPLOYEE.TEST_CENTER.RESULT_FILTER'),
  REVIEWER_GRADING_HELP: t(
    'AI_LEAD_EMPLOYEE.TEST_CENTER.REVIEWER_GRADING_HELP'
  ),
  REVIEW_PATH: t('AI_LEAD_EMPLOYEE.TEST_CENTER.REVIEW_PATH'),
  RUNNING: t('AI_LEAD_EMPLOYEE.TEST_CENTER.RUNNING'),
  RUN_AGAIN: t('AI_LEAD_EMPLOYEE.TEST_CENTER.RUN_AGAIN'),
  RUN_ERROR: t('AI_LEAD_EMPLOYEE.TEST_CENTER.RUN_ERROR'),
  RUN_FAILED: t('AI_LEAD_EMPLOYEE.TEST_CENTER.RUN_FAILED'),
  RUN_META: t('AI_LEAD_EMPLOYEE.TEST_CENTER.RUN_META'),
  RUN_PASSED: t('AI_LEAD_EMPLOYEE.TEST_CENTER.RUN_PASSED'),
  RUN_TEST: t('AI_LEAD_EMPLOYEE.TEST_CENTER.RUN_TEST'),
  RUN_TO_SEE_TRANSCRIPT: t(
    'AI_LEAD_EMPLOYEE.TEST_CENTER.RUN_TO_SEE_TRANSCRIPT'
  ),
  SAFETY_FAILURES: t('AI_LEAD_EMPLOYEE.TEST_CENTER.SAFETY_FAILURES'),
  SAVE_CHECK: t('AI_LEAD_EMPLOYEE.TEST_CENTER.SAVE_CHECK'),
  SAVE_GRADES: t('AI_LEAD_EMPLOYEE.TEST_CENTER.SAVE_GRADES'),
  SCENARIO: t('AI_LEAD_EMPLOYEE.TEST_CENTER.SCENARIO'),
  SCENARIO_COUNT: t('AI_LEAD_EMPLOYEE.TEST_CENTER.SCENARIO_COUNT'),
  SCENARIO_ROW: t('AI_LEAD_EMPLOYEE.TEST_CENTER.SCENARIO_ROW'),
  SEARCH: t('AI_LEAD_EMPLOYEE.TEST_CENTER.SEARCH'),
  SEARCH_PLACEHOLDER: t('AI_LEAD_EMPLOYEE.TEST_CENTER.SEARCH_PLACEHOLDER'),
  SELECT_SCENARIO: t('AI_LEAD_EMPLOYEE.TEST_CENTER.SELECT_SCENARIO'),
  SHOW_EVIDENCE: t('AI_LEAD_EMPLOYEE.TEST_CENTER.SHOW_EVIDENCE'),
  SHOW_SETUP: t('AI_LEAD_EMPLOYEE.TEST_CENTER.SHOW_SETUP'),
  SIMULATED_DELIVERED: t('AI_LEAD_EMPLOYEE.TEST_CENTER.SIMULATED_DELIVERED'),
  SIMULATED_MESSAGE_COUNT: t(
    'AI_LEAD_EMPLOYEE.TEST_CENTER.SIMULATED_MESSAGE_COUNT'
  ),
  SIMULATION: t('AI_LEAD_EMPLOYEE.TEST_CENTER.SIMULATION'),
  SIMULATION_TRANSCRIPT_NOTICE: t(
    'AI_LEAD_EMPLOYEE.TEST_CENTER.SIMULATION_TRANSCRIPT_NOTICE'
  ),
  SIMULATION_WARNING: t('AI_LEAD_EMPLOYEE.TEST_CENTER.SIMULATION_WARNING'),
  SOURCES_VALUE: t('AI_LEAD_EMPLOYEE.TEST_CENTER.SOURCES_VALUE'),
  STARTING_CHANNEL: t('AI_LEAD_EMPLOYEE.TEST_CENTER.STARTING_CHANNEL'),
  STEP_EVIDENCE: t('AI_LEAD_EMPLOYEE.TEST_CENTER.STEP_EVIDENCE'),
  SUBTITLE: t('AI_LEAD_EMPLOYEE.TEST_CENTER.SUBTITLE'),
  TAB_LABEL: t('AI_LEAD_EMPLOYEE.TEST_CENTER.TAB_LABEL'),
  TABS_RELEASE: t('AI_LEAD_EMPLOYEE.TEST_CENTER.TABS.RELEASE'),
  TABS_RESULTS: t('AI_LEAD_EMPLOYEE.TEST_CENTER.TABS.RESULTS'),
  TABS_SCENARIOS: t('AI_LEAD_EMPLOYEE.TEST_CENTER.TABS.SCENARIOS'),
  TEAM_ROLEPLAY: t('AI_LEAD_EMPLOYEE.TEST_CENTER.TEAM_ROLEPLAY'),
  TESTED_BY: t('AI_LEAD_EMPLOYEE.TEST_CENTER.TESTED_BY'),
  TEST_LEAD: t('AI_LEAD_EMPLOYEE.TEST_CENTER.TEST_LEAD'),
  TEST_SUMMARY: t('AI_LEAD_EMPLOYEE.TEST_CENTER.TEST_SUMMARY'),
  TITLE: t('AI_LEAD_EMPLOYEE.TEST_CENTER.TITLE'),
  TITLE_FIELD: t('AI_LEAD_EMPLOYEE.TEST_CENTER.TITLE_FIELD'),
  TO_DATE: t('AI_LEAD_EMPLOYEE.TEST_CENTER.TO_DATE'),
  TRANSCRIPT: t('AI_LEAD_EMPLOYEE.TEST_CENTER.TRANSCRIPT'),
  TRANSCRIPT_COLLAPSED: t('AI_LEAD_EMPLOYEE.TEST_CENTER.TRANSCRIPT_COLLAPSED'),
  UNANSWERED_RATE: t('AI_LEAD_EMPLOYEE.TEST_CENTER.UNANSWERED_RATE'),
  UNASSIGNED: t('AI_LEAD_EMPLOYEE.TEST_CENTER.UNASSIGNED'),
  WAITING: t('AI_LEAD_EMPLOYEE.TEST_CENTER.WAITING'),
  WHATSAPP_SIMULATION: t('AI_LEAD_EMPLOYEE.TEST_CENTER.WHATSAPP_SIMULATION'),
  WHAT_IT_CHECKS: t('AI_LEAD_EMPLOYEE.TEST_CENTER.WHAT_IT_CHECKS'),
}));
const labelKey = key => key.replace(/\./g, '_');
const label = key => labels.value[labelKey(key)] || key;
const translate = (key, params = {}) => {
  switch (key) {
    case 'CHECK_COUNT':
      return t('AI_LEAD_EMPLOYEE.TEST_CENTER.CHECK_COUNT', params);
    case 'CORRECTION_TITLE':
      return t('AI_LEAD_EMPLOYEE.TEST_CENTER.CORRECTION_TITLE', params);
    case 'GRADE_NOTES_LABEL':
      return t('AI_LEAD_EMPLOYEE.TEST_CENTER.GRADE_NOTES_LABEL', params);
    case 'HANDOFF_BOOKING_VALUE':
      return t('AI_LEAD_EMPLOYEE.TEST_CENTER.HANDOFF_BOOKING_VALUE', params);
    case 'LIVE_AI_STATE':
      return t('AI_LEAD_EMPLOYEE.TEST_CENTER.LIVE_AI_STATE', params);
    case 'NEXT_QUESTION_VALUE':
      return t('AI_LEAD_EMPLOYEE.TEST_CENTER.NEXT_QUESTION_VALUE', params);
    case 'QUALITY_SCORE':
      return t('AI_LEAD_EMPLOYEE.TEST_CENTER.QUALITY_SCORE', params);
    case 'RUN_META':
      return t('AI_LEAD_EMPLOYEE.TEST_CENTER.RUN_META', params);
    case 'SCENARIO_COUNT':
      return t('AI_LEAD_EMPLOYEE.TEST_CENTER.SCENARIO_COUNT', params);
    case 'SCENARIO_ROW':
      return t('AI_LEAD_EMPLOYEE.TEST_CENTER.SCENARIO_ROW', params);
    case 'SIMULATED_MESSAGE_COUNT':
      return t('AI_LEAD_EMPLOYEE.TEST_CENTER.SIMULATED_MESSAGE_COUNT', params);
    case 'SOURCES_VALUE':
      return t('AI_LEAD_EMPLOYEE.TEST_CENTER.SOURCES_VALUE', params);
    case 'STEP_EVIDENCE':
      return t('AI_LEAD_EMPLOYEE.TEST_CENTER.STEP_EVIDENCE', params);
    case 'TESTED_BY':
      return t('AI_LEAD_EMPLOYEE.TEST_CENTER.TESTED_BY', params);
    default:
      return key;
  }
};

const tabs = computed(() => [
  { key: 'scenarios', label: label('TABS.SCENARIOS') },
  { key: 'results', label: label('TABS.RESULTS') },
  { key: 'release', label: label('TABS.RELEASE') },
]);
const activeTabStyle = isActive =>
  isActive
    ? {
        color: 'rgb(8, 109, 224)',
        borderBottomColor: 'rgb(39, 129, 246)',
        borderBottomStyle: 'solid',
        borderBottomWidth: '2px',
      }
    : {};
const squareFilterControlStyle = {
  width: '40px',
  height: '40px',
};
const gradeKeys = [
  'approved_answer_use',
  'qualification_question_behavior',
  'invention_avoidance',
  'next_step',
  'lead_quality',
  'booking_eligibility',
  'handoff_eligibility',
  'tone',
  'safety',
];
const defaultResults = [
  'passed',
  'failed',
  'needs_review',
  'never_run',
  'running',
  'cancelled',
  'stale_configuration',
  'failed_model_call',
];

const activeTab = ref(route.query.tab?.toString() || 'scenarios');
const scenarios = ref([]);
const runs = ref([]);
const launchGate = ref({});
const filterOptions = ref({ results: defaultResults });
const selectedScenarioKey = ref(route.query.scenario_key?.toString() || '');
const selectedRunId = ref(route.query.run_id?.toString() || '');
const isLoading = ref(false);
const isRunning = ref(false);
const isSaving = ref(false);
const errorMessage = ref('');
const showMoreFilters = ref(false);
const showCorrection = ref(false);
const showEvidence = ref(true);
const showTranscriptMeta = ref(true);
const showPanelMenu = ref(false);
const isTranscriptCollapsed = ref(false);

const filters = reactive({
  search: route.query.search?.toString() || '',
  offer: route.query.offer?.toString() || '',
  result: route.query.result?.toString() || '',
  owner_id: route.query.owner_id?.toString() || '',
  configuration_version: route.query.configuration_version?.toString() || '',
  knowledge_version: route.query.knowledge_version?.toString() || '',
  from: route.query.from?.toString() || '',
  to: route.query.to?.toString() || '',
});
const launchDraft = reactive({
  team_roleplay_completed: false,
  pilot_conversations_reviewed_count: 0,
  approval_notes: '',
});
const grades = reactive(
  Object.fromEntries(gradeKeys.map(key => [key, { passed: false, notes: '' }]))
);
const correction = reactive({
  step_index: 1,
  title: '',
  question: '',
  answer: '',
  source_kind: 'faq',
});

const cleanQuery = query =>
  Object.fromEntries(
    Object.entries(query).filter(
      ([, value]) => value !== '' && value !== null && value !== undefined
    )
  );

const replaceQuery = partial => {
  router.replace({
    name: route.name,
    params: route.params,
    query: cleanQuery({ ...route.query, ...partial }),
  });
};

const humanize = value =>
  value
    ? value
        .toString()
        .replace(/_/g, ' ')
        .replace(/\b\w/g, letter => letter.toUpperCase())
    : label('EMPTY_VALUE');

const explicitValue = value => (value ? humanize(value) : label('NONE'));

const formatDateTime = value => {
  if (!value) return label('NOT_RUN');
  return new Date(value).toLocaleString(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  });
};

const formatMetric = value => {
  if (value === null || value === undefined) return label('NOT_ENOUGH_DATA');
  return typeof value === 'number' && value <= 1
    ? `${Math.round(value * 100)}%`
    : value;
};

const statusClass = result =>
  ({
    passed: 'bg-n-teal-3 text-n-teal-11',
    needs_review: 'bg-n-amber-3 text-n-amber-11',
    failed: 'bg-n-ruby-3 text-n-ruby-11',
    running: 'bg-n-blue-3 text-n-blue-11',
    cancelled: 'bg-n-slate-3 text-n-slate-11',
    stale_configuration: 'bg-n-amber-3 text-n-amber-11',
    failed_model_call: 'bg-n-ruby-3 text-n-ruby-11',
    never_run: 'bg-n-slate-3 text-n-slate-11',
  })[result] || 'bg-n-slate-3 text-n-slate-11';

const selectedScenario = computed(() =>
  scenarios.value.find(scenario => scenario.key === selectedScenarioKey.value)
);
const selectedRun = computed(
  () =>
    runs.value.find(run => run.id?.toString() === selectedRunId.value) ||
    runs.value[0] ||
    null
);
const latestRunByScenario = computed(() =>
  runs.value.reduce((memo, run) => {
    if (!memo[run.scenario_key]) memo[run.scenario_key] = run;
    return memo;
  }, {})
);
const scenarioRows = computed(() => {
  const query = filters.search.trim().toLowerCase();
  return scenarios.value
    .map((scenario, index) => {
      const latestRun = latestRunByScenario.value[scenario.key];
      return {
        ...scenario,
        index: index + 1,
        latestRun,
        result: latestRun?.result || 'never_run',
        owner: latestRun?.tester || label('UNASSIGNED'),
        offer: scenario.offer || label('DEFAULT_OFFER'),
        checks:
          scenario.what_checks ||
          scenario.description?.split('.').at(0) ||
          label('DEFAULT_CHECKS'),
      };
    })
    .filter(
      row =>
        !query ||
        [row.name, row.checks, row.owner]
          .join(' ')
          .toLowerCase()
          .includes(query)
    )
    .filter(row => !filters.offer || row.offer === filters.offer)
    .filter(row => !filters.result || row.result === filters.result)
    .filter(
      row =>
        !filters.owner_id ||
        row.latestRun?.user_id?.toString() === filters.owner_id
    );
});
const report = computed(() => launchGate.value.report || {});
const gate = computed(() => launchGate.value.gate || {});
const blockingReasons = computed(() => launchGate.value.blocking_reasons || []);
const canApproveLaunch = computed(
  () => launchGate.value.ready_for_approval && !launchGate.value.live_ai_enabled
);
const selectedSteps = computed(() => selectedRun.value?.steps || []);
const selectedChecks = computed(() =>
  selectedSteps.value.flatMap(step =>
    (step.checks || []).map(check => ({
      ...check,
      stepIndex: step.index,
    }))
  )
);
const summaryChecks = computed(() => {
  const checks = selectedChecks.value;
  if (checks.length) return checks;
  return gradeKeys.map(key => ({
    name: key,
    passed: Boolean(selectedRun.value?.grades?.[key]?.passed),
    actual: selectedRun.value?.grades?.[key]?.notes || '',
  }));
});
const selectedMessageCount = computed(
  () => selectedSteps.value.filter(step => !step.duplicate_ignored).length * 2
);
const releaseMetrics = computed(() => [
  [label('QUALIFICATION_ACCURACY'), report.value.qualification_accuracy],
  [label('HANDOFF_ACCURACY'), report.value.handoff_accuracy],
  [label('UNANSWERED_RATE'), report.value.unanswered_question_rate],
  [
    label('BOOKING_OUTCOMES'),
    Object.values(report.value.booking_outcomes || {}).reduce(
      (sum, value) => sum + value,
      0
    ),
  ],
  [label('SAFETY_FAILURES'), report.value.serious_safety_failures || 0],
  [
    label('ADMIN_APPROVAL'),
    gate.value.approved ? label('APPROVED') : label('WAITING'),
  ],
]);

const requestParams = () =>
  cleanQuery({
    scenario_key: route.query.scenario_key,
    owner_id: filters.owner_id,
    result: activeTab.value === 'results' ? filters.result : '',
    offer: filters.offer,
    configuration_version: filters.configuration_version,
    knowledge_version: filters.knowledge_version,
    from: filters.from,
    to: filters.to,
  });

const hydrateFromRoute = () => {
  activeTab.value = route.query.tab?.toString() || 'scenarios';
  selectedScenarioKey.value =
    route.query.scenario_key?.toString() || selectedScenarioKey.value;
  selectedRunId.value = route.query.run_id?.toString() || selectedRunId.value;
  Object.assign(filters, {
    search: route.query.search?.toString() || '',
    offer: route.query.offer?.toString() || '',
    result: route.query.result?.toString() || '',
    owner_id: route.query.owner_id?.toString() || '',
    configuration_version: route.query.configuration_version?.toString() || '',
    knowledge_version: route.query.knowledge_version?.toString() || '',
    from: route.query.from?.toString() || '',
    to: route.query.to?.toString() || '',
  });
};

const syncLaunchDraft = () => {
  launchDraft.team_roleplay_completed = Boolean(
    gate.value.team_roleplay_completed
  );
  launchDraft.pilot_conversations_reviewed_count =
    gate.value.pilot_conversations_reviewed_count || 0;
  launchDraft.approval_notes = gate.value.approval_notes || '';
};

const syncGrades = run => {
  gradeKeys.forEach(key => {
    grades[key].passed = Boolean(run?.grades?.[key]?.passed);
    grades[key].notes = run?.grades?.[key]?.notes || '';
  });
};

const syncCorrection = step => {
  correction.step_index = step?.index || 1;
  correction.title = translate('CORRECTION_TITLE', {
    scenario: selectedRun.value?.scenario_name || label('SIMULATION'),
  });
  correction.question = step?.lead_message || '';
  correction.answer = step?.selected_answer || '';
  correction.source_kind = step?.refusal_reason ? 'policy' : 'faq';
};

const loadSandbox = async () => {
  isLoading.value = true;
  errorMessage.value = '';
  try {
    const { data } = await EvaluationSandboxAPI.get();
    scenarios.value = data.scenarios || [];
    runs.value = data.runs || [];
    launchGate.value = data.launch_gate || {};
    filterOptions.value = data.filter_options || filterOptions.value;
    selectedScenarioKey.value ||= scenarios.value[0]?.key || '';
    selectedRunId.value ||= runs.value[0]?.id?.toString() || '';
    syncLaunchDraft();
    syncGrades(selectedRun.value);
  } catch (error) {
    errorMessage.value = error.response?.data?.error || label('LOAD_ERROR');
  } finally {
    isLoading.value = false;
  }
};

const loadRuns = async () => {
  isLoading.value = true;
  errorMessage.value = '';
  try {
    const { data } = await EvaluationSandboxAPI.runs(requestParams());
    runs.value = data || [];
    selectedRunId.value = runs.value[0]?.id?.toString() || '';
    syncGrades(selectedRun.value);
  } catch (error) {
    errorMessage.value =
      error.response?.data?.error || label('RESULTS_LOAD_ERROR');
  } finally {
    isLoading.value = false;
  }
};

const refreshGate = async () => {
  const { data } = await EvaluationSandboxAPI.launchGate();
  launchGate.value = data;
  syncLaunchDraft();
};

const selectScenario = scenario => {
  selectedScenarioKey.value = scenario.key;
  selectedRunId.value =
    scenario.latestRun?.id?.toString() || selectedRunId.value;
  syncGrades(selectedRun.value);
  replaceQuery({
    tab: 'scenarios',
    scenario_key: scenario.key,
    run_id: scenario.latestRun?.id || '',
  });
};

const selectRun = run => {
  selectedRunId.value = run.id.toString();
  selectedScenarioKey.value = run.scenario_key;
  syncGrades(run);
  replaceQuery({
    tab: 'results',
    run_id: run.id,
    scenario_key: run.scenario_key,
  });
};

const setTab = tab => {
  activeTab.value = tab;
  replaceQuery({ tab });
};

const applyFilter = partial => {
  replaceQuery(partial);
};

const clearFilters = () => {
  replaceQuery({
    search: '',
    offer: '',
    result: '',
    owner_id: '',
    configuration_version: '',
    knowledge_version: '',
    from: '',
    to: '',
  });
};

const replaceRun = run => {
  runs.value = [run, ...runs.value.filter(item => item.id !== run.id)];
  selectedRunId.value = run.id.toString();
  selectedScenarioKey.value = run.scenario_key;
  syncGrades(run);
};

const runScenario = async scenarioKey => {
  const key = scenarioKey || selectedScenarioKey.value;
  if (!key) return;

  isRunning.value = true;
  errorMessage.value = '';
  try {
    const { data } = await EvaluationSandboxAPI.runScenario(key);
    replaceRun(data);
    activeTab.value = 'results';
    replaceQuery({ tab: 'results', scenario_key: key, run_id: data.id });
    await refreshGate();
    useAlert(data.automated_passed ? label('RUN_PASSED') : label('RUN_FAILED'));
  } catch (error) {
    errorMessage.value = error.response?.data?.error || label('RUN_ERROR');
  } finally {
    isRunning.value = false;
  }
};

const saveGrades = async () => {
  if (!selectedRun.value) return;

  isSaving.value = true;
  try {
    const { data } = await EvaluationSandboxAPI.gradeRun(
      selectedRun.value.id,
      grades
    );
    replaceRun(data);
    await refreshGate();
    useAlert(data.passed ? label('GRADE_PASSED') : label('GRADE_FAILED'));
  } catch (error) {
    errorMessage.value = error.response?.data?.error || label('GRADE_ERROR');
  } finally {
    isSaving.value = false;
  }
};

const saveLaunchGate = async () => {
  isSaving.value = true;
  try {
    const { data } = await EvaluationSandboxAPI.updateLaunchGate(launchDraft);
    launchGate.value = data;
    useAlert(label('GATE_SAVED'));
  } finally {
    isSaving.value = false;
  }
};

const approveLaunch = async () => {
  isSaving.value = true;
  try {
    const { data } = await EvaluationSandboxAPI.approveLaunch(
      launchDraft.approval_notes
    );
    launchGate.value = data;
    useAlert(label('LAUNCH_APPROVED'));
  } catch (error) {
    launchGate.value = error.response?.data?.launch_gate || launchGate.value;
    errorMessage.value = error.response?.data?.error || label('LAUNCH_BLOCKED');
  } finally {
    isSaving.value = false;
  }
};

const markStepWrong = step => {
  gradeKeys.forEach(key => {
    grades[key].passed = key !== 'safety';
  });
  grades.approved_answer_use.passed = false;
  grades.approved_answer_use.notes = label('MARKED_WRONG_NOTE');
  syncCorrection(step);
  showCorrection.value = true;
};

const proposeKnowledge = async () => {
  if (!selectedRun.value) return;

  isSaving.value = true;
  try {
    await EvaluationSandboxAPI.proposeKnowledge(
      selectedRun.value.id,
      correction
    );
    showCorrection.value = false;
    useAlert(label('CORRECTION_PROPOSED'));
  } catch (error) {
    errorMessage.value =
      error.response?.data?.error || label('CORRECTION_ERROR');
  } finally {
    isSaving.value = false;
  }
};

watch(
  () => route.query,
  () => {
    hydrateFromRoute();
    if (activeTab.value === 'results') loadRuns();
  }
);

onMounted(loadSandbox);

const systemStepText = step => {
  if (step.duplicate_ignored) return label('DUPLICATE_IGNORED');
  if (step.blocked_by_control_state) return label('CONTROL_BLOCKED');
  return label('REVIEW_PATH').replace(
    '{reason}',
    humanize(step.review_request_reason || step.refusal_reason)
  );
};

const gradeNotesLabel = key =>
  translate('GRADE_NOTES_LABEL', { grade: humanize(key) });

const reviewScenarioStatus = result => {
  if (result.passed) return label('PASSED_REVIEW');
  return result.reviewed ? label('FAILED_REVIEW') : label('NEEDS_REVIEW');
};

const scenarioRowLabel = row =>
  translate('SCENARIO_ROW', {
    index: row.index,
    name:
      row.name || row.scenario_name || row.title || label('SELECT_SCENARIO'),
  });

const sourcesLabel = sources =>
  translate('SOURCES_VALUE', {
    sources:
      sources
        ?.map(source => source.title || source.question || source.source_kind)
        .filter(Boolean)
        .join(', ') || label('NONE'),
  });

const checkCountLabel = run =>
  translate('CHECK_COUNT', {
    result: humanize(run.result),
    passed: run.passed_checks ?? 0,
    total: run.total_checks ?? 0,
  });

const scenarioCountLabel = () =>
  translate('SCENARIO_COUNT', {
    shown: scenarioRows.value.length,
    total: scenarios.value.length,
  });

const stepEvidenceLabel = step =>
  translate('STEP_EVIDENCE', { id: step.index || label('NONE') });

const qualityScoreLabel = step =>
  translate('QUALITY_SCORE', {
    quality: explicitValue(step.qualification?.quality),
    score: step.qualification?.score ?? label('NONE'),
  });

const nextQuestionLabel = step =>
  translate('NEXT_QUESTION_VALUE', {
    question: step.qualification?.next_question || label('NONE'),
  });

const handoffBookingLabel = step =>
  translate('HANDOFF_BOOKING_VALUE', {
    handoff: explicitValue(step.handoff_decision),
    booking: explicitValue(step.booking_decision),
  });

const testedByLabel = run =>
  translate('TESTED_BY', {
    time: formatDateTime(run.completed_at || run.created_at),
    tester: run.tester || label('UNASSIGNED'),
  });

const runMetaLabel = run =>
  translate('RUN_META', {
    time: formatDateTime(run.completed_at || run.created_at),
    tester: run.tester || label('UNASSIGNED'),
  });

const simulatedMessageCountLabel = () =>
  translate('SIMULATED_MESSAGE_COUNT', { count: selectedMessageCount.value });

const liveAiStateLabel = () =>
  translate('LIVE_AI_STATE', {
    state: launchGate.value.live_ai_enabled
      ? label('ENABLED')
      : label('LOCKED'),
  });
</script>

<template>
  <section class="min-h-[calc(100vh-48px)] bg-n-background">
    <header
      class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between"
    >
      <div class="min-w-0">
        <h1 class="text-2xl font-semibold text-n-slate-12">
          {{ label('TITLE') }}
        </h1>
        <p class="mt-1 text-sm text-n-slate-11">
          {{ label('SUBTITLE') }}
        </p>
      </div>
      <button
        type="button"
        class="inline-flex w-full items-center justify-center gap-2 rounded-md bg-n-brand px-4 py-2.5 text-sm font-medium text-white shadow-sm disabled:cursor-not-allowed disabled:opacity-60 sm:w-auto"
        :disabled="isRunning || !selectedScenarioKey"
        @click="runScenario()"
      >
        <Icon icon="i-lucide-play" class="size-4" />
        {{ isRunning ? label('RUNNING') : label('RUN_TEST') }}
      </button>
    </header>

    <div
      class="flex gap-8 border-b border-n-weak"
      role="tablist"
      :aria-label="label('TAB_LABEL')"
    >
      <button
        v-for="tab in tabs"
        :key="tab.key"
        type="button"
        role="tab"
        class="-mb-px border-b-2 border-transparent px-1 pb-3 text-sm font-medium text-n-slate-11 outline-none transition-colors hover:text-n-slate-12 focus-visible:rounded-sm focus-visible:ring-2 focus-visible:ring-n-blue-7"
        :aria-selected="activeTab === tab.key"
        :data-testid="`test-center-tab-${tab.key}`"
        :style="activeTabStyle(activeTab === tab.key)"
        :class="{
          'border-n-brand text-n-blue-text': activeTab === tab.key,
        }"
        @click="setTab(tab.key)"
      >
        {{ tab.label }}
      </button>
    </div>

    <p
      v-if="errorMessage"
      class="mt-4 rounded-md border border-n-ruby-5 bg-n-ruby-2 px-3 py-2 text-sm text-n-ruby-11"
    >
      {{ errorMessage }}
    </p>
    <p v-if="isLoading" class="mt-4 text-sm text-n-slate-11">
      {{ label('LOADING') }}
    </p>

    <section
      v-if="activeTab === 'scenarios'"
      class="mt-5 grid gap-5 xl:grid-cols-[minmax(0,1fr)_minmax(480px,692px)]"
    >
      <div
        class="min-w-0 overflow-hidden rounded-lg border border-n-weak bg-n-solid-1"
      >
        <div
          class="grid gap-3 border-b border-n-weak p-5 md:grid-cols-[minmax(220px,1fr)_repeat(4,minmax(108px,auto))]"
        >
          <label class="relative min-w-0">
            <span class="sr-only">{{ label('SEARCH') }}</span>
            <Icon
              icon="i-lucide-search"
              class="absolute left-3 top-2.5 size-4 text-n-slate-10"
            />
            <input
              v-model="filters.search"
              :aria-label="label('SEARCH')"
              class="h-10 w-full rounded-md border border-n-weak bg-n-background pl-10 pr-3 text-sm text-n-slate-12"
              :placeholder="label('SEARCH_PLACEHOLDER')"
              @input="applyFilter({ search: filters.search })"
            />
          </label>
          <select
            v-model="filters.offer"
            :aria-label="label('OFFER_FILTER')"
            class="h-10 rounded-md border border-n-weak bg-n-background px-3 text-sm"
            @change="applyFilter({ offer: filters.offer })"
          >
            <option value="">{{ label('OFFER') }}</option>
            <option
              v-for="offer in filterOptions.offers || [label('DEFAULT_OFFER')]"
              :key="offer"
              :value="offer"
            >
              {{ offer }}
            </option>
          </select>
          <select
            v-model="filters.result"
            :aria-label="label('RESULT_FILTER')"
            class="h-10 rounded-md border border-n-weak bg-n-background px-3 text-sm"
            @change="applyFilter({ result: filters.result })"
          >
            <option value="">{{ label('RESULT') }}</option>
            <option
              v-for="result in filterOptions.results || defaultResults"
              :key="result"
              :value="result"
            >
              {{ humanize(result) }}
            </option>
          </select>
          <select
            v-model="filters.owner_id"
            :aria-label="label('OWNER_FILTER')"
            class="h-10 rounded-md border border-n-weak bg-n-background px-3 text-sm"
            @change="applyFilter({ owner_id: filters.owner_id })"
          >
            <option value="">{{ label('OWNER') }}</option>
            <option
              v-for="owner in filterOptions.owners || []"
              :key="owner.id"
              :value="owner.id"
            >
              {{ owner.name }}
            </option>
          </select>
          <Button
            data-testid="test-center-more-filters"
            slate
            outline
            md
            class="!h-10 !w-10 !rounded-md"
            data-icon="i-lucide-list-filter"
            icon="i-lucide-list-filter"
            :style="squareFilterControlStyle"
            :aria-label="label('MORE_FILTERS')"
            :title="label('MORE_FILTERS')"
            @click="showMoreFilters = !showMoreFilters"
          />
        </div>
        <div
          v-if="showMoreFilters"
          class="grid gap-3 border-b border-n-weak bg-n-slate-2 p-4 sm:grid-cols-3"
        >
          <input
            v-model="filters.configuration_version"
            :aria-label="label('CONFIGURATION_VERSION')"
            class="rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm"
            :placeholder="label('CONFIGURATION_VERSION')"
            @input="
              applyFilter({
                configuration_version: filters.configuration_version,
              })
            "
          />
          <input
            v-model="filters.knowledge_version"
            :aria-label="label('KNOWLEDGE_VERSION')"
            class="rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm"
            :placeholder="label('KNOWLEDGE_VERSION')"
            @input="
              applyFilter({ knowledge_version: filters.knowledge_version })
            "
          />
          <button
            type="button"
            class="rounded-md border border-n-weak px-3 py-2 text-sm font-medium text-n-slate-12"
            @click="clearFilters"
          >
            {{ label('CLEAR_FILTERS') }}
          </button>
        </div>
        <table
          class="hidden w-full table-fixed border-collapse text-left text-sm lg:table"
        >
          <thead
            class="border-b border-n-weak text-xs font-medium text-n-slate-11"
          >
            <tr>
              <th class="w-[30%] px-5 py-4">{{ label('SCENARIO') }}</th>
              <th class="w-[20%] px-5 py-4">{{ label('WHAT_IT_CHECKS') }}</th>
              <th class="w-[16%] px-5 py-4">{{ label('LAST_RESULT') }}</th>
              <th class="w-[18%] px-5 py-4">{{ label('LAST_TESTED') }}</th>
              <th class="w-[16%] px-5 py-4">{{ label('OWNER') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="row in scenarioRows"
              :key="row.key"
              class="cursor-pointer border-b border-n-weak align-top outline-none hover:bg-n-alpha-1 focus:bg-n-alpha-2"
              :class="{
                'bg-n-blue-2 shadow-[inset_3px_0_0_rgb(0,102,255)]':
                  selectedScenarioKey === row.key,
              }"
              tabindex="0"
              @click="selectScenario(row)"
              @keydown.enter.prevent="selectScenario(row)"
            >
              <td class="px-5 py-6 font-medium text-n-slate-12">
                {{ scenarioRowLabel(row) }}
              </td>
              <td class="px-5 py-6 text-n-slate-11">{{ row.checks }}</td>
              <td class="px-5 py-6">
                <span
                  class="inline-flex rounded-md px-2 py-1 text-xs font-medium"
                  :class="statusClass(row.result)"
                >
                  {{ humanize(row.result) }}
                </span>
              </td>
              <td class="px-5 py-6 text-n-slate-11">
                {{
                  formatDateTime(
                    row.latestRun?.completed_at || row.latestRun?.created_at
                  )
                }}
              </td>
              <td class="px-5 py-6 text-n-slate-12">{{ row.owner }}</td>
            </tr>
          </tbody>
        </table>
        <div class="grid divide-y divide-n-weak lg:hidden">
          <button
            v-for="row in scenarioRows"
            :key="row.key"
            type="button"
            class="grid gap-2 p-4 text-left"
            @click="selectScenario(row)"
          >
            <span class="font-medium text-n-slate-12">{{ row.name }}</span>
            <span class="text-sm text-n-slate-11">{{ row.checks }}</span>
            <span
              class="w-fit rounded-md px-2 py-1 text-xs font-medium"
              :class="statusClass(row.result)"
            >
              {{ humanize(row.result) }}
            </span>
          </button>
        </div>
        <p
          v-if="!scenarioRows.length"
          class="p-8 text-center text-sm text-n-slate-11"
        >
          {{ label('NO_SCENARIOS') }}
        </p>
        <footer
          class="border-t border-n-weak px-5 py-4 text-sm text-n-slate-11"
        >
          {{ scenarioCountLabel() }}
        </footer>
      </div>

      <aside
        class="relative min-w-0 overflow-hidden rounded-lg border border-n-weak bg-n-solid-1"
      >
        <div
          class="flex items-center justify-between gap-3 border-b border-n-weak p-5"
        >
          <div class="min-w-0">
            <h2 class="truncate text-lg font-semibold text-n-slate-12">
              {{
                selectedRun?.scenario_name ||
                selectedScenario?.name ||
                label('SELECT_SCENARIO')
              }}
            </h2>
            <p class="mt-1 text-xs font-medium text-n-slate-11">
              {{ label('SIMULATION_WARNING') }}
            </p>
          </div>
          <div class="flex shrink-0 items-center gap-2">
            <span
              class="rounded-md px-2 py-1 text-xs font-medium"
              :class="statusClass(selectedRun?.result || 'never_run')"
            >
              {{ humanize(selectedRun?.result || 'never_run') }}
            </span>
            <Button
              data-testid="test-center-panel-menu"
              slate
              outline
              sm
              class="!rounded-md"
              data-icon="i-lucide-ellipsis-vertical"
              icon="i-lucide-ellipsis-vertical"
              :aria-label="label('PANEL_MENU')"
              :aria-expanded="showPanelMenu"
              @click="showPanelMenu = !showPanelMenu"
            />
            <Button
              data-testid="test-center-panel-collapse"
              slate
              outline
              sm
              class="!rounded-md"
              :data-icon="
                isTranscriptCollapsed
                  ? 'i-lucide-panel-right-open'
                  : 'i-lucide-panel-right-close'
              "
              :icon="
                isTranscriptCollapsed
                  ? 'i-lucide-panel-right-open'
                  : 'i-lucide-panel-right-close'
              "
              :aria-label="
                isTranscriptCollapsed
                  ? label('EXPAND_PANEL')
                  : label('COLLAPSE_PANEL')
              "
              @click="isTranscriptCollapsed = !isTranscriptCollapsed"
            />
          </div>
        </div>
        <div
          v-if="showPanelMenu"
          class="absolute right-14 top-14 z-10 grid min-w-44 gap-1 rounded-md border border-n-weak bg-n-solid-1 p-1 text-sm shadow-md"
        >
          <button
            type="button"
            class="flex items-center gap-2 rounded px-3 py-2 text-left text-n-slate-12 hover:bg-n-slate-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-blue-7"
            @click="
              showPanelMenu = false;
              runScenario(selectedRun?.scenario_key);
            "
          >
            <Icon icon="i-lucide-refresh-cw" class="size-4" />
            {{ label('RUN_AGAIN') }}
          </button>
          <button
            type="button"
            class="flex items-center gap-2 rounded px-3 py-2 text-left text-n-slate-12 hover:bg-n-slate-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-blue-7"
            @click="
              showPanelMenu = false;
              markStepWrong(selectedSteps[0]);
            "
          >
            <Icon icon="i-lucide-flag" class="size-4" />
            {{ label('MARK_WRONG') }}
          </button>
        </div>
        <div
          v-if="selectedRun && isTranscriptCollapsed"
          class="p-8 text-center text-sm text-n-slate-11"
        >
          {{ label('TRANSCRIPT_COLLAPSED') }}
        </div>
        <div
          v-else-if="selectedRun"
          class="max-h-[calc(100vh-210px)] overflow-auto"
        >
          <div
            data-testid="test-center-warning-banner"
            class="m-5 mb-0 flex items-start gap-2 rounded-md border border-n-amber-5 bg-n-amber-2 px-3 py-2 text-sm text-n-amber-11"
          >
            <Icon
              icon="i-lucide-triangle-alert"
              class="mt-0.5 size-4 shrink-0"
            />
            <span>{{ label('SIMULATION_TRANSCRIPT_NOTICE') }}</span>
          </div>
          <div
            class="test-center-transcript grid gap-3 border-b border-n-weak p-5"
          >
            <template
              v-for="step in selectedSteps"
              :key="step.event_id || step.index"
            >
              <article
                class="max-w-[72%] rounded-lg border border-n-weak bg-white p-3 text-sm shadow-sm"
              >
                <p class="text-xs font-semibold text-n-teal-11">
                  {{ label('TEST_LEAD') }}
                </p>
                <p class="mt-1 break-words text-n-slate-12">
                  {{ step.lead_message || label('MEDIA_STEP') }}
                </p>
                <p class="mt-2 text-right text-xs text-n-slate-10">
                  {{ formatDateTime(selectedRun.created_at) }}
                </p>
              </article>
              <article
                v-if="!step.duplicate_ignored && step.selected_answer"
                class="ml-auto max-w-[72%] rounded-lg bg-[#dcf8c6] p-3 text-sm shadow-sm"
              >
                <p class="text-xs font-semibold text-[#2b6f45]">
                  {{ label('AI_EMPLOYEE') }}
                </p>
                <p class="mt-1 whitespace-pre-line break-words text-n-slate-12">
                  {{ step.selected_answer }}
                </p>
                <p class="mt-2 text-right text-xs text-n-slate-10">
                  {{ label('SIMULATED_DELIVERED') }}
                </p>
              </article>
              <article
                v-if="
                  step.duplicate_ignored ||
                  step.blocked_by_control_state ||
                  step.review_request_reason ||
                  step.refusal_reason
                "
                class="max-w-[82%] rounded-lg border border-n-amber-5 bg-n-amber-2 p-3 text-sm text-n-amber-11"
              >
                {{ systemStepText(step) }}
              </article>
            </template>
          </div>
          <div class="grid lg:grid-cols-[1fr_0.9fr]">
            <section
              class="border-b border-n-weak p-5 lg:border-b-0 lg:border-r"
            >
              <div class="mb-3 flex items-center justify-between">
                <h3 class="font-semibold text-n-slate-12">
                  {{ label('EVALUATION_CRITERIA') }}
                </h3>
                <button
                  type="button"
                  class="text-sm font-medium text-n-blue-11"
                  @click="showEvidence = !showEvidence"
                >
                  {{
                    showEvidence
                      ? label('HIDE_EVIDENCE')
                      : label('SHOW_EVIDENCE')
                  }}
                </button>
              </div>
              <div class="grid gap-2">
                <p
                  v-for="check in summaryChecks"
                  :key="`${check.stepIndex}-${check.name}`"
                  class="flex items-center justify-between gap-3 text-sm"
                >
                  <span class="min-w-0 truncate text-n-slate-11">
                    {{ humanize(check.name) }}
                  </span>
                  <span
                    class="inline-flex items-center gap-1 font-medium"
                    :class="check.passed ? 'text-n-teal-11' : 'text-n-ruby-11'"
                  >
                    <Icon
                      :icon="
                        check.passed
                          ? 'i-lucide-circle-check'
                          : 'i-lucide-circle-x'
                      "
                      class="size-4"
                    />
                    {{ check.passed ? label('PASSED') : label('FAILED') }}
                  </span>
                </p>
              </div>
              <dl v-if="showEvidence" class="mt-4 grid gap-3 text-sm">
                <div
                  v-for="step in selectedSteps"
                  :key="`evidence-${step.index}`"
                  class="rounded-md border border-n-weak p-3"
                >
                  <dt class="font-medium text-n-slate-12">
                    {{ stepEvidenceLabel(step) }}
                  </dt>
                  <dd class="mt-2 text-n-slate-11">
                    {{ qualityScoreLabel(step) }}
                  </dd>
                  <dd class="text-n-slate-11">
                    {{ nextQuestionLabel(step) }}
                  </dd>
                  <dd class="text-n-slate-11">
                    {{ handoffBookingLabel(step) }}
                  </dd>
                  <dd class="mt-2 break-words text-n-slate-11">
                    {{ sourcesLabel(step.sources) }}
                  </dd>
                </div>
              </dl>
            </section>
            <section class="p-5">
              <h3 class="font-semibold text-n-slate-12">
                {{ label('TEST_SUMMARY') }}
              </h3>
              <p
                class="mt-3 text-lg font-semibold"
                :class="
                  selectedRun.passed ? 'text-n-teal-11' : 'text-n-amber-11'
                "
              >
                {{ checkCountLabel(selectedRun) }}
              </p>
              <p class="mt-1 text-xs text-n-slate-11">
                {{ testedByLabel(selectedRun) }}
              </p>
              <div class="mt-4 grid grid-cols-2 gap-2">
                <button
                  type="button"
                  data-testid="test-center-run-again"
                  class="inline-flex items-center justify-center gap-2 rounded-md border border-n-weak px-3 py-2 text-sm font-medium text-n-slate-12 transition-colors hover:bg-n-slate-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-blue-7"
                  @click="runScenario(selectedRun.scenario_key)"
                >
                  <Icon icon="i-lucide-refresh-cw" class="size-4" />
                  {{ label('RUN_AGAIN') }}
                </button>
                <button
                  type="button"
                  data-testid="test-center-mark-wrong"
                  class="inline-flex items-center justify-center gap-2 rounded-md border border-n-weak px-3 py-2 text-sm font-medium text-n-slate-12 transition-colors hover:bg-n-slate-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-blue-7"
                  @click="markStepWrong(selectedSteps[0])"
                >
                  <Icon icon="i-lucide-flag" class="size-4" />
                  {{ label('MARK_WRONG') }}
                </button>
              </div>
              <button
                type="button"
                class="mt-3 text-sm font-medium text-n-blue-11"
                @click="showTranscriptMeta = !showTranscriptMeta"
              >
                {{
                  showTranscriptMeta ? label('HIDE_SETUP') : label('SHOW_SETUP')
                }}
              </button>
              <dl
                v-if="showTranscriptMeta"
                class="mt-4 grid grid-cols-2 gap-4 text-sm"
              >
                <div>
                  <dt class="text-n-slate-11">{{ label('OFFER') }}</dt>
                  <dd class="font-medium text-n-slate-12">
                    {{
                      selectedRun.expected_results?.offer ||
                      label('DEFAULT_OFFER')
                    }}
                  </dd>
                </div>
                <div>
                  <dt class="text-n-slate-11">
                    {{ label('STARTING_CHANNEL') }}
                  </dt>
                  <dd class="font-medium text-n-slate-12">
                    {{ label('WHATSAPP_SIMULATION') }}
                  </dd>
                </div>
                <div>
                  <dt class="text-n-slate-11">{{ label('CONFIGURATION') }}</dt>
                  <dd class="truncate font-medium text-n-slate-12">
                    {{ selectedRun.configuration_version }}
                  </dd>
                </div>
                <div>
                  <dt class="text-n-slate-11">{{ label('KNOWLEDGE') }}</dt>
                  <dd class="truncate font-medium text-n-slate-12">
                    {{ selectedRun.knowledge_version }}
                  </dd>
                </div>
                <div>
                  <dt class="text-n-slate-11">{{ label('MODEL') }}</dt>
                  <dd class="font-medium text-n-slate-12">
                    {{ selectedRun.model_identifier }}
                  </dd>
                </div>
                <div>
                  <dt class="text-n-slate-11">{{ label('TRANSCRIPT') }}</dt>
                  <dd class="font-medium text-n-slate-12">
                    {{ simulatedMessageCountLabel() }}
                  </dd>
                </div>
              </dl>
            </section>
          </div>
          <form
            v-if="showCorrection"
            class="border-t border-n-weak bg-n-slate-1 p-5"
            @submit.prevent="proposeKnowledge"
          >
            <h3 class="font-semibold text-n-slate-12">
              {{ label('CORRECTION_PROPOSAL') }}
            </h3>
            <p class="mt-1 text-sm text-n-slate-11">
              {{ label('CORRECTION_HELP') }}
            </p>
            <div class="mt-4 grid gap-3">
              <input
                v-model="correction.title"
                required
                :aria-label="label('CORRECTION_TITLE_LABEL')"
                class="rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm"
                :placeholder="label('TITLE_FIELD')"
              />
              <textarea
                v-model="correction.question"
                required
                :aria-label="label('CORRECTED_QUESTION')"
                rows="2"
                class="rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm"
                :placeholder="label('QUESTION')"
              />
              <textarea
                v-model="correction.answer"
                required
                :aria-label="label('CORRECTED_ANSWER')"
                rows="3"
                class="rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm"
                :placeholder="label('CORRECT_ANSWER')"
              />
              <div class="flex flex-wrap gap-2">
                <button
                  type="submit"
                  class="rounded-md bg-n-brand px-3 py-2 text-sm font-medium text-white"
                  :disabled="isSaving"
                >
                  {{ label('PROPOSE_TO_KNOWLEDGE') }}
                </button>
                <button
                  type="button"
                  class="rounded-md border border-n-weak px-3 py-2 text-sm font-medium"
                  @click="showCorrection = false"
                >
                  {{ label('CANCEL') }}
                </button>
              </div>
            </div>
          </form>
        </div>
        <div v-else class="p-8 text-center text-sm text-n-slate-11">
          {{ label('RUN_TO_SEE_TRANSCRIPT') }}
        </div>
      </aside>
    </section>

    <section
      v-if="activeTab === 'results'"
      class="mt-5 grid gap-5 xl:grid-cols-[360px_minmax(0,1fr)]"
    >
      <aside class="rounded-lg border border-n-weak bg-n-solid-1">
        <div class="grid gap-3 border-b border-n-weak p-4">
          <select
            v-model="filters.result"
            :aria-label="label('HISTORICAL_RESULT_FILTER')"
            class="rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm"
            @change="applyFilter({ result: filters.result })"
          >
            <option value="">{{ label('ALL_RESULTS') }}</option>
            <option
              v-for="result in filterOptions.results || defaultResults"
              :key="result"
              :value="result"
            >
              {{ humanize(result) }}
            </option>
          </select>
          <input
            v-model="filters.from"
            type="date"
            :aria-label="label('FROM_DATE')"
            class="rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm"
            @change="applyFilter({ from: filters.from })"
          />
          <input
            v-model="filters.to"
            type="date"
            :aria-label="label('TO_DATE')"
            class="rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm"
            @change="applyFilter({ to: filters.to })"
          />
        </div>
        <div class="max-h-[calc(100vh-260px)] overflow-auto">
          <button
            v-for="run in runs"
            :key="run.id"
            type="button"
            class="grid w-full gap-1 border-b border-n-weak p-4 text-left hover:bg-n-alpha-1"
            :class="{ 'bg-n-blue-2': selectedRun?.id === run.id }"
            @click="selectRun(run)"
          >
            <span class="font-medium text-n-slate-12">{{
              run.scenario_name
            }}</span>
            <span class="text-xs text-n-slate-11">
              {{ runMetaLabel(run) }}
            </span>
            <span
              class="w-fit rounded-md px-2 py-1 text-xs font-medium"
              :class="statusClass(run.result)"
            >
              {{ humanize(run.result) }}
            </span>
          </button>
          <p
            v-if="!runs.length && !isLoading"
            class="p-8 text-center text-sm text-n-slate-11"
          >
            {{ label('NO_RESULTS') }}
          </p>
        </div>
      </aside>
      <form
        v-if="selectedRun"
        class="rounded-lg border border-n-weak bg-n-solid-1 p-5"
        @submit.prevent="saveGrades"
      >
        <h2 class="text-lg font-semibold text-n-slate-12">
          {{ selectedRun.scenario_name }}
        </h2>
        <p class="mt-1 text-sm text-n-slate-11">
          {{ label('REVIEWER_GRADING_HELP') }}
        </p>
        <div class="mt-5 grid gap-3 md:grid-cols-2">
          <label
            v-for="key in gradeKeys"
            :key="key"
            class="grid gap-2 rounded-md border border-n-weak p-3 text-sm"
          >
            <span class="flex items-center gap-2 font-medium text-n-slate-12">
              <input v-model="grades[key].passed" type="checkbox" />
              {{ humanize(key) }}
            </span>
            <input
              v-model="grades[key].notes"
              class="rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm"
              :aria-label="gradeNotesLabel(key)"
              :placeholder="label('GRADE_NOTES')"
            />
          </label>
        </div>
        <div class="mt-5 flex flex-wrap gap-2">
          <button
            type="submit"
            class="rounded-md bg-n-brand px-3 py-2 text-sm font-medium text-white"
            :disabled="isSaving"
          >
            {{ label('SAVE_GRADES') }}
          </button>
          <button
            type="button"
            class="rounded-md border border-n-weak px-3 py-2 text-sm font-medium"
            @click="setTab('scenarios')"
          >
            {{ label('OPEN_TRANSCRIPT') }}
          </button>
        </div>
      </form>
    </section>

    <section v-if="activeTab === 'release'" class="mt-5 grid gap-5">
      <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-6">
        <div
          v-for="metric in releaseMetrics"
          :key="metric[0]"
          class="rounded-lg border border-n-weak bg-n-solid-1 p-4"
        >
          <p class="text-xs font-medium uppercase text-n-slate-11">
            {{ metric[0] }}
          </p>
          <p class="mt-3 text-xl font-semibold text-n-slate-12">
            {{ formatMetric(metric[1]) }}
          </p>
        </div>
      </div>
      <div class="grid gap-5 lg:grid-cols-[1fr_420px]">
        <section class="rounded-lg border border-n-weak bg-n-solid-1 p-5">
          <h2 class="font-semibold text-n-slate-12">
            {{ label('REQUIRED_SCENARIOS') }}
          </h2>
          <div class="mt-4 grid gap-2">
            <p
              v-for="(result, key) in report.scenario_results"
              :key="key"
              class="flex items-center justify-between gap-3 rounded-md border border-n-weak px-3 py-2 text-sm"
            >
              <span class="truncate text-n-slate-12">{{ humanize(key) }}</span>
              <span
                class="font-medium"
                :class="result.passed ? 'text-n-teal-11' : 'text-n-ruby-11'"
              >
                {{ reviewScenarioStatus(result) }}
              </span>
            </p>
          </div>
          <div
            v-if="blockingReasons.length"
            class="mt-5 rounded-md border border-n-amber-5 bg-n-amber-2 p-4 text-sm text-n-amber-11"
          >
            <p class="font-medium">{{ label('BLOCKERS') }}</p>
            <p
              v-for="reason in blockingReasons"
              :key="reason"
              class="mt-1 break-words"
            >
              {{ reason }}
            </p>
          </div>
        </section>
        <form
          class="rounded-lg border border-n-weak bg-n-solid-1 p-5"
          @submit.prevent="saveLaunchGate"
        >
          <h2 class="font-semibold text-n-slate-12">
            {{ label('RELEASE_CHECK') }}
          </h2>
          <label class="mt-4 flex items-center gap-2 text-sm text-n-slate-12">
            <input
              v-model="launchDraft.team_roleplay_completed"
              type="checkbox"
            />
            {{ label('TEAM_ROLEPLAY') }}
          </label>
          <label class="mt-4 grid gap-2 text-sm text-n-slate-12">
            <span>{{ label('PILOT_REVIEWS') }}</span>
            <input
              v-model.number="launchDraft.pilot_conversations_reviewed_count"
              type="number"
              min="0"
              class="rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm"
            />
          </label>
          <label class="mt-4 grid gap-2 text-sm text-n-slate-12">
            <span>{{ label('APPROVAL_NOTES') }}</span>
            <textarea
              v-model="launchDraft.approval_notes"
              rows="4"
              class="rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm"
            />
          </label>
          <div class="mt-5 flex flex-wrap gap-2">
            <button
              type="submit"
              class="rounded-md border border-n-weak px-3 py-2 text-sm font-medium"
              :disabled="isSaving"
            >
              {{ label('SAVE_CHECK') }}
            </button>
            <button
              type="button"
              class="rounded-md bg-n-brand px-3 py-2 text-sm font-medium text-white disabled:opacity-60"
              :disabled="!canApproveLaunch || isSaving"
              @click="approveLaunch"
            >
              {{ label('APPROVE_LAUNCH') }}
            </button>
          </div>
          <p
            class="mt-4 rounded-md px-3 py-2 text-sm font-medium"
            :class="
              launchGate.live_ai_enabled
                ? 'bg-n-teal-3 text-n-teal-11'
                : 'bg-n-slate-3 text-n-slate-11'
            "
          >
            {{ liveAiStateLabel() }}
          </p>
        </form>
      </div>
    </section>
  </section>
</template>

<style scoped>
.test-center-transcript {
  background-color: #f8f4ec;
  background-image: radial-gradient(
      circle at 16px 16px,
      rgb(15 23 42 / 4%) 1px,
      transparent 1px
    ),
    radial-gradient(
      circle at 42px 36px,
      rgb(15 23 42 / 3.5%) 1px,
      transparent 1px
    );
  background-size: 56px 56px;
}
</style>

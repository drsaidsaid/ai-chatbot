<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import evaluationSandboxAPI from 'dashboard/api/evaluationSandbox';

const { t } = useI18n();

const scenarios = ref([]);
const runs = ref([]);
const launchGate = ref({ report: {}, gate: {} });
const isLoading = ref(false);
const runningScenario = ref('');
const gradingRunId = ref(null);
const approvalNotes = ref('');
const gateForm = ref({
  team_roleplay_completed: false,
  pilot_conversations_reviewed_count: 0,
  approval_notes: '',
});

const gradeKeys = [
  'answer_correctness',
  'qualification_correctness',
  'tone',
  'safety',
  'source_quality',
  'next_action',
];

const gradeForms = ref({});

const requiredScenarioRows = computed(() => {
  const results = launchGate.value.report?.scenario_results || {};
  return scenarios.value.map(scenario => ({
    ...scenario,
    result: results[scenario.key] || { reviewed: false, passed: false },
  }));
});

const latestRun = computed(() => runs.value[0]);

const gradeLabels = computed(() => ({
  answer_correctness: t(
    'AI_LEAD_EMPLOYEE.TEST_CENTER.GRADE.ANSWER_CORRECTNESS'
  ),
  qualification_correctness: t(
    'AI_LEAD_EMPLOYEE.TEST_CENTER.GRADE.QUALIFICATION_CORRECTNESS'
  ),
  tone: t('AI_LEAD_EMPLOYEE.TEST_CENTER.GRADE.TONE'),
  safety: t('AI_LEAD_EMPLOYEE.TEST_CENTER.GRADE.SAFETY'),
  source_quality: t('AI_LEAD_EMPLOYEE.TEST_CENTER.GRADE.SOURCE_QUALITY'),
  next_action: t('AI_LEAD_EMPLOYEE.TEST_CENTER.GRADE.NEXT_ACTION'),
}));

const reviewedAccuracyLabel = computed(
  () =>
    `${Math.round(
      (launchGate.value.report?.reviewed_qualification_accuracy || 0) * 100
    )}%`
);

const minimumAccuracyLabel = computed(
  () =>
    `${Math.round(
      (launchGate.value.report?.minimum_qualification_accuracy || 0.85) * 100
    )}%`
);

const checkCountLabel = computed(() =>
  latestRun.value
    ? `${latestRun.value.passed_checks}/${latestRun.value.total_checks}`
    : ''
);

const load = async () => {
  isLoading.value = true;
  try {
    const { data } = await evaluationSandboxAPI.get();
    scenarios.value = data.scenarios || [];
    runs.value = data.runs || [];
    launchGate.value = data.launch_gate || { report: {}, gate: {} };
    gateForm.value = {
      team_roleplay_completed:
        launchGate.value.gate?.team_roleplay_completed || false,
      pilot_conversations_reviewed_count:
        launchGate.value.gate?.pilot_conversations_reviewed_count || 0,
      approval_notes: launchGate.value.gate?.approval_notes || '',
    };
    runs.value.forEach(run => {
      gradeForms.value[run.id] ||= {
        grades: Object.fromEntries(
          gradeKeys.map(key => [
            key,
            {
              passed: run.grades?.[key]?.passed || false,
              notes: run.grades?.[key]?.notes || '',
              serious_issue: run.grades?.[key]?.serious_issue || false,
            },
          ])
        ),
      };
    });
  } finally {
    isLoading.value = false;
  }
};

const runScenario = async scenario => {
  runningScenario.value = scenario.key;
  try {
    await evaluationSandboxAPI.createRun({ scenario_key: scenario.key });
    await load();
  } catch {
    useAlert(t('AI_LEAD_EMPLOYEE.TEST_CENTER.RUN_ERROR'));
  } finally {
    runningScenario.value = '';
  }
};

const gradeRun = async run => {
  gradingRunId.value = run.id;
  try {
    await evaluationSandboxAPI.gradeRun(run.id, gradeForms.value[run.id]);
    await load();
  } catch {
    useAlert(t('AI_LEAD_EMPLOYEE.TEST_CENTER.GRADE_ERROR'));
  } finally {
    gradingRunId.value = null;
  }
};

const updateGate = async () => {
  await evaluationSandboxAPI.updateLaunchGate(gateForm.value);
  await load();
};

const approveLaunch = async () => {
  try {
    await evaluationSandboxAPI.approveLaunch({
      approval_notes: approvalNotes.value,
    });
    await load();
  } catch {
    useAlert(t('AI_LEAD_EMPLOYEE.TEST_CENTER.APPROVAL_BLOCKED'));
  }
};

const humanize = value =>
  value
    ? value
        .split('_')
        .map(word => word.charAt(0).toUpperCase() + word.slice(1))
        .join(' ')
    : '';

const qualityLabel = step =>
  [
    humanize(step.qualification?.quality),
    step.qualification?.score ?? '-',
  ].join(' / ');

const nextActionLabel = step =>
  [
    humanize(step.handoff_decision),
    humanize(step.booking_decision),
    humanize(step.follow_up_decision),
  ].join(' / ');

onMounted(load);
</script>

<template>
  <section class="mt-6 grid gap-5">
    <div class="grid gap-3 md:grid-cols-4">
      <div class="border border-n-weak bg-n-solid-1 p-4">
        <p class="text-xs font-medium uppercase text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.METRIC.ACCURACY') }}
        </p>
        <p class="mt-2 text-2xl font-semibold text-n-slate-12">
          {{ reviewedAccuracyLabel }}
        </p>
      </div>
      <div class="border border-n-weak bg-n-solid-1 p-4">
        <p class="text-xs font-medium uppercase text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.METRIC.THRESHOLD') }}
        </p>
        <p class="mt-2 text-2xl font-semibold text-n-slate-12">
          {{ minimumAccuracyLabel }}
        </p>
      </div>
      <div class="border border-n-weak bg-n-solid-1 p-4">
        <p class="text-xs font-medium uppercase text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.METRIC.SERIOUS') }}
        </p>
        <p class="mt-2 text-2xl font-semibold text-n-slate-12">
          {{ launchGate.report?.serious_issue_count || 0 }}
        </p>
      </div>
      <div class="border border-n-weak bg-n-solid-1 p-4">
        <p class="text-xs font-medium uppercase text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.METRIC.LIVE') }}
        </p>
        <p class="mt-2 text-base font-semibold text-n-slate-12">
          {{
            launchGate.live_ai_enabled
              ? t('AI_LEAD_EMPLOYEE.TEST_CENTER.ENABLED')
              : t('AI_LEAD_EMPLOYEE.TEST_CENTER.BLOCKED')
          }}
        </p>
      </div>
    </div>

    <div class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_360px]">
      <section class="border border-n-weak bg-n-solid-1">
        <div
          class="grid grid-cols-[1fr_0.5fr_0.5fr_120px] gap-3 border-b border-n-weak px-4 py-3 text-xs font-medium uppercase text-n-slate-11"
        >
          <span>{{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.SCENARIO') }}</span>
          <span>{{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.REVIEWED') }}</span>
          <span>{{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.PASSED') }}</span>
          <span>{{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.ACTION') }}</span>
        </div>
        <div v-if="isLoading" class="px-4 py-6 text-sm text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.LOADING') }}
        </div>
        <template v-else>
          <div
            v-for="scenario in requiredScenarioRows"
            :key="scenario.key"
            class="grid grid-cols-[1fr_0.5fr_0.5fr_120px] gap-3 border-b border-n-weak px-4 py-4 text-sm text-n-slate-12"
          >
            <div class="min-w-0">
              <p class="font-medium">{{ scenario.name }}</p>
              <p class="mt-1 text-xs text-n-slate-11">
                {{ scenario.description }}
              </p>
            </div>
            <span>
              {{
                scenario.result.reviewed
                  ? t('AI_LEAD_EMPLOYEE.TEST_CENTER.YES')
                  : t('AI_LEAD_EMPLOYEE.TEST_CENTER.NO')
              }}
            </span>
            <span>
              {{
                scenario.result.passed
                  ? t('AI_LEAD_EMPLOYEE.TEST_CENTER.YES')
                  : t('AI_LEAD_EMPLOYEE.TEST_CENTER.NO')
              }}
            </span>
            <button
              type="button"
              class="inline-flex h-8 items-center justify-center rounded-lg bg-n-brand px-3 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-50"
              :disabled="runningScenario === scenario.key"
              @click="runScenario(scenario)"
            >
              {{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.RUN') }}
            </button>
          </div>
        </template>
      </section>

      <form
        class="grid gap-3 border border-n-weak bg-n-solid-1 p-4"
        @submit.prevent="updateGate"
      >
        <h2 class="text-base font-medium text-n-slate-12">
          {{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.LAUNCH_GATE') }}
        </h2>
        <label class="flex items-center gap-2 text-sm text-n-slate-12">
          <input
            v-model="gateForm.team_roleplay_completed"
            type="checkbox"
            class="size-4"
          />
          {{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.ROLEPLAY') }}
        </label>
        <label class="grid gap-1 text-sm text-n-slate-12">
          {{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.PILOT_REVIEWS') }}
          <input
            v-model.number="gateForm.pilot_conversations_reviewed_count"
            type="number"
            min="0"
            class="rounded-md border border-n-weak bg-n-background px-3 py-2"
          />
        </label>
        <label class="grid gap-1 text-sm text-n-slate-12">
          {{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.NOTES') }}
          <textarea
            v-model="gateForm.approval_notes"
            rows="3"
            class="rounded-md border border-n-weak bg-n-background px-3 py-2"
          />
        </label>
        <button
          type="submit"
          class="inline-flex h-8 items-center justify-center rounded-lg border border-n-weak px-3 text-sm font-medium text-n-slate-12"
        >
          {{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.SAVE_GATE') }}
        </button>
        <label class="grid gap-1 text-sm text-n-slate-12">
          {{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.APPROVAL_NOTES') }}
          <textarea
            v-model="approvalNotes"
            rows="3"
            class="rounded-md border border-n-weak bg-n-background px-3 py-2"
          />
        </label>
        <button
          type="button"
          class="inline-flex h-8 items-center justify-center rounded-lg bg-n-brand px-3 text-sm font-medium text-white"
          @click="approveLaunch"
        >
          {{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.APPROVE') }}
        </button>
      </form>
    </div>

    <section v-if="latestRun" class="border border-n-weak bg-n-solid-1 p-4">
      <div class="flex items-center justify-between gap-3">
        <h2 class="text-base font-medium text-n-slate-12">
          {{ latestRun.scenario_name }}
        </h2>
        <span class="text-sm text-n-slate-11">
          {{ checkCountLabel }}
        </span>
      </div>
      <div class="mt-4 grid gap-3 lg:grid-cols-2">
        <article
          v-for="step in latestRun.steps"
          :key="step.event_id"
          class="border border-n-weak p-3"
        >
          <p class="text-xs font-medium uppercase text-n-slate-11">
            {{ humanize(step.message_type) }}
          </p>
          <p class="mt-2 text-sm text-n-slate-12">{{ step.lead_message }}</p>
          <dl class="mt-3 grid gap-2 text-sm text-n-slate-12">
            <div>
              <dt class="text-xs text-n-slate-11">
                {{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.SELECTED_ANSWER') }}
              </dt>
              <dd class="whitespace-pre-wrap">
                {{ step.selected_answer || '-' }}
              </dd>
            </div>
            <div>
              <dt class="text-xs text-n-slate-11">
                {{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.SOURCES') }}
              </dt>
              <dd>{{ step.source_references?.length || 0 }}</dd>
            </div>
            <div>
              <dt class="text-xs text-n-slate-11">
                {{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.QUALITY') }}
              </dt>
              <dd>{{ qualityLabel(step) }}</dd>
            </div>
            <div>
              <dt class="text-xs text-n-slate-11">
                {{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.NEXT_ACTION') }}
              </dt>
              <dd>{{ nextActionLabel(step) }}</dd>
            </div>
          </dl>
        </article>
      </div>
      <form class="mt-4 grid gap-3" @submit.prevent="gradeRun(latestRun)">
        <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
          <label
            v-for="key in gradeKeys"
            :key="key"
            class="grid gap-2 border border-n-weak p-3 text-sm text-n-slate-12"
          >
            <span class="font-medium">{{ gradeLabels[key] }}</span>
            <span class="flex items-center gap-2">
              <input
                v-model="gradeForms[latestRun.id].grades[key].passed"
                type="checkbox"
                class="size-4"
              />
              {{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.PASS') }}
            </span>
            <span class="flex items-center gap-2">
              <input
                v-model="gradeForms[latestRun.id].grades[key].serious_issue"
                type="checkbox"
                class="size-4"
              />
              {{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.SERIOUS_ISSUE') }}
            </span>
            <textarea
              v-model="gradeForms[latestRun.id].grades[key].notes"
              rows="2"
              class="rounded-md border border-n-weak bg-n-background px-3 py-2"
            />
          </label>
        </div>
        <button
          type="submit"
          class="inline-flex h-8 w-fit items-center justify-center rounded-lg bg-n-brand px-3 text-sm font-medium text-white disabled:opacity-50"
          :disabled="gradingRunId === latestRun.id"
        >
          {{ t('AI_LEAD_EMPLOYEE.TEST_CENTER.SAVE_REVIEW') }}
        </button>
      </form>
    </section>
  </section>
</template>

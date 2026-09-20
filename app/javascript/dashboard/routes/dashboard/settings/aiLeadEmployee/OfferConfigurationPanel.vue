<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import OffersAPI from 'dashboard/api/qualificationOffers';
import EvaluationSandboxAPI from 'dashboard/api/evaluationSandbox';

const { t } = useI18n();
const draft = ref(null);
const drafts = reactive({});
const newField = ref('budget');
const builtinFields = {
  business_type: ['Business type', 'text'],
  problem: ['Problem to solve', 'text'],
  lead_volume: ['Inquiry volume', 'number'],
  urgency: ['Urgency', 'text'],
  budget: ['Purchase budget', 'money'],
  decision_authority: ['Decision authority', 'boolean'],
  contact_details: ['Contact details', 'text'],
  name: ['Name', 'text'],
  sales_call_agreement: ['Sales call agreement', 'boolean'],
};
const fields = computed(() => ({
  ...Object.fromEntries(
    Object.entries(builtinFields).map(([key, [meaning, answer_type]]) => [
      key,
      { key, meaning, answer_type },
    ])
  ),
  ...Object.fromEntries(
    (draft.value?.questions || []).map(question => [question.key, question])
  ),
}));
const booleanQuestions = computed(() =>
  (draft.value?.questions || []).filter(
    question => question.enabled && question.answer_type === 'boolean'
  )
);
const loading = ref(true);
const saving = ref(false);
const error = ref('');
const status = ref('');
const pricingPreview = ref(null);
const setupSources = reactive({});
const setupTitle = ref('');
const setupBody = ref('');
const setupSourceType = ref('pasted_prose');
const setupProposal = ref(null);
const setupQuestions = reactive({});
const setupTestResults = reactive({});
const previewPromotionEligible = ref(false);
const conflicts = reactive({});
const conflicted = computed(() => Boolean(conflicts[draft.value?.id]));
const label = key => t(`AI_LEAD_EMPLOYEE.OFFERS.${key}`);
const setupStatusLabel = sourceStatus =>
  label(
    { proposed: 'SETUP_STATUS_PROPOSED', published: 'SETUP_STATUS_PUBLISHED' }[
      sourceStatus
    ] || 'SETUP_STATUS_UNKNOWN'
  );
const setupModeLabel = mode =>
  label(
    {
      not_configured: 'MODE_NOT_CONFIGURED',
      disabled: 'MODE_DISABLED',
      enabled: 'MODE_ENABLED',
    }[mode] || 'MODE_NOT_CONFIGURED'
  );
const setupNextStepLabel = kind =>
  label(
    {
      answer_only: 'NEXT_ANSWER_ONLY',
      enquiry: 'NEXT_ENQUIRY',
      purchase_link: 'NEXT_PURCHASE_LINK',
      sales_call: 'NEXT_SALES_CALL',
      appointment: 'NEXT_APPOINTMENT',
    }[kind] || 'NEXT_ANSWER_ONLY'
  );
const setupPurposeLabel = purpose =>
  label(
    {
      fit: 'PURPOSE_FIT',
      readiness: 'PURPOSE_READINESS',
      action_eligibility: 'PURPOSE_ACTION_ELIGIBILITY',
    }[purpose] || 'PURPOSE_FIT'
  );
const setupRuleSummary = (source, rule) => {
  const question = source.configuration?.questions?.find(
    item => item.key === rule.field
  );
  return t('AI_LEAD_EMPLOYEE.OFFERS.SETUP_RULE_SUMMARY', {
    field: question?.meaning || label('SETUP_REVIEW_FIELD'),
    purpose: setupPurposeLabel(rule.dimension || rule.kind),
  });
};
const requirementGroupSummary = (source, group) => {
  const operatorLabel = operator => label(`OP_${operator.toUpperCase()}`);
  const valueLabel = (node, field) => {
    if (['positive', 'negative', 'known'].includes(node.operator)) return '';
    if (typeof node.value === 'boolean')
      return label(node.value ? 'YES' : 'NO');
    if (node.value?.amount)
      return `${node.value.amount} ${
        node.value.currency || field?.currency || ''
      }`.trim();
    if (Array.isArray(node.value)) return node.value.join(', ');
    return String(node.value ?? '');
  };
  const describe = node => {
    if (node.field) {
      const field = source.configuration?.questions?.find(
        item => item.key === node.field
      );
      const value = valueLabel(node, field);
      return `${field?.meaning || node.field} ${operatorLabel(node.operator)}${
        value ? ` ${value}` : ''
      }`;
    }
    const key = node.all ? 'all' : 'any';
    return `(${node[key].map(describe).join(key === 'all' ? ' and ' : ' or ')})`;
  };
  return `${setupPurposeLabel(group.dimension)}: ${describe(group)}`;
};
const inputClass =
  'h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12';
const buttonClass =
  'min-h-9 rounded-lg border border-n-weak px-3 text-sm text-n-slate-12 disabled:opacity-40';
const blankCommercialTerms = currency => ({
  amount: '',
  currency: currency || 'TZS',
  quote_required: false,
  effective_from: '',
  effective_until: '',
  timezone: 'Africa/Dar_es_Salaam',
  conditions: '',
  pricing_url: '',
  promotion_amount: '',
  promotion_starts_at: '',
  promotion_ends_at: '',
  promotion_conditions: '',
  promotion_requires_confirmation: false,
  promotion_eligibility_field: '',
});
const setupResultKey = source => `${source.id}:${source.version}`;
const clearSetupTests = () => {
  Object.keys(setupQuestions).forEach(key => delete setupQuestions[key]);
  Object.keys(setupTestResults).forEach(key => delete setupTestResults[key]);
};
const selectDraft = key => {
  draft.value = drafts[key];
  pricingPreview.value = null;
  previewPromotionEligible.value = false;
  error.value = '';
  status.value = '';
  setupProposal.value = null;
  clearSetupTests();
  // eslint-disable-next-line no-use-before-define
  if (draft.value?.id) loadSetupSources(draft.value.id);
};
const newOffer = () => {
  drafts.new ||= {
    name: '',
    currency: 'TZS',
    enabled: true,
    qualification_mode: 'not_configured',
    next_step: { kind: 'answer_only' },
    questions: [],
    budget_ranges: [],
    rules: [],
    requirement_groups: [],
    score_weights: {},
    score_thresholds: { qualified: 60, highly_qualified: 80 },
    commercial_terms: blankCommercialTerms('TZS'),
    commercial_proposals: [],
  };
  selectDraft('new');
};
const addQuestion = () => {
  if (draft.value.questions.some(question => question.key === newField.value))
    return;
  const field = builtinFields[newField.value];
  draft.value.questions.push({
    key: field
      ? newField.value
      : `custom_${crypto.randomUUID().replaceAll('-', '')}`,
    meaning: field?.[0] || '',
    answer_type: field?.[1] || 'text',
    prompt: '',
    position: draft.value.questions.length,
    enabled: true,
    required: true,
    purpose: 'fit',
  });
};
const moveQuestion = (index, delta) => {
  const questions = draft.value.questions;
  const [question] = questions.splice(index, 1);
  questions.splice(index + delta, 0, question);
  questions.forEach((item, position) => {
    item.position = position;
  });
};
const addRange = () =>
  draft.value.budget_ranges.push({
    label: label('RANGE'),
    minimum: '',
    maximum: null,
    position: draft.value.budget_ranges.length,
    enabled: true,
  });
const changeCurrency = () => {
  draft.value.rules.forEach(rule => {
    if (fields.value[rule.field]?.answer_type === 'money' && rule.value) {
      rule.value.currency = draft.value.currency;
    }
  });
};
const addRule = () =>
  draft.value.rules.push({
    kind: 'score_rule',
    dimension: 'fit',
    field: 'budget',
    operator: 'positive',
    value: null,
    score_delta: 0,
    priority: draft.value.rules.length,
    enabled: true,
  });
const newRequirementLeaf = () => ({
  field: 'business_type',
  operator: 'known',
  value: null,
});
const groupBranch = group => (group.all ? 'all' : 'any');
const changeGroupBranch = (group, branch) => {
  const previous = groupBranch(group);
  const children = group[previous];
  delete group[previous];
  group[branch] = children;
};
const addRequirementGroup = () =>
  draft.value.requirement_groups.push({
    dimension: 'fit',
    any: [newRequirementLeaf()],
  });
const addGroupLeaf = group =>
  group[groupBranch(group)].push(newRequirementLeaf());
const addNestedGroup = group =>
  group[groupBranch(group)].push({ all: [newRequirementLeaf()] });
const addNestedLeaf = group =>
  group[groupBranch(group)].push(newRequirementLeaf());
const operatorsFor = rule => {
  const type = fields.value[rule.field]?.answer_type;
  return [
    'positive',
    'negative',
    'known',
    'eq',
    ...(['money', 'number'].includes(type) ? ['lt', 'lte', 'gt', 'gte'] : []),
    ...(type === 'choice' ? ['in'] : []),
  ];
};
const resetRule = rule => {
  if (!operatorsFor(rule).includes(rule.operator)) rule.operator = 'positive';
  const type = fields.value[rule.field]?.answer_type;
  rule.value = ['positive', 'negative', 'known'].includes(rule.operator)
    ? null
    : ({
        money: { amount: '', currency: draft.value.currency },
        number: 0,
        boolean: true,
        choice: rule.operator === 'in' ? [] : '',
      }[type] ?? '');
};

const orderedDraft = offer => ({
  ...offer,
  qualification_mode: offer.qualification_mode || 'not_configured',
  next_step: offer.next_step || { kind: 'answer_only' },
  questions: [...offer.questions]
    .sort((left, right) => left.position - right.position)
    .map(question => ({ purpose: 'fit', ...question })),
  requirement_groups: offer.requirement_groups || [],
  commercial_terms: {
    ...blankCommercialTerms(offer.currency),
    ...(offer.commercial_terms_draft || {}),
  },
});

const load = async () => {
  loading.value = true;
  error.value = '';
  try {
    const { data } = await OffersAPI.get();
    data.forEach(offer => {
      drafts[offer.id] = orderedDraft(offer);
    });
    if (data.length) selectDraft(data[0].id);
    else newOffer();
  } catch (exception) {
    error.value = exception.response?.data?.error || label('LOAD_ERROR');
  } finally {
    loading.value = false;
  }
};
const loadSetupSources = async offerId => {
  try {
    const { data } = await OffersAPI.setupSources(offerId);
    setupSources[offerId] = Array.isArray(data) ? data : [];
  } catch {
    // The Offer remains editable when setup source history is temporarily unavailable.
  }
};
const reopenSetup = source => {
  setupTitle.value = source.title;
  setupBody.value = source.body;
  setupSourceType.value = source.source_type;
  setupProposal.value = source;
  Object.assign(
    draft.value,
    JSON.parse(JSON.stringify(source.configuration || {}))
  );
  clearSetupTests();
};
const editPublishedSetup = source => {
  setupTitle.value = source.title;
  setupBody.value = source.body;
  setupSourceType.value = source.source_type;
  setupProposal.value = null;
  clearSetupTests();
};
const setupTestResult = source => setupTestResults[setupResultKey(source)];
const setupTestBlockedReason = source =>
  setupTestResult(source)?.steps?.find(step => step.blocked_reason)
    ?.blocked_reason;
const setupTestBlockedReasonLabel = source =>
  label(
    {
      provider_configuration_changed:
        'SETUP_TEST_BLOCKED_PROVIDER_CONFIGURATION_CHANGED',
      provider_disabled: 'SETUP_TEST_BLOCKED_PROVIDER_DISABLED',
      usage_limit_exhausted: 'SETUP_TEST_BLOCKED_USAGE_LIMIT',
      no_approved_knowledge: 'SETUP_TEST_BLOCKED_REVIEW_REQUIRED',
    }[setupTestBlockedReason(source)] || 'SETUP_TEST_BLOCKED_GENERIC'
  );
const setupTestAnswered = source =>
  setupTestResult(source)?.status === 'completed' &&
  !setupTestBlockedReason(source) &&
  setupTestResult(source)?.steps?.some(
    step => step.selected_answer && step.source_references?.length
  );
const reviewedConfiguration = () => {
  const configuration = JSON.parse(JSON.stringify(draft.value));
  delete configuration.commercial_terms;
  delete configuration.commercial_terms_draft;
  delete configuration.published_commercial_terms;
  delete configuration.commercial_proposals;
  configuration.questions.forEach((question, position) => {
    question.position = position;
  });
  configuration.budget_ranges.forEach((range, position) => {
    range.position = position;
  });
  if (!['purchase_link', 'appointment'].includes(configuration.next_step.kind))
    delete configuration.next_step.url;
  if (configuration.next_step.kind === 'answer_only')
    delete configuration.next_step.prompt;
  return configuration;
};
const proposeSetup = async () => {
  if (!draft.value?.id || !setupBody.value.trim() || saving.value) return;
  saving.value = true;
  error.value = '';
  try {
    const { data } = await OffersAPI.createSetupSource(draft.value.id, {
      title: setupTitle.value.trim() || label('SETUP_DEFAULT_TITLE'),
      source_type: setupSourceType.value,
      body: setupBody.value,
      reviewed_configuration: reviewedConfiguration(),
    });
    setupSources[draft.value.id] = [
      data,
      ...(setupSources[draft.value.id] || []),
    ];
    setupProposal.value = data;
    status.value = label('SETUP_PROPOSED');
  } catch (exception) {
    error.value =
      exception.response?.data?.error || label('SETUP_REVIEW_ERROR');
  } finally {
    saving.value = false;
  }
};
const publishSetup = async source => {
  if (!draft.value?.id || saving.value) return;
  saving.value = true;
  error.value = '';
  try {
    const { data } = await OffersAPI.publishSetupSource(
      draft.value.id,
      source.id,
      {
        expected_source_version: source.version,
        expected_offer_version: draft.value.version,
      }
    );
    setupSources[draft.value.id] = (setupSources[draft.value.id] || []).map(
      item => (item.id === data.id ? data : item)
    );
    setupProposal.value = data;
    // eslint-disable-next-line no-use-before-define
    await reloadCurrent();
    status.value = label('SETUP_PUBLISHED');
  } catch (exception) {
    error.value = exception.response?.data?.error || label('SETUP_CONFLICT');
  } finally {
    saving.value = false;
  }
};
const correctSetup = async source => {
  if (!draft.value?.id || saving.value) return;
  saving.value = true;
  error.value = '';
  try {
    const { data } = await OffersAPI.updateSetupSource(
      draft.value.id,
      source.id,
      {
        title: setupTitle.value.trim() || source.title,
        source_type: setupSourceType.value,
        body: setupBody.value,
        reviewed_configuration: reviewedConfiguration(),
        expected_source_version: source.version,
      }
    );
    setupSources[draft.value.id] = (setupSources[draft.value.id] || []).map(
      item => (item.id === data.id ? data : item)
    );
    setupProposal.value = data;
    status.value = label('SETUP_CORRECTED');
  } catch (exception) {
    error.value =
      exception.response?.data?.error || label('SETUP_CORRECTION_ERROR');
  } finally {
    saving.value = false;
  }
};

const testSetup = async source => {
  const key = setupResultKey(source);
  const question = setupQuestions[key]?.trim();
  if (!question || saving.value) return;
  saving.value = true;
  error.value = '';
  delete setupTestResults[key];
  try {
    const { data } = await EvaluationSandboxAPI.runScenario(
      'business_setup_context',
      {
        business_setup_source_id: source.id,
        question,
      }
    );
    setupTestResults[key] = data;
  } catch (exception) {
    error.value = exception.response?.data?.error || label('SETUP_TEST_ERROR');
  } finally {
    saving.value = false;
  }
};

const save = async () => {
  if (saving.value || conflicted.value) return;
  saving.value = true;
  error.value = '';
  status.value = '';
  try {
    const payload = { offer: reviewedConfiguration() };
    const { data } = draft.value.id
      ? await OffersAPI.update(draft.value.id, payload)
      : await OffersAPI.create(payload);
    if (!draft.value.id) delete drafts.new;
    drafts[data.id] = orderedDraft(data);
    draft.value = drafts[data.id];
    status.value = label('SAVED');
  } catch (exception) {
    if (exception.response?.status === 409) conflicts[draft.value.id] = true;
    error.value = exception.response?.data?.error || label('SAVE_ERROR');
  } finally {
    saving.value = false;
  }
};
const replaceDraft = data => {
  drafts[data.id] = orderedDraft(data);
  draft.value = drafts[data.id];
};
const saveCommercialTerms = async () => {
  if (saving.value || !draft.value?.id) return;
  saving.value = true;
  error.value = '';
  status.value = '';
  try {
    const commercialTerms = JSON.parse(
      JSON.stringify(draft.value.commercial_terms)
    );
    const draftVersion = commercialTerms.draft_version;
    delete commercialTerms.draft_version;
    const { data } = await OffersAPI.saveCommercialTerms(draft.value.id, {
      commercial_terms: commercialTerms,
      draft_version: draftVersion,
    });
    replaceDraft(data);
    status.value = label('COMMERCIAL_DRAFT_SAVED');
  } catch (exception) {
    error.value =
      exception.response?.data?.error || label('COMMERCIAL_SAVE_ERROR');
  } finally {
    saving.value = false;
  }
};
const publishCommercialTerms = async () => {
  if (saving.value || !draft.value?.commercial_terms?.draft_version) return;
  saving.value = true;
  error.value = '';
  try {
    const { data } = await OffersAPI.publishCommercialTerms(
      draft.value.id,
      draft.value.commercial_terms.draft_version
    );
    replaceDraft(data);
    pricingPreview.value = null;
    status.value = label('COMMERCIAL_PUBLISHED');
  } catch (exception) {
    error.value =
      exception.response?.data?.error || label('COMMERCIAL_PUBLISH_ERROR');
  } finally {
    saving.value = false;
  }
};
const previewCommercialTerms = async () => {
  if (!draft.value?.id) return;
  const { data } = await OffersAPI.previewCommercialTerms(draft.value.id, {
    promotion_eligible: previewPromotionEligible.value,
  });
  pricingPreview.value = data;
};
const reviewCommercialProposal = async (proposal, action) => {
  if (saving.value) return;
  saving.value = true;
  try {
    const { data } = await OffersAPI.reviewCommercialProposal(
      draft.value.id,
      proposal.id,
      action
    );
    replaceDraft(data);
  } catch (exception) {
    error.value =
      exception.response?.data?.error || label('COMMERCIAL_SAVE_ERROR');
  } finally {
    saving.value = false;
  }
};
const reloadCurrent = async () => {
  saving.value = true;
  try {
    const { data } = await OffersAPI.show(draft.value.id);
    drafts[data.id] = orderedDraft(data);
    delete conflicts[data.id];
    selectDraft(data.id);
  } catch (exception) {
    error.value = exception.response?.data?.error || label('LOAD_ERROR');
  } finally {
    saving.value = false;
  }
};
onMounted(load);
</script>

<template>
  <section class="grid gap-5">
    <div v-if="!loading" class="flex flex-wrap items-end gap-3">
      <label class="grid min-w-48 flex-1 gap-1 text-sm">
        {{ label('SELECT') }}
        <select
          :value="draft?.id || 'new'"
          :class="inputClass"
          :disabled="saving"
          data-testid="offer-select"
          @change="selectDraft($event.target.value)"
        >
          <option v-for="(item, key) in drafts" :key="key" :value="key">
            {{ item.name || label('NEW') }}
          </option>
        </select>
      </label>
      <button
        type="button"
        :class="buttonClass"
        :disabled="saving"
        data-testid="new-offer"
        @click="newOffer"
      >
        {{ label('NEW') }}
      </button>
    </div>
    <p v-if="loading" role="status">
      {{ label('LOADING') }}
    </p>
    <p v-if="error" role="alert" class="text-sm text-n-ruby-11">
      {{ error }}
    </p>
    <p v-if="status" role="status" class="text-sm text-n-teal-11">
      {{ status }}
    </p>
    <button
      v-if="conflicted"
      type="button"
      :class="buttonClass"
      :disabled="saving"
      data-testid="reload-offer"
      @click="reloadCurrent"
    >
      {{ label('RELOAD') }}
    </button>
    <form v-if="draft" class="grid gap-5" @submit.prevent="save">
      <fieldset :disabled="saving" class="contents">
        <p v-if="draft.version" class="text-sm text-n-slate-11">
          {{
            t('AI_LEAD_EMPLOYEE.OFFERS.REVISION', { version: draft.version })
          }}
        </p>
        <label class="grid gap-1 text-sm">
          {{ label('NAME') }}
          <input
            v-model="draft.name"
            required
            :class="inputClass"
            data-testid="offer-name"
          />
        </label>
        <label class="flex items-center gap-2 text-sm">
          <input v-model="draft.enabled" type="checkbox" />
          {{ label('ENABLED') }}
        </label>
        <section
          v-if="draft.id"
          class="grid gap-4 rounded-xl border border-n-weak bg-n-solid-2 p-4 sm:p-5"
          data-testid="commercial-terms-section"
        >
          <div class="grid gap-2 sm:grid-cols-[1fr_auto] sm:items-start">
            <div>
              <h3 class="text-base font-semibold text-n-slate-12">
                {{ label('COMMERCIAL_TERMS') }}
              </h3>
              <p class="mt-1 text-sm leading-6 text-n-slate-11">
                {{ label('COMMERCIAL_TERMS_HELP') }}
              </p>
            </div>
            <span
              class="w-fit rounded-full bg-n-slate-3 px-3 py-1 text-xs font-medium text-n-slate-11"
            >
              {{
                draft.published_commercial_terms
                  ? label('COMMERCIAL_PUBLISHED_STATE')
                  : label('COMMERCIAL_NOT_PUBLISHED')
              }}
            </span>
          </div>
          <div
            v-if="draft.published_commercial_terms"
            class="rounded-lg border border-n-weak bg-n-background p-3 text-sm text-n-slate-12"
            data-testid="published-commercial-summary"
          >
            <strong>{{ label('CURRENT_PUBLISHED_PRICE') }}</strong>
            <template v-if="draft.published_commercial_terms.quote_required">
              {{ label('QUOTE_REQUIRED') }}
            </template>
            <template v-else>
              {{ draft.published_commercial_terms.currency }}
              {{ draft.published_commercial_terms.amount }}
            </template>
            <span class="text-n-slate-11">
              {{ label('SEPARATOR') }}{{ label('COMMERCIAL_REVISION') }}
              {{ draft.published_commercial_terms.revision }}
            </span>
          </div>
          <label class="flex items-center gap-2 text-sm text-n-slate-12">
            <input
              v-model="draft.commercial_terms.quote_required"
              type="checkbox"
              data-testid="commercial-quote-required"
            />
            {{ label('QUOTE_REQUIRED') }}
          </label>
          <div class="grid gap-3 sm:grid-cols-2">
            <label
              v-if="!draft.commercial_terms.quote_required"
              class="grid gap-1 text-sm"
            >
              {{ label('PUBLISHED_AMOUNT') }}
              <input
                v-model="draft.commercial_terms.amount"
                required
                inputmode="decimal"
                :class="inputClass"
                data-testid="commercial-amount"
              />
            </label>
            <label class="grid gap-1 text-sm">
              {{ label('CURRENCY') }}
              <select
                v-model="draft.commercial_terms.currency"
                :class="inputClass"
                data-testid="commercial-currency"
              >
                <option
                  v-for="currency in ['TZS', 'USD', 'KES', 'EUR', 'GBP']"
                  :key="currency"
                  :value="currency"
                >
                  {{ currency }}
                </option>
              </select>
            </label>
            <label class="grid gap-1 text-sm">
              {{ label('EFFECTIVE_FROM') }}
              <input
                v-model="draft.commercial_terms.effective_from"
                type="datetime-local"
                :class="inputClass"
              />
            </label>
            <label class="grid gap-1 text-sm">
              {{ label('EFFECTIVE_UNTIL') }}
              <input
                v-model="draft.commercial_terms.effective_until"
                type="datetime-local"
                :class="inputClass"
              />
            </label>
            <label class="grid gap-1 text-sm sm:col-span-2">
              {{ label('TIMEZONE') }}
              <input
                v-model="draft.commercial_terms.timezone"
                required
                :class="inputClass"
                data-testid="commercial-timezone"
              />
            </label>
            <label class="grid gap-1 text-sm sm:col-span-2">
              {{ label('PRICE_CONDITIONS') }}
              <textarea
                v-model="draft.commercial_terms.conditions"
                class="min-h-20 rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
              />
            </label>
            <label class="grid gap-1 text-sm sm:col-span-2">
              {{ label('PRICING_LINK') }}
              <input
                v-model="draft.commercial_terms.pricing_url"
                type="url"
                :class="inputClass"
              />
            </label>
          </div>
          <fieldset class="grid gap-3 rounded-lg border border-n-weak p-3">
            <legend class="px-1 text-sm font-semibold">
              {{ label('PROMOTION') }}
            </legend>
            <div class="grid gap-3 sm:grid-cols-2">
              <label class="grid gap-1 text-sm">
                {{ label('PROMOTION_AMOUNT') }}
                <input
                  v-model="draft.commercial_terms.promotion_amount"
                  inputmode="decimal"
                  :class="inputClass"
                />
              </label>
              <label
                class="flex items-center gap-2 text-sm sm:self-end sm:pb-2"
              >
                <input
                  v-model="
                    draft.commercial_terms.promotion_requires_confirmation
                  "
                  type="checkbox"
                />
                {{ label('PROMOTION_CONFIRMATION') }}
              </label>
              <label
                v-if="draft.commercial_terms.promotion_requires_confirmation"
                class="grid gap-1 text-sm sm:col-span-2"
              >
                {{ label('PROMOTION_ELIGIBILITY_FIELD') }}
                <select
                  v-model="draft.commercial_terms.promotion_eligibility_field"
                  required
                  :class="inputClass"
                >
                  <option value="">{{ label('CHOOSE_BOOLEAN_FIELD') }}</option>
                  <option
                    v-for="question in booleanQuestions"
                    :key="question.key"
                    :value="question.key"
                  >
                    {{ question.meaning }}
                  </option>
                </select>
              </label>
              <label class="grid gap-1 text-sm">
                {{ label('PROMOTION_START') }}
                <input
                  v-model="draft.commercial_terms.promotion_starts_at"
                  type="datetime-local"
                  :class="inputClass"
                />
              </label>
              <label class="grid gap-1 text-sm">
                {{ label('PROMOTION_END') }}
                <input
                  v-model="draft.commercial_terms.promotion_ends_at"
                  type="datetime-local"
                  :class="inputClass"
                />
              </label>
              <label class="grid gap-1 text-sm sm:col-span-2">
                {{ label('PROMOTION_CONDITIONS') }}
                <textarea
                  v-model="draft.commercial_terms.promotion_conditions"
                  class="min-h-20 rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
                />
              </label>
            </div>
          </fieldset>
          <div
            v-if="draft.commercial_proposals?.length"
            class="grid gap-2 rounded-lg border border-n-weak p-3"
          >
            <h4 class="text-sm font-semibold">
              {{ label('DOCUMENT_PRICE_PROPOSALS') }}
            </h4>
            <article
              v-for="proposal in draft.commercial_proposals"
              :key="proposal.id"
              class="grid gap-2 border-t border-n-weak pt-2 text-sm first:border-0 first:pt-0"
            >
              <p>
                {{ proposal.proposed_terms.currency }}
                {{ proposal.proposed_terms.amount || label('QUOTE_REQUIRED') }}
                {{ label('SEPARATOR') }}{{ proposal.status }}
              </p>
              <p
                v-if="proposal.conflict_details?.reason"
                class="text-n-amber-11"
              >
                {{ proposal.conflict_details.reason }}
              </p>
              <div
                v-if="['pending', 'conflict_review'].includes(proposal.status)"
                class="flex flex-wrap gap-2"
              >
                <button
                  type="button"
                  :class="buttonClass"
                  @click="reviewCommercialProposal(proposal, 'approve')"
                >
                  {{ label('APPROVE_DRAFT') }}
                </button>
                <button
                  type="button"
                  :class="buttonClass"
                  @click="reviewCommercialProposal(proposal, 'reject')"
                >
                  {{ label('REJECT') }}
                </button>
              </div>
            </article>
          </div>
          <div class="flex flex-wrap gap-2">
            <button
              type="button"
              :class="buttonClass"
              data-testid="save-commercial-terms"
              @click="saveCommercialTerms"
            >
              {{ label('SAVE_COMMERCIAL_DRAFT') }}
            </button>
            <button
              type="button"
              :disabled="!draft.commercial_terms.draft_version"
              class="min-h-9 rounded-lg bg-n-brand px-3 text-sm font-medium text-white disabled:opacity-40"
              data-testid="publish-commercial-terms"
              @click="publishCommercialTerms"
            >
              {{ label('PUBLISH_COMMERCIAL_TERMS') }}
            </button>
            <button
              v-if="draft.published_commercial_terms"
              type="button"
              :class="buttonClass"
              data-testid="preview-commercial-terms"
              @click="previewCommercialTerms"
            >
              {{ label('PREVIEW_LEAD_ANSWER') }}
            </button>
            <label
              v-if="
                draft.published_commercial_terms
                  ?.promotion_requires_confirmation
              "
              class="flex items-center gap-2 text-sm"
            >
              <input v-model="previewPromotionEligible" type="checkbox" />
              {{ label('PREVIEW_PROMOTION_ELIGIBLE') }}
            </label>
          </div>
          <p
            v-if="pricingPreview"
            class="rounded-lg bg-n-background p-3 text-sm leading-6 text-n-slate-12"
            role="status"
          >
            {{ pricingPreview.answer || label('PRICE_NOT_CURRENT') }}
          </p>
        </section>
        <section
          v-if="draft.id"
          class="grid gap-3 rounded-xl border border-n-weak bg-n-solid-2 p-4 sm:p-5"
          data-testid="business-setup-section"
        >
          <div>
            <h3 class="text-base font-semibold text-n-slate-12">
              {{ label('SETUP_TITLE') }}
            </h3>
            <p class="mt-1 text-sm leading-6 text-n-slate-11">
              {{ label('SETUP_HELP') }}
            </p>
          </div>
          <div class="grid gap-3 sm:grid-cols-2">
            <label class="grid gap-1 text-sm">
              {{ label('SETUP_SOURCE_NAME') }}
              <input
                v-model="setupTitle"
                :class="inputClass"
                :placeholder="label('SETUP_SOURCE_NAME_PLACEHOLDER')"
              />
            </label>
            <label class="grid gap-1 text-sm">
              {{ label('SETUP_SOURCE_TYPE') }}
              <select v-model="setupSourceType" :class="inputClass">
                <option value="pasted_prose">
                  {{ label('SETUP_PASTED_NOTES') }}
                </option>
                <option value="document">
                  {{ label('SETUP_DOCUMENT_TEXT') }}
                </option>
              </select>
            </label>
            <label class="grid gap-1 text-sm sm:col-span-2">
              {{ label('SETUP_BODY_LABEL') }}
              <textarea
                v-model="setupBody"
                class="min-h-28 rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
                :placeholder="label('SETUP_BODY_PLACEHOLDER')"
              />
            </label>
          </div>
          <div class="flex flex-wrap gap-2">
            <button
              type="button"
              :class="buttonClass"
              :disabled="!setupBody.trim() || saving"
              data-testid="propose-business-setup"
              @click="proposeSetup"
            >
              {{ label('SETUP_REVIEW') }}
            </button>
            <span class="text-sm text-n-slate-11">
              {{ label('SETUP_PRICE_HELP') }}
            </span>
          </div>
          <article
            v-for="source in setupSources[draft.id] || []"
            :key="source.id"
            class="grid gap-2 rounded-lg border border-n-weak bg-n-background p-3 text-sm"
          >
            <p class="font-medium text-n-slate-12">
              {{ source.title }}{{ label('SEPARATOR')
              }}{{ setupStatusLabel(source.status) }}
            </p>
            <p v-if="source.proposed_facts?.length">
              <strong>{{ label('SETUP_PROPOSED_FACTS') }}</strong>
              {{ source.proposed_facts.join(' ') }}
            </p>
            <p v-if="source.proposed_rules?.length">
              <strong>{{ label('SETUP_PROPOSED_RULES') }}</strong>
              {{ source.proposed_rules.join(' ') }}
            </p>
            <p class="text-n-slate-11">
              {{ label('SETUP_PROPOSED_CONFIGURATION') }}
              {{ setupModeLabel(source.configuration?.qualification_mode)
              }}{{ label('SEPARATOR')
              }}{{ setupNextStepLabel(source.configuration?.next_step?.kind) }}
            </p>
            <details
              v-if="source.history?.length"
              class="text-n-slate-11"
              data-testid="business-setup-history"
            >
              <summary>{{ label('SETUP_HISTORY') }}</summary>
              <ul class="mt-1 list-disc pl-5">
                <li v-for="revision in source.history" :key="revision.version">
                  {{
                    t('AI_LEAD_EMPLOYEE.OFFERS.SETUP_HISTORY_ENTRY', {
                      version: revision.version,
                      body: revision.body,
                    })
                  }}
                </li>
              </ul>
            </details>
            <ul
              v-if="source.configuration?.questions?.length"
              class="list-disc pl-5 text-n-slate-11"
            >
              <li
                v-for="question in source.configuration.questions"
                :key="question.key"
              >
                {{ question.meaning }}{{ label('SEPARATOR')
                }}{{ setupPurposeLabel(question.purpose) }}
              </li>
            </ul>
            <ul
              v-if="source.configuration?.rules?.length"
              class="list-disc pl-5 text-n-slate-11"
            >
              <li
                v-for="rule in source.configuration.rules"
                :key="`${rule.field}:${rule.priority}`"
              >
                {{ setupRuleSummary(source, rule) }}
              </li>
            </ul>
            <ul
              v-if="source.configuration?.requirement_groups?.length"
              class="list-disc pl-5 text-n-slate-11"
            >
              <li
                v-for="(group, index) in source.configuration
                  .requirement_groups"
                :key="`group-${index}`"
              >
                {{ requirementGroupSummary(source, group) }}
              </li>
            </ul>
            <p v-if="source.unknowns?.length" class="text-n-amber-11">
              <strong>{{ label('SETUP_STILL_NEEDED') }}</strong>
              {{ source.unknowns.join(' ') }}
            </p>
            <p class="text-n-slate-11">
              {{
                t('AI_LEAD_EMPLOYEE.OFFERS.SETUP_VERSION', {
                  version: source.version,
                })
              }}
            </p>
            <button
              v-if="
                source.status === 'proposed' && setupProposal?.id !== source.id
              "
              type="button"
              :class="buttonClass"
              :disabled="saving"
              data-testid="reopen-business-setup"
              @click="reopenSetup(source)"
            >
              {{ label('SETUP_REOPEN') }}
            </button>
            <button
              v-if="
                source.status === 'proposed' && setupProposal?.id === source.id
              "
              type="button"
              :class="buttonClass"
              :disabled="saving"
              data-testid="correct-business-setup"
              @click="correctSetup(source)"
            >
              {{ label('SETUP_SAVE_CORRECTION') }}
            </button>
            <button
              v-if="source.status === 'proposed'"
              type="button"
              class="w-fit min-h-9 rounded-lg bg-n-brand px-3 text-sm font-medium text-white disabled:opacity-40"
              :disabled="saving"
              data-testid="publish-business-setup"
              @click="publishSetup(source)"
            >
              {{ label('SETUP_PUBLISH') }}
            </button>
            <button
              v-if="source.status === 'published'"
              type="button"
              :class="buttonClass"
              :disabled="saving"
              data-testid="edit-published-business-setup"
              @click="editPublishedSetup(source)"
            >
              {{ label('SETUP_EDIT_PUBLISHED') }}
            </button>
            <div v-if="source.status === 'published'" class="grid gap-2">
              <label class="grid gap-1">
                {{ label('SETUP_TEST_QUESTION') }}
                <input
                  v-model="setupQuestions[setupResultKey(source)]"
                  :class="inputClass"
                  :placeholder="label('SETUP_TEST_PLACEHOLDER')"
                  data-testid="business-setup-question"
                />
              </label>
              <button
                type="button"
                :class="buttonClass"
                :disabled="
                  !setupQuestions[setupResultKey(source)]?.trim() || saving
                "
                data-testid="test-business-setup"
                @click="testSetup(source)"
              >
                {{ label('SETUP_TEST') }}
              </button>
              <p
                v-if="setupTestAnswered(source)"
                role="status"
                class="text-n-slate-11"
              >
                {{ label('SETUP_TEST_COMPLETE') }}
              </p>
              <p
                v-else-if="setupTestBlockedReason(source)"
                role="alert"
                class="text-n-ruby-11"
              >
                {{
                  t('AI_LEAD_EMPLOYEE.OFFERS.SETUP_TEST_BLOCKED', {
                    reason: setupTestBlockedReasonLabel(source),
                  })
                }}
              </p>
              <p
                v-else-if="setupTestResult(source)?.status === 'completed'"
                role="alert"
                class="text-n-ruby-11"
              >
                {{ label('SETUP_TEST_NO_ANSWER') }}
              </p>
              <p
                v-else-if="setupTestResult(source)"
                role="alert"
                class="text-n-ruby-11"
              >
                {{ label('SETUP_TEST_FAILED') }}
              </p>
            </div>
          </article>
        </section>
        <div class="grid gap-3 sm:grid-cols-2">
          <label class="grid gap-1 text-sm">
            {{ label('QUALIFICATION_MODE') }}
            <select
              v-model="draft.qualification_mode"
              :class="inputClass"
              data-testid="qualification-mode"
            >
              <option value="not_configured">
                {{ label('MODE_NOT_CONFIGURED') }}
              </option>
              <option value="disabled">
                {{ label('MODE_DISABLED') }}
              </option>
              <option value="enabled">
                {{ label('MODE_ENABLED') }}
              </option>
            </select>
          </label>
          <label class="grid gap-1 text-sm">
            {{ label('NEXT_STEP') }}
            <select
              v-model="draft.next_step.kind"
              :class="inputClass"
              data-testid="next-step"
            >
              <option
                v-for="kind in [
                  'answer_only',
                  'enquiry',
                  'purchase_link',
                  'sales_call',
                  'appointment',
                ]"
                :key="kind"
                :value="kind"
              >
                {{ label(`NEXT_${kind.toUpperCase()}`) }}
              </option>
            </select>
          </label>
        </div>
        <div
          v-if="draft.next_step.kind !== 'answer_only'"
          class="grid gap-3 sm:grid-cols-2"
        >
          <label class="grid gap-1 text-sm">
            {{ label('NEXT_STEP_PROMPT') }}
            <input
              v-model="draft.next_step.prompt"
              :class="inputClass"
              maxlength="240"
              data-testid="next-step-prompt"
            />
          </label>
          <label
            v-if="
              ['purchase_link', 'appointment'].includes(draft.next_step.kind)
            "
            class="grid gap-1 text-sm"
          >
            {{ label('NEXT_STEP_URL') }}
            <input
              v-model="draft.next_step.url"
              :class="inputClass"
              type="url"
              data-testid="next-step-url"
            />
          </label>
        </div>
        <!-- eslint-disable vue/no-bare-strings-in-template -->
        <fieldset class="grid gap-3">
          <legend class="mb-3 text-base font-semibold">
            {{ label('QUESTIONS') }}
          </legend>
          <p class="text-sm text-n-slate-11">
            {{ label('QUESTIONS_HELP') }}
          </p>
          <div
            v-for="(question, index) in draft.questions"
            :key="question.key"
            class="grid gap-3 rounded-lg border border-n-weak p-4"
          >
            <label class="grid gap-1 text-sm">
              {{ label('MEANING') }}
              <input
                v-model="question.meaning"
                required
                :class="inputClass"
                :readonly="Boolean(builtinFields[question.key])"
              />
            </label>
            <label class="grid gap-1 text-sm">
              {{ label('ANSWER_TYPE') }}
              <select
                v-model="question.answer_type"
                :class="inputClass"
                :disabled="Boolean(builtinFields[question.key])"
              >
                <option
                  v-for="type in [
                    'text',
                    'boolean',
                    'number',
                    'money',
                    'choice',
                  ]"
                  :key="type"
                  :value="type"
                >
                  {{ label(`TYPE_${type.toUpperCase()}`) }}
                </option>
              </select>
            </label>
            <label
              v-if="question.answer_type === 'choice'"
              class="grid gap-1 text-sm"
            >
              {{ label('CHOICES') }}
              <textarea
                :value="(question.options || []).join('\n')"
                :class="inputClass"
                @input="
                  question.options = $event.target.value
                    .split('\n')
                    .filter(Boolean)
                "
              />
            </label>
            <label
              v-if="['number', 'money'].includes(question.answer_type)"
              class="grid gap-1 text-sm"
            >
              {{ label('PERIOD') }}
              <input v-model="question.period" :class="inputClass" />
            </label>
            <label class="grid gap-1 text-sm">
              {{ label('PROMPT') }}
              <input
                v-model="question.prompt"
                required
                :class="inputClass"
                :data-testid="`question-prompt-${index}`"
              />
            </label>
            <label class="grid gap-1 text-sm">
              {{ label('PURPOSE') }}
              <select
                v-model="question.purpose"
                :class="inputClass"
                :data-testid="`question-purpose-${index}`"
              >
                <option value="fit">{{ label('PURPOSE_FIT') }}</option>
                <option value="readiness">
                  {{ label('PURPOSE_READINESS') }}
                </option>
                <option value="action_eligibility">
                  {{ label('PURPOSE_ACTION_ELIGIBILITY') }}
                </option>
              </select>
            </label>
            <div class="flex flex-wrap items-center gap-3">
              <label class="flex items-center gap-2 text-sm">
                <input v-model="question.enabled" type="checkbox" />
                {{ label('ENABLED') }}
              </label>
              <label class="flex items-center gap-2 text-sm">
                <input v-model="question.required" type="checkbox" />
                {{ label('REQUIRED') }}
              </label>
              <button
                type="button"
                :class="buttonClass"
                :disabled="index === 0"
                :data-testid="`question-up-${index}`"
                @click="moveQuestion(index, -1)"
              >
                {{ label('UP') }}
              </button>
              <button
                type="button"
                :class="buttonClass"
                :disabled="index === draft.questions.length - 1"
                @click="moveQuestion(index, 1)"
              >
                {{ label('DOWN') }}
              </button>
              <button
                type="button"
                :class="buttonClass"
                @click="draft.questions.splice(index, 1)"
              >
                {{ label('REMOVE') }}
              </button>
            </div>
          </div>
          <div class="flex gap-2">
            <select
              v-model="newField"
              :class="inputClass"
              :aria-label="label('FIELD')"
              data-testid="new-question-field"
            >
              <option
                v-for="(field, key) in builtinFields"
                :key="key"
                :value="key"
                :disabled="
                  draft.questions.some(question => question.key === key)
                "
              >
                {{ field[0] }}
              </option>
              <option value="custom">
                {{ label('CUSTOM') }}
              </option>
            </select>
            <button
              type="button"
              :class="buttonClass"
              data-testid="add-question"
              @click="addQuestion"
            >
              {{ label('ADD_QUESTION') }}
            </button>
          </div>
        </fieldset>
        <label class="grid gap-1 text-sm">
          {{ label('CURRENCY') }}
          <select
            v-model="draft.currency"
            :class="inputClass"
            data-testid="offer-currency"
            @change="changeCurrency"
          >
            <option
              v-for="currency in ['TZS', 'USD', 'KES', 'EUR', 'GBP']"
              :key="currency"
              :value="currency"
            >
              {{ currency }}
            </option>
          </select>
        </label>
        <fieldset class="grid gap-3">
          <legend class="mb-3 text-base font-semibold">
            {{ label('BUDGET_RANGES') }}
          </legend>
          <div
            v-for="(range, index) in draft.budget_ranges"
            :key="index"
            class="grid gap-2 rounded-lg border border-n-weak p-4 sm:grid-cols-2"
          >
            <label class="grid gap-1 text-sm sm:col-span-2">
              {{ label('RANGE') }}
              <input v-model="range.label" required :class="inputClass" />
            </label>
            <label class="grid gap-1 text-sm">
              {{
                t('AI_LEAD_EMPLOYEE.OFFERS.MINIMUM', {
                  currency: draft.currency,
                })
              }}
              <input
                v-model="range.minimum"
                inputmode="decimal"
                :class="inputClass"
                :data-testid="`budget-minimum-${index}`"
              />
            </label>
            <label class="grid gap-1 text-sm">
              {{
                t('AI_LEAD_EMPLOYEE.OFFERS.MAXIMUM', {
                  currency: draft.currency,
                })
              }}
              <input
                v-model="range.maximum"
                inputmode="decimal"
                :class="inputClass"
                :data-testid="`budget-maximum-${index}`"
              />
            </label>
            <label class="flex items-center gap-2 text-sm">
              <input v-model="range.enabled" type="checkbox" />
              {{ label('ENABLED') }}
            </label>
            <button
              type="button"
              :class="buttonClass"
              @click="draft.budget_ranges.splice(index, 1)"
            >
              {{ label('REMOVE') }}
            </button>
          </div>
          <button
            type="button"
            :class="buttonClass"
            data-testid="add-budget-range"
            @click="addRange"
          >
            {{ label('ADD_RANGE') }}
          </button>
        </fieldset>
        <fieldset class="grid gap-3">
          <legend class="mb-3 text-base font-semibold">
            {{ label('RULES') }}
          </legend>
          <p class="text-sm text-n-slate-11">
            {{ label('RULES_HELP') }}
          </p>
          <div
            v-for="(rule, index) in draft.rules"
            :key="index"
            class="grid gap-3 rounded-lg border border-n-weak p-4 sm:grid-cols-2"
          >
            <label class="grid gap-1 text-sm">
              {{ label('FIELD') }}
              <select
                v-model="rule.field"
                :class="inputClass"
                :data-testid="`rule-field-${index}`"
                @change="resetRule(rule)"
              >
                <option
                  v-for="field in fields"
                  :key="field.key"
                  :value="field.key"
                >
                  {{ field.meaning }}
                </option>
              </select>
            </label>
            <label class="grid gap-1 text-sm">
              {{ label('OPERATOR') }}
              <select
                v-model="rule.operator"
                :class="inputClass"
                :data-testid="`rule-operator-${index}`"
                @change="resetRule(rule)"
              >
                <option
                  v-for="operator in operatorsFor(rule)"
                  :key="operator"
                  :value="operator"
                >
                  {{ label(`OP_${operator.toUpperCase()}`) }}
                </option>
              </select>
            </label>
            <label
              v-if="!['positive', 'negative', 'known'].includes(rule.operator)"
              class="grid gap-1 text-sm"
            >
              {{ label('VALUE') }}
              <template v-if="fields[rule.field]?.answer_type === 'money'">
                <span> {{ rule.value.currency }} </span>
                <input
                  v-model="rule.value.amount"
                  inputmode="decimal"
                  required
                  :class="inputClass"
                  :data-testid="`rule-value-${index}`"
                />
              </template>
              <input
                v-else-if="fields[rule.field]?.answer_type === 'number'"
                v-model.number="rule.value"
                type="number"
                step="any"
                required
                :class="inputClass"
                :data-testid="`rule-value-${index}`"
              />
              <select
                v-else-if="fields[rule.field]?.answer_type === 'boolean'"
                v-model="rule.value"
                :class="inputClass"
              >
                <option :value="true">
                  {{ label('YES') }}
                </option>
                <option :value="false">
                  {{ label('NO') }}
                </option>
              </select>
              <select
                v-else-if="fields[rule.field]?.answer_type === 'choice'"
                v-model="rule.value"
                :multiple="rule.operator === 'in'"
                :class="inputClass"
              >
                <option
                  v-for="option in fields[rule.field].options"
                  :key="option"
                  :value="option"
                >
                  {{ option }}
                </option>
              </select>
              <input
                v-else
                v-model="rule.value"
                required
                :class="inputClass"
                :data-testid="`rule-value-${index}`"
              />
            </label>
            <label class="grid gap-1 text-sm">
              {{ label('EFFECT') }}
              <select
                v-model="rule.kind"
                :class="inputClass"
                :data-testid="`rule-effect-${index}`"
                @change="
                  rule.forced_outcome =
                    rule.kind === 'hard_rule' ? 'unqualified' : null
                "
              >
                <option value="score_rule">
                  {{ label('ADD_SCORE') }}
                </option>
                <option value="hard_rule">
                  {{ label('EXCLUDE') }}
                </option>
                <option value="requirement">
                  {{ label('REQUIREMENT') }}
                </option>
              </select>
            </label>
            <label
              v-if="rule.kind === 'requirement'"
              class="grid gap-1 text-sm"
            >
              {{ label('DIMENSION') }}
              <select
                v-model="rule.dimension"
                :class="inputClass"
                :data-testid="`rule-dimension-${index}`"
              >
                <option value="fit">{{ label('PURPOSE_FIT') }}</option>
                <option value="readiness">
                  {{ label('PURPOSE_READINESS') }}
                </option>
                <option value="action_eligibility">
                  {{ label('PURPOSE_ACTION_ELIGIBILITY') }}
                </option>
              </select>
            </label>
            <label v-if="rule.kind === 'score_rule'" class="grid gap-1 text-sm">
              {{ label('SCORE') }}
              <input
                v-model.number="rule.score_delta"
                type="number"
                min="0"
                required
                :class="inputClass"
                :data-testid="`rule-score-${index}`"
              />
            </label>
            <label class="grid gap-1 text-sm">
              {{ label('PRIORITY') }}
              <input
                v-model.number="rule.priority"
                type="number"
                min="0"
                required
                :class="inputClass"
              />
            </label>
            <label class="flex items-center gap-2 text-sm">
              <input v-model="rule.enabled" type="checkbox" />
              {{ label('ENABLED') }}
            </label>
            <button
              type="button"
              :class="buttonClass"
              @click="draft.rules.splice(index, 1)"
            >
              {{ label('REMOVE') }}
            </button>
          </div>
          <button
            type="button"
            :class="buttonClass"
            data-testid="add-rule"
            @click="addRule"
          >
            {{ label('ADD_RULE') }}
          </button>
        </fieldset>
        <fieldset class="grid gap-3">
          <legend class="mb-3 text-base font-semibold">
            Alternative requirements
          </legend>
          <p class="text-sm text-n-slate-11">
            Combine typed requirements with all or any. A satisfied any branch
            does not ask for the other branch.
          </p>
          <div
            v-for="(group, groupIndex) in draft.requirement_groups"
            :key="`requirement-group-${groupIndex}`"
            class="grid gap-3 rounded-lg border border-n-weak p-4"
          >
            <div class="grid gap-3 sm:grid-cols-3">
              <select v-model="group.dimension" :class="inputClass">
                <option value="fit">Fit</option>
                <option value="readiness">Readiness</option>
                <option value="action_eligibility">Action eligibility</option>
              </select>
              <select
                :value="groupBranch(group)"
                :class="inputClass"
                :data-testid="`group-branch-${groupIndex}`"
                @change="changeGroupBranch(group, $event.target.value)"
              >
                <option value="all">All must apply</option>
                <option value="any">Any one can apply</option>
              </select>
              <button
                type="button"
                :class="buttonClass"
                @click="draft.requirement_groups.splice(groupIndex, 1)"
              >
                {{ label('REMOVE') }}
              </button>
            </div>
            <template
              v-for="(node, nodeIndex) in group[groupBranch(group)]"
              :key="nodeIndex"
            >
              <div v-if="node.field" class="grid gap-2 sm:grid-cols-4">
                <select
                  v-model="node.field"
                  :class="inputClass"
                  :data-testid="`group-field-${groupIndex}-${nodeIndex}`"
                  :aria-label="label('FIELD')"
                  @change="resetRule(node)"
                >
                  <option
                    v-for="field in fields"
                    :key="field.key"
                    :value="field.key"
                  >
                    {{ field.meaning }}
                  </option>
                </select>
                <select
                  v-model="node.operator"
                  :class="inputClass"
                  :data-testid="`group-operator-${groupIndex}-${nodeIndex}`"
                  :aria-label="label('OPERATOR')"
                  @change="resetRule(node)"
                >
                  <option
                    v-for="operator in operatorsFor(node)"
                    :key="operator"
                    :value="operator"
                  >
                    {{ label(`OP_${operator.toUpperCase()}`) }}
                  </option>
                </select>
                <template
                  v-if="
                    !['positive', 'negative', 'known'].includes(node.operator)
                  "
                >
                  <input
                    v-if="fields[node.field]?.answer_type === 'money'"
                    v-model="node.value.amount"
                    inputmode="decimal"
                    :class="inputClass"
                    :aria-label="label('VALUE')"
                    :data-testid="`group-value-${groupIndex}-${nodeIndex}`"
                  />
                  <input
                    v-else-if="fields[node.field]?.answer_type === 'number'"
                    v-model.number="node.value"
                    type="number"
                    :class="inputClass"
                    :aria-label="label('VALUE')"
                    :data-testid="`group-value-${groupIndex}-${nodeIndex}`"
                  />
                  <select
                    v-else-if="fields[node.field]?.answer_type === 'boolean'"
                    v-model="node.value"
                    :class="inputClass"
                    :aria-label="label('VALUE')"
                    :data-testid="`group-value-${groupIndex}-${nodeIndex}`"
                  >
                    <option :value="true">{{ label('YES') }}</option>
                    <option :value="false">{{ label('NO') }}</option>
                  </select>
                  <select
                    v-else-if="fields[node.field]?.answer_type === 'choice'"
                    v-model="node.value"
                    :multiple="node.operator === 'in'"
                    :class="inputClass"
                    :aria-label="label('VALUE')"
                    :data-testid="`group-value-${groupIndex}-${nodeIndex}`"
                  >
                    <option
                      v-for="option in fields[node.field].options"
                      :key="option"
                      :value="option"
                    >
                      {{ option }}
                    </option>
                  </select>
                  <input v-else v-model="node.value" :class="inputClass" />
                </template>
                <button
                  type="button"
                  :class="buttonClass"
                  @click="group[groupBranch(group)].splice(nodeIndex, 1)"
                >
                  {{ label('REMOVE') }}
                </button>
              </div>
              <div v-else class="grid gap-2 rounded border border-n-weak p-3">
                <div class="flex gap-2">
                  <span class="text-sm">{{
                    groupBranch(node) === 'all'
                      ? 'All must apply'
                      : 'Any one can apply'
                  }}</span>
                  <button
                    type="button"
                    :class="buttonClass"
                    @click="group[groupBranch(group)].splice(nodeIndex, 1)"
                  >
                    {{ label('REMOVE') }}
                  </button>
                </div>
                <div
                  v-for="(leaf, leafIndex) in node[groupBranch(node)]"
                  :key="leafIndex"
                  class="grid gap-2 sm:grid-cols-4"
                >
                  <select
                    v-model="leaf.field"
                    :class="inputClass"
                    :aria-label="label('FIELD')"
                    @change="resetRule(leaf)"
                  >
                    <option
                      v-for="field in fields"
                      :key="field.key"
                      :value="field.key"
                    >
                      {{ field.meaning }}
                    </option>
                  </select>
                  <select
                    v-model="leaf.operator"
                    :class="inputClass"
                    :aria-label="label('OPERATOR')"
                    @change="resetRule(leaf)"
                  >
                    <option
                      v-for="operator in operatorsFor(leaf)"
                      :key="operator"
                      :value="operator"
                    >
                      {{ label(`OP_${operator.toUpperCase()}`) }}
                    </option>
                  </select>
                  <template
                    v-if="
                      !['positive', 'negative', 'known'].includes(leaf.operator)
                    "
                  >
                    <input
                      v-if="fields[leaf.field]?.answer_type === 'money'"
                      v-model="leaf.value.amount"
                      inputmode="decimal"
                      :class="inputClass"
                      :aria-label="label('VALUE')"
                    />
                    <input
                      v-else-if="fields[leaf.field]?.answer_type === 'number'"
                      v-model.number="leaf.value"
                      type="number"
                      :class="inputClass"
                      :aria-label="label('VALUE')"
                    />
                    <select
                      v-else-if="fields[leaf.field]?.answer_type === 'boolean'"
                      v-model="leaf.value"
                      :class="inputClass"
                      :aria-label="label('VALUE')"
                    >
                      <option :value="true">{{ label('YES') }}</option>
                      <option :value="false">{{ label('NO') }}</option>
                    </select>
                    <select
                      v-else-if="fields[leaf.field]?.answer_type === 'choice'"
                      v-model="leaf.value"
                      :multiple="leaf.operator === 'in'"
                      :class="inputClass"
                      :aria-label="label('VALUE')"
                    >
                      <option
                        v-for="option in fields[leaf.field].options"
                        :key="option"
                        :value="option"
                      >
                        {{ option }}
                      </option>
                    </select>
                    <input v-else v-model="leaf.value" :class="inputClass" />
                  </template>
                  <button
                    type="button"
                    :class="buttonClass"
                    @click="node[groupBranch(node)].splice(leafIndex, 1)"
                  >
                    {{ label('REMOVE') }}
                  </button>
                </div>
                <button
                  type="button"
                  :class="buttonClass"
                  @click="addNestedLeaf(node)"
                >
                  Add requirement
                </button>
              </div>
            </template>
            <div class="flex gap-2">
              <button
                type="button"
                :class="buttonClass"
                @click="addGroupLeaf(group)"
              >
                Add requirement
              </button>
              <button
                type="button"
                :class="buttonClass"
                @click="addNestedGroup(group)"
              >
                Add all/any branch
              </button>
            </div>
          </div>
          <button
            type="button"
            :class="buttonClass"
            data-testid="add-requirement-group"
            @click="addRequirementGroup"
          >
            Add alternative group
          </button>
        </fieldset>
        <!-- eslint-enable vue/no-bare-strings-in-template -->
        <fieldset class="grid gap-3 sm:grid-cols-2">
          <legend class="mb-3 text-base font-semibold">
            {{ label('THRESHOLDS') }}
          </legend>
          <label
            v-for="key in ['qualified', 'highly_qualified']"
            :key="key"
            class="grid gap-1 text-sm"
          >
            {{ label(key.toUpperCase()) }}
            <input
              v-model.number="draft.score_thresholds[key]"
              type="number"
              min="0"
              required
              :class="inputClass"
            />
          </label>
        </fieldset>
        <button
          type="submit"
          formnovalidate
          data-testid="save-offer"
          :disabled="saving || conflicted"
          class="min-h-10 justify-self-start rounded-lg bg-n-brand px-4 text-sm font-medium text-white disabled:opacity-50"
        >
          {{ label(saving ? 'SAVING' : 'SAVE') }}
        </button>
      </fieldset>
    </form>
  </section>
</template>

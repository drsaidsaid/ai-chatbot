<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import OffersAPI from 'dashboard/api/qualificationOffers';

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
const loading = ref(true);
const saving = ref(false);
const error = ref('');
const status = ref('');
const conflicts = reactive({});
const conflicted = computed(() => Boolean(conflicts[draft.value?.id]));
const label = key => t(`AI_LEAD_EMPLOYEE.OFFERS.${key}`);
const inputClass =
  'h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12';
const buttonClass =
  'min-h-9 rounded-lg border border-n-weak px-3 text-sm text-n-slate-12 disabled:opacity-40';
const selectDraft = key => {
  draft.value = drafts[key];
  error.value = '';
  status.value = '';
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
    score_weights: {},
    score_thresholds: { qualified: 60, highly_qualified: 80 },
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

const save = async () => {
  if (saving.value || conflicted.value) return;
  saving.value = true;
  error.value = '';
  status.value = '';
  try {
    const payload = { offer: JSON.parse(JSON.stringify(draft.value)) };
    payload.offer.questions.forEach((question, position) => {
      question.position = position;
    });
    payload.offer.budget_ranges.forEach((range, position) => {
      range.position = position;
    });
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
          :disabled="saving || conflicted"
          class="min-h-10 justify-self-start rounded-lg bg-n-brand px-4 text-sm font-medium text-white disabled:opacity-50"
        >
          {{ label(saving ? 'SAVING' : 'SAVE') }}
        </button>
      </fieldset>
    </form>
  </section>
</template>

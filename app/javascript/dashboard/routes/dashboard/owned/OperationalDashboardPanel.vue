<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import OperationalDashboardAPI from 'dashboard/api/operationalDashboard';

const props = defineProps({
  surface: {
    type: String,
    required: true,
  },
});

const { t } = useI18n();
const route = useRoute();

const STORAGE_KEY = 'aiLeadEmployee.savedQueues';
const leads = ref([]);
const performance = ref({});
const filterOptions = ref({
  qualities: [],
  follow_up_states: [],
  assignees: [],
  sources: [],
  booking_statuses: [],
  review_statuses: [],
  follow_up_statuses: [],
  control_states: [],
});
const builtInQueues = ref([]);
const metrics = computed(() => [
  {
    key: 'total_leads',
    label: t('AI_LEAD_EMPLOYEE.DASHBOARD.METRIC.TOTAL_LEADS'),
  },
  {
    key: 'highly_qualified_leads',
    label: t('AI_LEAD_EMPLOYEE.DASHBOARD.METRIC.HIGHLY_QUALIFIED'),
  },
  {
    key: 'unanswered_questions',
    label: t('AI_LEAD_EMPLOYEE.DASHBOARD.METRIC.UNANSWERED'),
  },
  {
    key: 'booked_calls',
    label: t('AI_LEAD_EMPLOYEE.DASHBOARD.METRIC.BOOKED_CALLS'),
  },
  {
    key: 'knowledge_approvals',
    label: t('AI_LEAD_EMPLOYEE.DASHBOARD.METRIC.KNOWLEDGE_APPROVALS'),
  },
  {
    key: 'human_active_conversations',
    label: t('AI_LEAD_EMPLOYEE.DASHBOARD.METRIC.HUMAN_ACTIVE'),
  },
  {
    key: 'ai_active_conversations',
    label: t('AI_LEAD_EMPLOYEE.DASHBOARD.METRIC.AI_ACTIVE'),
  },
]);
const queueLabels = computed(() => ({
  all_leads: t('AI_LEAD_EMPLOYEE.DASHBOARD.QUEUE.ALL_LEADS'),
  hot_leads: t('AI_LEAD_EMPLOYEE.DASHBOARD.QUEUE.HOT_LEADS'),
  unanswered_questions: t(
    'AI_LEAD_EMPLOYEE.DASHBOARD.QUEUE.UNANSWERED_QUESTIONS'
  ),
  reviews: t('AI_LEAD_EMPLOYEE.DASHBOARD.QUEUE.REVIEWS'),
  knowledge_approval: t('AI_LEAD_EMPLOYEE.DASHBOARD.QUEUE.KNOWLEDGE_APPROVAL'),
  booked_calls: t('AI_LEAD_EMPLOYEE.DASHBOARD.QUEUE.BOOKED_CALLS'),
  follow_up: t('AI_LEAD_EMPLOYEE.DASHBOARD.QUEUE.FOLLOW_UP'),
  unassigned: t('AI_LEAD_EMPLOYEE.DASHBOARD.QUEUE.UNASSIGNED'),
  my_queue: t('AI_LEAD_EMPLOYEE.DASHBOARD.QUEUE.MY_QUEUE'),
  ai_active: t('AI_LEAD_EMPLOYEE.DASHBOARD.QUEUE.AI_ACTIVE'),
  human_active: t('AI_LEAD_EMPLOYEE.DASHBOARD.QUEUE.HUMAN_ACTIVE'),
}));
const isLoading = ref(false);
const savedQueues = ref([]);
const queueName = ref('');
const filters = ref({
  quality: '',
  follow_up_state: '',
  assignee_id: '',
  source_id: '',
  unanswered: false,
  review_status: '',
  follow_up_status: '',
  knowledge_approval: false,
  booking_status: '',
  control_state: '',
});

const surfaceFilters = computed(() => {
  if (props.surface === 'HOT_LEADS') return { quality: 'highly_qualified' };
  if (props.surface === 'REVIEWS') return { review_status: 'open' };
  if (props.surface === 'BOOKINGS') return { booking_status: 'booked' };
  return {};
});

const requestFilters = computed(() => ({
  ...surfaceFilters.value,
  ...Object.fromEntries(
    Object.entries(filters.value).filter(
      ([, value]) => value !== '' && value !== false
    )
  ),
}));

const conversationPath = row =>
  `/app/accounts/${route.params.accountId}/conversations/${row.conversation_display_id}`;

const loadSavedQueues = () => {
  try {
    savedQueues.value =
      JSON.parse(window.localStorage.getItem(STORAGE_KEY)) || [];
  } catch {
    savedQueues.value = [];
  }
};

const persistSavedQueues = () => {
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(savedQueues.value));
};

const saveQueue = () => {
  if (!queueName.value.trim()) return;

  const queue = {
    id: Date.now(),
    name: queueName.value.trim(),
    filters: { ...filters.value },
  };
  savedQueues.value = [
    queue,
    ...savedQueues.value.filter(item => item.name !== queue.name),
  ].slice(0, 8);
  queueName.value = '';
  persistSavedQueues();
};

const applyQueue = queue => {
  filters.value = { ...filters.value, ...queue.filters };
};

const loadDashboard = async () => {
  isLoading.value = true;
  try {
    const { data } = await OperationalDashboardAPI.get(requestFilters.value);
    leads.value = data.leads || [];
    performance.value = data.performance || {};
    filterOptions.value = data.filter_options || filterOptions.value;
    builtInQueues.value = data.queues || [];
  } finally {
    isLoading.value = false;
  }
};

const clearFilters = () => {
  filters.value = {
    quality: '',
    follow_up_state: '',
    assignee_id: '',
    source_id: '',
    unanswered: false,
    review_status: '',
    follow_up_status: '',
    knowledge_approval: false,
    booking_status: '',
    control_state: '',
  };
};

const applyBuiltInQueue = queue => {
  clearFilters();
  filters.value = { ...filters.value, ...queue.filters };
};

const queueLabel = queue =>
  queueLabels.value[queue.key] || queueLabels.value.all_leads;

const humanize = value =>
  value
    ? value
        .split('_')
        .map(word => word.charAt(0).toUpperCase() + word.slice(1))
        .join(' ')
    : t('AI_LEAD_EMPLOYEE.DASHBOARD.EMPTY_VALUE');

watch(requestFilters, loadDashboard, { deep: true });
watch(() => props.surface, clearFilters);

onMounted(() => {
  loadSavedQueues();
  loadDashboard();
});
</script>

<template>
  <section class="mt-6 grid gap-4">
    <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-7">
      <div
        v-for="metric in metrics"
        :key="metric.key"
        class="border border-n-weak bg-n-solid-1 p-4"
      >
        <p class="text-xs font-medium uppercase text-n-slate-11">
          {{ metric.label }}
        </p>
        <p class="mt-2 text-2xl font-semibold text-n-slate-12">
          {{ performance[metric.key] ?? 0 }}
        </p>
      </div>
    </div>

    <form
      class="grid gap-3 border border-n-weak bg-n-solid-1 p-4 md:grid-cols-2 xl:grid-cols-9"
      @submit.prevent="saveQueue"
    >
      <div
        v-if="builtInQueues.length"
        class="flex flex-wrap gap-2 md:col-span-2 xl:col-span-9"
      >
        <button
          v-for="queue in builtInQueues"
          :key="queue.key"
          type="button"
          class="rounded-md border border-n-weak px-3 py-1 text-sm text-n-slate-12"
          @click="applyBuiltInQueue(queue)"
        >
          {{ queueLabel(queue) }}
        </button>
      </div>
      <select
        v-model="filters.quality"
        class="min-w-0 rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm"
      >
        <option value="">
          {{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FILTER.QUALITY') }}
        </option>
        <option
          v-for="quality in filterOptions.qualities"
          :key="quality"
          :value="quality"
        >
          {{ humanize(quality) }}
        </option>
      </select>
      <select
        v-model="filters.follow_up_state"
        class="min-w-0 rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm"
      >
        <option value="">
          {{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FILTER.FOLLOW_UP') }}
        </option>
        <option
          v-for="state in filterOptions.follow_up_states"
          :key="state"
          :value="state"
        >
          {{ humanize(state) }}
        </option>
      </select>
      <select
        v-model="filters.assignee_id"
        class="min-w-0 rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm"
      >
        <option value="">
          {{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FILTER.ASSIGNEE') }}
        </option>
        <option value="me">
          {{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FILTER.ME') }}
        </option>
        <option value="unassigned">
          {{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FILTER.UNASSIGNED') }}
        </option>
        <option
          v-for="assignee in filterOptions.assignees"
          :key="assignee.id"
          :value="assignee.id"
        >
          {{ assignee.name }}
        </option>
      </select>
      <select
        v-model="filters.source_id"
        class="min-w-0 rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm"
      >
        <option value="">
          {{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FILTER.SOURCE') }}
        </option>
        <option
          v-for="source in filterOptions.sources"
          :key="source.id"
          :value="source.id"
        >
          {{ source.name }}
        </option>
      </select>
      <select
        v-model="filters.booking_status"
        class="min-w-0 rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm"
      >
        <option value="">
          {{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FILTER.BOOKING') }}
        </option>
        <option
          v-for="status in filterOptions.booking_statuses"
          :key="status"
          :value="status"
        >
          {{ humanize(status) }}
        </option>
      </select>
      <select
        v-model="filters.review_status"
        class="min-w-0 rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm"
      >
        <option value="">
          {{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FILTER.REVIEW') }}
        </option>
        <option
          v-for="status in filterOptions.review_statuses"
          :key="status"
          :value="status"
        >
          {{ humanize(status) }}
        </option>
      </select>
      <select
        v-model="filters.follow_up_status"
        class="min-w-0 rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm"
      >
        <option value="">
          {{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FILTER.FOLLOW_UP_STATUS') }}
        </option>
        <option
          v-for="status in filterOptions.follow_up_statuses"
          :key="status"
          :value="status"
        >
          {{ humanize(status) }}
        </option>
      </select>
      <select
        v-model="filters.control_state"
        class="min-w-0 rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm"
      >
        <option value="">
          {{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FILTER.CONTROL_STATE') }}
        </option>
        <option
          v-for="state in filterOptions.control_states"
          :key="state"
          :value="state"
        >
          {{ humanize(state) }}
        </option>
      </select>
      <label class="flex min-w-0 items-center gap-2 text-sm text-n-slate-12">
        <input
          v-model="filters.unanswered"
          type="checkbox"
          class="rounded border-n-weak"
        />
        {{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FILTER.UNANSWERED') }}
      </label>
      <label class="flex min-w-0 items-center gap-2 text-sm text-n-slate-12">
        <input
          v-model="filters.knowledge_approval"
          type="checkbox"
          class="rounded border-n-weak"
        />
        {{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FILTER.KNOWLEDGE_APPROVAL') }}
      </label>
      <div class="flex gap-2 md:col-span-2 xl:col-span-9">
        <input
          v-model="queueName"
          class="min-w-0 flex-1 rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm"
          :placeholder="t('AI_LEAD_EMPLOYEE.DASHBOARD.SAVED_QUEUE_PLACEHOLDER')"
        />
        <button
          type="submit"
          class="rounded-md bg-n-brand px-3 py-2 text-sm font-medium text-white"
        >
          {{ t('AI_LEAD_EMPLOYEE.DASHBOARD.SAVE_QUEUE') }}
        </button>
        <button
          type="button"
          class="rounded-md border border-n-weak px-3 py-2 text-sm font-medium text-n-slate-12"
          @click="clearFilters"
        >
          {{ t('AI_LEAD_EMPLOYEE.DASHBOARD.CLEAR') }}
        </button>
      </div>
      <div
        v-if="savedQueues.length"
        class="flex flex-wrap gap-2 md:col-span-2 xl:col-span-9"
      >
        <button
          v-for="queue in savedQueues"
          :key="queue.id"
          type="button"
          class="rounded-md border border-n-weak px-3 py-1 text-sm text-n-slate-12"
          @click="applyQueue(queue)"
        >
          {{ queue.name }}
        </button>
      </div>
    </form>

    <section class="overflow-x-auto border border-n-weak bg-n-solid-1">
      <div class="min-w-[1240px]">
        <div
          class="grid grid-cols-[1.1fr_1fr_0.8fr_1.2fr_0.8fr_0.9fr_0.8fr_0.8fr_0.9fr] gap-3 border-b border-n-weak px-4 py-3 text-xs font-medium uppercase text-n-slate-11"
        >
          <span>{{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FIELD.LEAD') }}</span>
          <span>{{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FIELD.CONTACT') }}</span>
          <span>{{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FIELD.QUALITY') }}</span>
          <span>{{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FIELD.REASONS') }}</span>
          <span>{{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FIELD.ASSIGNEE') }}</span>
          <span>{{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FIELD.SOURCE') }}</span>
          <span>{{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FIELD.FOLLOW_UP') }}</span>
          <span>{{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FIELD.CONTROL') }}</span>
          <span>{{ t('AI_LEAD_EMPLOYEE.DASHBOARD.FIELD.BOOKING') }}</span>
        </div>
        <div v-if="isLoading" class="px-4 py-6 text-sm text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.DASHBOARD.LOADING') }}
        </div>
        <div
          v-else-if="!leads.length"
          class="px-4 py-6 text-sm text-n-slate-11"
        >
          {{ t('AI_LEAD_EMPLOYEE.DASHBOARD.EMPTY') }}
        </div>
        <template v-else>
          <a
            v-for="lead in leads"
            :key="lead.id"
            class="grid grid-cols-[1.1fr_1fr_0.8fr_1.2fr_0.8fr_0.9fr_0.8fr_0.8fr_0.9fr] gap-3 border-b border-n-weak px-4 py-3 text-sm text-n-slate-12 hover:bg-n-alpha-2"
            :href="conversationPath(lead)"
          >
            <span class="min-w-0">
              <span class="block truncate font-medium">{{ lead.name }}</span>
              <span class="block text-xs text-n-slate-11">
                {{
                  t('AI_LEAD_EMPLOYEE.DASHBOARD.CONVERSATION_NUMBER', {
                    id: lead.conversation_display_id,
                  })
                }}
              </span>
            </span>
            <span class="min-w-0">
              <span class="block truncate">
                {{ lead.phone_number || humanize('') }}
              </span>
              <span class="block truncate text-xs text-n-slate-11">
                {{ lead.email || humanize('') }}
              </span>
            </span>
            <span>{{ humanize(lead.quality) }}</span>
            <span class="min-w-0 truncate">
              {{ lead.reasons?.join(', ') || humanize('') }}
            </span>
            <span class="min-w-0 truncate">
              {{
                lead.assignee?.name ||
                t('AI_LEAD_EMPLOYEE.DASHBOARD.UNASSIGNED')
              }}
            </span>
            <span class="min-w-0 truncate">{{ lead.source?.name }}</span>
            <span>{{ humanize(lead.follow_up_state) }}</span>
            <span>{{ humanize(lead.control_state) }}</span>
            <span>{{ humanize(lead.booking_state) }}</span>
          </a>
        </template>
      </div>
    </section>
  </section>
</template>

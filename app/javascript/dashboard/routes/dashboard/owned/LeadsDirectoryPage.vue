<script setup>
import { computed, nextTick, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import Icon from 'next/icon/Icon.vue';
import LeadsAPI from 'dashboard/api/leads';
import LeadDetail from './LeadDetail.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const leads = ref([]);
const selectedLead = ref(null);
const counts = ref({});
const meta = ref({
  page: 1,
  per_page: 25,
  total_count: 0,
  total_pages: 1,
  sort: 'last_contact',
  direction: 'desc',
});
const filterOptions = ref({
  qualities: [],
  follow_up_states: [],
  booking_statuses: [],
  assignees: [],
  sources: [],
});
const isLoading = ref(false);
const isExporting = ref(false);
const errorMessage = ref('');
const statusMessage = ref('');
const showMoreFilters = ref(false);
const showEditModal = ref(false);
const showMobileDetail = ref(false);
const importInput = ref(null);
const selectedLeadIds = ref(new Set());
const editErrors = ref([]);
const editForm = reactive({
  name: '',
  phone_number: '',
  email: '',
  business_name: '',
  city: '',
  country: '',
  assignee_id: '',
  evidence: {
    problem: '',
    budget: '',
    urgency: '',
    decision_authority: '',
  },
});
const uiFilters = reactive({
  q: '',
  quality: 'all',
  follow_up_state: '',
  assignee_id: '',
  source_id: '',
  booking_status: '',
  page: 1,
  per_page: 25,
  sort: 'last_contact',
  direction: 'desc',
  lead_id: '',
});
let searchTimer;

const qualityChips = computed(() => [
  {
    key: 'all',
    label: t('AI_LEAD_EMPLOYEE.LEADS.QUALITY.ALL'),
    tone: 'border-n-blue-4 bg-n-blue-2 text-n-blue-11',
  },
  {
    key: 'highly_qualified',
    label: t('AI_LEAD_EMPLOYEE.LEADS.QUALITY.HIGHLY_QUALIFIED'),
    tone: 'border-n-teal-4 bg-n-teal-2 text-n-teal-11',
  },
  {
    key: 'qualified',
    label: t('AI_LEAD_EMPLOYEE.LEADS.QUALITY.QUALIFIED'),
    tone: 'border-n-blue-4 bg-n-blue-2 text-n-blue-11',
  },
  {
    key: 'low_qualified',
    label: t('AI_LEAD_EMPLOYEE.LEADS.QUALITY.LOW_QUALIFIED'),
    tone: 'border-n-amber-4 bg-n-amber-2 text-n-amber-11',
  },
  {
    key: 'unqualified',
    label: t('AI_LEAD_EMPLOYEE.LEADS.QUALITY.UNQUALIFIED'),
    tone: 'border-n-ruby-4 bg-n-ruby-2 text-n-ruby-11',
  },
  {
    key: 'unknown',
    label: t('AI_LEAD_EMPLOYEE.LEADS.QUALITY.UNKNOWN'),
    tone: 'border-n-slate-4 bg-n-slate-2 text-n-slate-11',
  },
]);

const pageStart = computed(() => {
  if (!meta.value.total_count) return 0;
  return (meta.value.page - 1) * meta.value.per_page + 1;
});

const pageEnd = computed(() =>
  Math.min(meta.value.page * meta.value.per_page, meta.value.total_count)
);

const hasNextPage = computed(() => meta.value.page < meta.value.total_pages);
const hasPreviousPage = computed(() => meta.value.page > 1);
const pageLeadIds = computed(() => leads.value.map(lead => lead.id));
const selectedLeadIdsOnPage = computed(() =>
  pageLeadIds.value.filter(id => selectedLeadIds.value.has(id))
);
const allPageLeadsSelected = computed(
  () =>
    pageLeadIds.value.length > 0 &&
    selectedLeadIdsOnPage.value.length === pageLeadIds.value.length
);
const somePageLeadsSelected = computed(
  () => selectedLeadIdsOnPage.value.length > 0 && !allPageLeadsSelected.value
);

const cleanQuery = query =>
  Object.fromEntries(
    Object.entries(query).filter(([, value]) => value !== '' && value !== null)
  );

const hydrateFromRoute = () => {
  uiFilters.q = route.query.q?.toString() || '';
  uiFilters.quality = route.query.quality?.toString() || 'all';
  uiFilters.follow_up_state = route.query.follow_up_state?.toString() || '';
  uiFilters.assignee_id = route.query.assignee_id?.toString() || '';
  uiFilters.source_id = route.query.source_id?.toString() || '';
  uiFilters.booking_status = route.query.booking_status?.toString() || '';
  uiFilters.page = Number(route.query.page || 1);
  uiFilters.per_page = Number(route.query.per_page || 25);
  uiFilters.sort = route.query.sort?.toString() || 'last_contact';
  uiFilters.direction = route.query.direction?.toString() || 'desc';
  uiFilters.lead_id = route.query.lead_id?.toString() || '';
};

const requestParams = () =>
  cleanQuery({
    q: uiFilters.q,
    quality: uiFilters.quality === 'all' ? '' : uiFilters.quality,
    follow_up_state: uiFilters.follow_up_state,
    assignee_id: uiFilters.assignee_id,
    source_id: uiFilters.source_id,
    booking_status: uiFilters.booking_status,
    page: uiFilters.page,
    per_page: uiFilters.per_page,
    sort: uiFilters.sort,
    direction: uiFilters.direction,
    lead_id: uiFilters.lead_id,
  });

const replaceQuery = partial => {
  router.replace({
    name: route.name,
    params: route.params,
    query: cleanQuery({
      ...route.query,
      ...partial,
    }),
  });
};

const applyFilter = partial => {
  showMobileDetail.value = false;
  replaceQuery({ ...partial, page: 1 });
};

const isMobileViewport = () =>
  typeof window !== 'undefined' &&
  typeof window.matchMedia === 'function' &&
  window.matchMedia('(max-width: 1023px)').matches;

const loadLeads = async () => {
  isLoading.value = true;
  errorMessage.value = '';
  try {
    const { data } = await LeadsAPI.get(requestParams());
    leads.value = data.leads || [];
    selectedLead.value = data.selected_lead || leads.value[0] || null;
    showMobileDetail.value = Boolean(uiFilters.lead_id && isMobileViewport());
    counts.value = data.counts || {};
    meta.value = { ...meta.value, ...(data.meta || {}) };
    filterOptions.value = data.filter_options || filterOptions.value;
  } catch (error) {
    errorMessage.value =
      error.response?.data?.error || t('AI_LEAD_EMPLOYEE.LEADS.LOAD_ERROR');
  } finally {
    isLoading.value = false;
  }
};

const selectLead = lead => {
  selectedLead.value = lead;
  if (isMobileViewport()) {
    showMobileDetail.value = true;
  }
  replaceQuery({ lead_id: lead.id });
};

const isLeadBulkSelected = lead => selectedLeadIds.value.has(lead.id);

const toggleLeadBulkSelection = lead => {
  const nextSelectedIds = new Set(selectedLeadIds.value);
  if (nextSelectedIds.has(lead.id)) {
    nextSelectedIds.delete(lead.id);
  } else {
    nextSelectedIds.add(lead.id);
  }
  selectedLeadIds.value = nextSelectedIds;
  selectLead(lead);
};

const togglePageBulkSelection = () => {
  const nextSelectedIds = new Set(selectedLeadIds.value);
  if (allPageLeadsSelected.value) {
    pageLeadIds.value.forEach(id => nextSelectedIds.delete(id));
  } else {
    pageLeadIds.value.forEach(id => nextSelectedIds.add(id));
  }
  selectedLeadIds.value = nextSelectedIds;
};

const sortBy = sort => {
  const nextDirection =
    uiFilters.sort === sort && uiFilters.direction === 'desc' ? 'asc' : 'desc';
  applyFilter({ sort, direction: nextDirection });
};

const pageTo = page => {
  replaceQuery({ page });
};

const clearFilters = () => {
  showMobileDetail.value = false;
  replaceQuery({
    q: '',
    quality: '',
    follow_up_state: '',
    assignee_id: '',
    source_id: '',
    booking_status: '',
    page: 1,
    lead_id: '',
  });
};

const humanize = value =>
  value
    ? value
        .toString()
        .replace(/[._-]/g, ' ')
        .split(' ')
        .filter(Boolean)
        .map(word => word.charAt(0).toUpperCase() + word.slice(1))
        .join(' ')
    : t('AI_LEAD_EMPLOYEE.LEADS.EMPTY_VALUE');

const translateOrFallback = (key, fallback) => {
  // eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys
  const translated = t(key);
  return translated === key ? fallback : translated;
};

const labelFor = (group, value) => {
  if (!value) return t('AI_LEAD_EMPLOYEE.LEADS.EMPTY_VALUE');

  return translateOrFallback(
    `AI_LEAD_EMPLOYEE.LEADS.${group}.${value.toString().toUpperCase()}`,
    humanize(value)
  );
};

const qualityLabel = value => labelFor('QUALITY', value);
const followUpLabel = value => labelFor('FOLLOW_UP_STATE', value);
const bookingStatusLabel = value => labelFor('BOOKING_STATUS', value);
const importStatusLabel = value => labelFor('IMPORT_STATUS', value);
const nextActionLabel = action => labelFor('NEXT_ACTION', action?.key);
const bookingLabel = booking => labelFor('BOOKING_LABEL', booking?.key);
const channelKindLabel = value => labelFor('CHANNEL_KIND', value);
const evidenceSignalLabel = value => labelFor('EVIDENCE_SIGNAL', value);
const conversationStateLabel = value => labelFor('CONVERSATION_STATE', value);

const formatTime = value => {
  if (!value) return t('AI_LEAD_EMPLOYEE.LEADS.EMPTY_VALUE');
  return new Intl.DateTimeFormat(undefined, {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(new Date(value));
};

const compactTime = value => {
  if (!value) return '';
  return new Intl.DateTimeFormat(undefined, {
    hour: 'numeric',
    minute: '2-digit',
  }).format(new Date(value));
};

const qualityToneClass = quality => {
  if (quality === 'highly_qualified') return 'bg-n-teal-3 text-n-teal-11';
  if (quality === 'qualified') return 'bg-n-blue-3 text-n-blue-11';
  if (quality === 'low_qualified') return 'bg-n-amber-3 text-n-amber-11';
  if (quality === 'unqualified') return 'bg-n-ruby-3 text-n-ruby-11';
  return 'bg-n-slate-3 text-n-slate-11';
};

const bookingToneClass = booking => {
  if (booking?.status === 'confirmed' || booking?.status === 'booked') {
    return 'bg-n-blue-3 text-n-blue-11';
  }
  if (booking?.status === 'canceled') return 'bg-n-ruby-3 text-n-ruby-11';
  return 'bg-n-slate-3 text-n-slate-11';
};

const sourceIcon = source => {
  const type =
    source?.channel_type?.toLowerCase() || source?.name?.toLowerCase();
  if (type?.includes('facebook')) return 'i-lucide-megaphone';
  if (type?.includes('instagram')) return 'i-lucide-camera';
  if (type?.includes('whatsapp')) return 'i-lucide-message-circle';
  return 'i-lucide-users-round';
};

const sortIcon = sort =>
  uiFilters.sort === sort && uiFilters.direction === 'asc'
    ? 'i-lucide-arrow-up'
    : 'i-lucide-arrow-down';

const openImportPicker = () => {
  importInput.value?.click();
};

const importLeads = async event => {
  const [file] = event.target.files || [];
  if (!file) return;

  statusMessage.value = '';
  errorMessage.value = '';
  try {
    const { data } = await LeadsAPI.importLeads(file);
    const result = data.import || {};
    statusMessage.value = t('AI_LEAD_EMPLOYEE.LEADS.IMPORT_RESULT', {
      status: importStatusLabel(result.status),
      imported: result.imported_count || 0,
      failed: result.failed_count || 0,
    });
    await loadLeads();
  } catch (error) {
    errorMessage.value =
      error.response?.data?.error ||
      (error.response?.data?.error_key
        ? labelFor('ERROR', error.response.data.error_key)
        : t('AI_LEAD_EMPLOYEE.LEADS.IMPORT_ERROR'));
  } finally {
    event.target.value = '';
  }
};

const exportLeads = async () => {
  isExporting.value = true;
  statusMessage.value = '';
  errorMessage.value = '';
  try {
    const { data } = await LeadsAPI.exportLeads(requestParams());
    const url = window.URL.createObjectURL(data);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'leads.csv';
    link.click();
    window.URL.revokeObjectURL(url);
    statusMessage.value = t('AI_LEAD_EMPLOYEE.LEADS.EXPORT_STARTED');
  } catch (error) {
    errorMessage.value =
      error.response?.data?.error || t('AI_LEAD_EMPLOYEE.LEADS.EXPORT_ERROR');
  } finally {
    isExporting.value = false;
  }
};

const openEditModal = () => {
  if (!selectedLead.value) return;
  const fields = selectedLead.value.detail?.editable_fields || {};
  editForm.name = fields.name || selectedLead.value.name || '';
  editForm.phone_number =
    fields.phone_number || selectedLead.value.phone_number || '';
  editForm.email = fields.email || selectedLead.value.email || '';
  editForm.business_name =
    fields.business_name || selectedLead.value.business_name || '';
  editForm.city = fields.city || '';
  editForm.country = fields.country || '';
  editForm.assignee_id = fields.assignee_id || '';
  editForm.evidence.problem = fields.evidence?.problem || '';
  editForm.evidence.budget = fields.evidence?.budget || '';
  editForm.evidence.urgency = fields.evidence?.urgency || '';
  editForm.evidence.decision_authority =
    fields.evidence?.decision_authority || '';
  editErrors.value = [];
  showEditModal.value = true;
};

const validateEditForm = () => {
  const errors = [];
  if (!editForm.name.trim()) {
    errors.push(t('AI_LEAD_EMPLOYEE.LEADS.EDIT.NAME_REQUIRED'));
  }
  if (
    editForm.phone_number &&
    !/^\+[1-9]\d{1,14}$/.test(editForm.phone_number)
  ) {
    errors.push(t('AI_LEAD_EMPLOYEE.LEADS.EDIT.PHONE_INVALID'));
  }
  editErrors.value = errors;
  return errors.length === 0;
};

const saveLead = async () => {
  if (!selectedLead.value || !validateEditForm()) return;

  errorMessage.value = '';
  try {
    const { data } = await LeadsAPI.update(selectedLead.value.id, {
      lead: {
        name: editForm.name,
        phone_number: editForm.phone_number,
        email: editForm.email,
        business_name: editForm.business_name,
        city: editForm.city,
        country: editForm.country,
        assignee_id: editForm.assignee_id,
        evidence: editForm.evidence,
      },
    });
    selectedLead.value = data;
    statusMessage.value = t('AI_LEAD_EMPLOYEE.LEADS.EDIT.SAVED');
    showEditModal.value = false;
    await loadLeads();
  } catch (error) {
    editErrors.value = [
      error.response?.data?.error || t('AI_LEAD_EMPLOYEE.LEADS.EDIT.ERROR'),
    ];
  }
};

watch(
  () => route.query,
  async () => {
    hydrateFromRoute();
    await loadLeads();
  },
  { immediate: true }
);

watch(
  () => uiFilters.q,
  value => {
    window.clearTimeout(searchTimer);
    searchTimer = window.setTimeout(() => {
      if (value !== (route.query.q || '')) {
        applyFilter({ q: value, lead_id: '' });
      }
    }, 250);
  }
);

watch(showEditModal, async value => {
  if (value) await nextTick();
});
</script>

<template>
  <section
    class="flex h-full min-h-0 w-full flex-col overflow-hidden bg-n-background text-n-slate-12"
    data-testid="leads-directory"
  >
    <header
      class="flex min-h-[72px] shrink-0 items-center gap-3 border-b border-n-weak bg-n-background px-4 lg:px-5"
    >
      <h1 class="min-w-0 shrink-0 text-xl font-semibold text-n-slate-12">
        {{ t('AI_LEAD_EMPLOYEE.LEADS.TITLE') }}
      </h1>
      <label class="sr-only" for="leads-search">
        {{ t('AI_LEAD_EMPLOYEE.LEADS.SEARCH') }}
      </label>
      <div class="relative hidden min-w-[280px] max-w-[414px] flex-1 md:block">
        <Icon
          icon="i-lucide-search"
          class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-n-slate-10"
        />
        <input
          id="leads-search"
          v-model="uiFilters.q"
          type="search"
          class="h-9 w-full rounded-lg border border-n-weak bg-n-solid-1 py-2 pl-9 pr-3 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-10 focus:border-n-brand"
          :placeholder="t('AI_LEAD_EMPLOYEE.LEADS.SEARCH')"
        />
      </div>
      <div class="ml-auto flex shrink-0 items-center gap-2">
        <input
          ref="importInput"
          type="file"
          accept=".csv,text/csv"
          class="sr-only"
          @change="importLeads"
        />
        <button
          type="button"
          class="inline-flex h-9 items-center gap-2 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
          @click="openImportPicker"
        >
          <Icon icon="i-lucide-upload" class="size-4" />
          <span class="hidden sm:inline">{{
            t('AI_LEAD_EMPLOYEE.LEADS.IMPORT')
          }}</span>
        </button>
        <button
          type="button"
          class="inline-flex h-9 items-center gap-2 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand disabled:opacity-60"
          :disabled="isExporting"
          @click="exportLeads"
        >
          <Icon icon="i-lucide-download" class="size-4" />
          <span class="hidden sm:inline">{{
            t('AI_LEAD_EMPLOYEE.LEADS.EXPORT')
          }}</span>
        </button>
        <button
          type="button"
          class="grid size-9 place-items-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
          :aria-label="t('AI_LEAD_EMPLOYEE.LEADS.MORE_ACTIONS')"
          @click="showMoreFilters = !showMoreFilters"
        >
          <Icon icon="i-lucide-ellipsis-vertical" class="size-4" />
        </button>
      </div>
    </header>

    <main class="grid min-h-0 flex-1 lg:grid-cols-[minmax(0,1fr)_292px]">
      <section class="flex min-h-0 flex-col overflow-hidden">
        <div
          v-if="!showMobileDetail"
          class="shrink-0 border-b border-n-weak bg-n-background px-4 py-3 lg:px-5"
        >
          <div class="relative md:hidden">
            <Icon
              icon="i-lucide-search"
              class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-n-slate-10"
            />
            <input
              v-model="uiFilters.q"
              type="search"
              class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 py-2 pl-9 pr-3 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-10 focus:border-n-brand"
              :placeholder="t('AI_LEAD_EMPLOYEE.LEADS.SEARCH')"
            />
          </div>

          <div class="mt-0 flex gap-3 overflow-x-auto pb-1 md:mt-0">
            <button
              v-for="chip in qualityChips"
              :key="chip.key"
              type="button"
              class="inline-flex h-8 shrink-0 items-center gap-2 rounded-lg border px-3 text-sm font-medium focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
              :class="
                uiFilters.quality === chip.key
                  ? chip.tone
                  : 'border-n-weak bg-n-solid-1 text-n-slate-11 hover:bg-n-alpha-2'
              "
              @click="applyFilter({ quality: chip.key, lead_id: '' })"
            >
              <span>{{ chip.label }}</span>
              <span class="tabular-nums">{{ counts[chip.key] || 0 }}</span>
            </button>
          </div>

          <div
            class="mt-3 grid gap-2 md:grid-cols-2 lg:grid-cols-[152px_160px_184px_184px_140px]"
          >
            <select
              v-model="uiFilters.assignee_id"
              class="h-9 min-w-0 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
              @change="
                applyFilter({ assignee_id: uiFilters.assignee_id, lead_id: '' })
              "
            >
              <option value="">
                {{ t('AI_LEAD_EMPLOYEE.LEADS.FILTER.ASSIGNEE') }}
              </option>
              <option value="me">
                {{ t('AI_LEAD_EMPLOYEE.LEADS.FILTER.ME') }}
              </option>
              <option value="unassigned">
                {{ t('AI_LEAD_EMPLOYEE.LEADS.FILTER.UNASSIGNED') }}
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
              v-model="uiFilters.source_id"
              class="h-9 min-w-0 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
              @change="
                applyFilter({ source_id: uiFilters.source_id, lead_id: '' })
              "
            >
              <option value="">
                {{ t('AI_LEAD_EMPLOYEE.LEADS.FILTER.SOURCE') }}
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
              v-model="uiFilters.follow_up_state"
              class="h-9 min-w-0 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
              @change="
                applyFilter({
                  follow_up_state: uiFilters.follow_up_state,
                  lead_id: '',
                })
              "
            >
              <option value="">
                {{ t('AI_LEAD_EMPLOYEE.LEADS.FILTER.FOLLOW_UP') }}
              </option>
              <option
                v-for="state in filterOptions.follow_up_states"
                :key="state"
                :value="state"
              >
                {{ followUpLabel(state) }}
              </option>
            </select>
            <select
              v-model="uiFilters.booking_status"
              class="h-9 min-w-0 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
              @change="
                applyFilter({
                  booking_status: uiFilters.booking_status,
                  lead_id: '',
                })
              "
            >
              <option value="">
                {{ t('AI_LEAD_EMPLOYEE.LEADS.FILTER.BOOKING') }}
              </option>
              <option
                v-for="status in filterOptions.booking_statuses"
                :key="status"
                :value="status"
              >
                {{ bookingStatusLabel(status) }}
              </option>
            </select>
            <div class="relative">
              <button
                type="button"
                class="inline-flex h-9 w-full items-center justify-center gap-2 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
                :aria-expanded="String(showMoreFilters)"
                @click="showMoreFilters = !showMoreFilters"
              >
                <Icon icon="i-lucide-list-filter" class="size-4" />
                {{ t('AI_LEAD_EMPLOYEE.LEADS.FILTER.MORE') }}
              </button>
              <div
                v-if="showMoreFilters"
                class="absolute right-0 z-20 mt-2 w-56 rounded-lg border border-n-weak bg-n-solid-1 p-3 shadow-lg"
              >
                <label class="mt-3 block text-xs font-medium text-n-slate-11">
                  {{ t('AI_LEAD_EMPLOYEE.LEADS.SORT_BY') }}
                  <select
                    v-model="uiFilters.sort"
                    class="mt-1 h-9 w-full rounded-md border border-n-weak bg-n-background px-2 text-sm text-n-slate-12"
                    @change="
                      applyFilter({
                        sort: uiFilters.sort,
                        direction: uiFilters.direction,
                      })
                    "
                  >
                    <option value="last_contact">
                      {{ t('AI_LEAD_EMPLOYEE.LEADS.FIELD.LAST_CONTACT') }}
                    </option>
                    <option value="name">
                      {{ t('AI_LEAD_EMPLOYEE.LEADS.FIELD.LEAD') }}
                    </option>
                    <option value="business">
                      {{ t('AI_LEAD_EMPLOYEE.LEADS.FIELD.BUSINESS') }}
                    </option>
                    <option value="quality">
                      {{ t('AI_LEAD_EMPLOYEE.LEADS.FIELD.QUALITY') }}
                    </option>
                    <option value="score">
                      {{ t('AI_LEAD_EMPLOYEE.LEADS.FIELD.SCORE') }}
                    </option>
                  </select>
                </label>
                <label class="mt-3 block text-xs font-medium text-n-slate-11">
                  {{ t('AI_LEAD_EMPLOYEE.LEADS.SORT_DIRECTION') }}
                  <select
                    v-model="uiFilters.direction"
                    class="mt-1 h-9 w-full rounded-md border border-n-weak bg-n-background px-2 text-sm text-n-slate-12"
                    @change="
                      applyFilter({
                        sort: uiFilters.sort,
                        direction: uiFilters.direction,
                      })
                    "
                  >
                    <option value="desc">
                      {{ t('AI_LEAD_EMPLOYEE.LEADS.SORT_DESCENDING') }}
                    </option>
                    <option value="asc">
                      {{ t('AI_LEAD_EMPLOYEE.LEADS.SORT_ASCENDING') }}
                    </option>
                  </select>
                </label>
                <label class="block text-xs font-medium text-n-slate-11">
                  {{ t('AI_LEAD_EMPLOYEE.LEADS.PER_PAGE') }}
                  <select
                    v-model.number="uiFilters.per_page"
                    class="mt-1 h-9 w-full rounded-md border border-n-weak bg-n-background px-2 text-sm text-n-slate-12"
                    @change="applyFilter({ per_page: uiFilters.per_page })"
                  >
                    <option :value="25">
                      {{
                        t('AI_LEAD_EMPLOYEE.LEADS.PER_PAGE_OPTION', {
                          count: 25,
                        })
                      }}
                    </option>
                    <option :value="50">
                      {{
                        t('AI_LEAD_EMPLOYEE.LEADS.PER_PAGE_OPTION', {
                          count: 50,
                        })
                      }}
                    </option>
                    <option :value="100">
                      {{
                        t('AI_LEAD_EMPLOYEE.LEADS.PER_PAGE_OPTION', {
                          count: 100,
                        })
                      }}
                    </option>
                  </select>
                </label>
                <button
                  type="button"
                  class="mt-3 h-9 w-full rounded-md border border-n-weak text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2"
                  @click="clearFilters"
                >
                  {{ t('AI_LEAD_EMPLOYEE.LEADS.CLEAR_FILTERS') }}
                </button>
              </div>
            </div>
          </div>

          <p
            v-if="statusMessage"
            class="mt-2 text-xs font-medium text-n-teal-11"
          >
            {{ statusMessage }}
          </p>
          <p
            v-if="errorMessage"
            class="mt-2 text-xs font-medium text-n-ruby-11"
          >
            {{ errorMessage }}
          </p>
        </div>

        <div class="hidden min-h-0 flex-1 overflow-auto lg:block">
          <table class="w-full min-w-[1060px] table-fixed text-left text-sm">
            <colgroup>
              <col class="w-10" />
              <col class="w-[146px]" />
              <col class="w-[136px]" />
              <col class="w-[116px]" />
              <col class="w-[66px]" />
              <col class="w-[126px]" />
              <col class="w-[110px]" />
              <col class="w-[106px]" />
              <col class="w-[124px]" />
              <col class="w-[113px]" />
            </colgroup>
            <thead
              class="sticky top-0 z-10 border-b border-n-weak bg-n-background text-xs font-medium text-n-slate-11"
            >
              <tr>
                <th class="px-3 py-3">
                  <input
                    type="checkbox"
                    class="rounded border-n-weak"
                    :checked="allPageLeadsSelected"
                    :indeterminate="somePageLeadsSelected"
                    :aria-label="t('AI_LEAD_EMPLOYEE.LEADS.SELECT_ALL')"
                    @change="togglePageBulkSelection"
                  />
                </th>
                <th class="px-3 py-3">
                  <button
                    type="button"
                    class="inline-flex items-center gap-1"
                    @click="sortBy('name')"
                  >
                    {{ t('AI_LEAD_EMPLOYEE.LEADS.FIELD.LEAD') }}
                    <Icon
                      v-if="uiFilters.sort === 'name'"
                      :icon="sortIcon('name')"
                      class="size-3"
                    />
                  </button>
                </th>
                <th class="px-3 py-3">
                  <button
                    type="button"
                    class="inline-flex items-center gap-1"
                    @click="sortBy('business')"
                  >
                    {{ t('AI_LEAD_EMPLOYEE.LEADS.FIELD.BUSINESS') }}
                    <Icon
                      v-if="uiFilters.sort === 'business'"
                      :icon="sortIcon('business')"
                      class="size-3"
                    />
                  </button>
                </th>
                <th class="px-3 py-3">
                  <button
                    type="button"
                    class="inline-flex items-center gap-1"
                    @click="sortBy('quality')"
                  >
                    {{ t('AI_LEAD_EMPLOYEE.LEADS.FIELD.QUALITY') }}
                    <Icon
                      v-if="uiFilters.sort === 'quality'"
                      :icon="sortIcon('quality')"
                      class="size-3"
                    />
                  </button>
                </th>
                <th class="px-3 py-3">
                  <button
                    type="button"
                    class="inline-flex items-center gap-1"
                    @click="sortBy('score')"
                  >
                    {{ t('AI_LEAD_EMPLOYEE.LEADS.FIELD.SCORE') }}
                    <Icon
                      v-if="uiFilters.sort === 'score'"
                      :icon="sortIcon('score')"
                      class="size-3"
                    />
                  </button>
                </th>
                <th class="px-3 py-3">
                  {{ t('AI_LEAD_EMPLOYEE.LEADS.FIELD.SOURCE') }}
                </th>
                <th class="px-3 py-3">
                  {{ t('AI_LEAD_EMPLOYEE.LEADS.FIELD.ASSIGNEE') }}
                </th>
                <th class="px-3 py-3">
                  <button
                    type="button"
                    class="inline-flex items-center gap-1"
                    @click="sortBy('last_contact')"
                  >
                    {{ t('AI_LEAD_EMPLOYEE.LEADS.FIELD.LAST_CONTACT') }}
                    <Icon :icon="sortIcon('last_contact')" class="size-3" />
                  </button>
                </th>
                <th class="px-3 py-3">
                  {{ t('AI_LEAD_EMPLOYEE.LEADS.FIELD.NEXT_ACTION') }}
                </th>
                <th class="px-3 py-3">
                  {{ t('AI_LEAD_EMPLOYEE.LEADS.FIELD.BOOKING') }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-n-weak bg-n-background">
              <tr v-if="isLoading">
                <td colspan="10" class="px-4 py-8 text-sm text-n-slate-11">
                  {{ t('AI_LEAD_EMPLOYEE.LEADS.LOADING') }}
                </td>
              </tr>
              <tr v-else-if="!leads.length">
                <td colspan="10" class="px-4 py-8 text-sm text-n-slate-11">
                  {{ t('AI_LEAD_EMPLOYEE.LEADS.EMPTY') }}
                </td>
              </tr>
              <template v-else>
                <tr
                  v-for="lead in leads"
                  :key="lead.id"
                  class="h-[58px] cursor-pointer hover:bg-n-alpha-2"
                  :class="selectedLead?.id === lead.id ? 'bg-n-blue-2' : ''"
                  @click="selectLead(lead)"
                >
                  <td class="px-3 py-2">
                    <input
                      type="checkbox"
                      class="rounded border-n-weak"
                      :checked="isLeadBulkSelected(lead)"
                      :aria-label="
                        t('AI_LEAD_EMPLOYEE.LEADS.SELECT_ROW', {
                          name: lead.name,
                        })
                      "
                      @click.stop="toggleLeadBulkSelection(lead)"
                    />
                  </td>
                  <td class="min-w-0 px-3 py-2">
                    <div class="flex min-w-0 items-center gap-2">
                      <span
                        class="grid size-8 shrink-0 place-items-center rounded-full bg-n-slate-3 text-xs font-medium text-n-slate-12"
                      >
                        {{ lead.initials }}
                      </span>
                      <span class="min-w-0">
                        <span
                          class="block truncate font-medium text-n-slate-12"
                        >
                          {{ lead.name }}
                        </span>
                        <span class="block truncate text-xs text-n-slate-11">
                          {{ lead.phone_number || lead.email }}
                        </span>
                      </span>
                    </div>
                  </td>
                  <td class="px-3 py-2">
                    <span class="block truncate text-n-slate-12">
                      {{
                        lead.business_name ||
                        t('AI_LEAD_EMPLOYEE.LEADS.EMPTY_VALUE')
                      }}
                    </span>
                    <span class="block truncate text-xs text-n-slate-11">
                      {{ lead.location }}
                    </span>
                  </td>
                  <td class="px-3 py-2">
                    <span
                      class="inline-flex rounded-md px-2 py-1 text-xs font-medium"
                      :class="qualityToneClass(lead.quality)"
                    >
                      {{ qualityLabel(lead.quality) }}
                    </span>
                  </td>
                  <td class="px-3 py-2 tabular-nums text-n-slate-12">
                    {{ lead.score }}
                  </td>
                  <td class="px-3 py-2">
                    <span
                      class="inline-flex w-full min-w-0 items-center gap-1 text-xs text-n-slate-11"
                    >
                      <Icon
                        :icon="sourceIcon(lead.source)"
                        class="size-4 shrink-0 text-n-blue-10"
                      />
                      <span class="min-w-0 truncate">{{
                        lead.source?.name ||
                        t('AI_LEAD_EMPLOYEE.LEADS.EMPTY_VALUE')
                      }}</span>
                    </span>
                  </td>
                  <td class="px-3 py-2">
                    <span class="inline-flex w-full min-w-0 items-center gap-2">
                      <span
                        class="grid size-6 shrink-0 place-items-center rounded-full bg-n-blue-3 text-xs font-medium text-n-blue-11"
                      >
                        {{ lead.assignee?.initials || 'U' }}
                      </span>
                      <span class="min-w-0 truncate">{{
                        lead.assignee?.name ||
                        t('AI_LEAD_EMPLOYEE.LEADS.UNASSIGNED')
                      }}</span>
                    </span>
                  </td>
                  <td class="px-3 py-2 text-n-slate-11">
                    <span class="block">{{
                      compactTime(lead.last_contact_at)
                    }}</span>
                    <span class="block text-xs">{{
                      formatTime(lead.last_contact_at).split(',')[0]
                    }}</span>
                  </td>
                  <td class="px-3 py-2">
                    <span class="block truncate text-n-slate-12">{{
                      nextActionLabel(lead.next_action)
                    }}</span>
                    <span class="block truncate text-xs text-n-slate-11">{{
                      formatTime(lead.next_action?.due_at)
                    }}</span>
                  </td>
                  <td class="px-3 py-2">
                    <span
                      class="inline-flex rounded-md px-2 py-1 text-xs font-medium"
                      :class="bookingToneClass(lead.booking)"
                    >
                      {{ bookingLabel(lead.booking) }}
                    </span>
                    <span
                      v-if="lead.booking?.starts_at"
                      class="mt-1 block text-xs text-n-blue-11"
                    >
                      {{
                        formatTime(lead.booking.starts_at)
                          .split(',')
                          .slice(0, 2)
                          .join(',')
                      }}
                    </span>
                  </td>
                </tr>
              </template>
            </tbody>
          </table>
        </div>

        <div
          v-if="!showMobileDetail"
          class="min-h-0 flex-1 overflow-auto px-4 py-3 lg:hidden"
        >
          <p v-if="isLoading" class="py-6 text-sm text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.LEADS.LOADING') }}
          </p>
          <p v-else-if="!leads.length" class="py-6 text-sm text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.LEADS.EMPTY') }}
          </p>
          <div v-else class="grid gap-3">
            <button
              v-for="lead in leads"
              :key="lead.id"
              type="button"
              class="rounded-lg border border-n-weak bg-n-solid-1 p-3 text-left focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
              :class="
                selectedLead?.id === lead.id
                  ? 'border-n-blue-7 bg-n-blue-2'
                  : ''
              "
              @click="selectLead(lead)"
            >
              <div class="flex items-start gap-3">
                <span
                  class="grid size-10 shrink-0 place-items-center rounded-full bg-n-slate-3 text-sm font-medium text-n-slate-12"
                >
                  {{ lead.initials }}
                </span>
                <span class="min-w-0 flex-1">
                  <span class="block truncate font-medium text-n-slate-12">{{
                    lead.name
                  }}</span>
                  <span class="block truncate text-sm text-n-slate-11">{{
                    lead.business_name || lead.phone_number
                  }}</span>
                </span>
                <span
                  class="rounded-md px-2 py-1 text-xs font-medium"
                  :class="qualityToneClass(lead.quality)"
                >
                  {{ qualityLabel(lead.quality) }}
                </span>
              </div>
              <div class="mt-3 grid grid-cols-2 gap-2 text-xs text-n-slate-11">
                <span>
                  {{
                    t('AI_LEAD_EMPLOYEE.LEADS.SCORE_VALUE', {
                      score: lead.score,
                    })
                  }}
                </span>
                <span class="truncate">{{
                  nextActionLabel(lead.next_action)
                }}</span>
                <span class="truncate">{{ lead.source?.name }}</span>
                <span class="truncate">{{ bookingLabel(lead.booking) }}</span>
              </div>
            </button>
          </div>
        </div>

        <footer
          v-if="!showMobileDetail"
          class="flex h-14 shrink-0 items-center gap-3 border-t border-n-weak bg-n-background px-4 text-sm text-n-slate-11 lg:px-5"
        >
          <span class="min-w-0 flex-1 truncate">
            {{
              t('AI_LEAD_EMPLOYEE.LEADS.PAGINATION', {
                start: pageStart,
                end: pageEnd,
                total: meta.total_count,
              })
            }}
          </span>
          <button
            type="button"
            class="grid size-9 place-items-center rounded-lg border border-n-weak text-n-slate-12 disabled:opacity-40"
            :disabled="!hasPreviousPage"
            :aria-label="t('AI_LEAD_EMPLOYEE.LEADS.PREVIOUS_PAGE')"
            @click="pageTo(meta.page - 1)"
          >
            <Icon icon="i-lucide-chevron-left" class="size-4" />
          </button>
          <span
            class="rounded-lg bg-n-blue-3 px-3 py-2 text-sm font-medium text-n-blue-11"
          >
            {{ meta.page }}
          </span>
          <button
            type="button"
            class="grid size-9 place-items-center rounded-lg border border-n-weak text-n-slate-12 disabled:opacity-40"
            :disabled="!hasNextPage"
            :aria-label="t('AI_LEAD_EMPLOYEE.LEADS.NEXT_PAGE')"
            @click="pageTo(meta.page + 1)"
          >
            <Icon icon="i-lucide-chevron-right" class="size-4" />
          </button>
        </footer>

        <div
          v-if="showMobileDetail && selectedLead"
          class="min-h-0 flex-1 overflow-hidden lg:hidden"
        >
          <button
            type="button"
            class="flex h-12 w-full items-center gap-2 border-b border-n-weak px-4 text-sm font-medium text-n-slate-12"
            @click="showMobileDetail = false"
          >
            <Icon icon="i-lucide-arrow-left" class="size-4" />
            {{ t('AI_LEAD_EMPLOYEE.LEADS.BACK_TO_LIST') }}
          </button>
          <LeadDetail
            :lead="selectedLead"
            :quality-label="qualityLabel"
            :follow-up-label="followUpLabel"
            :booking-status-label="bookingStatusLabel"
            :next-action-label="nextActionLabel"
            :channel-kind-label="channelKindLabel"
            :evidence-signal-label="evidenceSignalLabel"
            :conversation-state-label="conversationStateLabel"
            :format-time="formatTime"
            :quality-tone-class="qualityToneClass"
            :t="t"
            mobile
            @edit="openEditModal"
          />
        </div>
      </section>

      <aside
        class="hidden min-h-0 border-l border-n-weak bg-n-background lg:flex lg:flex-col"
        :aria-label="t('AI_LEAD_EMPLOYEE.LEADS.DETAIL_LABEL')"
      >
        <LeadDetail
          v-if="selectedLead"
          :lead="selectedLead"
          :quality-label="qualityLabel"
          :follow-up-label="followUpLabel"
          :booking-status-label="bookingStatusLabel"
          :next-action-label="nextActionLabel"
          :channel-kind-label="channelKindLabel"
          :evidence-signal-label="evidenceSignalLabel"
          :conversation-state-label="conversationStateLabel"
          :format-time="formatTime"
          :quality-tone-class="qualityToneClass"
          :t="t"
          @edit="openEditModal"
        />
      </aside>
    </main>

    <div
      v-if="showEditModal"
      class="fixed inset-0 z-50 grid place-items-center bg-n-slate-12/40 p-4"
      role="dialog"
      aria-modal="true"
      :aria-label="t('AI_LEAD_EMPLOYEE.LEADS.EDIT.TITLE')"
    >
      <form
        class="max-h-full w-full max-w-2xl overflow-auto rounded-lg border border-n-weak bg-n-solid-1 p-5 shadow-xl"
        @submit.prevent="saveLead"
      >
        <div class="flex items-center gap-3">
          <h2 class="min-w-0 flex-1 text-lg font-semibold text-n-slate-12">
            {{ t('AI_LEAD_EMPLOYEE.LEADS.EDIT.TITLE') }}
          </h2>
          <button
            type="button"
            class="grid size-9 place-items-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2"
            :aria-label="t('AI_LEAD_EMPLOYEE.LEADS.EDIT.CLOSE')"
            @click="showEditModal = false"
          >
            <Icon icon="i-lucide-x" class="size-4" />
          </button>
        </div>

        <div
          v-if="editErrors.length"
          class="mt-3 rounded-md bg-n-ruby-3 p-3 text-sm text-n-ruby-11"
        >
          <p v-for="message in editErrors" :key="message">{{ message }}</p>
        </div>

        <div class="mt-4 grid gap-3 md:grid-cols-2">
          <label class="block text-xs font-medium text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.LEADS.EDIT.NAME') }}
            <input
              v-model="editForm.name"
              class="mt-1 h-10 w-full rounded-md border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
              required
            />
          </label>
          <label class="block text-xs font-medium text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.LEADS.EDIT.PHONE') }}
            <input
              v-model="editForm.phone_number"
              class="mt-1 h-10 w-full rounded-md border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
            />
          </label>
          <label class="block text-xs font-medium text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.LEADS.EDIT.EMAIL') }}
            <input
              v-model="editForm.email"
              class="mt-1 h-10 w-full rounded-md border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
            />
          </label>
          <label class="block text-xs font-medium text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.LEADS.EDIT.BUSINESS') }}
            <input
              v-model="editForm.business_name"
              class="mt-1 h-10 w-full rounded-md border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
            />
          </label>
          <label class="block text-xs font-medium text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.LEADS.EDIT.CITY') }}
            <input
              v-model="editForm.city"
              class="mt-1 h-10 w-full rounded-md border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
            />
          </label>
          <label class="block text-xs font-medium text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.LEADS.EDIT.COUNTRY') }}
            <input
              v-model="editForm.country"
              class="mt-1 h-10 w-full rounded-md border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
            />
          </label>
          <label class="block text-xs font-medium text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.LEADS.EDIT.ASSIGNEE') }}
            <select
              v-model="editForm.assignee_id"
              class="mt-1 h-10 w-full rounded-md border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
            >
              <option value="">
                {{ t('AI_LEAD_EMPLOYEE.LEADS.UNASSIGNED') }}
              </option>
              <option
                v-for="assignee in filterOptions.assignees"
                :key="assignee.id"
                :value="assignee.id"
              >
                {{ assignee.name }}
              </option>
            </select>
          </label>
        </div>

        <div class="mt-5 grid gap-3 md:grid-cols-2">
          <label
            v-for="signal in [
              'problem',
              'budget',
              'urgency',
              'decision_authority',
            ]"
            :key="signal"
            class="block text-xs font-medium text-n-slate-11"
          >
            {{ evidenceSignalLabel(signal) }}
            <input
              v-model="editForm.evidence[signal]"
              class="mt-1 h-10 w-full rounded-md border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
            />
          </label>
        </div>

        <div class="mt-5 flex justify-end gap-2">
          <button
            type="button"
            class="h-9 rounded-lg border border-n-weak px-4 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2"
            @click="showEditModal = false"
          >
            {{ t('AI_LEAD_EMPLOYEE.LEADS.EDIT.CANCEL') }}
          </button>
          <button
            type="submit"
            class="h-9 rounded-lg bg-n-brand px-4 text-sm font-medium text-white"
          >
            {{ t('AI_LEAD_EMPLOYEE.LEADS.EDIT.SAVE') }}
          </button>
        </div>
      </form>
    </div>
  </section>
</template>

<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import Icon from 'next/icon/Icon.vue';
import bookingsAPI from 'dashboard/api/bookings';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const activeTab = ref(route.query.tab?.toString() || 'agenda');
const bookings = ref([]);
const selectedBooking = ref(null);
const meta = ref({ total_count: 0, capacity_booked: 0, capacity_limit: 20 });
const filterOptions = ref({
  statuses: [],
  assignees: [],
  offers: [],
  timezones: [],
});
const availability = ref({
  configuration: {},
  slots: [],
  provider_state: 'connected',
});
const calendar = ref([]);
const isLoading = ref(false);
const errorMessage = ref('');
const showMoreFilters = ref(false);
const showMobileDetail = ref(false);
const dialogMode = ref('');
const isSaving = ref(false);

const filters = reactive({
  from: route.query.from?.toString() || '',
  days: Number(route.query.days || 7),
  status: route.query.status?.toString() || '',
  assignee_id: route.query.assignee_id?.toString() || '',
  offer: route.query.offer?.toString() || '',
  timezone: route.query.timezone?.toString() || '',
  booking_id: route.query.booking_id?.toString() || '',
});

const actionForm = reactive({
  starts_at: '',
  reason: '',
});

const tabs = computed(() => [
  { key: 'agenda', label: t('AI_LEAD_EMPLOYEE.BOOKINGS.TABS.AGENDA') },
  { key: 'calendar', label: t('AI_LEAD_EMPLOYEE.BOOKINGS.TABS.CALENDAR') },
  {
    key: 'availability',
    label: t('AI_LEAD_EMPLOYEE.BOOKINGS.TABS.AVAILABILITY'),
  },
]);

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

const requestParams = () =>
  cleanQuery({
    from: filters.from,
    days: filters.days,
    status: filters.status,
    assignee_id: filters.assignee_id,
    offer: filters.offer,
    timezone: filters.timezone,
    booking_id: filters.booking_id,
  });

const isMobileViewport = () =>
  typeof window !== 'undefined' &&
  typeof window.matchMedia === 'function' &&
  window.matchMedia('(max-width: 1023px)').matches;

const hydrateFromRoute = () => {
  activeTab.value = route.query.tab?.toString() || 'agenda';
  filters.from = route.query.from?.toString() || '';
  filters.days = Number(route.query.days || 7);
  filters.status = route.query.status?.toString() || '';
  filters.assignee_id = route.query.assignee_id?.toString() || '';
  filters.offer = route.query.offer?.toString() || '';
  filters.timezone = route.query.timezone?.toString() || '';
  filters.booking_id = route.query.booking_id?.toString() || '';
};

const loadBookings = async () => {
  isLoading.value = true;
  errorMessage.value = '';
  try {
    const { data } = await bookingsAPI.get(requestParams());
    bookings.value = data.bookings || [];
    selectedBooking.value = data.selected_booking || bookings.value[0] || null;
    meta.value = { ...meta.value, ...(data.meta || {}) };
    filterOptions.value = data.filter_options || filterOptions.value;
    availability.value = data.availability || availability.value;
    calendar.value = data.calendar || [];
    if (selectedBooking.value)
      filters.booking_id = selectedBooking.value.id.toString();
  } catch (error) {
    errorMessage.value =
      error.response?.data?.error || t('AI_LEAD_EMPLOYEE.BOOKINGS.LOAD_ERROR');
  } finally {
    isLoading.value = false;
  }
};

watch(
  () => route.query,
  () => {
    hydrateFromRoute();
    loadBookings();
  }
);

const setTab = tab => {
  activeTab.value = tab;
  replaceQuery({ tab });
};

const applyFilter = partial => {
  showMobileDetail.value = false;
  replaceQuery(partial);
};

const clearFilters = () => {
  applyFilter({
    status: '',
    assignee_id: '',
    offer: '',
    timezone: '',
    booking_id: '',
  });
};

const moveRange = direction => {
  const base = filters.from ? new Date(filters.from) : new Date();
  base.setDate(base.getDate() + direction * filters.days);
  applyFilter({ from: base.toISOString() });
};

const setToday = () => {
  applyFilter({ from: new Date().toISOString() });
};

const selectBooking = booking => {
  selectedBooking.value = booking;
  if (isMobileViewport()) showMobileDetail.value = true;
  replaceQuery({ booking_id: booking.id });
};

const toDatetimeLocalValue = value => {
  if (!value) return '';
  const date = new Date(value);
  const localDate = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return localDate.toISOString().slice(0, 16);
};

const datetimeLocalToIso = value =>
  value ? new Date(value).toISOString() : '';

const openDialog = mode => {
  dialogMode.value = mode;
  actionForm.starts_at = toDatetimeLocalValue(selectedBooking.value?.starts_at);
  actionForm.reason = '';
};

const closeDialog = () => {
  dialogMode.value = '';
  isSaving.value = false;
};

const submitAction = async () => {
  if (!selectedBooking.value) return;

  isSaving.value = true;
  const idempotencyKey = `${dialogMode.value}-${selectedBooking.value.id}-${Date.now()}`;
  try {
    if (dialogMode.value === 'reschedule') {
      const { data } = await bookingsAPI.reschedule(selectedBooking.value.id, {
        starts_at: datetimeLocalToIso(actionForm.starts_at),
        idempotency_key: idempotencyKey,
      });
      selectedBooking.value = data;
      useAlert(t('AI_LEAD_EMPLOYEE.BOOKINGS.RESCHEDULED'));
    } else {
      const { data } = await bookingsAPI.cancel(selectedBooking.value.id, {
        reason: actionForm.reason,
        idempotency_key: idempotencyKey,
      });
      selectedBooking.value = data;
      useAlert(t('AI_LEAD_EMPLOYEE.BOOKINGS.CANCELED'));
    }
    closeDialog();
    await loadBookings();
  } catch (error) {
    errorMessage.value =
      error.response?.data?.error || t('AI_LEAD_EMPLOYEE.BOOKINGS.SAVE_ERROR');
  } finally {
    isSaving.value = false;
  }
};

const dayKey = value => new Date(value).toISOString().slice(0, 10);

const formatDateTime = (value, options = {}) => {
  if (!value) return t('AI_LEAD_EMPLOYEE.BOOKINGS.EMPTY_VALUE');
  return new Intl.DateTimeFormat(undefined, options).format(new Date(value));
};

const dayLabel = value => {
  const today = new Date();
  const tomorrow = new Date();
  tomorrow.setDate(today.getDate() + 1);
  let prefix = formatDateTime(value, { weekday: 'short' });
  if (dayKey(value) === dayKey(today)) {
    prefix = t('AI_LEAD_EMPLOYEE.BOOKINGS.TODAY');
  } else if (dayKey(value) === dayKey(tomorrow)) {
    prefix = t('AI_LEAD_EMPLOYEE.BOOKINGS.TOMORROW');
  }
  return `${prefix} · ${formatDateTime(value, {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })}`;
};

const groupedBookings = computed(() => {
  const groups = [];
  bookings.value.forEach(booking => {
    const key = dayKey(booking.starts_at);
    let group = groups.find(item => item.key === key);
    if (!group) {
      group = { key, label: dayLabel(booking.starts_at), bookings: [] };
      groups.push(group);
    }
    group.bookings.push(booking);
  });
  return groups;
});

const capacityPercent = computed(() => {
  const limit = Number(meta.value.capacity_limit || 1);
  return Math.min(
    100,
    Math.round((Number(meta.value.capacity_booked || 0) / limit) * 100)
  );
});

const pageRangeLabel = computed(
  () => meta.value.range?.label || t('AI_LEAD_EMPLOYEE.BOOKINGS.THIS_WEEK')
);

const pageCountLabel = computed(() =>
  t('AI_LEAD_EMPLOYEE.BOOKINGS.PAGINATION', {
    count: bookings.value.length,
    total: meta.value.total_count || bookings.value.length,
  })
);

const capacityLabel = computed(() =>
  t('AI_LEAD_EMPLOYEE.BOOKINGS.CAPACITY_COUNT', {
    booked: meta.value.capacity_booked,
    limit: meta.value.capacity_limit,
  })
);

const activeBookingId = computed(() => selectedBooking.value?.id);

const timeRange = booking =>
  `${formatDateTime(booking.starts_at, {
    hour: 'numeric',
    minute: '2-digit',
  })} - ${formatDateTime(booking.ends_at, {
    hour: 'numeric',
    minute: '2-digit',
  })}`;

const minutesLabel = value =>
  t('AI_LEAD_EMPLOYEE.BOOKINGS.MINUTES', { count: value });

const joinedLabel = (left, right) =>
  t('AI_LEAD_EMPLOYEE.BOOKINGS.JOINED_LABEL', { left, right });

const humanize = value =>
  value
    ? value
        .toString()
        .replace(/[._-]/g, ' ')
        .split(' ')
        .filter(Boolean)
        .map(word => word.charAt(0).toUpperCase() + word.slice(1))
        .join(' ')
    : t('AI_LEAD_EMPLOYEE.BOOKINGS.EMPTY_VALUE');

const labelFor = (group, value) => {
  if (!value) return t('AI_LEAD_EMPLOYEE.BOOKINGS.EMPTY_VALUE');
  const key = `AI_LEAD_EMPLOYEE.BOOKINGS.${group}.${value.toString().toUpperCase()}`;
  // eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys
  const translated = t(key);
  return translated === key ? humanize(value) : translated;
};

const statusClass = value => {
  if (['confirmed', 'ready'].includes(value))
    return 'text-n-teal-11 bg-n-teal-3';
  if (['awaiting', 'invited', 'in_progress'].includes(value))
    return 'text-n-amber-11 bg-n-amber-3';
  if (
    [
      'conflict',
      'no_invite',
      'not_started',
      'needs_attention',
      'canceled',
    ].includes(value)
  )
    return 'text-n-ruby-11 bg-n-ruby-3';
  return 'text-n-slate-11 bg-n-slate-3';
};

const dotClass = value => {
  if (['confirmed', 'ready'].includes(value)) return 'bg-n-teal-9';
  if (['awaiting', 'invited', 'in_progress'].includes(value))
    return 'bg-n-amber-9';
  if (
    [
      'conflict',
      'no_invite',
      'not_started',
      'needs_attention',
      'canceled',
    ].includes(value)
  )
    return 'bg-n-ruby-9';
  return 'bg-n-slate-9';
};

const meetingHref = computed(() => selectedBooking.value?.meeting_link || '#');
const selectedContact = computed(() => selectedBooking.value?.contact || {});
const selectedAssignee = computed(() => selectedBooking.value?.assignee || {});
const detail = computed(() => selectedBooking.value?.detail || {});

onMounted(loadBookings);
</script>

<template>
  <section
    class="-mx-6 -mb-6 mt-6 flex h-[calc(100vh-9.5rem)] min-h-[680px] flex-col overflow-hidden border-t border-n-weak bg-n-solid-1 lg:-mx-0 lg:rounded-lg lg:border"
  >
    <header class="shrink-0 border-b border-n-weak bg-n-solid-1 px-4 pt-4">
      <div
        class="flex flex-col gap-3 lg:flex-row lg:items-end lg:justify-between"
      >
        <div>
          <h2 class="text-xl font-semibold text-n-slate-12">
            {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.TITLE') }}
          </h2>
          <nav
            class="mt-4 flex gap-6"
            :aria-label="t('AI_LEAD_EMPLOYEE.BOOKINGS.TAB_LABEL')"
          >
            <button
              v-for="tab in tabs"
              :key="tab.key"
              type="button"
              class="border-b-2 px-0 pb-3 text-sm font-medium outline-none transition-colors focus-visible:rounded focus-visible:ring-2 focus-visible:ring-n-blue-7"
              :class="
                activeTab === tab.key
                  ? 'border-n-brand text-n-blue-11'
                  : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
              "
              @click="setTab(tab.key)"
            >
              {{ tab.label }}
            </button>
          </nav>
        </div>
        <div class="hidden min-w-[260px] lg:block">
          <div
            class="flex items-center justify-between text-xs text-n-slate-11"
          >
            <span>
              {{
                joinedLabel(
                  t('AI_LEAD_EMPLOYEE.BOOKINGS.TEAM_CAPACITY'),
                  formatDateTime(new Date(), {
                    month: 'short',
                    day: 'numeric',
                    year: 'numeric',
                  })
                )
              }}
            </span>
            <button
              type="button"
              class="rounded p-1 text-n-slate-11 hover:bg-n-slate-3 focus-visible:ring-2 focus-visible:ring-n-blue-7"
              :aria-label="t('AI_LEAD_EMPLOYEE.BOOKINGS.MORE_ACTIONS')"
            >
              <Icon icon="i-lucide-ellipsis-vertical" class="size-4" />
            </button>
          </div>
          <div class="mt-2 h-2 overflow-hidden rounded-full bg-n-slate-3">
            <div
              class="h-full rounded-full bg-n-teal-9"
              :style="{ width: `${capacityPercent}%` }"
            />
          </div>
          <p class="mt-1 text-xs text-n-slate-11">
            {{ capacityLabel }} {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.BOOKED') }}
          </p>
        </div>
      </div>
    </header>

    <div
      class="flex min-h-0 flex-1 flex-col lg:grid lg:grid-cols-[minmax(0,1fr)_340px]"
    >
      <main class="min-h-0 overflow-auto bg-n-background p-3 lg:p-4">
        <div class="flex flex-col gap-3">
          <div class="flex flex-wrap items-center gap-2">
            <button
              type="button"
              class="h-9 rounded-md border border-n-weak bg-n-solid-1 px-3 text-sm font-medium text-n-slate-12 hover:bg-n-slate-2 focus-visible:ring-2 focus-visible:ring-n-blue-7"
              @click="setToday"
            >
              {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.TODAY') }}
            </button>
            <button
              type="button"
              class="grid size-9 place-items-center rounded-md border border-n-weak bg-n-solid-1 text-n-slate-11 hover:bg-n-slate-2 focus-visible:ring-2 focus-visible:ring-n-blue-7"
              :aria-label="t('AI_LEAD_EMPLOYEE.BOOKINGS.PREVIOUS_RANGE')"
              @click="moveRange(-1)"
            >
              <Icon icon="i-lucide-chevron-left" class="size-4" />
            </button>
            <button
              type="button"
              class="grid size-9 place-items-center rounded-md border border-n-weak bg-n-solid-1 text-n-slate-11 hover:bg-n-slate-2 focus-visible:ring-2 focus-visible:ring-n-blue-7"
              :aria-label="t('AI_LEAD_EMPLOYEE.BOOKINGS.NEXT_RANGE')"
              @click="moveRange(1)"
            >
              <Icon icon="i-lucide-chevron-right" class="size-4" />
            </button>
            <div
              class="ml-2 flex items-center gap-2 text-sm font-medium text-n-slate-12"
            >
              <span>{{ pageRangeLabel }}</span>
              <Icon
                icon="i-lucide-calendar-days"
                class="size-4 text-n-slate-11"
              />
            </div>
          </div>

          <div class="flex flex-wrap gap-2">
            <label class="relative min-w-[170px]">
              <span class="sr-only">
                {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FILTER.TEAM_MEMBER') }}
              </span>
              <select
                v-model="filters.assignee_id"
                class="h-9 w-full rounded-md border border-n-weak bg-n-solid-1 px-9 pr-8 text-sm text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-blue-7"
                @change="applyFilter({ assignee_id: filters.assignee_id })"
              >
                <option value="">
                  {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FILTER.TEAM_MEMBER') }}
                </option>
                <option
                  v-for="assignee in filterOptions.assignees"
                  :key="assignee.id"
                  :value="assignee.id"
                >
                  {{ assignee.name }}
                </option>
              </select>
              <Icon
                icon="i-lucide-user-round"
                class="pointer-events-none absolute left-3 top-2.5 size-4 text-n-slate-11"
              />
            </label>
            <label class="relative min-w-[180px]">
              <span class="sr-only">
                {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FILTER.STATUS') }}
              </span>
              <select
                v-model="filters.status"
                class="h-9 w-full rounded-md border border-n-weak bg-n-solid-1 px-9 pr-8 text-sm text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-blue-7"
                @change="applyFilter({ status: filters.status })"
              >
                <option value="">
                  {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FILTER.STATUS') }}
                </option>
                <option
                  v-for="status in filterOptions.statuses"
                  :key="status"
                  :value="status"
                >
                  {{ labelFor('STATUS', status) }}
                </option>
              </select>
              <Icon
                icon="i-lucide-calendar-check-2"
                class="pointer-events-none absolute left-3 top-2.5 size-4 text-n-slate-11"
              />
            </label>
            <label class="relative min-w-[160px]">
              <span class="sr-only">
                {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FILTER.OFFER') }}
              </span>
              <select
                v-model="filters.offer"
                class="h-9 w-full rounded-md border border-n-weak bg-n-solid-1 px-9 pr-8 text-sm text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-blue-7"
                @change="applyFilter({ offer: filters.offer })"
              >
                <option value="">
                  {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FILTER.OFFER') }}
                </option>
                <option
                  v-for="offer in filterOptions.offers"
                  :key="offer"
                  :value="offer"
                >
                  {{ offer }}
                </option>
              </select>
              <Icon
                icon="i-lucide-tag"
                class="pointer-events-none absolute left-3 top-2.5 size-4 text-n-slate-11"
              />
            </label>
            <label class="relative min-w-[180px]">
              <span class="sr-only">
                {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FILTER.TIMEZONE') }}
              </span>
              <select
                v-model="filters.timezone"
                class="h-9 w-full rounded-md border border-n-weak bg-n-solid-1 px-9 pr-8 text-sm text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-blue-7"
                @change="applyFilter({ timezone: filters.timezone })"
              >
                <option value="">
                  {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FILTER.TIMEZONE') }}
                </option>
                <option
                  v-for="timezone in filterOptions.timezones"
                  :key="timezone"
                  :value="timezone"
                >
                  {{ timezone }}
                </option>
              </select>
              <Icon
                icon="i-lucide-globe-2"
                class="pointer-events-none absolute left-3 top-2.5 size-4 text-n-slate-11"
              />
            </label>
            <button
              type="button"
              class="inline-flex h-9 items-center gap-2 rounded-md border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 hover:bg-n-slate-2 focus-visible:ring-2 focus-visible:ring-n-blue-7"
              @click="showMoreFilters = !showMoreFilters"
            >
              <Icon icon="i-lucide-ellipsis" class="size-4" />
              {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FILTER.MORE') }}
            </button>
            <button
              v-if="showMoreFilters"
              type="button"
              class="h-9 rounded-md border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-11 hover:bg-n-slate-2 focus-visible:ring-2 focus-visible:ring-n-blue-7"
              @click="clearFilters"
            >
              {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.CLEAR_FILTERS') }}
            </button>
          </div>
        </div>

        <p
          v-if="errorMessage"
          class="mt-3 rounded-md border border-n-ruby-4 bg-n-ruby-2 px-3 py-2 text-sm text-n-ruby-11"
        >
          {{ errorMessage }}
        </p>

        <div
          v-if="activeTab === 'agenda'"
          class="mt-3 overflow-hidden rounded-md border border-n-weak bg-n-solid-1"
        >
          <div
            class="hidden grid-cols-[150px_1.3fr_1.1fr_1.1fr_1.1fr_1.1fr_1.1fr_.9fr] border-b border-n-weak px-3 py-2 text-xs font-semibold text-n-slate-11 lg:grid"
          >
            <span>{{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.DATE_TIME') }}</span>
            <span>{{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.LEAD') }}</span>
            <span>{{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.BUSINESS') }}</span>
            <span>{{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.ASSIGNED_TO') }}</span>
            <span>{{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.CALL_TYPE') }}</span>
            <span>{{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.WHATSAPP') }}</span>
            <span>{{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.CALENDAR') }}</span>
            <span>{{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.PREP') }}</span>
          </div>
          <div v-if="isLoading" class="p-4 text-sm text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.LOADING') }}
          </div>
          <div
            v-else-if="!groupedBookings.length"
            class="p-6 text-sm text-n-slate-11"
          >
            {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.EMPTY') }}
          </div>
          <div v-else class="divide-y divide-n-weak">
            <section v-for="group in groupedBookings" :key="group.key">
              <div
                class="flex items-center gap-2 bg-n-slate-2 px-3 py-2 text-xs font-semibold text-n-slate-12"
              >
                <span>{{ group.label }}</span>
                <span
                  class="rounded-full bg-n-slate-4 px-2 py-0.5 text-n-slate-11"
                >
                  {{ group.bookings.length }}
                </span>
              </div>
              <button
                v-for="booking in group.bookings"
                :key="booking.id"
                type="button"
                class="grid w-full gap-2 border-t border-n-weak px-3 py-3 text-left outline-none hover:bg-n-blue-2 focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-n-blue-7 lg:grid-cols-[150px_1.3fr_1.1fr_1.1fr_1.1fr_1.1fr_1.1fr_.9fr]"
                :class="
                  activeBookingId === booking.id
                    ? 'border-l-2 border-l-n-brand bg-n-blue-2'
                    : 'border-l-2 border-l-transparent'
                "
                @click="selectBooking(booking)"
              >
                <span class="text-sm font-medium text-n-slate-12">
                  {{ timeRange(booking) }}
                </span>
                <span
                  class="flex min-w-0 items-center gap-2 text-sm text-n-slate-12"
                >
                  <span
                    class="grid size-6 shrink-0 place-items-center rounded-full bg-n-slate-3 text-[11px] font-medium"
                  >
                    {{ booking.contact.initials }}
                  </span>
                  <span class="truncate">{{ booking.contact.name }}</span>
                </span>
                <span class="truncate text-sm text-n-slate-12">
                  {{
                    booking.contact.business_name ||
                    t('AI_LEAD_EMPLOYEE.BOOKINGS.EMPTY_VALUE')
                  }}
                </span>
                <span class="flex items-center gap-2 text-sm text-n-slate-12">
                  <span
                    class="grid size-6 place-items-center rounded-full bg-n-blue-3 text-[11px] font-medium text-n-blue-11"
                  >
                    {{ booking.assignee?.initials || 'U' }}
                  </span>
                  {{
                    booking.assignee?.name ||
                    t('AI_LEAD_EMPLOYEE.BOOKINGS.UNASSIGNED')
                  }}
                </span>
                <span class="text-sm text-n-slate-12">
                  {{ labelFor('CALL_TYPE', booking.call_type) }}
                  <span class="block text-xs text-n-slate-11">
                    {{ minutesLabel(30) }}
                  </span>
                </span>
                <span class="text-sm text-n-slate-12">
                  <span
                    class="mr-1 inline-block size-2 rounded-full"
                    :class="dotClass(booking.whatsapp_state)"
                  />
                  {{ labelFor('WHATSAPP_STATE', booking.whatsapp_state) }}
                </span>
                <span class="text-sm text-n-slate-12">
                  <span
                    class="mr-1 inline-block size-2 rounded-full"
                    :class="dotClass(booking.calendar_state)"
                  />
                  {{ labelFor('CALENDAR_STATE', booking.calendar_state) }}
                </span>
                <span class="text-sm text-n-slate-12">
                  <span
                    class="mr-1 inline-block size-2 rounded-full"
                    :class="dotClass(booking.preparation_state)"
                  />
                  {{ labelFor('PREPARATION_STATE', booking.preparation_state) }}
                </span>
              </button>
            </section>
          </div>
        </div>

        <div
          v-if="activeTab === 'calendar'"
          class="mt-3 grid gap-3 lg:grid-cols-7"
        >
          <section
            v-for="day in calendar"
            :key="day.date"
            class="min-h-[220px] rounded-md border border-n-weak bg-n-solid-1 p-3"
          >
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{
                formatDateTime(day.date, {
                  weekday: 'short',
                  month: 'short',
                  day: 'numeric',
                })
              }}
            </h3>
            <button
              v-for="booking in day.bookings"
              :key="booking.id"
              type="button"
              class="mt-3 w-full rounded-md border border-n-weak bg-n-background p-2 text-left text-xs focus-visible:ring-2 focus-visible:ring-n-blue-7"
              @click="selectBooking(booking)"
            >
              <span class="font-medium text-n-slate-12">{{
                timeRange(booking)
              }}</span>
              <span class="mt-1 block truncate text-n-slate-11">
                {{ booking.contact.name }}
              </span>
              <span
                class="mt-2 inline-flex rounded px-1.5 py-0.5"
                :class="statusClass(booking.calendar_state)"
              >
                {{ labelFor('CALENDAR_STATE', booking.calendar_state) }}
              </span>
            </button>
          </section>
        </div>

        <div
          v-if="activeTab === 'availability'"
          class="mt-3 grid gap-3 lg:grid-cols-[280px_minmax(0,1fr)]"
        >
          <aside
            class="rounded-md border border-n-weak bg-n-solid-1 p-4 text-sm text-n-slate-11"
          >
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.AVAILABILITY_RULES') }}
            </h3>
            <dl class="mt-3 grid gap-3">
              <div>
                <dt class="text-xs font-medium uppercase text-n-slate-10">
                  {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.CALENDAR') }}
                </dt>
                <dd>
                  {{
                    joinedLabel(
                      availability.configuration?.provider,
                      availability.configuration?.calendar_id
                    )
                  }}
                </dd>
              </div>
              <div>
                <dt class="text-xs font-medium uppercase text-n-slate-10">
                  {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.TIMEZONE') }}
                </dt>
                <dd>{{ availability.configuration?.timezone }}</dd>
              </div>
              <div>
                <dt class="text-xs font-medium uppercase text-n-slate-10">
                  {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.BUFFERS') }}
                </dt>
                <dd>
                  {{
                    t('AI_LEAD_EMPLOYEE.BOOKINGS.BUFFER_PAIR', {
                      before: availability.configuration?.buffer_before_minutes,
                      after: availability.configuration?.buffer_after_minutes,
                    })
                  }}
                </dd>
              </div>
              <div>
                <dt class="text-xs font-medium uppercase text-n-slate-10">
                  {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.MINIMUM_NOTICE') }}
                </dt>
                <dd>
                  {{
                    minutesLabel(
                      availability.configuration?.minimum_notice_minutes
                    )
                  }}
                </dd>
              </div>
            </dl>
          </aside>
          <section class="rounded-md border border-n-weak bg-n-solid-1 p-4">
            <div class="flex items-center justify-between gap-3">
              <h3 class="text-sm font-semibold text-n-slate-12">
                {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.AVAILABLE_SLOTS') }}
              </h3>
              <span
                class="rounded px-2 py-1 text-xs"
                :class="
                  availability.provider_state === 'connected'
                    ? 'bg-n-teal-3 text-n-teal-11'
                    : 'bg-n-ruby-3 text-n-ruby-11'
                "
              >
                {{ labelFor('PROVIDER_STATE', availability.provider_state) }}
              </span>
            </div>
            <div
              v-if="!availability.slots?.length"
              class="mt-4 rounded-md border border-dashed border-n-weak p-4 text-sm text-n-slate-11"
            >
              {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.NO_SLOTS') }}
            </div>
            <div v-else class="mt-4 grid gap-2 md:grid-cols-2 xl:grid-cols-3">
              <button
                v-for="slot in availability.slots"
                :key="slot.starts_at"
                type="button"
                class="rounded-md border border-n-weak bg-n-background p-3 text-left text-sm focus-visible:ring-2 focus-visible:ring-n-blue-7"
                @click="actionForm.starts_at = slot.starts_at"
              >
                <span class="font-medium text-n-slate-12">
                  {{
                    formatDateTime(slot.starts_at, {
                      weekday: 'short',
                      month: 'short',
                      day: 'numeric',
                      hour: 'numeric',
                      minute: '2-digit',
                    })
                  }}
                </span>
                <span class="mt-1 block text-xs text-n-slate-11">
                  {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.SLOT_SOURCE') }}
                </span>
              </button>
            </div>
          </section>
        </div>

        <footer
          class="mt-3 flex items-center justify-between gap-3 text-xs text-n-slate-11"
        >
          <span>{{ pageCountLabel }}</span>
          <div class="flex items-center gap-2">
            <button
              class="grid size-8 place-items-center rounded-md border border-n-weak bg-n-solid-1 text-n-slate-11"
              type="button"
              :aria-label="t('AI_LEAD_EMPLOYEE.BOOKINGS.PREVIOUS_PAGE')"
            >
              <Icon icon="i-lucide-chevron-left" class="size-4" />
            </button>
            <span class="rounded-md bg-n-blue-3 px-3 py-2 text-n-blue-11">
              {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.PAGE_NUMBER', { page: 1 }) }}
            </span>
            <button
              class="grid size-8 place-items-center rounded-md border border-n-weak bg-n-solid-1 text-n-slate-11"
              type="button"
              :aria-label="t('AI_LEAD_EMPLOYEE.BOOKINGS.NEXT_PAGE')"
            >
              <Icon icon="i-lucide-chevron-right" class="size-4" />
            </button>
          </div>
        </footer>
      </main>

      <aside
        v-if="selectedBooking"
        class="hidden min-h-0 border-l border-n-weak bg-n-solid-1 lg:flex lg:flex-col"
        :aria-label="t('AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL_LABEL')"
      >
        <div class="flex min-h-0 flex-1 flex-col overflow-auto p-4">
          <header class="flex items-start gap-3 border-b border-n-weak pb-4">
            <span
              class="grid size-10 place-items-center rounded-full bg-n-slate-3 text-sm font-medium text-n-slate-12"
            >
              {{ selectedContact.initials }}
            </span>
            <div class="min-w-0 flex-1">
              <h3 class="truncate text-base font-semibold text-n-slate-12">
                {{ selectedContact.name }}
              </h3>
              <p class="mt-1 text-sm text-n-slate-11">
                {{ selectedContact.phone_number }}
              </p>
              <p class="truncate text-xs text-n-slate-11">
                {{ selectedContact.location }}
              </p>
            </div>
          </header>

          <section class="border-b border-n-weak py-4 text-sm">
            <h4 class="font-semibold text-n-slate-12">
              {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL.BOOKING_DETAILS') }}
            </h4>
            <dl class="mt-3 grid gap-3">
              <div class="flex justify-between gap-3">
                <dt class="text-n-slate-11">
                  {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.WHEN') }}
                </dt>
                <dd class="text-right text-n-slate-12">
                  {{ timeRange(selectedBooking) }}
                </dd>
              </div>
              <div class="flex justify-between gap-3">
                <dt class="text-n-slate-11">
                  {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.OFFER') }}
                </dt>
                <dd class="text-right text-n-slate-12">
                  {{ selectedBooking.offer }}
                </dd>
              </div>
              <div class="flex justify-between gap-3">
                <dt class="text-n-slate-11">
                  {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.STATUS') }}
                </dt>
                <dd>
                  <span
                    class="rounded px-2 py-1 text-xs"
                    :class="statusClass(selectedBooking.status)"
                  >
                    {{ labelFor('STATUS', selectedBooking.status) }}
                  </span>
                </dd>
              </div>
              <div class="flex justify-between gap-3">
                <dt class="text-n-slate-11">
                  {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.BOOKED_VIA') }}
                </dt>
                <dd class="text-right text-n-slate-12">
                  {{ selectedBooking.booked_channel }}
                </dd>
              </div>
              <div class="flex justify-between gap-3">
                <dt class="text-n-slate-11">
                  {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.CREATED') }}
                </dt>
                <dd class="text-right text-n-slate-12">
                  {{
                    formatDateTime(selectedBooking.created_at, {
                      month: 'short',
                      day: 'numeric',
                      hour: 'numeric',
                      minute: '2-digit',
                    })
                  }}
                </dd>
              </div>
            </dl>
          </section>

          <section class="border-b border-n-weak py-4 text-sm">
            <div class="flex items-center justify-between gap-3">
              <h4 class="font-semibold text-n-slate-12">
                {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL.ASSIGNED_TO') }}
              </h4>
              <button
                type="button"
                class="rounded-md border border-n-weak px-3 py-1.5 text-xs text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-blue-7"
              >
                {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.REASSIGN') }}
              </button>
            </div>
            <p class="mt-3 flex items-center gap-2 text-n-slate-12">
              <span
                class="grid size-6 place-items-center rounded-full bg-n-blue-3 text-xs text-n-blue-11"
              >
                {{ selectedAssignee.initials || 'U' }}
              </span>
              {{
                selectedAssignee.name ||
                t('AI_LEAD_EMPLOYEE.BOOKINGS.UNASSIGNED')
              }}
              <span class="size-1.5 rounded-full bg-n-teal-9" />
            </p>
          </section>

          <section class="border-b border-n-weak py-4 text-sm">
            <h4 class="font-semibold text-n-slate-12">
              {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL.MEETING_LINK') }}
            </h4>
            <div class="mt-3 flex items-center justify-between gap-3">
              <a
                :href="meetingHref"
                class="min-w-0 truncate text-n-blue-11 hover:underline focus-visible:ring-2 focus-visible:ring-n-blue-7"
              >
                {{ selectedBooking.booked_channel }}
                {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.CALL') }}
              </a>
              <a
                :href="meetingHref"
                class="rounded-md border border-n-weak px-3 py-1.5 text-xs text-n-slate-12 hover:bg-n-slate-2 focus-visible:ring-2 focus-visible:ring-n-blue-7"
              >
                {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.JOIN_CALL') }}
              </a>
            </div>
            <p class="mt-2 text-xs text-n-slate-11">
              {{
                t('AI_LEAD_EMPLOYEE.BOOKINGS.CALL_STARTS', {
                  time: formatDateTime(selectedBooking.starts_at, {
                    hour: 'numeric',
                    minute: '2-digit',
                  }),
                })
              }}
            </p>
          </section>

          <section class="border-b border-n-weak py-4 text-sm">
            <h4 class="font-semibold text-n-slate-12">
              {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL.CALENDAR_INVITE') }}
            </h4>
            <p class="mt-3 flex gap-2 text-n-slate-11">
              <span
                class="mt-1 size-2 rounded-full"
                :class="dotClass(selectedBooking.calendar_state)"
              />
              {{
                joinedLabel(
                  labelFor('CALENDAR_STATE', selectedBooking.calendar_state),
                  selectedBooking.provider
                )
              }}
            </p>
            <button
              type="button"
              class="mt-3 w-full rounded-md border border-n-weak px-3 py-2 text-sm text-n-slate-12 hover:bg-n-slate-2 focus-visible:ring-2 focus-visible:ring-n-blue-7"
            >
              {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.OPEN_CALENDAR') }}
            </button>
          </section>

          <section class="py-4 text-sm">
            <h4 class="font-semibold text-n-slate-12">
              {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL.PREPARATION_BRIEF') }}
            </h4>
            <p class="mt-2 leading-5 text-n-slate-11">
              {{ detail.preparation_brief }}
            </p>
            <h5 class="mt-4 text-xs font-semibold uppercase text-n-slate-10">
              {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL.STRONGEST_EVIDENCE') }}
            </h5>
            <p
              v-for="item in detail.strongest_evidence"
              :key="`${item.signal}-${item.value}`"
              class="mt-2 flex gap-2 text-n-slate-11"
            >
              <Icon
                icon="i-lucide-check-circle-2"
                class="mt-0.5 size-4 shrink-0 text-n-teal-10"
              />
              {{ item.value }}
            </p>
            <h5 class="mt-4 text-xs font-semibold uppercase text-n-slate-10">
              {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL.LIKELY_OBJECTION') }}
            </h5>
            <p class="mt-2 flex gap-2 text-n-slate-11">
              <Icon
                icon="i-lucide-circle-alert"
                class="mt-0.5 size-4 shrink-0 text-n-amber-10"
              />
              {{ detail.likely_objection }}
            </p>
            <h5 class="mt-4 text-xs font-semibold uppercase text-n-slate-10">
              {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL.OPENING_QUESTION') }}
            </h5>
            <p class="mt-2 rounded-md bg-n-slate-2 p-3 text-n-slate-12">
              {{ detail.suggested_opening_question }}
            </p>
          </section>
        </div>
        <footer class="shrink-0 border-t border-n-weak p-4">
          <a
            :href="selectedBooking.conversation.path"
            class="inline-flex h-9 w-full items-center justify-center gap-2 rounded-md bg-n-brand px-3 text-sm font-medium text-white focus-visible:ring-2 focus-visible:ring-n-blue-7"
          >
            <Icon icon="i-lucide-message-circle" class="size-4" />
            {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.OPEN_CONVERSATION') }}
          </a>
          <div class="mt-2 grid grid-cols-2 gap-2">
            <button
              type="button"
              class="inline-flex h-9 items-center justify-center gap-2 rounded-md border border-n-weak text-sm text-n-slate-12 hover:bg-n-slate-2 focus-visible:ring-2 focus-visible:ring-n-blue-7"
              @click="openDialog('reschedule')"
            >
              <Icon icon="i-lucide-calendar-clock" class="size-4" />
              {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.RESCHEDULE') }}
            </button>
            <button
              type="button"
              class="inline-flex h-9 items-center justify-center gap-2 rounded-md border border-n-ruby-5 text-sm text-n-ruby-11 hover:bg-n-ruby-2 focus-visible:ring-2 focus-visible:ring-n-ruby-7"
              @click="openDialog('cancel')"
            >
              <Icon icon="i-lucide-trash-2" class="size-4" />
              {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.CANCEL_BOOKING') }}
            </button>
          </div>
        </footer>
      </aside>
    </div>

    <div
      v-if="showMobileDetail && selectedBooking"
      class="fixed inset-x-0 bottom-0 z-50 max-h-[82vh] overflow-auto rounded-t-lg border border-n-weak bg-n-solid-1 p-4 shadow-lg lg:hidden"
    >
      <div class="flex items-center justify-between">
        <h3 class="text-base font-semibold text-n-slate-12">
          {{ selectedContact.name }}
        </h3>
        <button
          type="button"
          class="rounded p-2 focus-visible:ring-2 focus-visible:ring-n-blue-7"
          :aria-label="t('AI_LEAD_EMPLOYEE.BOOKINGS.CLOSE_DETAIL')"
          @click="showMobileDetail = false"
        >
          <Icon icon="i-lucide-x" class="size-4" />
        </button>
      </div>
      <p class="mt-2 text-sm text-n-slate-11">
        {{ joinedLabel(timeRange(selectedBooking), selectedBooking.offer) }}
      </p>
      <dl class="mt-4 grid grid-cols-2 gap-3 text-sm">
        <div>
          <dt class="text-xs uppercase text-n-slate-10">
            {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.STATUS') }}
          </dt>
          <dd class="mt-1 font-medium text-n-slate-12">
            {{ labelFor('STATUS', selectedBooking.status) }}
          </dd>
        </div>
        <div>
          <dt class="text-xs uppercase text-n-slate-10">
            {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.CALENDAR') }}
          </dt>
          <dd class="mt-1 font-medium text-n-slate-12">
            {{ labelFor('CALENDAR_STATE', selectedBooking.calendar_state) }}
          </dd>
        </div>
        <div>
          <dt class="text-xs uppercase text-n-slate-10">
            {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL.ASSIGNED_TO') }}
          </dt>
          <dd class="mt-1 font-medium text-n-slate-12">
            {{
              selectedAssignee.name || t('AI_LEAD_EMPLOYEE.BOOKINGS.UNASSIGNED')
            }}
          </dd>
        </div>
        <div>
          <dt class="text-xs uppercase text-n-slate-10">
            {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.PREP') }}
          </dt>
          <dd class="mt-1 font-medium text-n-slate-12">
            {{
              labelFor('PREPARATION_STATE', selectedBooking.preparation_state)
            }}
          </dd>
        </div>
      </dl>
      <div class="mt-4 rounded-md bg-n-slate-2 p-3">
        <h4 class="text-sm font-semibold text-n-slate-12">
          {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL.PREPARATION_BRIEF') }}
        </h4>
        <p class="mt-2 text-sm text-n-slate-11">
          {{ detail.preparation_brief }}
        </p>
        <p class="mt-3 text-xs font-semibold uppercase text-n-slate-10">
          {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.DETAIL.STRONGEST_EVIDENCE') }}
        </p>
        <p
          v-for="item in detail.strongest_evidence || []"
          :key="`mobile-${item.signal}-${item.value}`"
          class="mt-1 text-sm text-n-slate-12"
        >
          {{ item.value }}
        </p>
        <p
          v-if="!detail.strongest_evidence?.length"
          class="mt-1 text-sm text-n-slate-11"
        >
          {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.EMPTY_VALUE') }}
        </p>
      </div>
      <a
        :href="selectedBooking.conversation.path"
        class="mt-4 inline-flex h-9 w-full items-center justify-center rounded-md bg-n-brand px-3 text-sm font-medium text-white"
      >
        {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.OPEN_CONVERSATION') }}
      </a>
      <div class="mt-3 grid grid-cols-2 gap-2">
        <button
          type="button"
          class="h-9 rounded-md border border-n-weak px-3 text-sm font-medium text-n-slate-12"
          @click="openDialog('reschedule')"
        >
          {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.RESCHEDULE') }}
        </button>
        <button
          type="button"
          class="h-9 rounded-md border border-n-ruby-5 px-3 text-sm font-medium text-n-ruby-11"
          @click="openDialog('cancel')"
        >
          {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.CANCEL_BOOKING') }}
        </button>
      </div>
    </div>

    <div
      v-if="dialogMode"
      class="fixed inset-0 z-50 grid place-items-center bg-n-alpha-black2 p-4"
    >
      <form
        class="w-full max-w-md rounded-lg border border-n-weak bg-n-solid-1 p-5 shadow-xl"
        @submit.prevent="submitAction"
      >
        <h3 class="text-base font-semibold text-n-slate-12">
          {{
            dialogMode === 'reschedule'
              ? t('AI_LEAD_EMPLOYEE.BOOKINGS.RESCHEDULE')
              : t('AI_LEAD_EMPLOYEE.BOOKINGS.CANCEL_BOOKING')
          }}
        </h3>
        <label
          v-if="dialogMode === 'reschedule'"
          class="mt-4 block text-sm font-medium text-n-slate-11"
        >
          {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.NEW_TIME') }}
          <input
            v-model="actionForm.starts_at"
            type="datetime-local"
            required
            class="mt-1 h-10 w-full rounded-md border border-n-weak bg-n-background px-3 text-sm text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-blue-7"
          />
        </label>
        <label v-else class="mt-4 block text-sm font-medium text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.CANCEL_REASON') }}
          <textarea
            v-model="actionForm.reason"
            rows="3"
            class="mt-1 w-full rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-blue-7"
          />
        </label>
        <p class="mt-3 text-sm text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.ACTION_CONSEQUENCES') }}
        </p>
        <div class="mt-5 flex justify-end gap-2">
          <button
            type="button"
            class="h-9 rounded-md border border-n-weak px-3 text-sm text-n-slate-12"
            @click="closeDialog"
          >
            {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.DISMISS') }}
          </button>
          <button
            type="submit"
            class="h-9 rounded-md px-3 text-sm font-medium text-white disabled:opacity-50"
            :class="dialogMode === 'cancel' ? 'bg-n-ruby-9' : 'bg-n-brand'"
            :disabled="isSaving"
          >
            {{
              isSaving
                ? t('AI_LEAD_EMPLOYEE.BOOKINGS.SAVING')
                : t('AI_LEAD_EMPLOYEE.BOOKINGS.CONFIRM_ACTION')
            }}
          </button>
        </div>
      </form>
    </div>
  </section>
</template>

<script setup>
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';
import Avatar from 'next/avatar/Avatar.vue';
import Icon from 'next/icon/Icon.vue';
import MessagesView from 'dashboard/components/widgets/conversation/MessagesView.vue';
import ConversationApi from 'dashboard/api/inbox/conversation';
import BookingsAPI from 'dashboard/api/bookings';
import OperationalDashboardAPI from 'dashboard/api/operationalDashboard';
import {
  conversationCockpitQueueFilters,
  isConversationCockpitQueue,
} from 'dashboard/components-next/sidebar/aiLeadEmployeeNavigation';

const props = defineProps({
  inboxId: {
    type: [String, Number],
    default: 0,
  },
  conversationId: {
    type: [String, Number],
    default: 0,
  },
});

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const { accountScopedRoute } = useAccount();

const rows = ref([]);
const performance = ref({});
const filterOptions = ref({
  qualities: [],
  follow_up_states: [],
  assignees: [],
  sources: [],
  booking_statuses: [],
});
const filters = ref({
  quality: '',
  follow_up_state: '',
  assignee_id: '',
  source_id: '',
  booking_status: '',
  unanswered: false,
});
const searchQuery = ref('');
const isLoadingRows = ref(false);
const isLoadingConversation = ref(false);
const isUpdatingAction = ref(false);
const activeDetailTab = ref('summary');
const isMobileBriefOpen = ref(false);

const currentChat = useMapGetter('getSelectedChat');
const currentUser = useMapGetter('getCurrentUser');

const activeQueue = computed(() =>
  isConversationCockpitQueue(route.query.queue) ? route.query.queue : 'hot'
);

const queueItems = computed(() => [
  {
    key: 'hot',
    label: t('AI_LEAD_EMPLOYEE.INBOX_QUEUE.HOT'),
    icon: 'i-lucide-flame',
    count: performance.value.highly_qualified_leads || 0,
    className: 'border-n-ruby-6 bg-n-ruby-3 text-n-ruby-11',
  },
  {
    key: 'review',
    label: t('AI_LEAD_EMPLOYEE.INBOX_QUEUE.REVIEW'),
    icon: 'i-lucide-user-round',
    count: performance.value.unanswered_questions || 0,
    className: 'border-n-amber-6 bg-n-amber-3 text-n-amber-11',
  },
  {
    key: 'booked',
    label: t('AI_LEAD_EMPLOYEE.INBOX_QUEUE.BOOKED'),
    icon: 'i-lucide-calendar-days',
    count: performance.value.booked_calls || 0,
    className: 'border-n-teal-6 bg-n-teal-3 text-n-teal-11',
  },
]);

const detailTabs = computed(() => [
  {
    key: 'summary',
    label: t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.TAB.SUMMARY'),
  },
  {
    key: 'evidence',
    label: t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.TAB.EVIDENCE'),
  },
  {
    key: 'activity',
    label: t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.TAB.ACTIVITY'),
  },
]);

const selectedDisplayId = computed(() => Number(props.conversationId || 0));

const selectedRow = computed(() => {
  if (!rows.value.length) return null;
  return (
    rows.value.find(
      row => Number(row.conversation_display_id) === selectedDisplayId.value
    ) || rows.value[0]
  );
});

const selectedContact = computed(
  () => currentChat.value?.meta?.sender || selectedRow.value || {}
);

function humanize(value) {
  return value
    ? value
        .toString()
        .replace(/[._-]/g, ' ')
        .split(' ')
        .filter(Boolean)
        .map(word => word.charAt(0).toUpperCase() + word.slice(1))
        .join(' ')
    : t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.EMPTY_VALUE');
}

const cockpit = computed(() => currentChat.value?.cockpit || {});
const qualification = computed(() => currentChat.value?.lead_qualification);
const currentAssignee = computed(() => currentChat.value?.meta?.assignee);
const currentInbox = computed(() =>
  currentChat.value?.inbox_id
    ? store.getters['inboxes/getInbox'](currentChat.value.inbox_id)
    : {}
);
const summaryRows = computed(() => cockpit.value.summary?.why || []);
const evidenceRows = computed(() => cockpit.value.evidence || []);
const activityRows = computed(() => cockpit.value.activity || []);
const nextAction = computed(() => cockpit.value.next_action || {});
const openReviews = computed(() => cockpit.value.open_reviews || []);
const primaryOpenReview = computed(() => openReviews.value[0] || null);
const openReviewSummary = computed(() => {
  if (!openReviews.value.length) return '';

  const reason = primaryOpenReview.value?.reason;
  if (!reason) {
    return t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.OPEN_REVIEW_COUNT', {
      count: openReviews.value.length,
    });
  }

  return t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.OPEN_REVIEW_REASON', {
    count: openReviews.value.length,
    reason: humanize(reason),
  });
});
const latestBooking = computed(() => cockpit.value.booking);
const latestHandoff = computed(() => cockpit.value.handoff);
const missingSignals = computed(
  () =>
    cockpit.value.summary?.missing_signals ||
    qualification.value?.missing_signals ||
    []
);
const strongestEvidence = computed(
  () =>
    cockpit.value.summary?.strongest_evidence ||
    qualification.value?.reasons ||
    []
);

const requestFilters = computed(() => {
  const filledFilters = Object.fromEntries(
    Object.entries(filters.value).filter(
      ([, value]) => value !== '' && value !== false
    )
  );
  if (props.inboxId) {
    filledFilters.source_id = props.inboxId;
  }
  return {
    ...filledFilters,
    ...conversationCockpitQueueFilters[activeQueue.value],
  };
});

const queueRoute = queue => ({
  name: route.name || 'home',
  params: route.params,
  query: { ...route.query, queue },
});

const rowLabel = row =>
  t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.OPEN_CONVERSATION', {
    name: row.name,
    id: row.conversation_display_id,
  });

const formatTime = value => {
  if (!value) return '';
  const timestamp = typeof value === 'number' ? value * 1000 : value;
  return new Intl.DateTimeFormat(undefined, {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(new Date(timestamp));
};

const shortTime = value => {
  if (!value) return '';
  const timestamp = typeof value === 'number' ? value * 1000 : value;
  return new Intl.DateTimeFormat(undefined, {
    hour: 'numeric',
    minute: '2-digit',
  }).format(new Date(timestamp));
};

const qualityToneClass = quality => {
  if (quality === 'highly_qualified') return 'bg-n-teal-3 text-n-teal-11';
  if (quality === 'qualified') return 'bg-n-blue-3 text-n-blue-11';
  if (quality === 'low_qualified') return 'bg-n-amber-3 text-n-amber-11';
  if (quality === 'unqualified') return 'bg-n-ruby-3 text-n-ruby-11';
  return 'bg-n-slate-3 text-n-slate-11';
};

const controlToneClass = controlState => {
  if (controlState === 'human_active') return 'text-n-slate-12';
  if (controlState === 'ai_active') return 'text-n-teal-11';
  if (controlState === 'ai_paused') return 'text-n-amber-11';
  if (controlState === 'handoff_requested') return 'text-n-blue-11';
  return 'text-n-slate-11';
};

const activityIcon = kind => {
  if (kind === 'booking') return 'i-lucide-calendar-days';
  if (kind === 'review') return 'i-lucide-message-square-warning';
  if (kind === 'handoff' || kind === 'assignment') return 'i-lucide-user-round';
  if (kind === 'control' || kind === 'ai_decision') return 'i-lucide-bot';
  if (kind === 'delivery') return 'i-lucide-send';
  return 'i-lucide-clock';
};

const activityToneClass = tone => {
  if (tone === 'teal') return 'text-n-teal-11 bg-n-teal-3';
  if (tone === 'amber') return 'text-n-amber-11 bg-n-amber-3';
  if (tone === 'blue') return 'text-n-blue-11 bg-n-blue-3';
  return 'text-n-slate-11 bg-n-slate-3';
};

const quotedText = value => (value ? `"${value}"` : '');

const contactInitials = row =>
  (row?.name || '')
    .split(' ')
    .map(part => part[0])
    .join('')
    .slice(0, 2)
    .toUpperCase();

const leadSubtitle = computed(
  () =>
    selectedRow.value?.contact_details?.additional_attributes?.company_name ||
    selectedRow.value?.location ||
    selectedRow.value?.phone_number ||
    ''
);

const phoneNumber = computed(
  () => selectedContact.value?.phone_number || selectedRow.value?.phone_number
);

const location = computed(
  () =>
    selectedRow.value?.location ||
    selectedContact.value?.additional_attributes?.location ||
    [
      selectedContact.value?.additional_attributes?.city,
      selectedContact.value?.additional_attributes?.country,
    ]
      .filter(Boolean)
      .join(', ')
);

const queueSummary = computed(() =>
  t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.QUEUE_COUNT', {
    count: rows.value.length,
  })
);

const canPauseAI = computed(
  () =>
    currentChat.value?.control_state === 'ai_active' && !isUpdatingAction.value
);
const canResumeAI = computed(
  () =>
    currentChat.value?.control_state &&
    currentChat.value.control_state !== 'ai_active' &&
    !['human_active', 'closed'].includes(currentChat.value.control_state) &&
    !isUpdatingAction.value
);

const ensureQueueQuery = () => {
  if (isConversationCockpitQueue(route.query.queue)) return;
  router.replace({
    name: route.name || 'home',
    params: route.params,
    query: { ...route.query, queue: activeQueue.value },
  });
};

const loadDashboard = async () => {
  isLoadingRows.value = true;
  try {
    const { data } = await OperationalDashboardAPI.get(requestFilters.value);
    let nextRows = data.leads || [];
    performance.value = data.performance || {};
    filterOptions.value = data.filter_options || filterOptions.value;

    if (searchQuery.value.trim()) {
      const searchResponse = await ConversationApi.search({
        q: searchQuery.value.trim(),
      });
      const matchingIds = new Set(
        (searchResponse.data?.payload || []).map(conversation =>
          Number(conversation.id)
        )
      );
      nextRows = nextRows.filter(row =>
        matchingIds.has(Number(row.conversation_display_id))
      );
    }

    rows.value = nextRows;
  } finally {
    isLoadingRows.value = false;
  }
};

const openConversation = row => {
  if (!row?.conversation_display_id) return;
  router.push({
    name: 'inbox_conversation',
    params: {
      accountId: route.params.accountId,
      conversation_id: row.conversation_display_id,
    },
    query: { ...route.query, queue: activeQueue.value },
  });
};

const syncSelectedConversation = async () => {
  if (!rows.value.length) return;
  const selectedExists = rows.value.some(
    row => Number(row.conversation_display_id) === selectedDisplayId.value
  );
  if (selectedDisplayId.value && selectedExists) return;
  await nextTick();
  openConversation(rows.value[0]);
};

const loadConversation = async displayId => {
  if (!displayId) {
    store.dispatch('clearSelectedState');
    return;
  }

  isLoadingConversation.value = true;
  try {
    const { data } = await ConversationApi.show(displayId);
    const selectedData = {
      ...data,
      dataFetched: data.messages?.length ? undefined : true,
    };
    await store.dispatch('updateConversation', selectedData);
    await store.dispatch('setActiveChat', {
      data: selectedData,
      after: route.query.messageId,
    });
    emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE, {
      messageId: route.query.messageId,
    });
    activeDetailTab.value = 'summary';
    isMobileBriefOpen.value = false;
  } finally {
    isLoadingConversation.value = false;
  }
};

const reloadCurrentConversation = async () => {
  if (currentChat.value?.id) {
    await loadConversation(currentChat.value.id);
  }
};

const pauseAI = async () => {
  if (!canPauseAI.value) return;
  isUpdatingAction.value = true;
  try {
    await store.dispatch('pauseAI', { conversationId: currentChat.value.id });
    await reloadCurrentConversation();
  } finally {
    isUpdatingAction.value = false;
  }
};

const resumeAI = async () => {
  if (!canResumeAI.value) return;
  isUpdatingAction.value = true;
  try {
    await store.dispatch('resumeAI', { conversationId: currentChat.value.id });
    await reloadCurrentConversation();
  } finally {
    isUpdatingAction.value = false;
  }
};

const assignToMe = async () => {
  if (
    !currentChat.value?.id ||
    !currentUser.value?.id ||
    isUpdatingAction.value
  ) {
    return;
  }

  isUpdatingAction.value = true;
  try {
    await store.dispatch('assignAgent', {
      conversationId: currentChat.value.id,
      agentId: currentUser.value.id,
      assigneeType: 'User',
    });
    await reloadCurrentConversation();
  } finally {
    isUpdatingAction.value = false;
  }
};

const confirmCallTime = async () => {
  if (!currentChat.value?.id || isUpdatingAction.value) return;

  isUpdatingAction.value = true;
  try {
    const startsAt =
      latestBooking.value?.starts_at ||
      new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
    await BookingsAPI.create({
      conversation_id: currentChat.value.id,
      starts_at: startsAt,
      idempotency_key: `cockpit-${currentChat.value.id}-${startsAt}`,
    });
    useAlert(t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.CALL_CONFIRMED'));
    await loadDashboard();
    await reloadCurrentConversation();
  } catch {
    useAlert(t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.CALL_CONFIRM_FAILED'));
  } finally {
    isUpdatingAction.value = false;
  }
};

const clearFilters = () => {
  filters.value = {
    quality: '',
    follow_up_state: '',
    assignee_id: '',
    source_id: '',
    booking_status: '',
    unanswered: false,
  };
  searchQuery.value = '';
};

watch(
  () => route.query.queue,
  () => {
    ensureQueueQuery();
  }
);

watch(requestFilters, loadDashboard, { deep: true });
watch(searchQuery, loadDashboard);
watch(rows, syncSelectedConversation);
watch(selectedDisplayId, loadConversation, { immediate: true });

onMounted(() => {
  store.dispatch('agents/get');
  store.dispatch('inboxes/get');
  ensureQueueQuery();
  loadDashboard();
});
</script>

<template>
  <section
    class="flex h-full min-h-0 w-full overflow-hidden bg-n-background text-n-slate-12"
    data-testid="inbox-conversation-cockpit"
  >
    <aside
      class="hidden h-full w-[304px] shrink-0 flex-col border-r border-n-weak bg-n-surface-1 lg:flex 2xl:w-[320px]"
      :aria-label="t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.INBOX_CONVERSATIONS')"
    >
      <header class="border-b border-n-weak px-3 py-3">
        <div class="flex h-8 items-center gap-2">
          <button
            type="button"
            class="inline-flex min-w-0 flex-1 items-center gap-1 rounded-md px-1 text-left text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
          >
            <span class="truncate">
              {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.URGENCY') }}
            </span>
            <Icon icon="i-lucide-chevron-down" class="size-4 shrink-0" />
          </button>
          <button
            type="button"
            class="grid size-8 place-items-center rounded-md text-n-slate-11 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
            :aria-label="t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.FILTERS')"
          >
            <Icon icon="i-lucide-list-filter" class="size-4" />
          </button>
          <button
            type="button"
            class="grid size-8 place-items-center rounded-md text-n-slate-11 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
            :aria-label="t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.SORT')"
          >
            <Icon icon="i-lucide-arrow-up-down" class="size-4" />
          </button>
        </div>

        <div class="mt-3 flex gap-2" role="list">
          <RouterLink
            v-for="item in queueItems"
            :key="item.key"
            :to="queueRoute(item.key)"
            class="inline-flex h-8 flex-1 items-center justify-center gap-1 rounded-lg border px-2 text-xs font-medium transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
            :class="
              activeQueue === item.key
                ? item.className
                : 'border-n-weak bg-n-solid-1 text-n-slate-11 hover:bg-n-alpha-2'
            "
            :aria-current="activeQueue === item.key ? 'page' : undefined"
          >
            <Icon :icon="item.icon" class="size-4" />
            <span>{{ item.label }}</span>
            <span class="tabular-nums">{{ item.count }}</span>
          </RouterLink>
        </div>

        <div class="mt-3 grid gap-2">
          <label class="sr-only" for="cockpit-search">
            {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.SEARCH') }}
          </label>
          <div class="relative">
            <Icon
              icon="i-lucide-search"
              class="absolute left-2 top-1/2 size-4 -translate-y-1/2 text-n-slate-10"
            />
            <input
              id="cockpit-search"
              v-model="searchQuery"
              type="search"
              class="h-9 w-full rounded-lg border border-n-weak bg-n-background py-2 pl-8 pr-3 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-10 focus:border-n-brand"
              :placeholder="t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.SEARCH')"
            />
          </div>

          <div class="grid grid-cols-2 gap-2">
            <select
              v-model="filters.quality"
              class="min-w-0 rounded-md border border-n-weak bg-n-background px-2 py-1.5 text-xs text-n-slate-11"
            >
              <option value="">
                {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ALL_QUALITY') }}
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
              class="min-w-0 rounded-md border border-n-weak bg-n-background px-2 py-1.5 text-xs text-n-slate-11"
            >
              <option value="">
                {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ALL_STATES') }}
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
              class="min-w-0 rounded-md border border-n-weak bg-n-background px-2 py-1.5 text-xs text-n-slate-11"
            >
              <option value="">
                {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ALL_ASSIGNEES') }}
              </option>
              <option value="me">
                {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ME') }}
              </option>
              <option value="unassigned">
                {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.UNASSIGNED') }}
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
              class="min-w-0 rounded-md border border-n-weak bg-n-background px-2 py-1.5 text-xs text-n-slate-11"
            >
              <option value="">
                {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ALL_SOURCES') }}
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
              class="min-w-0 rounded-md border border-n-weak bg-n-background px-2 py-1.5 text-xs text-n-slate-11"
            >
              <option value="">
                {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ALL_BOOKINGS') }}
              </option>
              <option
                v-for="status in filterOptions.booking_statuses"
                :key="status"
                :value="status"
              >
                {{ humanize(status) }}
              </option>
            </select>
          </div>
          <button
            type="button"
            class="w-max rounded-md px-2 py-1 text-xs font-medium text-n-blue-11 hover:bg-n-blue-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
            @click="clearFilters"
          >
            {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.CLEAR_FILTERS') }}
          </button>
        </div>
      </header>

      <div class="min-h-0 flex-1 overflow-y-auto">
        <div v-if="isLoadingRows" class="px-4 py-5 text-sm text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.LOADING') }}
        </div>
        <div v-else-if="!rows.length" class="px-4 py-5 text-sm text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.EMPTY_QUEUE') }}
        </div>
        <template v-else>
          <button
            v-for="row in rows"
            :key="row.id"
            type="button"
            class="flex w-full gap-3 border-b border-n-weak px-3 py-3 text-left transition-colors hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-inset focus-visible:outline-n-brand"
            :class="
              Number(row.conversation_display_id) === selectedDisplayId
                ? 'bg-n-background'
                : 'bg-n-surface-1'
            "
            :aria-label="rowLabel(row)"
            @click="openConversation(row)"
          >
            <div
              class="grid size-10 shrink-0 place-items-center rounded-lg bg-n-slate-3 text-sm font-medium text-n-slate-11"
            >
              {{ contactInitials(row) }}
            </div>
            <div class="min-w-0 flex-1">
              <div class="flex items-start gap-2">
                <span class="min-w-0 flex-1 truncate text-sm font-medium">
                  {{ row.name }}
                </span>
                <span class="shrink-0 text-xs text-n-slate-11">
                  {{ shortTime(row.last_activity_at) }}
                </span>
              </div>
              <p class="mt-0.5 truncate text-sm text-n-slate-11">
                {{
                  row.last_message_preview ||
                  row.reasons?.[0] ||
                  humanize(row.follow_up_state)
                }}
              </p>
              <div class="mt-2 flex items-center gap-1.5">
                <Icon
                  icon="i-logos-whatsapp-icon"
                  class="size-3.5"
                  aria-hidden="true"
                />
                <span
                  class="rounded-full px-2 py-0.5 text-xs font-medium"
                  :class="qualityToneClass(row.quality)"
                >
                  {{ humanize(row.quality) }}
                </span>
                <span
                  v-if="row.unanswered_questions_count"
                  class="size-1.5 rounded-full bg-n-ruby-9"
                />
              </div>
            </div>
          </button>
        </template>
      </div>

      <footer
        class="border-t border-n-weak px-3 py-3 text-center text-xs text-n-slate-11"
      >
        {{ queueSummary }}
      </footer>
    </aside>

    <main class="flex min-w-0 flex-1 flex-col bg-n-background">
      <header
        v-if="currentChat.id"
        class="flex min-h-[72px] shrink-0 items-center gap-3 border-b border-n-weak bg-n-background px-4 lg:min-h-[82px]"
      >
        <button
          type="button"
          class="grid size-10 place-items-center rounded-lg text-n-slate-12 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand lg:hidden"
          :aria-label="t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.BACK_TO_LIST')"
          @click="
            router.push({
              name: 'home',
              params: route.params,
              query: route.query,
            })
          "
        >
          <Icon icon="i-lucide-arrow-left" class="size-5" />
        </button>
        <Avatar
          :name="selectedContact.name"
          :src="selectedContact.thumbnail"
          :size="40"
          hide-offline-status
        />
        <div class="min-w-0 flex-1">
          <div class="flex min-w-0 items-center gap-2">
            <h1 class="truncate text-base font-semibold text-n-slate-12">
              {{ selectedContact.name || selectedRow?.name }}
            </h1>
            <Icon
              icon="i-logos-whatsapp-icon"
              class="size-4 shrink-0"
              aria-hidden="true"
            />
            <span
              v-if="qualification?.quality"
              class="hidden rounded-full px-2 py-0.5 text-xs font-medium sm:inline-flex"
              :class="qualityToneClass(qualification.quality)"
            >
              {{ humanize(qualification.quality) }}
            </span>
          </div>
          <div
            class="mt-1 flex min-w-0 flex-wrap items-center gap-x-3 gap-y-1 text-xs text-n-slate-11"
          >
            <span v-if="leadSubtitle" class="truncate">{{ leadSubtitle }}</span>
            <span v-if="phoneNumber" class="truncate">{{ phoneNumber }}</span>
            <span v-if="location" class="truncate">{{ location }}</span>
          </div>
        </div>

        <div
          class="hidden items-center gap-4 border-l border-n-weak pl-4 text-sm lg:flex"
        >
          <div
            class="flex items-center gap-2"
            :class="controlToneClass(currentChat.control_state)"
          >
            <Icon icon="i-lucide-user-round" class="size-4" />
            <span>{{ humanize(currentChat.control_state) }}</span>
            <span class="size-1.5 rounded-full bg-n-teal-9" />
          </div>
          <div class="min-w-[116px]">
            <div class="text-xs text-n-slate-11">
              {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ASSIGNEE') }}
            </div>
            <button
              type="button"
              class="mt-0.5 inline-flex items-center gap-1 rounded-md text-sm font-medium text-n-slate-12 hover:text-n-blue-11 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
              @click="assignToMe"
            >
              <Avatar
                :name="currentAssignee?.name || currentUser?.name"
                :src="currentAssignee?.avatar_url || currentUser?.avatar_url"
                :size="20"
                hide-offline-status
              />
              <span>{{
                currentAssignee?.name ||
                t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.UNASSIGNED')
              }}</span>
              <Icon icon="i-lucide-chevron-down" class="size-3.5" />
            </button>
          </div>
          <div class="min-w-[148px]">
            <div class="text-xs text-n-slate-11">
              {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.BOOKING') }}
            </div>
            <div class="mt-0.5 flex items-center gap-2 text-sm text-n-slate-12">
              <Icon
                icon="i-lucide-calendar-days"
                class="size-4 text-n-slate-11"
              />
              <span>{{
                latestBooking
                  ? formatTime(latestBooking.starts_at)
                  : humanize(selectedRow?.booking_state)
              }}</span>
            </div>
          </div>
          <button
            type="button"
            class="grid size-9 place-items-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
            :aria-label="t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.MORE_ACTIONS')"
          >
            <Icon icon="i-lucide-more-vertical" class="size-5" />
          </button>
        </div>
      </header>

      <div
        v-if="!currentChat.id"
        class="grid flex-1 place-items-center p-6 text-sm text-n-slate-11"
      >
        {{
          isLoadingConversation || isLoadingRows
            ? t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.LOADING')
            : t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.SELECT_CONVERSATION')
        }}
      </div>

      <MessagesView
        v-else
        :inbox-id="currentChat.inbox_id"
        class="min-h-0 flex-1"
        data-testid="cockpit-message-view"
      >
        <template #beforeComposer>
          <section
            class="shrink-0 border-t border-n-weak bg-n-background px-3 py-2"
          >
            <button
              type="button"
              class="flex w-full items-center gap-3 rounded-lg border border-n-weak bg-n-solid-1 px-3 py-3 text-left shadow-sm hover:bg-n-alpha-1 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand lg:hidden"
              :aria-expanded="String(isMobileBriefOpen)"
              aria-controls="mobile-lead-brief-panel"
              @click="isMobileBriefOpen = !isMobileBriefOpen"
            >
              <Icon
                icon="i-lucide-shield-check"
                class="size-5 text-n-teal-11"
              />
              <div class="min-w-0 flex-1">
                <div class="truncate text-sm font-medium text-n-slate-12">
                  {{ humanize(qualification?.quality) }}
                  <span class="mx-1 text-n-slate-10">
                    {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.SEPARATOR') }}
                  </span>
                  {{
                    t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.SCORE', {
                      score: qualification?.score || 0,
                    })
                  }}
                  <span class="mx-1 text-n-slate-10">
                    {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.SEPARATOR') }}
                  </span>
                  {{ nextAction.label }}
                </div>
              </div>
              <Icon
                :icon="
                  isMobileBriefOpen
                    ? 'i-lucide-chevron-down'
                    : 'i-lucide-chevron-right'
                "
                class="size-5 text-n-slate-11"
              />
            </button>

            <section
              v-if="isMobileBriefOpen"
              id="mobile-lead-brief-panel"
              class="mt-2 max-h-[42vh] overflow-y-auto rounded-lg border border-n-weak bg-n-background p-4 shadow-sm lg:hidden"
              :aria-label="t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.LEAD_BRIEF')"
            >
              <div class="mx-auto mb-3 h-1 w-12 rounded-full bg-n-slate-6" />
              <div class="flex items-start justify-between gap-3">
                <div>
                  <h2 class="text-base font-semibold text-n-slate-12">
                    {{ humanize(qualification?.quality) }}
                  </h2>
                  <p class="mt-1 text-sm text-n-slate-11">
                    {{ nextAction.label }}
                    {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.SEPARATOR') }}
                    {{ nextAction.detail }}
                  </p>
                </div>
                <button
                  type="button"
                  class="grid size-9 place-items-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
                  :aria-label="t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.CLOSE')"
                  @click="isMobileBriefOpen = false"
                >
                  <Icon icon="i-lucide-x" class="size-5" />
                </button>
              </div>
              <div class="mt-4 grid gap-3">
                <div
                  v-for="item in summaryRows"
                  :key="item.label"
                  class="flex justify-between gap-4 text-sm"
                >
                  <span class="text-n-slate-11">{{ item.label }}</span>
                  <span class="text-right font-medium text-n-slate-12">{{
                    item.value
                  }}</span>
                </div>
              </div>
              <div class="mt-4 flex gap-2">
                <button
                  type="button"
                  class="h-10 flex-1 rounded-lg bg-n-brand px-3 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-60"
                  :disabled="isUpdatingAction"
                  @click="confirmCallTime"
                >
                  {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.CONFIRM_CALL') }}
                </button>
                <button
                  type="button"
                  class="h-10 flex-1 rounded-lg border border-n-weak px-3 text-sm font-medium text-n-slate-12 disabled:cursor-not-allowed disabled:opacity-60"
                  :disabled="!canPauseAI && !canResumeAI"
                  @click="canPauseAI ? pauseAI() : resumeAI()"
                >
                  {{
                    canPauseAI
                      ? t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.PAUSE_AI')
                      : t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.RESUME_AI')
                  }}
                </button>
              </div>
            </section>

            <article
              class="hidden rounded-lg border border-n-weak bg-n-solid-1 p-3 shadow-sm lg:block"
            >
              <div class="flex items-start justify-between gap-3">
                <div class="min-w-0">
                  <div class="flex items-center gap-2">
                    <h2 class="text-sm font-semibold text-n-slate-12">
                      {{
                        t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.PROPOSED_NEXT_STEP')
                      }}
                    </h2>
                    <span
                      class="rounded-full bg-n-teal-3 px-2 py-0.5 text-xs font-medium text-n-teal-11"
                    >
                      {{ humanize(nextAction.kind) }}
                    </span>
                  </div>
                  <p class="mt-1 text-sm text-n-slate-11">
                    {{ nextAction.detail }}
                  </p>
                  <div
                    v-if="latestHandoff || openReviews.length"
                    class="mt-2 flex flex-wrap gap-2 text-xs"
                  >
                    <span
                      v-if="latestHandoff"
                      class="rounded-full bg-n-blue-3 px-2 py-0.5 font-medium text-n-blue-11"
                    >
                      {{
                        t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.HANDOFF_STATE', {
                          state: humanize(latestHandoff.status),
                        })
                      }}
                    </span>
                    <span
                      v-if="openReviews.length"
                      class="rounded-full bg-n-amber-3 px-2 py-0.5 font-medium text-n-amber-11"
                    >
                      {{ openReviewSummary }}
                    </span>
                  </div>
                </div>
                <details class="shrink-0 text-xs text-n-slate-11">
                  <summary
                    class="cursor-pointer rounded-md px-2 py-1 hover:bg-n-alpha-2"
                  >
                    {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.TECHNICAL_DETAILS') }}
                  </summary>
                  <div
                    class="mt-2 w-52 rounded-md border border-n-weak bg-n-background p-2"
                  >
                    <div>
                      {{
                        t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.CONTROL_VERSION', {
                          version: currentChat.control_version,
                        })
                      }}
                    </div>
                    <div>{{ humanize(currentChat.control_state) }}</div>
                    <div>{{ currentInbox?.name }}</div>
                  </div>
                </details>
              </div>
              <div
                class="mt-3 grid gap-3 text-xs text-n-slate-11 md:grid-cols-3"
              >
                <div>
                  <div class="font-medium text-n-slate-12">
                    {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.PROPOSED_TIME') }}
                  </div>
                  <div>
                    {{
                      latestBooking
                        ? formatTime(latestBooking.starts_at)
                        : nextAction.detail
                    }}
                  </div>
                </div>
                <div>
                  <div class="font-medium text-n-slate-12">
                    {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ATTENDEE') }}
                  </div>
                  <div>{{ selectedContact.name }} {{ phoneNumber }}</div>
                </div>
                <div>
                  <div class="font-medium text-n-slate-12">
                    {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.CALL_TYPE') }}
                  </div>
                  <div>
                    {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.PRODUCT_DEMO') }}
                  </div>
                </div>
              </div>
              <div class="mt-3 flex flex-wrap justify-end gap-2">
                <RouterLink
                  :to="accountScopedRoute('owned_knowledge_index')"
                  class="inline-flex h-9 items-center gap-2 rounded-lg border border-n-weak px-3 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
                >
                  {{ t('AI_LEAD_EMPLOYEE.NAV.KNOWLEDGE') }}
                  <Icon icon="i-lucide-external-link" class="size-4" />
                </RouterLink>
                <RouterLink
                  :to="accountScopedRoute('owned_test_center_index')"
                  class="inline-flex h-9 items-center gap-2 rounded-lg border border-n-weak px-3 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
                >
                  {{ t('AI_LEAD_EMPLOYEE.NAV.TEST_CENTER') }}
                  <Icon icon="i-lucide-external-link" class="size-4" />
                </RouterLink>
                <button
                  type="button"
                  class="inline-flex h-9 items-center gap-2 rounded-lg bg-n-brand px-3 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-60"
                  :disabled="isUpdatingAction"
                  @click="confirmCallTime"
                >
                  {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.CONFIRM_CALL') }}
                </button>
                <button
                  type="button"
                  class="inline-flex h-9 items-center gap-2 rounded-lg border border-n-weak px-3 text-sm font-medium text-n-slate-12 disabled:cursor-not-allowed disabled:opacity-60"
                  :disabled="isUpdatingAction"
                  @click="assignToMe"
                >
                  <Icon icon="i-lucide-user-round" class="size-4" />
                  {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ASSIGN') }}
                </button>
                <button
                  type="button"
                  class="inline-flex h-9 items-center gap-2 rounded-lg border border-n-weak px-3 text-sm font-medium text-n-slate-12 disabled:cursor-not-allowed disabled:opacity-60"
                  :disabled="!canPauseAI && !canResumeAI"
                  @click="canPauseAI ? pauseAI() : resumeAI()"
                >
                  <Icon icon="i-lucide-send" class="size-4" />
                  {{
                    canPauseAI
                      ? t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.PAUSE_AI')
                      : t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.RESUME_AI')
                  }}
                </button>
              </div>
            </article>
          </section>
        </template>
      </MessagesView>
    </main>

    <aside
      v-if="currentChat.id"
      class="hidden h-full w-[356px] shrink-0 flex-col border-l border-n-weak bg-n-background lg:flex 2xl:w-[380px]"
      :aria-label="t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.LEAD_BRIEF')"
    >
      <div class="flex h-12 shrink-0 border-b border-n-weak px-4">
        <button
          v-for="tab in detailTabs"
          :key="tab.key"
          type="button"
          class="-mb-px flex-1 border-b-2 px-2 text-sm font-medium capitalize focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
          :class="
            activeDetailTab === tab.key
              ? 'border-n-brand text-n-blue-11'
              : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
          "
          @click="activeDetailTab = tab.key"
        >
          {{ tab.label }}
        </button>
      </div>
      <div class="min-h-0 flex-1 overflow-y-auto px-4 py-4">
        <section v-if="activeDetailTab === 'summary'" class="grid gap-5">
          <div>
            <h2 class="text-sm font-semibold text-n-slate-12">
              {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.WHY_THIS_LEAD_MATTERS') }}
            </h2>
            <dl class="mt-3 grid gap-3">
              <div
                v-for="item in summaryRows"
                :key="item.label"
                class="grid grid-cols-[120px_1fr] gap-3 text-sm"
              >
                <dt class="text-n-slate-11">{{ item.label }}</dt>
                <dd class="text-n-slate-12">{{ item.value }}</dd>
              </div>
            </dl>
          </div>
          <div class="border-t border-n-weak pt-4">
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.STRONGEST_EVIDENCE') }}
            </h3>
            <ul class="mt-3 grid gap-3">
              <li
                v-for="item in strongestEvidence"
                :key="item"
                class="flex gap-2 text-sm text-n-slate-12"
              >
                <Icon
                  icon="i-lucide-circle-check"
                  class="mt-0.5 size-4 shrink-0 text-n-teal-11"
                />
                <span>{{ item }}</span>
              </li>
            </ul>
          </div>
          <div class="border-t border-n-weak pt-4">
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.MISSING_SIGNALS') }}
            </h3>
            <ul class="mt-3 grid gap-3">
              <li
                v-for="item in missingSignals"
                :key="item"
                class="flex gap-2 text-sm text-n-slate-12"
              >
                <Icon
                  icon="i-lucide-circle-alert"
                  class="mt-0.5 size-4 shrink-0 text-n-amber-11"
                />
                <span>{{ humanize(item) }}</span>
              </li>
              <li v-if="!missingSignals.length" class="text-sm text-n-slate-11">
                {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.NO_MISSING_SIGNALS') }}
              </li>
            </ul>
          </div>
          <div class="border-t border-n-weak pt-4">
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.NEXT_RECOMMENDED_ACTION') }}
            </h3>
            <p class="mt-2 text-sm text-n-slate-12">{{ nextAction.label }}</p>
            <p class="mt-1 text-sm text-n-slate-11">{{ nextAction.detail }}</p>
          </div>
        </section>

        <section v-else-if="activeDetailTab === 'evidence'" class="grid gap-3">
          <article
            v-for="item in evidenceRows"
            :key="item.id"
            class="rounded-lg border border-n-weak bg-n-solid-1 p-3"
          >
            <div class="flex items-start justify-between gap-2">
              <div class="min-w-0">
                <h2 class="text-sm font-semibold text-n-slate-12">
                  {{ humanize(item.signal) }}
                </h2>
                <p class="mt-1 text-sm text-n-slate-11">{{ item.value }}</p>
              </div>
              <span
                class="rounded-full px-2 py-0.5 text-xs font-medium"
                :class="
                  item.superseded
                    ? 'bg-n-slate-3 text-n-slate-11'
                    : 'bg-n-teal-3 text-n-teal-11'
                "
              >
                {{
                  item.superseded
                    ? t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.SUPERSEDED')
                    : t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.CURRENT')
                }}
              </span>
            </div>
            <p v-if="item.source_message" class="mt-2 text-xs text-n-slate-11">
              {{ quotedText(item.source_message) }}
            </p>
            <div
              class="mt-2 flex items-center justify-between text-xs text-n-slate-11"
            >
              <span>{{ humanize(item.source) }}</span>
              <span>{{ formatTime(item.observed_at) }}</span>
            </div>
          </article>
        </section>

        <section v-else class="grid gap-3">
          <article
            v-for="item in activityRows"
            :key="item.id"
            class="flex gap-3 rounded-lg border border-n-weak bg-n-solid-1 p-3"
          >
            <div
              class="grid size-8 shrink-0 place-items-center rounded-full"
              :class="activityToneClass(item.tone)"
            >
              <Icon :icon="activityIcon(item.kind)" class="size-4" />
            </div>
            <div class="min-w-0 flex-1">
              <div class="flex items-start justify-between gap-2">
                <h2 class="text-sm font-medium text-n-slate-12">
                  {{ item.label }}
                </h2>
                <span class="shrink-0 text-xs text-n-slate-11">
                  {{ formatTime(item.occurred_at) }}
                </span>
              </div>
              <p class="mt-1 text-sm text-n-slate-11">{{ item.detail }}</p>
            </div>
          </article>
        </section>
      </div>
    </aside>
  </section>
</template>

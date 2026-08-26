<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import Icon from 'next/icon/Icon.vue';
import OperationalDashboardAPI from 'dashboard/api/operationalDashboard';
import {
  conversationCockpitQueueFilters,
  isConversationCockpitQueue,
  queueRouteQuery,
} from './aiLeadEmployeeNavigation';

const props = defineProps({
  mobile: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['queueData']);

const { t } = useI18n();
const route = useRoute();
const { accountScopedRoute } = useAccount();
const performance = ref({});
const activeQueueConversationIds = ref([]);
const isLoadingQueue = ref(false);

const activeQueue = computed(() => {
  const queue = route.query.queue;
  return isConversationCockpitQueue(queue) ? queue : '';
});

const countFor = key => {
  const metricMap = {
    hot: 'highly_qualified_leads',
    review: 'unanswered_questions',
    booked: 'booked_calls',
  };
  return performance.value[metricMap[key]] ?? 0;
};

const queueItems = computed(() => [
  {
    key: 'hot',
    label: t('AI_LEAD_EMPLOYEE.INBOX_QUEUE.HOT'),
    icon: 'i-lucide-flame',
    tone: 'ruby',
    count: countFor('hot'),
  },
  {
    key: 'review',
    label: t('AI_LEAD_EMPLOYEE.INBOX_QUEUE.REVIEW'),
    icon: 'i-lucide-user-round',
    tone: 'amber',
    count: countFor('review'),
  },
  {
    key: 'booked',
    label: t('AI_LEAD_EMPLOYEE.INBOX_QUEUE.BOOKED'),
    icon: 'i-lucide-calendar-days',
    tone: 'teal',
    count: countFor('booked'),
  },
]);

const routeForQueue = key =>
  accountScopedRoute('home', {}, queueRouteQuery(key));

const chipClass = item => {
  const isActive = activeQueue.value === item.key;
  const mobileSize = 'min-h-10 flex-1 justify-center px-3 text-base';
  const desktopSize = 'h-8 px-2.5 text-sm';
  const base = props.mobile ? mobileSize : desktopSize;

  if (item.tone === 'ruby') {
    return [
      base,
      isActive
        ? 'border-n-ruby-6 bg-n-ruby-3 text-n-ruby-11'
        : 'border-n-weak bg-n-solid-1 text-n-ruby-11 hover:bg-n-ruby-2',
    ];
  }

  if (item.tone === 'amber') {
    return [
      base,
      isActive
        ? 'border-n-amber-6 bg-n-amber-3 text-n-amber-11'
        : 'border-n-weak bg-n-solid-1 text-n-amber-11 hover:bg-n-amber-2',
    ];
  }

  return [
    base,
    isActive
      ? 'border-n-teal-6 bg-n-teal-3 text-n-teal-11'
      : 'border-n-weak bg-n-solid-1 text-n-teal-11 hover:bg-n-teal-2',
  ];
};

const loadCounts = async () => {
  try {
    const { data } = await OperationalDashboardAPI.get();
    performance.value = data.performance || {};
  } catch {
    performance.value = {};
  }
};

const loadQueueConversationIds = async queue => {
  if (!isConversationCockpitQueue(queue)) {
    activeQueueConversationIds.value = [];
    emit('queueData', { queue: '', conversationIds: [], isLoading: false });
    return;
  }

  isLoadingQueue.value = true;
  emit('queueData', { queue, conversationIds: [], isLoading: true });
  try {
    const { data } = await OperationalDashboardAPI.get(
      conversationCockpitQueueFilters[queue]
    );
    activeQueueConversationIds.value = (data.leads || [])
      .map(lead => Number(lead.conversation_display_id || lead.conversation_id))
      .filter(Boolean);
    emit('queueData', {
      queue,
      conversationIds: activeQueueConversationIds.value,
      isLoading: false,
    });
  } catch {
    activeQueueConversationIds.value = [];
    emit('queueData', {
      queue,
      conversationIds: [],
      isLoading: false,
    });
  } finally {
    isLoadingQueue.value = false;
  }
};

watch(activeQueue, loadQueueConversationIds, { immediate: true });

onMounted(loadCounts);
</script>

<template>
  <div
    class="flex gap-2"
    :class="props.mobile ? 'w-full px-4 py-3' : 'px-3 pb-3'"
    :aria-label="t('AI_LEAD_EMPLOYEE.INBOX_QUEUE.LABEL')"
  >
    <RouterLink
      v-for="item in queueItems"
      :key="item.key"
      :to="routeForQueue(item.key)"
      class="inline-flex items-center gap-1.5 rounded-lg border font-medium transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
      :class="chipClass(item)"
      :aria-current="activeQueue === item.key ? 'page' : undefined"
      :aria-label="
        t('AI_LEAD_EMPLOYEE.INBOX_QUEUE.ARIA', {
          label: item.label,
          count: item.count,
        })
      "
    >
      <Icon :icon="item.icon" class="size-4 shrink-0" />
      <span class="truncate">{{ item.label }}</span>
      <span
        class="tabular-nums"
        :class="{ 'opacity-60': isLoadingQueue && activeQueue === item.key }"
      >
        {{ item.count }}
      </span>
    </RouterLink>
  </div>
</template>

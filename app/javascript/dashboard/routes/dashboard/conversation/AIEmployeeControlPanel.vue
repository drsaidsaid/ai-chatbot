<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';

const props = defineProps({
  currentChat: {
    type: Object,
    default: () => ({}),
  },
});

const store = useStore();
const { t } = useI18n();
const isUpdating = ref(false);

const controlState = computed(
  () => props.currentChat.control_state || 'ai_active'
);
const controlVersion = computed(() => props.currentChat.control_version || 0);
const metaWhatsappEvents = computed(
  () => props.currentChat.meta_whatsapp_events || []
);
const aiEmployeeDecision = computed(
  () => props.currentChat.ai_employee_decision || null
);
const leadQualification = computed(
  () => props.currentChat.lead_qualification || null
);
const qualificationEvidence = computed(
  () => leadQualification.value?.evidence || {}
);
const decisionSources = computed(() => aiEmployeeDecision.value?.sources || []);
const isAIActive = computed(() => controlState.value === 'ai_active');
const canUpdateAI = computed(
  () => !['human_active', 'closed'].includes(controlState.value)
);
const stateLabel = computed(() => {
  switch (controlState.value) {
    case 'ai_active':
      return t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.STATE.AI_ACTIVE');
    case 'ai_paused':
      return t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.STATE.AI_PAUSED');
    case 'human_active':
      return t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.STATE.HUMAN_ACTIVE');
    case 'handoff_requested':
      return t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.STATE.HANDOFF_REQUESTED');
    case 'closed':
      return t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.STATE.CLOSED');
    default:
      return controlState.value;
  }
});

const latestEventLabel = event => {
  if (event.event_kind?.startsWith('status.')) {
    return t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.EVENT.STATUS');
  }

  switch (event.event_kind) {
    case 'message.text':
      return t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.EVENT.MESSAGE_TEXT');
    case 'message.audio':
    case 'message.voice':
      return t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.EVENT.MESSAGE_VOICE');
    case 'status':
      return t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.EVENT.STATUS');
    default:
      return event.event_kind;
  }
};

const formatTime = timestamp => {
  if (!timestamp) return '';
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(timestamp * 1000));
};

const updateAIControl = async action => {
  if (!props.currentChat.id || isUpdating.value) return;

  isUpdating.value = true;
  try {
    await store.dispatch(action, { conversationId: props.currentChat.id });
  } finally {
    isUpdating.value = false;
  }
};
</script>

<template>
  <section class="flex flex-col gap-3 px-3 py-3 text-sm">
    <div class="flex items-center justify-between gap-3">
      <span class="font-medium text-n-slate-12">
        {{ $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.TITLE') }}
      </span>
      <span
        class="rounded-sm border border-n-weak px-2 py-1 text-xs font-medium text-n-slate-11"
      >
        {{ stateLabel }}
      </span>
    </div>

    <div class="flex gap-2">
      <woot-button
        size="small"
        variant="smooth"
        color-scheme="secondary"
        :disabled="!canUpdateAI || !isAIActive || isUpdating"
        @click="updateAIControl('pauseAI')"
      >
        {{ $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.PAUSE') }}
      </woot-button>
      <woot-button
        size="small"
        variant="smooth"
        color-scheme="secondary"
        :disabled="!canUpdateAI || isAIActive || isUpdating"
        @click="updateAIControl('resumeAI')"
      >
        {{ $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.RESUME') }}
      </woot-button>
    </div>

    <div class="text-xs text-n-slate-11">
      {{
        $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.CONTROL_VERSION', {
          version: controlVersion,
        })
      }}
    </div>

    <div
      v-if="aiEmployeeDecision"
      class="flex flex-col gap-2 border-t border-n-weak pt-3 text-xs"
    >
      <div class="font-medium uppercase text-n-slate-11">
        {{ $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.LAST_DECISION') }}
      </div>
      <div v-if="decisionSources.length" class="flex flex-col gap-1">
        <span
          v-for="source in decisionSources"
          :key="source.id"
          class="text-n-slate-12"
        >
          {{ source.title }}
          <span class="text-n-slate-11">{{ source.source_kind }}</span>
        </span>
      </div>
      <span v-else class="text-n-slate-11">
        {{
          $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.REFUSAL_REASON', {
            reason: aiEmployeeDecision.refusal_reason,
          })
        }}
      </span>
    </div>

    <div
      v-if="leadQualification"
      class="flex flex-col gap-2 border-t border-n-weak pt-3 text-xs"
    >
      <div class="font-medium uppercase text-n-slate-11">
        {{ $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.QUALIFICATION.TITLE') }}
      </div>
      <div class="flex items-center justify-between gap-2">
        <span class="text-n-slate-11">
          {{ $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.QUALIFICATION.QUALITY') }}
        </span>
        <span class="font-medium text-n-slate-12">
          {{ leadQualification.quality }}
        </span>
      </div>
      <div class="flex items-center justify-between gap-2">
        <span class="text-n-slate-11">
          {{ $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.QUALIFICATION.SCORE') }}
        </span>
        <span class="font-medium text-n-slate-12">
          {{ leadQualification.score }}
        </span>
      </div>
      <div v-if="leadQualification.next_question" class="flex flex-col gap-1">
        <span class="text-n-slate-11">
          {{
            $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.QUALIFICATION.NEXT_QUESTION')
          }}
        </span>
        <span class="text-n-slate-12">
          {{ leadQualification.next_question }}
        </span>
      </div>
      <div
        v-if="Object.keys(qualificationEvidence).length"
        class="flex flex-col gap-1"
      >
        <span class="text-n-slate-11">
          {{ $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.QUALIFICATION.FACTS') }}
        </span>
        <span
          v-for="(evidence, signal) in qualificationEvidence"
          :key="signal"
          class="text-n-slate-12"
        >
          <span>{{ signal }}</span>
          <span class="text-n-slate-11">{{ evidence.value }}</span>
        </span>
      </div>
      <div v-if="leadQualification.reasons?.length" class="flex flex-col gap-1">
        <span class="text-n-slate-11">
          {{ $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.QUALIFICATION.REASONS') }}
        </span>
        <span
          v-for="reason in leadQualification.reasons"
          :key="reason"
          class="text-n-slate-12"
        >
          {{ reason }}
        </span>
      </div>
    </div>

    <div v-if="metaWhatsappEvents.length" class="flex flex-col gap-2">
      <div class="text-xs font-medium uppercase text-n-slate-11">
        {{ $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.RECENT_EVENTS') }}
      </div>
      <div
        v-for="event in metaWhatsappEvents"
        :key="event.id"
        class="flex flex-col gap-1 border-t border-n-weak pt-2"
      >
        <span class="text-n-slate-12">{{ latestEventLabel(event) }}</span>
        <span class="text-xs text-n-slate-11">
          {{ event.provider_event_id }}
        </span>
        <span class="text-xs text-n-slate-11">
          {{ formatTime(event.processed_at || event.created_at) }}
        </span>
      </div>
    </div>
  </section>
</template>

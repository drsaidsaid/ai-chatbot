<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import LeadQualificationsAPI from 'dashboard/api/leadQualifications';

const props = defineProps({
  currentChat: {
    type: Object,
    default: () => ({}),
  },
});

const QUALIFICATION_SIGNALS = [
  'business_type',
  'problem',
  'lead_volume',
  'urgency',
  'budget',
  'decision_authority',
  'contact_details',
];

const store = useStore();
const { t } = useI18n();
const isUpdating = ref(false);
const isSavingEvidence = ref(false);
const correctionSignal = ref(QUALIFICATION_SIGNALS[0]);
const correctionValue = ref('');

const controlState = computed(
  () => props.currentChat.control_state || 'ai_active'
);
const controlVersion = computed(() => props.currentChat.control_version || 0);
const controlEvents = computed(() => props.currentChat.control_events || []);
const metaWhatsappEvents = computed(
  () => props.currentChat.meta_whatsapp_events || []
);
const ownerName = computed(
  () =>
    props.currentChat.meta?.assignee?.name ||
    props.currentChat.meta?.assignee?.available_name ||
    null
);
const aiEmployeeDecision = computed(
  () => props.currentChat.ai_employee_decision || null
);
const leadQualification = computed(
  () => props.currentChat.lead_qualification || null
);
const leadFollowUps = computed(() => leadQualification.value?.follow_ups || []);
const leadFollowUpOptedOut = computed(
  () => leadQualification.value?.follow_up_opted_out || false
);
const qualificationEvidence = computed(
  () => leadQualification.value?.evidence || {}
);
const qualificationEvidenceRecords = computed(
  () => leadQualification.value?.evidence_records || []
);
const leadHandoffs = computed(() => leadQualification.value?.handoffs || []);
const contactId = computed(
  () =>
    props.currentChat.meta?.sender?.id || leadQualification.value?.contact_id
);
const decisionSources = computed(() => aiEmployeeDecision.value?.sources || []);
const canPauseAI = computed(() => controlState.value === 'ai_active');
const canResumeAI = computed(
  () => !['ai_active', 'closed'].includes(controlState.value)
);
const canRequestHandoff = computed(() => controlState.value === 'ai_active');
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
  if (event.event_kind === 'smb_message_echoes') {
    return t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.EVENT.MESSAGE_ECHO');
  }

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

const controlEventLabel = event => {
  const action = event.action || '';
  const from = event.from || '';
  const to = event.to || '';
  if (!from && !to) return action;

  return `${action}: ${from} -> ${to}`;
};

const formatTime = timestamp => {
  if (!timestamp) return '';
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(timestamp * 1000));
};

const formatDateTime = timestamp => {
  if (!timestamp) return '';
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(timestamp));
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

const saveEvidenceCorrection = async () => {
  if (
    !contactId.value ||
    !correctionValue.value.trim() ||
    isSavingEvidence.value
  ) {
    return;
  }

  isSavingEvidence.value = true;
  try {
    await LeadQualificationsAPI.evidence(contactId.value, {
      signal: correctionSignal.value,
      value: correctionValue.value.trim(),
    });
    correctionValue.value = '';
    await store.dispatch('getConversation', props.currentChat.id);
  } finally {
    isSavingEvidence.value = false;
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
      <button
        type="button"
        class="inline-flex h-8 items-center justify-center gap-1 rounded-lg border border-n-weak px-2 text-sm font-medium text-n-slate-12 disabled:cursor-not-allowed disabled:opacity-50"
        :disabled="!canPauseAI || isUpdating"
        data-testid="ai-control-pause"
        @click="updateAIControl('pauseAI')"
      >
        <span class="i-lucide-pause size-3.5" />
        {{ $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.PAUSE') }}
      </button>
      <button
        type="button"
        class="inline-flex h-8 items-center justify-center gap-1 rounded-lg border border-n-weak px-2 text-sm font-medium text-n-slate-12 disabled:cursor-not-allowed disabled:opacity-50"
        :disabled="!canResumeAI || isUpdating"
        data-testid="ai-control-resume"
        @click="updateAIControl('resumeAI')"
      >
        <span class="i-lucide-play size-3.5" />
        {{ $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.RESUME') }}
      </button>
      <button
        type="button"
        class="inline-flex h-8 items-center justify-center gap-1 rounded-lg border border-n-weak px-2 text-sm font-medium text-n-slate-12 disabled:cursor-not-allowed disabled:opacity-50"
        :disabled="!canRequestHandoff || isUpdating"
        data-testid="ai-control-handoff"
        @click="updateAIControl('handoffAI')"
      >
        <span class="i-lucide-hand size-3.5" />
        {{ $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.HANDOFF') }}
      </button>
    </div>

    <div class="flex flex-col gap-1 text-xs text-n-slate-11">
      <div class="flex items-center justify-between gap-2">
        <span>{{ $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.OWNER') }}</span>
        <span class="font-medium text-n-slate-12">
          {{ ownerName || $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.NO_OWNER') }}
        </span>
      </div>
      <span>
        {{
          $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.CONTROL_VERSION', {
            version: controlVersion,
          })
        }}
      </span>
    </div>

    <div v-if="controlEvents.length" class="flex flex-col gap-2">
      <div class="text-xs font-medium uppercase text-n-slate-11">
        {{ $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.RECENT_CONTROL_EVENTS') }}
      </div>
      <div
        v-for="event in controlEvents"
        :key="event.id"
        class="flex flex-col gap-1 border-t border-n-weak pt-2 text-xs"
      >
        <span class="text-n-slate-12">{{ controlEventLabel(event) }}</span>
        <span v-if="event.actor_name" class="text-n-slate-11">
          {{ event.actor_name }}
        </span>
        <span class="text-n-slate-11">
          {{ formatTime(event.created_at) }}
        </span>
      </div>
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
      <div
        v-if="qualificationEvidenceRecords.length"
        class="flex flex-col gap-1"
      >
        <span class="text-n-slate-11">
          {{
            $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.QUALIFICATION.EVIDENCE_REVIEW')
          }}
        </span>
        <span
          v-for="record in qualificationEvidenceRecords"
          :key="record.id"
          class="text-n-slate-12"
        >
          <span>{{ record.signal }}</span>
          <span class="text-n-slate-11">{{ record.value }}</span>
          <span class="text-n-slate-11">{{ record.source }}</span>
        </span>
      </div>
      <form
        class="flex flex-col gap-2"
        @submit.prevent="saveEvidenceCorrection"
      >
        <span class="text-n-slate-11">
          {{
            $t(
              'CONVERSATION_SIDEBAR.AI_EMPLOYEE.QUALIFICATION.EVIDENCE_CORRECTION'
            )
          }}
        </span>
        <select
          v-model="correctionSignal"
          class="h-8 rounded-md border border-n-weak bg-n-alpha-2 px-2 text-xs text-n-slate-12 outline-none"
          data-testid="qualification-evidence-signal"
        >
          <option
            v-for="signal in QUALIFICATION_SIGNALS"
            :key="signal"
            :value="signal"
          >
            {{ signal }}
          </option>
        </select>
        <div class="flex gap-2">
          <input
            v-model="correctionValue"
            type="text"
            class="min-w-0 flex-1 rounded-md border border-n-weak bg-n-alpha-2 px-2 text-xs text-n-slate-12 outline-none"
            :placeholder="
              $t(
                'CONVERSATION_SIDEBAR.AI_EMPLOYEE.QUALIFICATION.EVIDENCE_VALUE'
              )
            "
            data-testid="qualification-evidence-value"
          />
          <button
            type="submit"
            class="inline-flex h-8 items-center justify-center gap-1 rounded-lg border border-n-weak px-2 text-sm font-medium text-n-slate-12 disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="
              !contactId || !correctionValue.trim() || isSavingEvidence
            "
            data-testid="qualification-evidence-save"
          >
            <span class="i-lucide-check size-3.5" />
            {{ $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.QUALIFICATION.SAVE') }}
          </button>
        </div>
      </form>
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
      <div v-if="leadFollowUpOptedOut" class="text-n-slate-12">
        {{ $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.FOLLOW_UP.OPTED_OUT') }}
      </div>
      <div v-if="leadFollowUps.length" class="flex flex-col gap-1">
        <span class="text-n-slate-11">
          {{ $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.FOLLOW_UP.TITLE') }}
        </span>
        <span
          v-for="followUp in leadFollowUps"
          :key="followUp.id"
          class="text-n-slate-12"
        >
          {{
            $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.FOLLOW_UP.ATTEMPT', {
              status: followUp.status,
              stage: followUp.stage,
              attempt: followUp.attempt_number,
            })
          }}
          <span class="text-n-slate-11">
            {{
              formatDateTime(
                followUp.sent_at ||
                  followUp.cancelled_at ||
                  followUp.failed_at ||
                  followUp.scheduled_at
              )
            }}
          </span>
          <span
            v-if="followUp.cancellation_reason || followUp.failure_reason"
            class="text-n-slate-11"
          >
            {{ followUp.cancellation_reason || followUp.failure_reason }}
          </span>
        </span>
      </div>
      <div v-if="leadHandoffs.length" class="flex flex-col gap-1">
        <span class="text-n-slate-11">
          {{ $t('CONVERSATION_SIDEBAR.AI_EMPLOYEE.HANDOFF_STATUS') }}
        </span>
        <span
          v-for="handoff in leadHandoffs"
          :key="handoff.id"
          class="text-n-slate-12"
        >
          {{ handoff.status }}
          <span class="text-n-slate-11">
            {{
              handoff.alert_deliveries
                ?.map(delivery => delivery.status)
                .join(', ')
            }}
          </span>
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

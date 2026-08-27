<script setup>
import { computed } from 'vue';
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  lead: { type: Object, required: true },
  qualityLabel: { type: Function, required: true },
  followUpLabel: { type: Function, required: true },
  bookingStatusLabel: { type: Function, required: true },
  nextActionLabel: { type: Function, required: true },
  channelKindLabel: { type: Function, required: true },
  evidenceSignalLabel: { type: Function, required: true },
  conversationStateLabel: { type: Function, required: true },
  formatTime: { type: Function, required: true },
  qualityToneClass: { type: Function, required: true },
  t: { type: Function, required: true },
  mobile: { type: Boolean, default: false },
});

defineEmits(['edit']);

const businessLocation = computed(() =>
  [props.lead.business_name, props.lead.location].filter(Boolean).join(' / ')
);

const contactChannels = computed(
  () => props.lead.detail?.contact_channels || []
);

const primaryContactLabel = computed(
  () =>
    contactChannels.value.find(channel =>
      ['phone', 'email'].includes(channel.kind)
    )?.label ||
    props.lead.phone_number ||
    props.lead.email ||
    props.t('AI_LEAD_EMPLOYEE.LEADS.EMPTY_VALUE')
);

const whyItems = computed(() => props.lead.detail?.why_this_lead_matters || []);

const strongestEvidence = computed(
  () => props.lead.detail?.strongest_evidence || []
);

const missingSignals = computed(() => props.lead.detail?.missing_signals || []);

const relatedConversations = computed(
  () => props.lead.detail?.related_conversations || []
);

const relatedBookings = computed(
  () => props.lead.detail?.related_bookings || []
);

const conversationStateItems = computed(() =>
  [
    {
      label: props.t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.CONVERSATION_STATUS'),
      value: props.lead.conversation?.status,
    },
    {
      label: props.t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.CONTROL_STATE'),
      value: props.lead.conversation?.control_state,
    },
  ].filter(item => item.value)
);

const channelIcon = kind => {
  if (kind === 'phone') return 'i-lucide-phone';
  if (kind === 'email') return 'i-lucide-mail';
  return 'i-lucide-inbox';
};
</script>

<template>
  <div
    class="flex min-h-0 flex-col overflow-auto p-4"
    :class="mobile ? 'max-h-[560px]' : 'h-full'"
  >
    <header class="flex items-start gap-3 border-b border-n-weak pb-4">
      <span
        class="grid size-10 shrink-0 place-items-center rounded-full bg-n-slate-3 text-sm font-medium text-n-slate-12"
      >
        {{ lead.initials }}
      </span>
      <div class="min-w-0 flex-1">
        <h2 class="truncate text-base font-semibold text-n-slate-12">
          {{ lead.name }}
        </h2>
        <p class="mt-1 truncate text-sm text-n-slate-11">
          {{ primaryContactLabel }}
        </p>
        <p class="truncate text-xs text-n-slate-11">
          {{ businessLocation }}
        </p>
      </div>
      <div class="flex gap-1 text-n-blue-11">
        <Icon icon="i-lucide-message-circle" class="size-4" />
        <Icon icon="i-lucide-circle-dot" class="size-4" />
      </div>
    </header>

    <section v-if="contactChannels.length" class="border-b border-n-weak py-4">
      <h3 class="text-sm font-semibold text-n-slate-12">
        {{ t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.CONTACT_CHANNELS') }}
      </h3>
      <div class="mt-3 grid gap-2">
        <p
          v-for="channel in contactChannels"
          :key="`${channel.kind}-${channel.label}`"
          class="flex min-w-0 items-center gap-2 text-sm text-n-slate-11"
        >
          <Icon
            :icon="channelIcon(channel.kind)"
            class="size-4 shrink-0 text-n-blue-10"
          />
          <span class="shrink-0 text-xs font-medium uppercase text-n-slate-10">
            {{ channelKindLabel(channel.kind) }}
          </span>
          <span class="min-w-0 truncate text-n-slate-12">
            {{ channel.label }}
          </span>
        </p>
      </div>
    </section>

    <section class="border-b border-n-weak py-4">
      <h3 class="text-sm font-semibold text-n-slate-12">
        {{ t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.QUALIFICATION') }}
      </h3>
      <div class="mt-3 grid gap-3 text-sm">
        <div class="flex items-center justify-between gap-3">
          <span class="text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.LEADS.FIELD.QUALITY') }}
          </span>
          <span
            class="rounded-md px-2 py-1 text-xs font-medium"
            :class="qualityToneClass(lead.quality)"
          >
            {{ qualityLabel(lead.quality) }}
          </span>
        </div>
        <div class="flex items-center justify-between gap-3">
          <span class="text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.LEADS.FIELD.SCORE') }}
          </span>
          <span class="text-n-slate-12">
            {{
              t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.SCORE_OUT_OF_100', {
                score: lead.score,
              })
            }}
          </span>
        </div>
      </div>
    </section>

    <section class="border-b border-n-weak py-4">
      <h3 class="text-sm font-semibold text-n-slate-12">
        {{ t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.WHY') }}
      </h3>
      <p
        v-for="item in whyItems"
        :key="item"
        class="mt-2 text-sm leading-5 text-n-slate-11"
      >
        {{ item }}
      </p>
    </section>

    <section class="border-b border-n-weak py-4">
      <h3 class="text-sm font-semibold text-n-slate-12">
        {{ t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.EVIDENCE') }}
      </h3>
      <div class="mt-3 grid gap-2">
        <p
          v-for="item in strongestEvidence"
          :key="item.id"
          class="flex gap-2 text-sm text-n-slate-11"
        >
          <Icon
            icon="i-lucide-check-circle-2"
            class="mt-0.5 size-4 shrink-0 text-n-teal-10"
          />
          <span>
            {{
              t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.EVIDENCE_ITEM', {
                signal: evidenceSignalLabel(item.signal),
                value: item.value,
              })
            }}
          </span>
        </p>
        <p v-if="!strongestEvidence.length" class="text-sm text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.LEADS.EMPTY_VALUE') }}
        </p>
      </div>
    </section>

    <section class="border-b border-n-weak py-4">
      <h3 class="text-sm font-semibold text-n-slate-12">
        {{ t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.MISSING') }}
      </h3>
      <div class="mt-3 grid gap-2">
        <p
          v-for="signal in missingSignals"
          :key="signal"
          class="flex gap-2 text-sm text-n-slate-11"
        >
          <Icon
            icon="i-lucide-circle-alert"
            class="mt-0.5 size-4 shrink-0 text-n-amber-10"
          />
          <span>{{ evidenceSignalLabel(signal) }}</span>
        </p>
        <p v-if="!missingSignals.length" class="text-sm text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.NO_MISSING') }}
        </p>
      </div>
    </section>

    <section class="border-b border-n-weak py-4">
      <h3 class="text-sm font-semibold text-n-slate-12">
        {{ t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.CONVERSATION') }}
      </h3>
      <p class="mt-2 text-xs text-n-slate-11">
        {{
          t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.LAST_MESSAGE_WITH_TIME', {
            time: formatTime(
              lead.detail?.conversation_summary?.last_message_at
            ),
          })
        }}
      </p>
      <p
        class="mt-3 rounded-md bg-n-blue-2 p-3 text-sm leading-5 text-n-slate-12"
      >
        {{
          lead.detail?.conversation_summary?.last_message_preview ||
          t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.NO_MESSAGE')
        }}
      </p>
      <p class="mt-2 text-xs text-n-slate-11">
        {{
          t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.TOTAL_MESSAGES_COUNT', {
            count: lead.detail?.conversation_summary?.total_messages || 0,
          })
        }}
      </p>
      <dl v-if="conversationStateItems.length" class="mt-3 grid gap-2 text-xs">
        <div
          v-for="item in conversationStateItems"
          :key="item.label"
          class="flex justify-between gap-3"
        >
          <dt class="text-n-slate-11">
            {{ item.label }}
          </dt>
          <dd class="truncate font-medium text-n-slate-12">
            {{ conversationStateLabel(item.value) }}
          </dd>
        </div>
      </dl>
    </section>

    <section class="border-b border-n-weak py-4">
      <h3 class="text-sm font-semibold text-n-slate-12">
        {{ t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.OWNER') }}
      </h3>
      <dl class="mt-3 grid gap-2 text-sm">
        <div class="flex justify-between gap-3">
          <dt class="text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.LEADS.FIELD.ASSIGNEE') }}
          </dt>
          <dd class="truncate text-n-slate-12">
            {{ lead.assignee?.name || t('AI_LEAD_EMPLOYEE.LEADS.UNASSIGNED') }}
          </dd>
        </div>
        <div class="flex justify-between gap-3">
          <dt class="text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.LEADS.FILTER.FOLLOW_UP') }}
          </dt>
          <dd class="truncate text-n-blue-11">
            {{ followUpLabel(lead.detail?.qualification?.follow_up_state) }}
          </dd>
        </div>
        <div class="flex justify-between gap-3">
          <dt class="text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.LEADS.FIELD.NEXT_ACTION') }}
          </dt>
          <dd class="truncate text-n-slate-12">
            {{ nextActionLabel(lead.next_action) }}
          </dd>
        </div>
        <div class="flex justify-between gap-3">
          <dt class="text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.DUE') }}
          </dt>
          <dd class="truncate text-n-slate-12">
            {{ formatTime(lead.next_action?.due_at) }}
          </dd>
        </div>
      </dl>
    </section>

    <section class="border-b border-n-weak py-4">
      <h3 class="text-sm font-semibold text-n-slate-12">
        {{ t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.RELATED') }}
      </h3>
      <div class="mt-3 grid gap-2">
        <a
          v-for="conversation in relatedConversations"
          :key="conversation.id"
          :href="conversation.path"
          class="flex items-center justify-between rounded-md border border-n-weak px-3 py-2 text-sm text-n-slate-12 hover:bg-n-alpha-2"
        >
          <span>
            {{
              t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.CONVERSATION_NUMBER', {
                id: conversation.display_id,
              })
            }}
          </span>
          <span class="truncate text-xs text-n-slate-11">
            {{ formatTime(conversation.last_contact_at) }}
          </span>
        </a>
        <p v-if="!relatedConversations.length" class="text-sm text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.NO_RELATED') }}
        </p>
      </div>
      <div class="mt-4 grid gap-2">
        <h4 class="text-xs font-medium uppercase text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.BOOKINGS') }}
        </h4>
        <a
          v-for="booking in relatedBookings"
          :key="booking.id"
          :href="booking.path"
          class="flex items-center justify-between rounded-md border border-n-weak px-3 py-2 text-sm text-n-slate-12 hover:bg-n-alpha-2"
        >
          <span>
            {{
              t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.BOOKING_NUMBER', {
                id: booking.id,
              })
            }}
          </span>
          <span class="truncate text-xs text-n-slate-11">
            {{
              t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.BOOKING_SUMMARY', {
                status: bookingStatusLabel(booking.status),
                time: formatTime(booking.starts_at),
              })
            }}
          </span>
        </a>
        <p v-if="!relatedBookings.length" class="text-sm text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.NO_RELATED_BOOKINGS') }}
        </p>
      </div>
    </section>

    <section class="pt-4">
      <h3 class="text-sm font-semibold text-n-slate-12">
        {{ t('AI_LEAD_EMPLOYEE.LEADS.DETAIL.ACTIONS') }}
      </h3>
      <div class="mt-3 grid gap-2">
        <a
          v-if="lead.conversation?.path"
          :href="lead.conversation.path"
          class="inline-flex h-10 items-center justify-center gap-2 rounded-lg bg-n-brand px-3 text-sm font-medium text-white"
        >
          <Icon icon="i-lucide-message-circle" class="size-4" />
          {{ t('AI_LEAD_EMPLOYEE.LEADS.OPEN_CONVERSATION') }}
        </a>
        <button
          type="button"
          class="inline-flex h-10 items-center justify-center gap-2 rounded-lg border border-n-weak px-3 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2"
          @click="$emit('edit')"
        >
          <Icon icon="i-lucide-pencil" class="size-4" />
          {{ t('AI_LEAD_EMPLOYEE.LEADS.EDIT_LEAD') }}
        </button>
      </div>
    </section>
  </div>
</template>

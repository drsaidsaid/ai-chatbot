<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import OffersAPI from 'dashboard/api/qualificationOffers';
import LeadQualificationsAPI from 'dashboard/api/leadQualifications';
import OfferQualificationSummary from './OfferQualificationSummary.vue';

const props = defineProps({ currentChat: { type: Object, required: true } });
const { t } = useI18n();
const store = useStore();
const label = key => t(`AI_LEAD_EMPLOYEE.OFFERS.${key}`);
const qualification = computed(
  () => props.currentChat.lead_qualification || {}
);
const contactId = computed(
  () => props.currentChat.meta?.sender?.id || qualification.value.contact_id
);
const selectedId = ref('');
const fieldKey = ref('');
const correction = ref('');
const saving = ref(false);
const error = ref('');
const inputClass =
  'min-h-9 w-full rounded-lg border border-n-weak bg-n-solid-1 px-2 text-sm text-n-slate-12';
watch(
  () => [props.currentChat.id, qualification.value.offer_id],
  () => {
    selectedId.value = qualification.value.offer_id?.toString() || '';
    fieldKey.value = qualification.value.fields?.[0]?.key || '';
    correction.value = '';
    error.value = '';
  },
  { immediate: true }
);

const perform = async action => {
  if (saving.value) return;
  saving.value = true;
  error.value = '';
  const conversationId = props.currentChat.id;
  try {
    await action();
    await store.dispatch('getConversation', conversationId);
  } catch (exception) {
    error.value = exception.response?.data?.error || label('CHANGE_ERROR');
  } finally {
    saving.value = false;
  }
};
const selectOffer = () =>
  perform(() =>
    OffersAPI.selectConversation(
      props.currentChat.id,
      selectedId.value ? Number(selectedId.value) : null
    )
  );
const saveCorrection = () => {
  if (
    !contactId.value ||
    !qualification.value.offer_id ||
    !fieldKey.value ||
    !correction.value.trim()
  )
    return;
  perform(async () => {
    await LeadQualificationsAPI.evidence(contactId.value, {
      offer_id: qualification.value.offer_id,
      conversation_id: props.currentChat.id,
      field_key: fieldKey.value,
      value: correction.value.trim(),
    });
    correction.value = '';
  });
};
</script>

<template>
  <section class="grid gap-3 border-t border-n-weak pt-3">
    <fieldset :disabled="saving" class="grid gap-2">
      <label class="grid gap-1 text-sm">
        {{ label('CONVERSATION_OFFER') }}
        <select
          v-model="selectedId"
          :class="inputClass"
          data-testid="conversation-offer-select"
        >
          <option value="">
            {{ label('CHOOSE') }}
          </option>
          <option
            v-for="offer in qualification.offers"
            :key="offer.id"
            :value="String(offer.id)"
            :disabled="!offer.enabled"
          >
            {{ offer.name }}{{ offer.enabled ? '' : ` (${label('DISABLED')})` }}
          </option>
        </select>
      </label>
      <button
        type="button"
        :disabled="selectedId === (qualification.offer_id?.toString() || '')"
        class="min-h-9 rounded-lg border border-n-weak px-3 text-sm disabled:opacity-40"
        data-testid="select-conversation-offer"
        @click="selectOffer"
      >
        {{ label('USE_OFFER') }}
      </button>
    </fieldset>
    <p v-if="error" role="alert" class="text-sm text-n-ruby-11">
      {{ error }}
    </p>
    <OfferQualificationSummary
      :qualification="qualification"
      :show-outcome="false"
    />
    <form
      v-if="qualification.offer_id && qualification.fields?.length"
      class="grid gap-2"
      @submit.prevent="saveCorrection"
    >
      <fieldset :disabled="saving" class="grid gap-2">
        <legend class="mb-2 text-sm font-medium">
          {{ label('CORRECTION') }}
        </legend>
        <label class="grid gap-1 text-sm">
          {{ label('FIELD') }}
          <select v-model="fieldKey" :class="inputClass">
            <option
              v-for="field in qualification.fields"
              :key="field.key"
              :value="field.key"
            >
              {{ field.meaning }}
            </option>
          </select>
        </label>
        <label class="grid gap-1 text-sm">
          {{ label('CORRECTION_VALUE') }}
          <input
            v-model="correction"
            required
            :class="inputClass"
            data-testid="offer-correction-value"
          />
        </label>
        <p class="text-xs text-n-slate-11">
          {{ label('CORRECTION_HELP') }}
        </p>
        <button
          type="submit"
          :disabled="!correction.trim() || !contactId"
          class="min-h-9 rounded-lg bg-n-brand px-3 text-sm text-white disabled:opacity-40"
        >
          {{ label('SAVE_CORRECTION') }}
        </button>
      </fieldset>
    </form>
  </section>
</template>

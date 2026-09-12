<script setup>
import { onBeforeUnmount, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import LeadQualificationsAPI from 'dashboard/api/leadQualifications';
import OfferQualificationSummary from './OfferQualificationSummary.vue';

const props = defineProps({
  contactId: { type: Number, required: true },
  offerId: { type: Number, default: null },
});
const { t } = useI18n();
const qualification = ref(null);
const error = ref('');
const loading = ref(false);
let requestVersion = 0;
const load = async () => {
  requestVersion += 1;
  const version = requestVersion;
  qualification.value = null;
  error.value = '';
  loading.value = true;
  try {
    const { data } = await LeadQualificationsAPI.forOffer(
      props.contactId,
      props.offerId
    );
    if (version === requestVersion) qualification.value = data;
  } catch (exception) {
    if (version === requestVersion)
      error.value =
        exception.response?.data?.error ||
        t('AI_LEAD_EMPLOYEE.OFFERS.EVIDENCE_ERROR');
  } finally {
    if (version === requestVersion) loading.value = false;
  }
};
watch(() => [props.contactId, props.offerId], load, { immediate: true });
onBeforeUnmount(() => {
  requestVersion += 1;
});
</script>

<template>
  <div class="grid gap-2">
    <p v-if="loading" role="status" class="text-sm text-n-slate-11">
      {{ t('AI_LEAD_EMPLOYEE.OFFERS.LOADING_EVIDENCE') }}
    </p>
    <template v-if="error">
      <p role="alert" class="text-sm text-n-ruby-11">{{ error }}</p>
      <button
        type="button"
        class="min-h-9 rounded-lg border border-n-weak px-3 text-sm"
        @click="load"
      >
        {{ t('AI_LEAD_EMPLOYEE.OFFERS.RETRY') }}
      </button>
    </template>
    <OfferQualificationSummary
      v-if="qualification"
      :qualification="qualification"
    />
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import HumanReviewRequestsPanel from './HumanReviewRequestsPanel.vue';
import KnowledgeItemsPanel from './KnowledgeItemsPanel.vue';
import BookingsPanel from './BookingsPanel.vue';

const props = defineProps({
  surface: {
    type: String,
    required: true,
  },
});

const { t } = useI18n();

const title = computed(() => {
  if (props.surface === 'HOT_LEADS') {
    return t('AI_LEAD_EMPLOYEE.SURFACES.HOT_LEADS.TITLE');
  }
  if (props.surface === 'LEADS') {
    return t('AI_LEAD_EMPLOYEE.SURFACES.LEADS.TITLE');
  }
  if (props.surface === 'REVIEWS') {
    return t('AI_LEAD_EMPLOYEE.SURFACES.REVIEWS.TITLE');
  }
  if (props.surface === 'KNOWLEDGE') {
    return t('AI_LEAD_EMPLOYEE.SURFACES.KNOWLEDGE.TITLE');
  }
  return t('AI_LEAD_EMPLOYEE.SURFACES.BOOKINGS.TITLE');
});

const description = computed(() => {
  if (props.surface === 'HOT_LEADS') {
    return t('AI_LEAD_EMPLOYEE.SURFACES.HOT_LEADS.DESCRIPTION');
  }
  if (props.surface === 'LEADS') {
    return t('AI_LEAD_EMPLOYEE.SURFACES.LEADS.DESCRIPTION');
  }
  if (props.surface === 'REVIEWS') {
    return t('AI_LEAD_EMPLOYEE.SURFACES.REVIEWS.DESCRIPTION');
  }
  if (props.surface === 'KNOWLEDGE') {
    return t('AI_LEAD_EMPLOYEE.SURFACES.KNOWLEDGE.DESCRIPTION');
  }
  return t('AI_LEAD_EMPLOYEE.SURFACES.BOOKINGS.DESCRIPTION');
});
</script>

<template>
  <main class="flex-1 min-w-0 bg-n-background p-6">
    <section class="max-w-5xl mx-auto">
      <p class="text-xs font-medium uppercase text-n-slate-11 tracking-normal">
        {{ t('AI_LEAD_EMPLOYEE.PRODUCT_NAME') }}
      </p>
      <h1 class="mt-2 text-2xl font-semibold text-n-slate-12">
        {{ title }}
      </h1>
      <p class="mt-2 max-w-2xl text-sm text-n-slate-11">
        {{ description }}
      </p>
      <div class="mt-6 rounded-lg border border-n-weak bg-n-solid-1 p-5">
        <p class="text-sm text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.BASELINE_NOTICE') }}
        </p>
      </div>
      <HumanReviewRequestsPanel v-if="surface === 'REVIEWS'" />
      <KnowledgeItemsPanel v-if="surface === 'KNOWLEDGE'" />
      <BookingsPanel v-if="surface === 'BOOKINGS'" />
    </section>
  </main>
</template>

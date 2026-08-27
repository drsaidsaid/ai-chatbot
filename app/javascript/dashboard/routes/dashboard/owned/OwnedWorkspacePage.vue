<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import HumanReviewRequestsPanel from './HumanReviewRequestsPanel.vue';
import KnowledgeItemsPanel from './KnowledgeItemsPanel.vue';
import BookingsPanel from './BookingsPanel.vue';
import OperationalDashboardPanel from './OperationalDashboardPanel.vue';
import EvaluationSandboxPanel from './EvaluationSandboxPanel.vue';

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
  if (props.surface === 'TEST_CENTER') {
    return t('AI_LEAD_EMPLOYEE.SURFACES.TEST_CENTER.TITLE');
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
  if (props.surface === 'TEST_CENTER') {
    return t('AI_LEAD_EMPLOYEE.SURFACES.TEST_CENTER.DESCRIPTION');
  }
  return t('AI_LEAD_EMPLOYEE.SURFACES.BOOKINGS.DESCRIPTION');
});
const containerClass = computed(() => {
  if (props.surface === 'BOOKINGS') return 'max-w-none';
  if (props.surface === 'KNOWLEDGE') return 'max-w-none';
  if (props.surface === 'TEST_CENTER') return 'max-w-7xl';

  return 'max-w-5xl';
});
</script>

<template>
  <main class="min-w-0 flex-1 bg-n-background p-4 sm:p-6">
    <section class="mx-auto" :class="containerClass">
      <template v-if="!['BOOKINGS', 'KNOWLEDGE'].includes(surface)">
        <p
          class="text-xs font-medium uppercase text-n-slate-11 tracking-normal"
        >
          {{ t('AI_LEAD_EMPLOYEE.PRODUCT_NAME') }}
        </p>
        <h1 class="mt-2 text-2xl font-semibold text-n-slate-12">
          {{ title }}
        </h1>
        <p class="mt-2 max-w-2xl text-sm text-n-slate-11">
          {{ description }}
        </p>
      </template>
      <HumanReviewRequestsPanel v-if="surface === 'REVIEWS'" />
      <KnowledgeItemsPanel v-if="surface === 'KNOWLEDGE'" />
      <BookingsPanel v-if="surface === 'BOOKINGS'" />
      <EvaluationSandboxPanel v-if="surface === 'TEST_CENTER'" />
      <OperationalDashboardPanel
        v-if="['HOT_LEADS', 'LEADS', 'REVIEWS'].includes(surface)"
        :surface="surface"
      />
    </section>
  </main>
</template>

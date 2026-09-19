<script setup>
import { onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import HumanReviewRequestsAPI from 'dashboard/api/humanReviewRequests';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const failed = ref(false);

onMounted(async () => {
  try {
    const { data } = await HumanReviewRequestsAPI.show(route.params.reviewId);
    await router.replace({
      name: 'inbox_conversation',
      params: {
        accountId: route.params.accountId,
        conversation_id: data.conversation_display_id,
      },
      query: { queue: 'review', review_id: data.id },
    });
  } catch {
    failed.value = true;
  }
});
</script>

<template>
  <div>
    <p v-if="failed" class="p-4 text-sm text-n-slate-11">
      {{ t('AI_LEAD_EMPLOYEE.REVIEWS.LEGACY_LINK_ERROR') }}
    </p>
  </div>
</template>

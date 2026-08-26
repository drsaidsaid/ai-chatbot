<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import HumanReviewRequestsAPI from 'dashboard/api/humanReviewRequests';

const { t } = useI18n();
const route = useRoute();

const reviewRequests = ref([]);
const isLoading = ref(false);
const resolvingId = ref(null);
const resolutionForms = ref({});
const sourceOptions = ['faq', 'offer', 'pricing', 'supporting_document'];

const sourceLabels = computed(() => ({
  faq: t('AI_LEAD_EMPLOYEE.KNOWLEDGE.SOURCE.FAQ'),
  offer: t('AI_LEAD_EMPLOYEE.KNOWLEDGE.SOURCE.OFFER'),
  pricing: t('AI_LEAD_EMPLOYEE.KNOWLEDGE.SOURCE.PRICING'),
  supporting_document: t(
    'AI_LEAD_EMPLOYEE.KNOWLEDGE.SOURCE.SUPPORTING_DOCUMENT'
  ),
}));
const reasonLabels = computed(() => ({
  no_approved_knowledge: t(
    'AI_LEAD_EMPLOYEE.REVIEWS.REASON.NO_APPROVED_KNOWLEDGE'
  ),
  conflicting_knowledge: t(
    'AI_LEAD_EMPLOYEE.REVIEWS.REASON.CONFLICTING_KNOWLEDGE'
  ),
  sensitive_question: t('AI_LEAD_EMPLOYEE.REVIEWS.REASON.SENSITIVE_QUESTION'),
  qualification_blocker: t(
    'AI_LEAD_EMPLOYEE.REVIEWS.REASON.QUALIFICATION_BLOCKER'
  ),
  angry_question: t('AI_LEAD_EMPLOYEE.REVIEWS.REASON.ANGRY_QUESTION'),
}));

const loadReviewRequests = async () => {
  isLoading.value = true;
  try {
    const { data } = await HumanReviewRequestsAPI.get();
    reviewRequests.value = data;
    data.forEach(request => {
      resolutionForms.value[request.id] ||= {
        human_answer_message_id: '',
        propose_knowledge: true,
        source_kind: 'faq',
        title: '',
      };
    });
  } finally {
    isLoading.value = false;
  }
};

const resolveReviewRequest = async request => {
  resolvingId.value = request.id;
  try {
    await HumanReviewRequestsAPI.resolve(
      request.id,
      resolutionForms.value[request.id]
    );
    useAlert(t('AI_LEAD_EMPLOYEE.REVIEWS.RESOLVED'));
    await loadReviewRequests();
  } catch {
    useAlert(t('AI_LEAD_EMPLOYEE.REVIEWS.RESOLVE_ERROR'));
  } finally {
    resolvingId.value = null;
  }
};

const conversationPath = request =>
  `/app/accounts/${route.params.accountId}/conversations/${request.conversation_display_id}`;

onMounted(loadReviewRequests);
</script>

<template>
  <section class="mt-6 border border-n-weak bg-n-solid-1">
    <div
      class="grid grid-cols-[1.1fr_0.8fr_0.9fr_1.4fr] gap-3 border-b border-n-weak px-4 py-3 text-xs font-medium uppercase text-n-slate-11"
    >
      <span>{{ t('AI_LEAD_EMPLOYEE.REVIEWS.FIELD.QUESTION') }}</span>
      <span>{{ t('AI_LEAD_EMPLOYEE.REVIEWS.FIELD.REASON') }}</span>
      <span>{{ t('AI_LEAD_EMPLOYEE.REVIEWS.FIELD.CONVERSATION') }}</span>
      <span>{{ t('AI_LEAD_EMPLOYEE.REVIEWS.FIELD.RESOLUTION') }}</span>
    </div>
    <div v-if="isLoading" class="px-4 py-6 text-sm text-n-slate-11">
      {{ t('AI_LEAD_EMPLOYEE.REVIEWS.LOADING') }}
    </div>
    <div
      v-else-if="!reviewRequests.length"
      class="px-4 py-6 text-sm text-n-slate-11"
    >
      {{ t('AI_LEAD_EMPLOYEE.REVIEWS.EMPTY') }}
    </div>
    <div v-else>
      <div
        v-for="request in reviewRequests"
        :key="request.id"
        class="grid grid-cols-[1.1fr_0.8fr_0.9fr_1.4fr] gap-3 border-b border-n-weak px-4 py-4 text-sm text-n-slate-12"
      >
        <p class="min-w-0 break-words">
          {{ request.question }}
        </p>
        <span>{{ reasonLabels[request.reason] }}</span>
        <a class="text-n-blue-text underline" :href="conversationPath(request)">
          {{
            t('AI_LEAD_EMPLOYEE.REVIEWS.FIELD.CONVERSATION_NUMBER', {
              id: request.conversation_display_id,
            })
          }}
        </a>
        <form
          class="grid gap-2"
          @submit.prevent="resolveReviewRequest(request)"
        >
          <input
            v-model="resolutionForms[request.id].human_answer_message_id"
            required
            inputmode="numeric"
            class="rounded-md border border-n-weak bg-n-background px-3 py-2"
            :placeholder="t('AI_LEAD_EMPLOYEE.REVIEWS.FIELD.ANSWER_MESSAGE_ID')"
          />
          <label class="flex items-center gap-2 text-sm text-n-slate-12">
            <input
              v-model="resolutionForms[request.id].propose_knowledge"
              type="checkbox"
              class="rounded border-n-weak"
            />
            {{ t('AI_LEAD_EMPLOYEE.REVIEWS.PROPOSE_KNOWLEDGE') }}
          </label>
          <div class="grid gap-2 sm:grid-cols-2">
            <input
              v-model="resolutionForms[request.id].title"
              class="rounded-md border border-n-weak bg-n-background px-3 py-2"
              :placeholder="t('AI_LEAD_EMPLOYEE.KNOWLEDGE.FIELD.TITLE')"
            />
            <select
              v-model="resolutionForms[request.id].source_kind"
              class="rounded-md border border-n-weak bg-n-background px-3 py-2"
            >
              <option
                v-for="source in sourceOptions"
                :key="source"
                :value="source"
              >
                {{ sourceLabels[source] }}
              </option>
            </select>
          </div>
          <button
            type="submit"
            class="inline-flex h-8 items-center justify-center rounded-lg bg-n-brand px-3 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="resolvingId === request.id"
          >
            {{ t('AI_LEAD_EMPLOYEE.REVIEWS.RESOLVE') }}
          </button>
        </form>
      </div>
    </div>
  </section>
</template>

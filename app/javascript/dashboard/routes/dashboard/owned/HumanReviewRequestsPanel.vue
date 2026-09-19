<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import HumanReviewRequestsAPI from 'dashboard/api/humanReviewRequests';

const props = defineProps({
  conversationId: { type: [String, Number], default: null },
  reviewId: { type: [String, Number], default: null },
});

const route = useRoute();
const { t } = useI18n();
const reviewRequests = ref([]);
const isLoading = ref(false);
const resolvingId = ref(null);
const resolutionForms = ref({});
const resolutionResults = ref({});
const sourceOptions = [
  'faq',
  'offer',
  'pricing',
  'objection',
  'policy',
  'refund',
];

const replyOutcomeMessage = outcome => {
  const messages = {
    reply_pending_delivery: t('AI_LEAD_EMPLOYEE.REVIEWS.REPLY_PENDING'),
    reply_delivery_accepted: t('AI_LEAD_EMPLOYEE.REVIEWS.REPLY_ACCEPTED'),
    reply_delivery_unknown: t('AI_LEAD_EMPLOYEE.REVIEWS.REPLY_UNKNOWN'),
    reply_delivery_failed: t('AI_LEAD_EMPLOYEE.REVIEWS.REPLY_FAILED'),
    reply_delivery_canceled: t('AI_LEAD_EMPLOYEE.REVIEWS.REPLY_CANCELED'),
  }[outcome];
  return messages || t('AI_LEAD_EMPLOYEE.REVIEWS.REPLY_PENDING');
};

const reasonLabel = reason => {
  const labels = {
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
  };
  return labels[reason] || reason.replaceAll('_', ' ');
};

const visibleRequests = computed(() =>
  reviewRequests.value.filter(request => {
    if (props.reviewId) return Number(request.id) === Number(props.reviewId);
    return (
      !props.conversationId ||
      Number(request.conversation_id) === Number(props.conversationId)
    );
  })
);

const loadReviewRequests = async () => {
  isLoading.value = true;
  try {
    const response = props.reviewId
      ? await HumanReviewRequestsAPI.show(props.reviewId)
      : await HumanReviewRequestsAPI.get();
    const data = props.reviewId ? [response.data] : response.data;
    reviewRequests.value = data;
    data.forEach(request => {
      resolutionForms.value[request.id] ||= {
        answer: '',
        proposal_answer: '',
        source_kind: request.reason === 'sensitive_question' ? 'policy' : 'faq',
        title: request.question?.slice(0, 80) || '',
      };
    });
  } finally {
    isLoading.value = false;
  }
};

const resolveReviewRequest = async (request, resolutionKind) => {
  resolvingId.value = request.id;
  try {
    const { data } = await HumanReviewRequestsAPI.resolve(request.id, {
      answer: resolutionForms.value[request.id].answer,
      resolution_kind: resolutionKind,
    });
    resolutionResults.value[request.id] = data;
    useAlert(
      resolutionKind === 'send_reply'
        ? replyOutcomeMessage(data.reply_outcome)
        : t('AI_LEAD_EMPLOYEE.REVIEWS.PRIVATE_SAVED')
    );
  } catch {
    useAlert(t('AI_LEAD_EMPLOYEE.REVIEWS.RESOLVE_ERROR'));
  } finally {
    resolvingId.value = null;
  }
};

const proposeKnowledge = async request => {
  resolvingId.value = request.id;
  try {
    const { data } = await HumanReviewRequestsAPI.proposeKnowledge(request.id, {
      source_kind: resolutionForms.value[request.id].source_kind,
      title: resolutionForms.value[request.id].title,
      answer: resolutionForms.value[request.id].proposal_answer,
    });
    resolutionResults.value[request.id] = data;
    useAlert(t('AI_LEAD_EMPLOYEE.REVIEWS.PROPOSAL_SAVED'));
  } catch {
    useAlert(t('AI_LEAD_EMPLOYEE.REVIEWS.PROPOSAL_ERROR'));
  } finally {
    resolvingId.value = null;
  }
};

const conversationPath = request =>
  `/app/accounts/${route.params.accountId}/conversations/${request.conversation_display_id}?queue=review&review_id=${request.id}`;
const knowledgePath = request =>
  `/app/accounts/${route.params.accountId}/knowledge?knowledge_item_id=${request.knowledge_item_id}`;

onMounted(loadReviewRequests);
</script>

<template>
  <section class="mt-6 border border-n-weak bg-n-solid-1">
    <div v-if="isLoading" class="px-4 py-6 text-sm text-n-slate-11">
      {{ t('AI_LEAD_EMPLOYEE.REVIEWS.LOADING') }}
    </div>
    <div
      v-else-if="!visibleRequests.length"
      class="px-4 py-6 text-sm text-n-slate-11"
    >
      {{ t('AI_LEAD_EMPLOYEE.REVIEWS.EMPTY') }}
    </div>
    <article
      v-for="request in visibleRequests"
      :key="request.id"
      class="grid gap-3 border-b border-n-weak p-4 text-sm text-n-slate-12"
    >
      <div>
        <p class="font-medium">{{ request.question }}</p>
        <p class="mt-1 text-xs text-n-slate-11">
          {{
            t('AI_LEAD_EMPLOYEE.REVIEWS.REASON_ASSIGNED', {
              reason: reasonLabel(request.reason),
              name:
                request.assigned_user?.name ||
                t('AI_LEAD_EMPLOYEE.REVIEWS.UNASSIGNED'),
            })
          }}
        </p>
        <a
          class="mt-2 inline-flex text-n-blue-text underline"
          :href="conversationPath(request)"
        >
          {{
            t('AI_LEAD_EMPLOYEE.REVIEWS.OPEN_CONVERSATION', {
              id: request.conversation_display_id,
            })
          }}
        </a>
      </div>
      <textarea
        v-model="resolutionForms[request.id].answer"
        :disabled="Boolean(resolutionResults[request.id])"
        rows="4"
        class="rounded-md border border-n-weak bg-n-background px-3 py-2"
        :placeholder="t('AI_LEAD_EMPLOYEE.REVIEWS.ANSWER_PLACEHOLDER')"
      />
      <template v-if="!resolutionResults[request.id]">
        <p class="text-xs text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.REVIEWS.RESOLUTION_EFFECT') }}
        </p>
        <div class="flex flex-wrap gap-2">
          <button
            type="button"
            class="rounded-lg bg-n-brand px-3 py-2 text-sm font-medium text-white disabled:opacity-50"
            :disabled="
              resolvingId === request.id || !resolutionForms[request.id].answer
            "
            @click="resolveReviewRequest(request, 'send_reply')"
          >
            {{ t('AI_LEAD_EMPLOYEE.REVIEWS.SEND_AND_RESOLVE') }}
          </button>
          <button
            type="button"
            class="rounded-lg border border-n-weak px-3 py-2 text-sm font-medium disabled:opacity-50"
            :disabled="
              resolvingId === request.id || !resolutionForms[request.id].answer
            "
            @click="resolveReviewRequest(request, 'internal_note')"
          >
            {{ t('AI_LEAD_EMPLOYEE.REVIEWS.SAVE_NOTE_AND_RESOLVE') }}
          </button>
        </div>
      </template>
      <template
        v-else-if="
          resolutionResults[request.id].knowledge_proposal_outcome ===
          'not_requested'
        "
      >
        <p class="text-xs text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.REVIEWS.PROPOSAL_EFFECT') }}
        </p>
        <textarea
          v-model="resolutionForms[request.id].proposal_answer"
          rows="3"
          class="rounded-md border border-n-weak bg-n-background px-3 py-2"
          :placeholder="
            t('AI_LEAD_EMPLOYEE.REVIEWS.PROPOSAL_ANSWER_PLACEHOLDER')
          "
        />
        <div class="grid gap-2 sm:grid-cols-2">
          <input
            v-model="resolutionForms[request.id].title"
            class="rounded-md border border-n-weak bg-n-background px-3 py-2"
            :placeholder="
              t('AI_LEAD_EMPLOYEE.REVIEWS.PROPOSAL_TITLE_PLACEHOLDER')
            "
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
              {{ source }}
            </option>
          </select>
        </div>
        <button
          type="button"
          class="w-fit rounded-lg border border-n-weak px-3 py-2 text-sm font-medium disabled:opacity-50"
          :disabled="
            resolvingId === request.id ||
            !resolutionForms[request.id].proposal_answer
          "
          @click="proposeKnowledge(request)"
        >
          {{ t('AI_LEAD_EMPLOYEE.REVIEWS.PROPOSE_KNOWLEDGE') }}
        </button>
      </template>
      <a
        v-else
        class="w-fit text-n-blue-text underline"
        :href="knowledgePath(resolutionResults[request.id])"
      >
        {{ t('AI_LEAD_EMPLOYEE.REVIEWS.OPEN_PROPOSAL') }}
      </a>
    </article>
  </section>
</template>

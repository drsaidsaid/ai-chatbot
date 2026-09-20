<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import HumanReviewRequestsAPI from 'dashboard/api/humanReviewRequests';
import ReviewConfigurationSuggestionsAPI from 'dashboard/api/reviewConfigurationSuggestions';

const props = defineProps({
  conversationId: { type: [String, Number], default: null },
  reviewId: { type: [String, Number], default: null },
});

const route = useRoute();
const { t } = useI18n();
const currentRole = useMapGetter('getCurrentRole');
const reviewRequests = ref([]);
const isLoading = ref(false);
const resolvingId = ref(null);
const resolutionForms = ref({});
const resolutionResults = ref({});
const pendingSuggestions = ref([]);
const sourceOptions = computed(() => [
  { value: 'faq', label: t('AI_LEAD_EMPLOYEE.REVIEWS.SOURCE.FAQ') },
  { value: 'offer', label: t('AI_LEAD_EMPLOYEE.REVIEWS.SOURCE.OFFER') },
  { value: 'pricing', label: t('AI_LEAD_EMPLOYEE.REVIEWS.SOURCE.PRICING') },
  { value: 'objection', label: t('AI_LEAD_EMPLOYEE.REVIEWS.SOURCE.OBJECTION') },
  { value: 'policy', label: t('AI_LEAD_EMPLOYEE.REVIEWS.SOURCE.POLICY') },
  { value: 'refund', label: t('AI_LEAD_EMPLOYEE.REVIEWS.SOURCE.REFUND') },
]);
let loadRequest = 0;

const replyOutcomeMessage = outcome => {
  const messages = {
    reply_pending_delivery: t('AI_LEAD_EMPLOYEE.REVIEWS.REPLY_PENDING'),
    reply_delivery_accepted: t('AI_LEAD_EMPLOYEE.REVIEWS.REPLY_ACCEPTED'),
    reply_delivery_sent: t('AI_LEAD_EMPLOYEE.REVIEWS.REPLY_SENT'),
    reply_delivery_delivered: t('AI_LEAD_EMPLOYEE.REVIEWS.REPLY_DELIVERED'),
    reply_delivery_read: t('AI_LEAD_EMPLOYEE.REVIEWS.REPLY_READ'),
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
    unsupported_media: t('AI_LEAD_EMPLOYEE.REVIEWS.REASON.UNSUPPORTED_MEDIA'),
    source_unverified: t('AI_LEAD_EMPLOYEE.REVIEWS.REASON.SOURCE_UNVERIFIED'),
    provider_failed: t('AI_LEAD_EMPLOYEE.REVIEWS.REASON.PROVIDER_FAILED'),
    stale_knowledge: t('AI_LEAD_EMPLOYEE.REVIEWS.REASON.STALE_KNOWLEDGE'),
    delivery_unknown: t('AI_LEAD_EMPLOYEE.REVIEWS.REASON.DELIVERY_UNKNOWN'),
    human_requested: t('AI_LEAD_EMPLOYEE.REVIEWS.REASON.HUMAN_REQUESTED'),
  };
  return labels[reason] || reason.replaceAll('_', ' ');
};

const feedbackStatusLabel = status => {
  const labels = {
    pending: t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_STATE.PENDING'),
    reviewed: t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_STATE.REVIEWED'),
    dismissed: t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_STATE.DISMISSED'),
  };
  return labels[status] || status;
};

const qualificationLabel = quality => {
  const labels = {
    highly_qualified: t('AI_LEAD_EMPLOYEE.LEADS.QUALITY.HIGHLY_QUALIFIED'),
    qualified: t('AI_LEAD_EMPLOYEE.LEADS.QUALITY.QUALIFIED'),
    low_qualified: t('AI_LEAD_EMPLOYEE.LEADS.QUALITY.LOW_QUALIFIED'),
    unqualified: t('AI_LEAD_EMPLOYEE.LEADS.QUALITY.UNQUALIFIED'),
    unknown: t('AI_LEAD_EMPLOYEE.LEADS.QUALITY.UNKNOWN'),
  };
  return labels[quality] || labels.unknown;
};

const feedbackEvidenceLines = suggestion => {
  if (suggestion.source_type === 'human_review_request') {
    return [
      t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_SOURCE_QUESTION', {
        question: suggestion.evidence,
      }),
    ];
  }

  try {
    const evidence = JSON.parse(suggestion.evidence);
    const lines = [
      t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_QUALIFICATION_SUMMARY', {
        quality: qualificationLabel(evidence.quality),
        score: evidence.score ?? t('AI_LEAD_EMPLOYEE.REVIEWS.UNAVAILABLE'),
      }),
    ];
    const reasons = (Array.isArray(evidence.reasons) ? evidence.reasons : [])
      .slice(0, 2)
      .join('; ');
    if (reasons) {
      lines.push(
        t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_QUALIFICATION_REASONS', {
          reasons,
        })
      );
    }
    return lines;
  } catch {
    return [t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_SOURCE_UNAVAILABLE')];
  }
};

const visibleRequests = computed(() =>
  reviewRequests.value.filter(request => {
    if (props.reviewId) {
      return (
        Number(request.id) === Number(props.reviewId) &&
        (!props.conversationId ||
          Number(request.conversation_id) === Number(props.conversationId))
      );
    }
    return (
      !props.conversationId ||
      Number(request.conversation_id) === Number(props.conversationId)
    );
  })
);

const loadReviewRequests = async () => {
  loadRequest += 1;
  const requestNumber = loadRequest;
  isLoading.value = true;
  try {
    const response = props.reviewId
      ? await HumanReviewRequestsAPI.show(props.reviewId)
      : await HumanReviewRequestsAPI.get();
    const data = props.reviewId ? [response.data] : response.data;
    if (requestNumber !== loadRequest) return;
    reviewRequests.value = data;
    resolutionResults.value = Object.fromEntries(
      data
        .filter(request => ['resolved', 'rejected'].includes(request.status))
        .map(request => [request.id, request])
    );
    data.forEach(request => {
      resolutionForms.value[request.id] ||= {
        answer: request.operator_answer || '',
        proposal_answer:
          request.resolution_kind === 'send_reply'
            ? request.operator_answer || ''
            : '',
        feedback_category: 'poor_fit',
        feedback_suggestion: '',
        source_kind: request.reason === 'sensitive_question' ? 'policy' : 'faq',
        title: request.question?.slice(0, 80) || '',
      };
    });
  } finally {
    if (requestNumber === loadRequest) isLoading.value = false;
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

const assignReviewRequest = async (request, assignedUserId) => {
  resolvingId.value = request.id;
  try {
    const { data } = await HumanReviewRequestsAPI.assign(request.id, {
      assigned_user_id: Number(assignedUserId),
    });
    reviewRequests.value = reviewRequests.value.map(candidate =>
      candidate.id === request.id ? data : candidate
    );
    useAlert('Review assignment saved.');
  } catch {
    useAlert('Unable to assign this review.');
  } finally {
    resolvingId.value = null;
  }
};

const proposeConfigurationSuggestion = async request => {
  resolvingId.value = request.id;
  try {
    const { data } =
      await HumanReviewRequestsAPI.proposeConfigurationSuggestion(request.id, {
        category: resolutionForms.value[request.id].feedback_category,
        suggestion: resolutionForms.value[request.id].feedback_suggestion,
      });
    resolutionResults.value[request.id] = data;
    useAlert(t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_SAVED'));
  } catch {
    useAlert(t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_ERROR'));
  } finally {
    resolvingId.value = null;
  }
};

const reviewConfigurationSuggestion = async (request, outcome) => {
  resolvingId.value = request.id;
  try {
    const { data } = await HumanReviewRequestsAPI.reviewConfigurationSuggestion(
      request.id,
      { outcome }
    );
    resolutionResults.value[request.id] = data;
    useAlert(t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_REVIEWED'));
  } catch {
    useAlert(t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_ERROR'));
  } finally {
    resolvingId.value = null;
  }
};

const loadPendingSuggestions = async () => {
  if (
    currentRole.value !== 'administrator' ||
    props.reviewId ||
    props.conversationId
  ) {
    pendingSuggestions.value = [];
    return;
  }
  const { data } = await ReviewConfigurationSuggestionsAPI.get();
  pendingSuggestions.value = data;
};

const reviewPendingSuggestion = async (suggestion, outcome) => {
  resolvingId.value = `suggestion-${suggestion.id}`;
  try {
    await ReviewConfigurationSuggestionsAPI.review(suggestion.id, { outcome });
    pendingSuggestions.value = pendingSuggestions.value.filter(
      record => record.id !== suggestion.id
    );
    useAlert(t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_REVIEWED'));
  } catch {
    useAlert(t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_ERROR'));
  } finally {
    resolvingId.value = null;
  }
};

const suggestionConversationPath = suggestion =>
  `/app/accounts/${route.params.accountId}/conversations/${suggestion.conversation_display_id}`;

const conversationPath = request =>
  `/app/accounts/${route.params.accountId}/conversations/${request.conversation_display_id}?queue=review&review_id=${request.id}`;
const knowledgePath = request =>
  `/app/accounts/${route.params.accountId}/knowledge?knowledge_item_id=${request.knowledge_item_id}`;

onMounted(() => Promise.all([loadReviewRequests(), loadPendingSuggestions()]));
watch(() => [props.reviewId, props.conversationId], loadReviewRequests);
</script>

<template>
  <section class="mt-6 border border-n-weak bg-n-solid-1">
    <section
      v-if="pendingSuggestions.length"
      data-testid="pending-configuration-feedback"
      class="grid gap-3 border-b border-n-weak p-4"
    >
      <h2 class="font-medium text-n-slate-12">
        {{ t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_QUEUE_TITLE') }}
      </h2>
      <article
        v-for="suggestion in pendingSuggestions"
        :key="suggestion.id"
        class="grid gap-2 rounded-md border border-n-weak p-3 text-sm text-n-slate-12"
      >
        <p class="font-medium">{{ suggestion.suggestion }}</p>
        <p
          v-for="line in feedbackEvidenceLines(suggestion)"
          :key="line"
          class="text-xs text-n-slate-11"
        >
          {{ line }}
        </p>
        <a
          class="w-fit text-n-blue-text underline"
          :href="suggestionConversationPath(suggestion)"
        >
          {{
            t('AI_LEAD_EMPLOYEE.REVIEWS.OPEN_CONVERSATION', {
              id: suggestion.conversation_display_id,
            })
          }}
        </a>
        <div class="flex flex-wrap gap-2">
          <button
            type="button"
            class="rounded-lg border border-n-weak px-3 py-2 font-medium"
            :disabled="resolvingId === `suggestion-${suggestion.id}`"
            @click="reviewPendingSuggestion(suggestion, 'reviewed')"
          >
            {{ t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_MARK_REVIEWED') }}
          </button>
          <button
            type="button"
            class="rounded-lg border border-n-weak px-3 py-2 font-medium"
            :disabled="resolvingId === `suggestion-${suggestion.id}`"
            @click="reviewPendingSuggestion(suggestion, 'dismissed')"
          >
            {{ t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_DISMISS') }}
          </button>
        </div>
      </article>
    </section>
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
      <label
        v-if="currentRole === 'administrator'"
        class="grid max-w-sm gap-1 text-xs text-n-slate-11"
      >
        <span>{{ t('AI_LEAD_EMPLOYEE.REVIEWS.ASSIGN_OPERATOR') }}</span>
        <select
          :value="request.assigned_user?.id || ''"
          class="rounded-md border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12"
          :disabled="resolvingId === request.id"
          @change="assignReviewRequest(request, $event.target.value)"
        >
          <option value="" disabled>
            {{ t('AI_LEAD_EMPLOYEE.REVIEWS.SELECT_TEAM_MEMBER') }}
          </option>
          <option
            v-for="user in request.assignable_users"
            :key="user.id"
            :value="user.id"
          >
            {{ user.name }}
          </option>
        </select>
      </label>
      <textarea
        v-model="resolutionForms[request.id].answer"
        :disabled="Boolean(resolutionResults[request.id])"
        rows="4"
        class="rounded-md border border-n-weak bg-n-background px-3 py-2"
        :placeholder="t('AI_LEAD_EMPLOYEE.REVIEWS.ANSWER_PLACEHOLDER')"
      />
      <section
        v-if="
          resolutionResults[request.id]?.status === 'resolved' &&
          resolutionResults[request.id]?.resolution_kind === 'send_reply'
        "
        data-testid="persisted-reply-delivery"
        class="grid gap-1 rounded-md border border-n-weak bg-n-background p-3"
      >
        <p class="font-medium">
          {{ replyOutcomeMessage(resolutionResults[request.id].reply_outcome) }}
        </p>
        <p
          v-if="resolutionResults[request.id].reply_delivery?.failure_code"
          class="text-xs text-n-slate-11"
        >
          {{
            t('AI_LEAD_EMPLOYEE.REVIEWS.REPLY_FAILURE_CODE', {
              code: resolutionResults[request.id].reply_delivery.failure_code,
            })
          }}
        </p>
        <p
          v-if="resolutionResults[request.id].reply_delivery?.recoverable"
          class="text-xs text-n-slate-11"
        >
          {{ t('AI_LEAD_EMPLOYEE.REVIEWS.REPLY_RECOVERABLE') }}
        </p>
        <p
          v-else-if="
            [
              'reply_delivery_failed',
              'reply_delivery_unknown',
              'reply_delivery_canceled',
            ].includes(resolutionResults[request.id].reply_outcome)
          "
          class="text-xs text-n-slate-11"
        >
          {{ t('AI_LEAD_EMPLOYEE.REVIEWS.REPLY_MANUAL_CHECK') }}
        </p>
      </section>
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
          resolutionResults[request.id].status === 'resolved' &&
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
              :key="source.value"
              :value="source.value"
            >
              {{ source.label }}
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
        v-else-if="resolutionResults[request.id].status === 'resolved'"
        class="w-fit text-n-blue-text underline"
        :href="knowledgePath(resolutionResults[request.id])"
      >
        {{ t('AI_LEAD_EMPLOYEE.REVIEWS.OPEN_PROPOSAL') }}
      </a>
      <p v-else class="text-xs text-n-slate-11">
        {{ t('AI_LEAD_EMPLOYEE.REVIEWS.REJECTED') }}
      </p>
      <section
        v-if="resolutionResults[request.id]?.status === 'resolved'"
        class="grid gap-2 border-t border-n-weak pt-3"
      >
        <p class="font-medium">
          {{ t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_TITLE') }}
        </p>
        <template
          v-if="
            resolutionResults[request.id].configuration_suggestion_outcome ===
            'not_requested'
          "
        >
          <p class="text-xs text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_EFFECT') }}
          </p>
          <select
            v-model="resolutionForms[request.id].feedback_category"
            class="rounded-md border border-n-weak bg-n-background px-3 py-2"
          >
            <option value="poor_fit">
              {{ t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_CATEGORY.POOR_FIT') }}
            </option>
            <option value="not_ready">
              {{ t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_CATEGORY.NOT_READY') }}
            </option>
          </select>
          <textarea
            v-model="resolutionForms[request.id].feedback_suggestion"
            rows="3"
            class="rounded-md border border-n-weak bg-n-background px-3 py-2"
            :placeholder="
              t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_SUGGESTION_PLACEHOLDER')
            "
          />
          <button
            type="button"
            class="w-fit rounded-lg border border-n-weak px-3 py-2 text-sm font-medium disabled:opacity-50"
            :disabled="
              resolvingId === request.id ||
              !resolutionForms[request.id].feedback_suggestion
            "
            @click="proposeConfigurationSuggestion(request)"
          >
            {{ t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_PROPOSE') }}
          </button>
        </template>
        <template v-else>
          <p class="text-xs text-n-slate-11">
            {{
              t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_EVIDENCE', {
                evidence:
                  resolutionResults[request.id].configuration_suggestion
                    ?.evidence,
              })
            }}
          </p>
          <p>
            {{
              resolutionResults[request.id].configuration_suggestion?.suggestion
            }}
          </p>
          <div
            v-if="
              resolutionResults[request.id]
                .can_review_configuration_suggestion &&
              resolutionResults[request.id].configuration_suggestion_outcome ===
                'pending'
            "
            class="flex gap-2"
          >
            <button
              type="button"
              class="rounded-lg border border-n-weak px-3 py-2 text-sm font-medium"
              @click="reviewConfigurationSuggestion(request, 'reviewed')"
            >
              {{ t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_MARK_REVIEWED') }}
            </button>
            <button
              type="button"
              class="rounded-lg border border-n-weak px-3 py-2 text-sm font-medium"
              @click="reviewConfigurationSuggestion(request, 'dismissed')"
            >
              {{ t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_DISMISS') }}
            </button>
          </div>
          <p v-else class="text-xs text-n-slate-11">
            {{
              t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_STATUS', {
                status: feedbackStatusLabel(
                  resolutionResults[request.id].configuration_suggestion_outcome
                ),
              })
            }}
          </p>
        </template>
      </section>
    </article>
  </section>
</template>

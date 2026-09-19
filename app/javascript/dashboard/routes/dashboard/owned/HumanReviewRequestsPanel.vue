<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import HumanReviewRequestsAPI from 'dashboard/api/humanReviewRequests';

const props = defineProps({
  conversationId: { type: [String, Number], default: null },
  reviewId: { type: [String, Number], default: null },
});

const route = useRoute();
const reviewRequests = ref([]);
const isLoading = ref(false);
const resolvingId = ref(null);
const resolutionForms = ref({});
const resolutionResults = ref({});
const sourceOptions = ['faq', 'offer', 'pricing', 'objection', 'policy', 'refund'];

const visibleRequests = computed(() =>
  reviewRequests.value.filter(request => {
    if (props.reviewId) return Number(request.id) === Number(props.reviewId);
    return !props.conversationId || Number(request.conversation_id) === Number(props.conversationId);
  })
);

const loadReviewRequests = async () => {
  isLoading.value = true;
  try {
    const { data } = await HumanReviewRequestsAPI.get();
    reviewRequests.value = data;
    data.forEach(request => {
      resolutionForms.value[request.id] ||= {
        answer: '',
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
        ? 'Reply queued for the Lead and review resolved.'
        : 'Private note saved and review resolved.'
    );
  } catch {
    useAlert('The review could not be resolved. Nothing was sent.');
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
    });
    resolutionResults.value[request.id] = data;
    useAlert('Draft knowledge proposal saved for administrator approval.');
  } catch {
    useAlert('The review is resolved, but the knowledge proposal still needs attention.');
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

<!-- eslint-disable vue/no-bare-strings-in-template -->
<template>
  <section class="mt-6 border border-n-weak bg-n-solid-1">
    <div v-if="isLoading" class="px-4 py-6 text-sm text-n-slate-11">
      Loading review requests
    </div>
    <div v-else-if="!visibleRequests.length" class="px-4 py-6 text-sm text-n-slate-11">
      No review requests are waiting for this conversation.
    </div>
    <article v-for="request in visibleRequests" :key="request.id" class="grid gap-3 border-b border-n-weak p-4 text-sm text-n-slate-12">
      <div>
        <p class="font-medium">{{ request.question }}</p>
        <p class="mt-1 text-xs text-n-slate-11">
          {{ request.reason.replaceAll('_', ' ') }} · Assigned to {{ request.assigned_user?.name || 'Unassigned' }}
        </p>
        <a class="mt-2 inline-flex text-n-blue-text underline" :href="conversationPath(request)">
          Open conversation #{{ request.conversation_display_id }}
        </a>
      </div>
      <textarea
        v-model="resolutionForms[request.id].answer"
        :disabled="Boolean(resolutionResults[request.id])"
        rows="4"
        class="rounded-md border border-n-weak bg-n-background px-3 py-2"
        placeholder="Write the customer reply or private resolution note"
      />
      <template v-if="!resolutionResults[request.id]">
        <p class="text-xs text-n-slate-11">
          Send reply delivers this text to the Lead. Save private note keeps it inside your team.
        </p>
        <div class="flex flex-wrap gap-2">
          <button
            type="button"
            class="rounded-lg bg-n-brand px-3 py-2 text-sm font-medium text-white disabled:opacity-50"
            :disabled="resolvingId === request.id || !resolutionForms[request.id].answer"
            @click="resolveReviewRequest(request, 'send_reply')"
          >
            Send reply and resolve
          </button>
          <button
            type="button"
            class="rounded-lg border border-n-weak px-3 py-2 text-sm font-medium disabled:opacity-50"
            :disabled="resolvingId === request.id || !resolutionForms[request.id].answer"
            @click="resolveReviewRequest(request, 'internal_note')"
          >
            Save private note and resolve
          </button>
        </div>
      </template>
      <template v-else-if="resolutionResults[request.id].knowledge_proposal_outcome === 'not_requested'">
        <p class="text-xs text-n-slate-11">
          Reusable knowledge is optional and stays unavailable until an administrator approves this separate draft.
        </p>
        <div class="grid gap-2 sm:grid-cols-2">
          <input v-model="resolutionForms[request.id].title" class="rounded-md border border-n-weak bg-n-background px-3 py-2" placeholder="Knowledge proposal title" />
          <select v-model="resolutionForms[request.id].source_kind" class="rounded-md border border-n-weak bg-n-background px-3 py-2">
            <option v-for="source in sourceOptions" :key="source" :value="source">{{ source }}</option>
          </select>
        </div>
        <button
          type="button"
          class="w-fit rounded-lg border border-n-weak px-3 py-2 text-sm font-medium disabled:opacity-50"
          :disabled="resolvingId === request.id"
          @click="proposeKnowledge(request)"
        >
          Propose reusable knowledge
        </button>
      </template>
      <a v-else class="w-fit text-n-blue-text underline" :href="knowledgePath(resolutionResults[request.id])">
        Open draft knowledge proposal
      </a>
    </article>
  </section>
</template>

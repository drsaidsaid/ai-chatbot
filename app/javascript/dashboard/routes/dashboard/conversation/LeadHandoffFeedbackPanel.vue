<script setup>
import { onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import LeadHandoffsAPI from 'dashboard/api/leadHandoffs';
import ReviewConfigurationSuggestionsAPI from 'dashboard/api/reviewConfigurationSuggestions';

const props = defineProps({
  handoffId: { type: [String, Number], required: true },
});

const { t } = useI18n();
const handoff = ref(null);
const category = ref('poor_fit');
const suggestion = ref('');
const isSaving = ref(false);
let loadRequest = 0;

const load = async () => {
  loadRequest += 1;
  const request = loadRequest;
  try {
    const { data } = await LeadHandoffsAPI.show(props.handoffId);
    if (request === loadRequest) handoff.value = data;
  } catch {
    if (request === loadRequest) handoff.value = null;
  }
};

const propose = async () => {
  isSaving.value = true;
  try {
    const { data } = await LeadHandoffsAPI.proposeConfigurationSuggestion(
      props.handoffId,
      { category: category.value, suggestion: suggestion.value }
    );
    handoff.value = data;
    useAlert(t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_SAVED'));
  } catch {
    useAlert(t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const review = async outcome => {
  const record = handoff.value?.configuration_suggestion;
  if (!record) return;
  isSaving.value = true;
  try {
    const { data } = await ReviewConfigurationSuggestionsAPI.review(record.id, {
      outcome,
    });
    handoff.value = {
      ...handoff.value,
      configuration_suggestion_outcome: data.status,
      configuration_suggestion: data,
    };
    useAlert(t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_REVIEWED'));
  } catch {
    useAlert(t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

onMounted(load);
watch(() => props.handoffId, load);
</script>

<template>
  <div>
    <section
      v-if="handoff"
      data-testid="lead-handoff-feedback"
      class="mx-3 mb-3 grid gap-2 rounded-lg border border-n-weak bg-n-solid-1 p-3 text-sm text-n-slate-12"
    >
      <p class="font-medium">
        {{ t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_TITLE') }}
      </p>
      <template
        v-if="handoff.configuration_suggestion_outcome === 'not_requested'"
      >
        <p class="text-xs text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_EFFECT') }}
        </p>
        <select
          v-model="category"
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
          v-model="suggestion"
          rows="3"
          class="rounded-md border border-n-weak bg-n-background px-3 py-2"
          :placeholder="
            t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_SUGGESTION_PLACEHOLDER')
          "
        />
        <button
          type="button"
          class="w-fit rounded-lg border border-n-weak px-3 py-2 font-medium disabled:opacity-50"
          :disabled="isSaving || !suggestion"
          @click="propose"
        >
          {{ t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_PROPOSE') }}
        </button>
      </template>
      <template v-else>
        <p>{{ handoff.configuration_suggestion?.suggestion }}</p>
        <p class="text-xs text-n-slate-11">
          {{
            t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_STATUS', {
              status: handoff.configuration_suggestion_outcome,
            })
          }}
        </p>
        <div
          v-if="
            handoff.can_review_configuration_suggestion &&
            handoff.configuration_suggestion_outcome === 'pending'
          "
          class="flex flex-wrap gap-2"
        >
          <button
            type="button"
            class="rounded-lg border border-n-weak px-3 py-2 font-medium"
            :disabled="isSaving"
            @click="review('reviewed')"
          >
            {{ t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_MARK_REVIEWED') }}
          </button>
          <button
            type="button"
            class="rounded-lg border border-n-weak px-3 py-2 font-medium"
            :disabled="isSaving"
            @click="review('dismissed')"
          >
            {{ t('AI_LEAD_EMPLOYEE.REVIEWS.FEEDBACK_DISMISS') }}
          </button>
        </div>
      </template>
    </section>
  </div>
</template>

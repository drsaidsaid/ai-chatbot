<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import KnowledgeItemsAPI from 'dashboard/api/knowledgeItems';

const { t } = useI18n();

const knowledgeItems = ref([]);
const isLoading = ref(false);
const isSaving = ref(false);
const editingItemId = ref(null);
const form = ref({
  title: '',
  question: '',
  answer: '',
  source_kind: 'faq',
});

const sourceOptions = ['faq', 'offer', 'pricing', 'supporting_document'];
const isEditing = computed(() => editingItemId.value !== null);
const sourceLabels = computed(() => ({
  faq: t('AI_LEAD_EMPLOYEE.KNOWLEDGE.SOURCE.FAQ'),
  offer: t('AI_LEAD_EMPLOYEE.KNOWLEDGE.SOURCE.OFFER'),
  pricing: t('AI_LEAD_EMPLOYEE.KNOWLEDGE.SOURCE.PRICING'),
  supporting_document: t(
    'AI_LEAD_EMPLOYEE.KNOWLEDGE.SOURCE.SUPPORTING_DOCUMENT'
  ),
}));
const statusLabels = computed(() => ({
  draft: t('AI_LEAD_EMPLOYEE.KNOWLEDGE.STATUS.DRAFT'),
  approved: t('AI_LEAD_EMPLOYEE.KNOWLEDGE.STATUS.APPROVED'),
  rejected: t('AI_LEAD_EMPLOYEE.KNOWLEDGE.STATUS.REJECTED'),
  inactive: t('AI_LEAD_EMPLOYEE.KNOWLEDGE.STATUS.INACTIVE'),
}));

const resetForm = () => {
  editingItemId.value = null;
  form.value = {
    title: '',
    question: '',
    answer: '',
    source_kind: 'faq',
  };
};

const loadKnowledgeItems = async () => {
  isLoading.value = true;
  try {
    const { data } = await KnowledgeItemsAPI.get();
    knowledgeItems.value = data;
  } finally {
    isLoading.value = false;
  }
};

const saveKnowledgeItem = async () => {
  isSaving.value = true;
  try {
    if (isEditing.value) {
      await KnowledgeItemsAPI.update(editingItemId.value, form.value);
    } else {
      await KnowledgeItemsAPI.create(form.value);
    }
    useAlert(t('AI_LEAD_EMPLOYEE.KNOWLEDGE.SAVED'));
    resetForm();
    await loadKnowledgeItems();
  } catch {
    useAlert(t('AI_LEAD_EMPLOYEE.KNOWLEDGE.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const editKnowledgeItem = item => {
  editingItemId.value = item.id;
  form.value = {
    title: item.title,
    question: item.question,
    answer: item.answer,
    source_kind: item.source_kind,
  };
};

const applyLifecycleAction = async (item, action) => {
  try {
    await KnowledgeItemsAPI[action](item.id);
    await loadKnowledgeItems();
  } catch {
    useAlert(t('AI_LEAD_EMPLOYEE.KNOWLEDGE.SAVE_ERROR'));
  }
};

onMounted(loadKnowledgeItems);
</script>

<template>
  <div class="mt-6 grid gap-4 lg:grid-cols-[minmax(280px,360px)_1fr]">
    <form
      class="flex flex-col gap-3 border border-n-weak bg-n-solid-1 p-4"
      @submit.prevent="saveKnowledgeItem"
    >
      <h2 class="text-base font-semibold text-n-slate-12">
        {{
          isEditing
            ? t('AI_LEAD_EMPLOYEE.KNOWLEDGE.EDIT_TITLE')
            : t('AI_LEAD_EMPLOYEE.KNOWLEDGE.NEW_TITLE')
        }}
      </h2>
      <label class="flex flex-col gap-1 text-sm text-n-slate-12">
        {{ t('AI_LEAD_EMPLOYEE.KNOWLEDGE.FIELD.TITLE') }}
        <input
          v-model="form.title"
          required
          class="rounded-md border border-n-weak bg-n-background px-3 py-2"
        />
      </label>
      <label class="flex flex-col gap-1 text-sm text-n-slate-12">
        {{ t('AI_LEAD_EMPLOYEE.KNOWLEDGE.FIELD.SOURCE') }}
        <select
          v-model="form.source_kind"
          class="rounded-md border border-n-weak bg-n-background px-3 py-2"
        >
          <option v-for="source in sourceOptions" :key="source" :value="source">
            {{ sourceLabels[source] }}
          </option>
        </select>
      </label>
      <label class="flex flex-col gap-1 text-sm text-n-slate-12">
        {{ t('AI_LEAD_EMPLOYEE.KNOWLEDGE.FIELD.QUESTION') }}
        <textarea
          v-model="form.question"
          required
          rows="3"
          class="rounded-md border border-n-weak bg-n-background px-3 py-2"
        />
      </label>
      <label class="flex flex-col gap-1 text-sm text-n-slate-12">
        {{ t('AI_LEAD_EMPLOYEE.KNOWLEDGE.FIELD.ANSWER') }}
        <textarea
          v-model="form.answer"
          required
          rows="5"
          class="rounded-md border border-n-weak bg-n-background px-3 py-2"
        />
      </label>
      <div class="flex gap-2">
        <button
          type="submit"
          class="inline-flex h-8 items-center justify-center rounded-lg bg-n-brand px-3 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="isSaving"
        >
          {{ t('AI_LEAD_EMPLOYEE.KNOWLEDGE.SAVE') }}
        </button>
        <button
          v-if="isEditing"
          type="button"
          class="inline-flex h-8 items-center justify-center rounded-lg border border-n-weak px-3 text-sm font-medium text-n-slate-12"
          @click="resetForm"
        >
          {{ t('AI_LEAD_EMPLOYEE.KNOWLEDGE.CANCEL') }}
        </button>
      </div>
    </form>

    <section class="overflow-x-auto border border-n-weak bg-n-solid-1">
      <div class="min-w-[760px]">
        <div
          class="grid grid-cols-[1.2fr_1fr_0.7fr_0.7fr_1.1fr] gap-3 border-b border-n-weak px-4 py-3 text-xs font-medium uppercase text-n-slate-11"
        >
          <span>{{ t('AI_LEAD_EMPLOYEE.KNOWLEDGE.FIELD.TITLE') }}</span>
          <span>{{ t('AI_LEAD_EMPLOYEE.KNOWLEDGE.FIELD.SOURCE') }}</span>
          <span>{{ t('AI_LEAD_EMPLOYEE.KNOWLEDGE.FIELD.STATUS') }}</span>
          <span>{{ t('AI_LEAD_EMPLOYEE.KNOWLEDGE.FIELD.UPDATED') }}</span>
          <span>{{ t('AI_LEAD_EMPLOYEE.KNOWLEDGE.FIELD.ACTIONS') }}</span>
        </div>
      </div>
      <div v-if="isLoading" class="px-4 py-6 text-sm text-n-slate-11">
        {{ t('AI_LEAD_EMPLOYEE.KNOWLEDGE.LOADING') }}
      </div>
      <div
        v-else-if="!knowledgeItems.length"
        class="px-4 py-6 text-sm text-n-slate-11"
      >
        {{ t('AI_LEAD_EMPLOYEE.KNOWLEDGE.EMPTY') }}
      </div>
      <div v-else>
        <div
          v-for="item in knowledgeItems"
          :key="item.id"
          class="grid min-w-[760px] grid-cols-[1.2fr_1fr_0.7fr_0.7fr_1.1fr] gap-3 border-b border-n-weak px-4 py-3 text-sm text-n-slate-12"
        >
          <span class="min-w-0 truncate">{{ item.title }}</span>
          <span>
            {{ sourceLabels[item.source_kind] }}
          </span>
          <span>
            {{ statusLabels[item.status] }}
          </span>
          <span>{{ new Date(item.updated_at).toLocaleDateString() }}</span>
          <span class="flex flex-wrap gap-1">
            <button
              type="button"
              class="inline-flex h-8 items-center justify-center rounded-lg border border-n-weak px-3 text-sm font-medium text-n-slate-12"
              @click="editKnowledgeItem(item)"
            >
              {{ t('AI_LEAD_EMPLOYEE.KNOWLEDGE.EDIT') }}
            </button>
            <button
              type="button"
              class="inline-flex h-8 items-center justify-center rounded-lg border border-n-weak px-3 text-sm font-medium text-n-slate-12"
              @click="applyLifecycleAction(item, 'approve')"
            >
              {{ t('AI_LEAD_EMPLOYEE.KNOWLEDGE.APPROVE') }}
            </button>
            <button
              type="button"
              class="inline-flex h-8 items-center justify-center rounded-lg border border-n-weak px-3 text-sm font-medium text-n-slate-12"
              @click="applyLifecycleAction(item, 'reject')"
            >
              {{ t('AI_LEAD_EMPLOYEE.KNOWLEDGE.REJECT') }}
            </button>
            <button
              type="button"
              class="inline-flex h-8 items-center justify-center rounded-lg border border-n-weak px-3 text-sm font-medium text-n-slate-12"
              @click="applyLifecycleAction(item, 'deactivate')"
            >
              {{ t('AI_LEAD_EMPLOYEE.KNOWLEDGE.DEACTIVATE') }}
            </button>
          </span>
        </div>
      </div>
    </section>
  </div>
</template>

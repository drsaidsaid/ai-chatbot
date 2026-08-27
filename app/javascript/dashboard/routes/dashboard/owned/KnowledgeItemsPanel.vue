<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import Icon from 'next/icon/Icon.vue';
import KnowledgeDocumentsAPI from 'dashboard/api/knowledgeDocuments';
import KnowledgeItemsAPI from 'dashboard/api/knowledgeItems';
import HumanReviewRequestsAPI from 'dashboard/api/humanReviewRequests';

const route = useRoute();

const tabs = [
  { key: 'documents', label: 'Documents' },
  { key: 'approved_answers', label: 'Approved Answers' },
  { key: 'needs_review', label: 'Needs Review' },
];
const answerKinds = [
  'pricing',
  'refund',
  'guarantee',
  'eligibility',
  'objection',
  'policy',
  'faq',
  'offer',
];

const activeTab = ref('documents');
const documents = ref([]);
const approvedAnswers = ref([]);
const reviewRequests = ref([]);
const selectedDocumentId = ref(null);
const selectedAnswerId = ref(null);
const selectedReviewId = ref(null);
const isLoading = ref(false);
const isSaving = ref(false);
const isTesting = ref(false);
const documentSearch = ref('');
const answerSearch = ref('');
const reviewFilter = ref('all');
const showPreview = ref(false);
const showRevisionHistory = ref(false);
const showImport = ref(false);
const showNewAnswer = ref(false);
const hasUnsavedDocumentChanges = ref(false);
const testQuestion = ref('Can you explain Online Profits services?');
const testResult = ref(null);
const saveError = ref('');

const documentForm = reactive({
  title: '',
  body: '',
  used_by_ai_employee: true,
  general_question_access: true,
  sensitive_topics: ['pricing', 'refunds', 'guarantees'],
  offer_ids: [],
});
const importForm = reactive({
  title: 'Imported company context',
  body: '',
  source: 'manual_import',
});
const answerForm = reactive({
  title: '',
  question: '',
  answer: '',
  source_kind: 'pricing',
});
const reviewForms = reactive({});

const selectedDocument = computed(
  () =>
    documents.value.find(
      document => document.id === selectedDocumentId.value
    ) || null
);
const selectedAnswer = computed(
  () =>
    approvedAnswers.value.find(
      answer => answer.id === selectedAnswerId.value
    ) || null
);
const selectedReview = computed(
  () =>
    reviewRequests.value.find(
      request => request.id === selectedReviewId.value
    ) || null
);

const filteredDocuments = computed(() => {
  const query = documentSearch.value.trim().toLowerCase();
  if (!query) return documents.value;
  return documents.value.filter(document =>
    [document.title, document.body].join(' ').toLowerCase().includes(query)
  );
});
const filteredAnswers = computed(() => {
  const query = answerSearch.value.trim().toLowerCase();
  return approvedAnswers.value.filter(
    answer =>
      !query ||
      [answer.title, answer.question, answer.answer]
        .join(' ')
        .toLowerCase()
        .includes(query)
  );
});
const filteredReviews = computed(() => {
  if (reviewFilter.value === 'all') return reviewRequests.value;
  return reviewRequests.value.filter(
    request => request.reason === reviewFilter.value
  );
});

const statusLabel = status =>
  ({
    draft: 'Draft',
    published: 'Published',
    archived: 'Archived',
    import_failed: 'Failed import',
    approved: 'Approved',
    rejected: 'Rejected',
    inactive: 'Archived',
    })[status] || status;

const answerKindLabel = kind =>
  ({
    pricing: 'Pricing',
    refund: 'Refunds',
    guarantee: 'Guarantees',
    eligibility: 'Eligibility',
    objection: 'Objections',
    policy: 'Policy',
    faq: 'General FAQ',
    offer: 'Offers',
    supporting_document: 'Supporting document',
  })[kind] || kind;

const reasonLabel = reason =>
  ({
    no_approved_knowledge: 'No approved answer',
    conflicting_knowledge: 'Conflicting sources',
    sensitive_question: 'Sensitive question',
    qualification_blocker: 'Qualification blocker',
    angry_question: 'Angry lead',
  })[reason] || reason;

const relativeDate = value => {
  if (!value) return 'Not saved';
  return new Date(value).toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
  });
};

const syncDocumentForm = document => {
  if (!document) return;
  Object.assign(documentForm, {
    title: document.title,
    body: document.body || '',
    used_by_ai_employee: document.used_by_ai_employee,
    general_question_access: document.general_question_access,
    sensitive_topics: document.sensitive_topics?.length
      ? document.sensitive_topics
      : ['pricing', 'refunds', 'guarantees'],
    offer_ids: document.offer_ids || [],
  });
  hasUnsavedDocumentChanges.value = false;
};

const selectDocument = document => {
  selectedDocumentId.value = document.id;
  syncDocumentForm(document);
  showPreview.value = false;
  testResult.value = null;
};

const ensureReviewForm = request => {
  reviewForms[request.id] ||= {
    answer: '',
    send_to_lead: true,
    propose_knowledge: true,
    source_kind: request.reason === 'sensitive_question' ? 'policy' : 'faq',
    title: request.question?.slice(0, 72) || '',
  };
};

const loadDocuments = async () => {
  const { data } = await KnowledgeDocumentsAPI.list({
    q: documentSearch.value,
  });
  documents.value = data;
  if (!selectedDocumentId.value && data.length) selectDocument(data[0]);
  if (selectedDocumentId.value) {
    const selected = data.find(
      document => document.id === selectedDocumentId.value
    );
    if (selected) syncDocumentForm(selected);
  }
};
const loadApprovedAnswers = async () => {
  const { data } = await KnowledgeItemsAPI.get();
  approvedAnswers.value = data;
  selectedAnswerId.value ||= data[0]?.id || null;
};
const loadReviewRequests = async () => {
  const { data } = await HumanReviewRequestsAPI.get();
  reviewRequests.value = data;
  data.forEach(ensureReviewForm);
  selectedReviewId.value ||= data[0]?.id || null;
};
const loadWorkspace = async () => {
  isLoading.value = true;
  saveError.value = '';
  try {
    await Promise.all([
      loadDocuments(),
      loadApprovedAnswers(),
      loadReviewRequests(),
    ]);
  } catch {
    saveError.value = 'Could not load Knowledge workspace.';
  } finally {
    isLoading.value = false;
  }
};

const createDocument = async () => {
  isSaving.value = true;
  try {
    const { data } = await KnowledgeDocumentsAPI.create({
      title: 'Untitled Online Profits document',
      body: 'Add company context, services, offers, and policies here.',
      used_by_ai_employee: true,
      general_question_access: true,
      sensitive_topics: ['pricing', 'refunds', 'guarantees'],
      offer_ids: [],
    });
    documents.value.unshift(data);
    selectDocument(data);
  } catch {
    saveError.value = 'Could not create the document.';
  } finally {
    isSaving.value = false;
  }
};
const importDocument = async () => {
  isSaving.value = true;
  try {
    const { data } = await KnowledgeDocumentsAPI.import(importForm);
    documents.value.unshift(data);
    selectDocument(data);
    showImport.value = false;
    useAlert(
      data.status === 'import_failed'
        ? 'Import failed. Check the document content.'
        : 'Document imported'
    );
  } catch {
    saveError.value = 'Could not import the document.';
  } finally {
    isSaving.value = false;
  }
};
const saveDocument = async () => {
  if (!selectedDocument.value) return;
  isSaving.value = true;
  try {
    const { data } = await KnowledgeDocumentsAPI.update(
      selectedDocument.value.id,
      documentForm
    );
    documents.value = documents.value.map(document =>
      document.id === data.id ? data : document
    );
    selectDocument(data);
    useAlert('Draft saved');
  } catch {
    saveError.value = 'Could not save this document.';
  } finally {
    isSaving.value = false;
  }
};
const publishDocument = async () => {
  if (!selectedDocument.value) return;
  await saveDocument();
  const { data } = await KnowledgeDocumentsAPI.publish(
    selectedDocument.value.id
  );
  documents.value = documents.value.map(document =>
    document.id === data.id ? data : document
  );
  selectDocument(data);
  useAlert(
    'Document published. Sensitive claims still require Approved Answers.'
  );
};
const archiveDocument = async () => {
  if (!selectedDocument.value) return;
  const { data } = await KnowledgeDocumentsAPI.archive(
    selectedDocument.value.id
  );
  documents.value = documents.value.map(document =>
    document.id === data.id ? data : document
  );
  selectDocument(data);
};
const runDocumentTest = async () => {
  if (!selectedDocument.value) return;
  isTesting.value = true;
  const { data } = await KnowledgeDocumentsAPI.test(
    selectedDocument.value.id,
    testQuestion.value
  );
  testResult.value = data;
  isTesting.value = false;
};
const updateDocumentField = (key, value) => {
  documentForm[key] = value;
  hasUnsavedDocumentChanges.value = true;
};
const createAnswer = async () => {
  isSaving.value = true;
  try {
    const { data } = await KnowledgeItemsAPI.create(answerForm);
    approvedAnswers.value.unshift(data);
    selectedAnswerId.value = data.id;
    Object.assign(answerForm, {
      title: '',
      question: '',
      answer: '',
      source_kind: 'pricing',
    });
    showNewAnswer.value = false;
  } catch (error) {
    saveError.value =
      error.response?.data?.error || 'Could not save the Approved Answer.';
  } finally {
    isSaving.value = false;
  }
};
const applyAnswerLifecycle = async (answer, action) => {
  const { data } = await KnowledgeItemsAPI[action](answer.id);
  approvedAnswers.value = approvedAnswers.value.map(item =>
    item.id === data.id ? data : item
  );
};
const resolveReview = async request => {
  await HumanReviewRequestsAPI.resolve(request.id, reviewForms[request.id]);
  await Promise.all([loadReviewRequests(), loadApprovedAnswers()]);
  useAlert('Review request resolved');
};
const rejectReview = async request => {
  await HumanReviewRequestsAPI.reject(request.id, {
    operator_answer:
      reviewForms[request.id].answer ||
      'Rejected as not appropriate for AI Employee use.',
  });
  await loadReviewRequests();
};
const conversationPath = request =>
  `/app/accounts/${route.params.accountId}/conversations/${request.conversation_display_id}`;

onMounted(loadWorkspace);
</script>

<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<template>
  <section class="min-h-[calc(100vh-3rem)] bg-n-solid-1">
    <header
      class="mb-6 flex min-w-0 flex-col gap-4 sm:flex-row sm:items-start sm:justify-between"
      data-testid="knowledge-header"
    >
      <div class="min-w-0">
        <h1 class="text-2xl font-semibold text-n-slate-12">Knowledge</h1>
        <p class="mt-2 text-sm text-n-slate-11">
          Teach AI Lead Employee about your business.
        </p>
      </div>
      <div
        class="grid w-full grid-cols-2 gap-2 sm:flex sm:w-auto sm:shrink-0 sm:flex-wrap sm:justify-end sm:gap-3"
        data-testid="knowledge-header-actions"
      >
        <button
          type="button"
          class="inline-flex h-10 min-w-0 items-center justify-center gap-2 rounded-lg border border-n-weak bg-n-background px-3 text-sm font-medium text-n-slate-12 sm:px-4"
          @click="showImport = !showImport"
        >
          <Icon icon="i-lucide-upload" class="size-4 shrink-0" />
          <span class="truncate">Import document</span>
        </button>
        <button
          type="button"
          class="inline-flex h-10 min-w-0 items-center justify-center gap-2 rounded-lg bg-n-brand px-3 text-sm font-medium text-white shadow-sm sm:px-4"
          @click="createDocument"
        >
          <Icon icon="i-lucide-plus" class="size-4 shrink-0" />
          <span class="truncate">New document</span>
        </button>
      </div>
    </header>

    <div class="border-b border-n-weak">
      <nav
        class="-mx-4 flex min-w-0 gap-5 overflow-x-auto px-4 [scrollbar-width:thin] sm:mx-0 sm:gap-8 sm:px-0"
        aria-label="Knowledge workspace sections"
        data-testid="knowledge-tabs"
      >
        <button
          v-for="tab in tabs"
          :key="tab.key"
          type="button"
          class="shrink-0 whitespace-nowrap border-b-2 px-1 pb-4 text-sm font-medium outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
          :data-testid="`knowledge-tab-${tab.key}`"
          :class="
            activeTab === tab.key
              ? 'border-n-brand text-n-blue-text'
              : 'border-transparent text-n-slate-11'
          "
          @click="activeTab = tab.key"
        >
          {{ tab.label }}
        </button>
      </nav>
    </div>

    <div
      v-if="saveError"
      class="border-b border-n-ruby-5 bg-n-ruby-3 px-4 py-3 text-sm text-n-ruby-11"
    >
      {{ saveError }}
    </div>
    <div
      v-if="showImport"
      class="grid gap-3 border-b border-n-weak bg-n-background py-4 md:grid-cols-[1fr_2fr_auto]"
    >
      <input
        v-model="importForm.title"
        class="h-10 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm"
        aria-label="Imported document title"
      />
      <input
        v-model="importForm.body"
        class="h-10 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm"
        placeholder="Paste document text to import"
        aria-label="Imported document body"
      />
      <button
        type="button"
        class="h-10 rounded-lg bg-n-brand px-4 text-sm font-medium text-white disabled:opacity-50"
        :disabled="isSaving"
        @click="importDocument"
      >
        Import
      </button>
    </div>
    <div v-if="isLoading" class="p-6 text-sm text-n-slate-11">
      Loading Knowledge workspace...
    </div>

    <div
      v-else-if="activeTab === 'documents'"
      class="grid min-h-[calc(100vh-12rem)] lg:grid-cols-[320px_minmax(560px,1fr)_360px]"
    >
      <aside class="border-r border-n-weak bg-n-background py-5 pr-4">
        <label class="relative block">
          <Icon
            icon="i-lucide-search"
            class="absolute left-3 top-2.5 size-4 text-n-slate-10"
          />
          <input
            v-model="documentSearch"
            class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 pl-9 pr-3 text-sm"
            placeholder="Search documents..."
            aria-label="Search documents"
            @change="loadDocuments"
          />
        </label>
        <div
          v-if="!filteredDocuments.length"
          class="mt-4 rounded-lg border border-dashed border-n-weak p-4 text-sm text-n-slate-11"
        >
          No documents match this search.
        </div>
        <div class="mt-4 overflow-hidden">
          <button
            v-for="document in filteredDocuments"
            :key="document.id"
            type="button"
            class="flex w-full gap-3 border-b border-l-4 border-b-n-weak px-4 py-4 text-left outline-none last:border-b-0 hover:bg-n-slate-2 focus-visible:bg-n-blue-2/70"
            :class="
              selectedDocumentId === document.id
                ? 'border-l-n-brand bg-n-blue-2/70'
                : 'border-l-transparent'
            "
            @click="selectDocument(document)"
          >
            <Icon
              icon="i-lucide-file-text"
              class="mt-1 size-5 shrink-0 text-n-slate-11"
            />
            <span class="min-w-0 flex-1">
              <span
                class="block truncate text-sm font-semibold text-n-slate-12"
                >{{ document.title }}</span
              >
              <span
                class="mt-2 inline-flex rounded-md px-2 py-0.5 text-xs font-medium"
                :class="
                  document.status === 'published'
                    ? 'bg-n-teal-3 text-n-teal-11'
                    : document.status === 'import_failed'
                      ? 'bg-n-ruby-3 text-n-ruby-11'
                      : 'bg-n-blue-3 text-n-blue-11'
                "
                >{{ statusLabel(document.status) }}</span
              >
              <span class="ml-2 text-xs text-n-slate-10"
                >Updated {{ relativeDate(document.updated_at) }}</span
              >
            </span>
            <Icon
              icon="i-lucide-ellipsis-vertical"
              class="size-4 text-n-slate-10"
            />
          </button>
        </div>
        <p
          class="mt-7 rounded-lg bg-n-blue-2 p-4 text-sm leading-6 text-n-slate-11"
        >
          The AI Employee searches relevant parts of rich documents. Exact
          sensitive claims still come from Settings and Approved Answers.
        </p>
      </aside>

      <article v-if="selectedDocument" class="flex min-w-0 flex-col">
        <div class="border-b border-n-weak">
          <div
            class="flex min-h-12 flex-wrap items-center justify-between gap-3 px-4 py-2"
          >
            <div class="flex flex-wrap items-center gap-2">
              <select
                class="h-8 min-w-28 rounded-md border border-n-weak bg-n-background px-3 text-sm"
                :value="selectedDocument.status"
                aria-label="Document status"
                @change="
                  $event.target.value === 'archived' ? archiveDocument() : null
                "
              >
                <option value="published">Published</option>
                <option value="draft">Draft</option>
                <option value="archived">Archived</option>
              </select>
              <span class="text-sm text-n-slate-11">{{
                hasUnsavedDocumentChanges ? 'Unsaved changes' : 'Saved just now'
              }}</span>
            </div>
            <div class="flex flex-wrap items-center gap-2">
              <button
                type="button"
                class="inline-flex h-8 items-center gap-2 rounded-md border border-n-weak px-3 text-sm font-medium"
                @click="showPreview = !showPreview"
              >
                <Icon icon="i-lucide-eye" class="size-4" />
                Preview
              </button>
              <button
                type="button"
                class="h-8 rounded-md border border-n-weak px-3 text-sm font-medium"
                @click="saveDocument"
              >
                Save draft
              </button>
              <button
                type="button"
                class="h-8 rounded-md bg-n-brand px-4 text-sm font-medium text-white"
                :disabled="isSaving"
                @click="publishDocument"
              >
                Publish changes
              </button>
              <button
                type="button"
                class="inline-flex size-8 items-center justify-center rounded-md border border-n-weak"
                aria-label="Document actions"
                @click="archiveDocument"
              >
                <Icon icon="i-lucide-chevron-down" class="size-4" />
              </button>
            </div>
          </div>
          <div
            class="flex min-h-11 flex-wrap items-center gap-1 border-t border-n-weak px-4 py-1.5"
          >
            <select
              class="mr-2 h-8 min-w-36 rounded-md border border-n-weak bg-n-background px-3 text-sm"
              aria-label="Paragraph style"
            >
              <option>Paragraph</option>
              <option>Heading 2</option>
            </select>
            <button
              class="size-8 rounded-md border border-transparent font-semibold hover:border-n-weak focus-visible:ring-2 focus-visible:ring-n-brand"
              type="button"
            >
              B
            </button>
            <button
              class="size-8 rounded-md border border-transparent italic hover:border-n-weak focus-visible:ring-2 focus-visible:ring-n-brand"
              type="button"
            >
              I
            </button>
            <button
              class="h-8 rounded-md border border-transparent px-3 text-sm font-semibold hover:border-n-weak focus-visible:ring-2 focus-visible:ring-n-brand"
              type="button"
            >
              H2
            </button>
            <button
              class="size-8 rounded-md border border-transparent hover:border-n-weak focus-visible:ring-2 focus-visible:ring-n-brand"
              type="button"
              aria-label="Bulleted list"
            >
              <Icon icon="i-lucide-list" class="mx-auto size-4" />
            </button>
            <button
              class="size-8 rounded-md border border-transparent hover:border-n-weak focus-visible:ring-2 focus-visible:ring-n-brand"
              type="button"
              aria-label="Insert link"
            >
              <Icon icon="i-lucide-link" class="mx-auto size-4" />
            </button>
            <span class="mx-2 h-5 w-px bg-n-weak" />
            <button
              class="size-8 rounded-md border border-transparent hover:border-n-weak focus-visible:ring-2 focus-visible:ring-n-brand"
              type="button"
              aria-label="Undo"
            >
              <Icon icon="i-lucide-undo-2" class="mx-auto size-4" />
            </button>
            <button
              class="size-8 rounded-md border border-transparent hover:border-n-weak focus-visible:ring-2 focus-visible:ring-n-brand"
              type="button"
              aria-label="Redo"
            >
              <Icon icon="i-lucide-redo-2" class="mx-auto size-4" />
            </button>
            <button
              class="ml-auto size-8 rounded-md border border-transparent hover:border-n-weak focus-visible:ring-2 focus-visible:ring-n-brand"
              type="button"
              aria-label="More formatting"
            >
              <Icon icon="i-lucide-more-horizontal" class="mx-auto size-4" />
            </button>
          </div>
        </div>
        <div class="min-h-0 flex-1 overflow-auto px-6 py-5">
          <template v-if="showPreview">
            <h2 class="text-xl font-semibold text-n-slate-12">
              {{ documentForm.title }}
            </h2>
            <div
              class="mt-4 whitespace-pre-line text-sm leading-6 text-n-slate-12"
            >
              {{ documentForm.body }}
            </div>
          </template>
          <template v-else>
            <input
              :value="documentForm.title"
              class="w-full border border-transparent bg-transparent text-xl font-semibold text-n-slate-12 outline-none focus:border-n-weak focus:bg-n-background"
              aria-label="Document title"
              @input="updateDocumentField('title', $event.target.value)"
            />
            <textarea
              :value="documentForm.body"
              class="mt-4 min-h-[440px] w-full resize-none border border-transparent bg-transparent text-sm leading-7 text-n-slate-12 outline-none focus:border-n-weak focus:bg-n-background"
              aria-label="Document body"
              @input="updateDocumentField('body', $event.target.value)"
            />
          </template>
        </div>
        <footer
          class="flex flex-wrap items-center justify-between gap-3 border-t border-n-weak px-6 py-4 text-sm text-n-slate-11"
        >
          <span
            >{{ documentForm.body.length.toLocaleString() }} characters</span
          >
          <button
            type="button"
            class="font-medium text-n-blue-text"
            @click="showRevisionHistory = !showRevisionHistory"
          >
            View revision history
          </button>
        </footer>
        <div
          v-if="showRevisionHistory"
          class="border-t border-n-weak bg-n-background px-6 py-4"
        >
          <h3 class="text-sm font-semibold text-n-slate-12">
            Revision history
          </h3>
          <ol class="mt-3 grid gap-2 text-sm text-n-slate-11">
            <li
              v-for="revision in selectedDocument.revisions"
              :key="`${revision.event}-${revision.recorded_at}`"
            >
              {{ revision.event }} by
              {{ revision.editor_name || 'AI Lead Employee team' }} on
              {{ relativeDate(revision.recorded_at) }}
            </li>
          </ol>
        </div>
      </article>

      <aside
        v-if="selectedDocument"
        class="border-l border-n-weak bg-n-solid-1 py-6 pl-6"
      >
        <h2 class="text-base font-semibold text-n-slate-12">
          AI Employee access
        </h2>
        <p class="mt-2 text-sm leading-6 text-n-slate-11">
          Control how this document is used by the AI Employee in WhatsApp.
        </p>
        <div class="mt-6 grid gap-5">
          <label
            class="flex items-center justify-between gap-4 text-sm text-n-slate-12"
            >Used by WhatsApp AI Employee
            <button
              type="button"
              role="switch"
              class="relative h-6 w-11 rounded-full transition-colors focus-visible:ring-2 focus-visible:ring-n-brand"
              :class="
                documentForm.used_by_ai_employee ? 'bg-n-brand' : 'bg-n-slate-6'
              "
              :aria-checked="documentForm.used_by_ai_employee"
              @click="
                updateDocumentField(
                  'used_by_ai_employee',
                  !documentForm.used_by_ai_employee
                )
              "
            >
              <span
                class="absolute top-0.5 size-5 rounded-full bg-white shadow transition-transform"
                :class="
                  documentForm.used_by_ai_employee
                    ? 'translate-x-5'
                    : 'translate-x-0.5'
                "
              />
            </button>
          </label>
          <div class="border-t border-n-weak pt-5">
            <div class="flex items-center justify-between">
              <span class="text-sm font-semibold text-n-slate-12"
                >Applies to</span
              ><button
                type="button"
                class="text-n-blue-text"
                aria-label="Edit applicable offers"
              >
                <Icon icon="i-lucide-pencil" class="size-4" />
              </button>
            </div>
            <p class="mt-2 text-sm text-n-slate-11">All offers</p>
          </div>
          <label
            class="flex items-center justify-between gap-4 border-t border-n-weak pt-5 text-sm text-n-slate-12"
            >Can answer general questions
            <button
              type="button"
              role="switch"
              class="relative h-6 w-11 rounded-full transition-colors focus-visible:ring-2 focus-visible:ring-n-brand"
              :class="
                documentForm.general_question_access
                  ? 'bg-n-brand'
                  : 'bg-n-slate-6'
              "
              :aria-checked="documentForm.general_question_access"
              @click="
                updateDocumentField(
                  'general_question_access',
                  !documentForm.general_question_access
                )
              "
            >
              <span
                class="absolute top-0.5 size-5 rounded-full bg-white shadow transition-transform"
                :class="
                  documentForm.general_question_access
                    ? 'translate-x-5'
                    : 'translate-x-0.5'
                "
              />
            </button>
          </label>
          <div class="border-t border-n-weak pt-5">
            <h3 class="text-sm font-semibold text-n-slate-12">
              Sensitive topics
            </h3>
            <p class="mt-2 text-sm leading-6 text-n-slate-11">
              For pricing, refunds, guarantees, and eligibility, the AI Employee
              uses only Approved Answers.
            </p>
            <ul class="mt-4 grid gap-3">
              <li
                v-for="topic in ['Pricing', 'Refunds', 'Guarantees']"
                :key="topic"
                class="flex items-center justify-between gap-3 text-sm"
              >
                <span class="flex items-center gap-2 text-n-slate-12"
                  ><Icon
                    icon="i-lucide-shield-check"
                    class="size-4 text-n-slate-11"
                  />{{ topic }}</span
                ><span
                  class="rounded-md bg-n-teal-3 px-2 py-1 text-xs font-medium text-n-teal-11"
                  >Use Approved Answers</span
                >
              </li>
            </ul>
            <p
              class="mt-5 rounded-lg border border-n-amber-5 bg-n-amber-2 p-3 text-sm leading-6 text-n-amber-12"
            >
              Documents provide context. Approved Answers control exact claims.
            </p>
          </div>
          <div class="border-t border-n-weak pt-5">
            <h3 class="text-sm font-semibold text-n-slate-12">When unsure</h3>
            <p class="mt-2 text-sm leading-6 text-n-slate-11">
              If the AI Employee is unsure or cannot find a clear answer, it
              sends the conversation to Review.
            </p>
            <button
              type="button"
              class="mt-4 flex w-full items-center justify-center gap-2 rounded-lg border border-n-weak px-3 py-3 text-sm font-semibold"
              @click="runDocumentTest"
            >
              <Icon icon="i-lucide-flask-conical" class="size-4" />{{
                isTesting ? 'Testing...' : 'Test this document'
              }}
            </button>
            <input
              v-model="testQuestion"
              class="mt-3 h-10 w-full rounded-lg border border-n-weak bg-n-background px-3 text-sm"
              aria-label="Document test question"
            />
            <p
              v-if="testResult"
              class="mt-3 rounded-lg bg-n-background p-3 text-sm leading-6 text-n-slate-11"
            >
              {{
                testResult.answered
                  ? testResult.answer
                  : `Needs Review: ${testResult.refusal_reason}`
              }}
            </p>
          </div>
        </div>
      </aside>
    </div>

    <div
      v-else-if="activeTab === 'approved_answers'"
      class="grid min-h-[calc(100vh-15rem)] lg:grid-cols-[minmax(360px,1fr)_380px]"
    >
      <section class="border-r border-n-weak p-4">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <input
            v-model="answerSearch"
            aria-label="Search Approved Answers"
            class="h-10 min-w-[260px] flex-1 rounded-lg border border-n-weak bg-n-background px-3 text-sm"
            placeholder="Search Approved Answers..."
          />
          <button
            type="button"
            class="h-10 rounded-lg bg-n-brand px-3 text-sm font-medium text-white"
            @click="showNewAnswer = !showNewAnswer"
          >
            New Approved Answer
          </button>
        </div>
        <form
          v-if="showNewAnswer"
          class="mt-4 grid gap-3 rounded-lg border border-n-weak bg-n-background p-4"
          @submit.prevent="createAnswer"
        >
          <input
            v-model="answerForm.title"
            required
            aria-label="Approved Answer title"
            class="h-10 rounded-lg border border-n-weak px-3 text-sm"
            placeholder="Title"
          />
          <select
            v-model="answerForm.source_kind"
            aria-label="Approved Answer type"
            class="h-10 rounded-lg border border-n-weak px-3 text-sm"
          >
            <option v-for="kind in answerKinds" :key="kind" :value="kind">
              {{ answerKindLabel(kind) }}
            </option>
          </select>
          <input
            v-model="answerForm.question"
            required
            aria-label="Approved Answer question"
            class="h-10 rounded-lg border border-n-weak px-3 text-sm"
            placeholder="Exact question or claim"
          />
          <textarea
            v-model="answerForm.answer"
            required
            rows="4"
            aria-label="Approved Answer response"
            class="rounded-lg border border-n-weak px-3 py-2 text-sm"
            placeholder="Approved answer"
          />
          <button
            type="submit"
            class="h-9 rounded-lg bg-n-brand px-3 text-sm font-medium text-white"
          >
            Save draft
          </button>
        </form>
        <div class="mt-4 overflow-hidden rounded-lg border border-n-weak">
          <button
            v-for="answer in filteredAnswers"
            :key="answer.id"
            type="button"
            class="block w-full border-b border-n-weak px-4 py-4 text-left last:border-b-0 hover:bg-n-slate-2 focus-visible:ring-2 focus-visible:ring-n-brand"
            @click="selectedAnswerId = answer.id"
          >
            <span class="flex items-center justify-between gap-3"
              ><span class="font-semibold text-n-slate-12">{{
                answer.title
              }}</span
              ><span
                class="rounded-md px-2 py-1 text-xs font-medium"
                :class="
                  answer.status === 'approved'
                    ? 'bg-n-teal-3 text-n-teal-11'
                    : answer.status === 'rejected'
                      ? 'bg-n-ruby-3 text-n-ruby-11'
                      : 'bg-n-blue-3 text-n-blue-11'
                "
                >{{ statusLabel(answer.status) }}</span
              ></span
            >
            <span class="mt-2 block text-sm text-n-slate-11"
              >{{ answerKindLabel(answer.source_kind) }} ·
              {{ answer.question }}</span
            >
            <span
              v-if="answer.conflict_count"
              class="mt-2 inline-flex rounded-md bg-n-amber-3 px-2 py-1 text-xs font-medium text-n-amber-12"
              >Conflict warning</span
            >
          </button>
        </div>
      </section>
      <aside class="p-6">
        <template v-if="selectedAnswer">
          <h2 class="text-base font-semibold text-n-slate-12">
            {{ selectedAnswer.title }}
          </h2>
          <p class="mt-2 text-sm text-n-slate-11">
            {{ answerKindLabel(selectedAnswer.source_kind) }}
          </p>
          <p class="mt-5 text-sm font-semibold text-n-slate-12">Question</p>
          <p class="mt-2 text-sm leading-6 text-n-slate-11">
            {{ selectedAnswer.question }}
          </p>
          <p class="mt-5 text-sm font-semibold text-n-slate-12">
            Approved answer
          </p>
          <p class="mt-2 whitespace-pre-line text-sm leading-6 text-n-slate-11">
            {{ selectedAnswer.answer }}
          </p>
          <p
            v-if="selectedAnswer.conflict_count"
            class="mt-5 rounded-lg border border-n-amber-5 bg-n-amber-2 p-3 text-sm text-n-amber-12"
          >
            Conflicting approved answers exist. The AI Employee sends matching
            questions to Review.
          </p>
          <div class="mt-6 flex flex-wrap gap-2">
            <button
              type="button"
              class="h-9 rounded-lg bg-n-brand px-3 text-sm font-medium text-white"
              @click="applyAnswerLifecycle(selectedAnswer, 'approve')"
            >
              Approve
            </button>
            <button
              type="button"
              class="h-9 rounded-lg border border-n-weak px-3 text-sm font-medium"
              @click="applyAnswerLifecycle(selectedAnswer, 'reject')"
            >
              Reject
            </button>
            <button
              type="button"
              class="h-9 rounded-lg border border-n-weak px-3 text-sm font-medium"
              @click="applyAnswerLifecycle(selectedAnswer, 'deactivate')"
            >
              Archive
            </button>
          </div>
          <div class="mt-6 border-t border-n-weak pt-5 text-sm text-n-slate-11">
            Version history: created
            {{ relativeDate(selectedAnswer.created_at) }}, updated
            {{ relativeDate(selectedAnswer.updated_at) }}.
          </div>
        </template>
      </aside>
    </div>

    <div
      v-else
      class="grid min-h-[calc(100vh-15rem)] lg:grid-cols-[minmax(420px,1fr)_420px]"
    >
      <section class="border-r border-n-weak p-4">
        <select
          v-model="reviewFilter"
          class="h-10 rounded-lg border border-n-weak bg-n-background px-3 text-sm"
          aria-label="Filter Review Requests"
        >
          <option value="all">All Review Requests</option>
          <option value="no_approved_knowledge">No approved answer</option>
          <option value="conflicting_knowledge">Conflicts</option>
          <option value="sensitive_question">Sensitive</option>
        </select>
        <div
          v-if="!filteredReviews.length"
          class="mt-4 rounded-lg border border-dashed border-n-weak p-6 text-sm text-n-slate-11"
        >
          No Review Requests need attention.
        </div>
        <button
          v-for="request in filteredReviews"
          :key="request.id"
          type="button"
          class="mt-3 block w-full rounded-lg border border-n-weak p-4 text-left hover:bg-n-slate-2 focus-visible:ring-2 focus-visible:ring-n-brand"
          @click="selectedReviewId = request.id"
        >
          <span class="flex items-center justify-between gap-3"
            ><span class="font-semibold text-n-slate-12">{{
              request.question
            }}</span
            ><span
              class="rounded-md bg-n-amber-3 px-2 py-1 text-xs font-medium text-n-amber-12"
              >{{ reasonLabel(request.reason) }}</span
            ></span
          >
          <span class="mt-2 block text-sm text-n-slate-11"
            >Conversation #{{ request.conversation_display_id }}</span
          >
        </button>
      </section>
      <aside class="p-6">
        <template v-if="selectedReview">
          <h2 class="text-base font-semibold text-n-slate-12">
            Review Request
          </h2>
          <p class="mt-2 text-sm leading-6 text-n-slate-11">
            {{ selectedReview.question }}
          </p>
          <a
            class="mt-4 inline-flex text-sm font-medium text-n-blue-text underline"
            :href="conversationPath(selectedReview)"
            >Open linked conversation</a
          >
          <form
            class="mt-6 grid gap-3"
            @submit.prevent="resolveReview(selectedReview)"
          >
            <textarea
              v-model="reviewForms[selectedReview.id].answer"
              required
              rows="5"
              aria-label="Review answer"
              class="rounded-lg border border-n-weak bg-n-background px-3 py-2 text-sm"
              placeholder="Answer for this lead or internal resolution note"
            />
            <label class="flex items-center gap-2 text-sm text-n-slate-12"
              ><input
                v-model="reviewForms[selectedReview.id].send_to_lead"
                type="checkbox"
              />
              Send answer to Lead</label
            >
            <label class="flex items-center gap-2 text-sm text-n-slate-12"
              ><input
                v-model="reviewForms[selectedReview.id].propose_knowledge"
                type="checkbox"
              />
              Propose as Approved Answer</label
            >
            <input
              v-model="reviewForms[selectedReview.id].title"
              aria-label="Review proposed Approved Answer title"
              class="h-10 rounded-lg border border-n-weak bg-n-background px-3 text-sm"
              placeholder="Approved Answer title"
            />
            <select
              v-model="reviewForms[selectedReview.id].source_kind"
              aria-label="Review proposed Approved Answer type"
              class="h-10 rounded-lg border border-n-weak bg-n-background px-3 text-sm"
            >
              <option v-for="kind in answerKinds" :key="kind" :value="kind">
                {{ answerKindLabel(kind) }}
              </option>
            </select>
            <div class="flex flex-wrap gap-2">
              <button
                type="submit"
                class="h-9 rounded-lg bg-n-brand px-3 text-sm font-medium text-white"
              >
                Resolve</button
              ><button
                type="button"
                class="h-9 rounded-lg border border-n-weak px-3 text-sm font-medium"
                @click="rejectReview(selectedReview)"
              >
                Reject
              </button>
            </div>
          </form>
        </template>
      </aside>
    </div>
  </section>
</template>

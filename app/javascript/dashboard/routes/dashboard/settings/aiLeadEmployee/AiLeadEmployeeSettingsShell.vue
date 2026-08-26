<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  section: {
    type: String,
    required: true,
  },
});

const { t } = useI18n();
const { accountScopedRoute } = useAccount();
const saveState = ref('unsaved');

const sections = computed(() => [
  {
    key: 'ai_provider',
    routeName: 'owned_ai_provider_settings',
    label: t('AI_LEAD_EMPLOYEE.SETTINGS.SECTIONS.AI_PROVIDER'),
    description: '',
    rows: [],
    icon: 'i-lucide-brain-circuit',
  },
  {
    key: 'offers_qualification',
    routeName: 'ai_lead_employee_settings_offers_qualification',
    label: t('AI_LEAD_EMPLOYEE.SETTINGS.SECTIONS.OFFERS_QUALIFICATION'),
    description: t(
      'AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.offers_qualification.DESCRIPTION'
    ),
    rows: [
      t('AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.offers_qualification.ROW_1'),
      t('AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.offers_qualification.ROW_2'),
      t('AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.offers_qualification.ROW_3'),
    ],
    icon: 'i-lucide-tag',
  },
  {
    key: 'booking_business_hours',
    routeName: 'ai_lead_employee_settings_booking_business_hours',
    label: t('AI_LEAD_EMPLOYEE.SETTINGS.SECTIONS.BOOKING_BUSINESS_HOURS'),
    description: t(
      'AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.booking_business_hours.DESCRIPTION'
    ),
    rows: [
      t('AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.booking_business_hours.ROW_1'),
      t('AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.booking_business_hours.ROW_2'),
      t('AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.booking_business_hours.ROW_3'),
    ],
    icon: 'i-lucide-calendar-days',
  },
  {
    key: 'team_assignment',
    routeName: 'ai_lead_employee_settings_team_assignment',
    label: t('AI_LEAD_EMPLOYEE.SETTINGS.SECTIONS.TEAM_ASSIGNMENT'),
    description: t(
      'AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.team_assignment.DESCRIPTION'
    ),
    rows: [
      t('AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.team_assignment.ROW_1'),
      t('AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.team_assignment.ROW_2'),
      t('AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.team_assignment.ROW_3'),
    ],
    icon: 'i-lucide-users',
  },
  {
    key: 'follow_ups',
    routeName: 'ai_lead_employee_settings_follow_ups',
    label: t('AI_LEAD_EMPLOYEE.SETTINGS.SECTIONS.FOLLOW_UPS'),
    description: t(
      'AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.follow_ups.DESCRIPTION'
    ),
    rows: [
      t('AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.follow_ups.ROW_1'),
      t('AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.follow_ups.ROW_2'),
      t('AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.follow_ups.ROW_3'),
    ],
    icon: 'i-lucide-message-circle',
  },
  {
    key: 'alerts',
    routeName: 'ai_lead_employee_settings_alerts',
    label: t('AI_LEAD_EMPLOYEE.SETTINGS.SECTIONS.ALERTS'),
    description: t('AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.alerts.DESCRIPTION'),
    rows: [
      t('AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.alerts.ROW_1'),
      t('AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.alerts.ROW_2'),
      t('AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.alerts.ROW_3'),
    ],
    icon: 'i-lucide-bell',
  },
  {
    key: 'whatsapp_connection',
    routeName: 'ai_lead_employee_settings_whatsapp_connection',
    label: t('AI_LEAD_EMPLOYEE.SETTINGS.SECTIONS.WHATSAPP_CONNECTION'),
    description: t(
      'AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.whatsapp_connection.DESCRIPTION'
    ),
    rows: [
      t('AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.whatsapp_connection.ROW_1'),
      t('AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.whatsapp_connection.ROW_2'),
      t('AI_LEAD_EMPLOYEE.SETTINGS.PLACEHOLDER.whatsapp_connection.ROW_3'),
    ],
    icon: 'i-lucide-phone',
  },
]);

const activeSection = computed(
  () =>
    sections.value.find(section => section.key === props.section) ||
    sections.value[0]
);

const detailRows = computed(() => activeSection.value.rows);

const saveChanges = () => {
  saveState.value = 'saved';
  window.setTimeout(() => {
    saveState.value = 'unsaved';
  }, 1500);
};
</script>

<template>
  <main class="flex h-full min-w-0 flex-1 bg-n-background">
    <aside
      class="hidden w-64 shrink-0 border-r border-n-weak bg-n-solid-1 p-4 md:block"
      :aria-label="t('AI_LEAD_EMPLOYEE.SETTINGS.SECTION_NAV')"
    >
      <nav class="grid gap-1">
        <RouterLink
          v-for="item in sections"
          :key="item.key"
          :to="accountScopedRoute(item.routeName)"
          class="flex h-10 min-w-0 items-center gap-2 rounded-lg px-3 text-sm font-medium focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
          :class="
            item.key === activeSection.key
              ? 'bg-n-blue-2 text-n-blue-11'
              : 'text-n-slate-12 hover:bg-n-alpha-2'
          "
          :aria-current="item.key === activeSection.key ? 'page' : undefined"
        >
          <Icon :icon="item.icon" class="size-4 shrink-0" />
          <span class="truncate">{{ item.label }}</span>
        </RouterLink>
      </nav>
    </aside>

    <section class="flex min-w-0 flex-1 flex-col">
      <header
        class="flex min-h-16 items-center justify-between gap-3 border-b border-n-weak bg-n-solid-1 px-4 md:px-6"
      >
        <div class="min-w-0">
          <h1 class="truncate text-xl font-semibold text-n-slate-12">
            {{ t('AI_LEAD_EMPLOYEE.SETTINGS.TITLE') }}
          </h1>
          <p class="truncate text-sm text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.SETTINGS.DESCRIPTION') }}
          </p>
        </div>
        <div class="flex shrink-0 items-center gap-3">
          <span
            class="hidden items-center gap-1 text-xs text-n-slate-11 sm:inline-flex"
          >
            <span
              class="size-1.5 rounded-full"
              :class="saveState === 'saved' ? 'bg-n-teal-9' : 'bg-n-amber-9'"
            />
            {{
              saveState === 'saved'
                ? t('AI_LEAD_EMPLOYEE.SETTINGS.SAVED')
                : t('AI_LEAD_EMPLOYEE.SETTINGS.UNSAVED')
            }}
          </span>
          <button
            type="button"
            class="h-9 rounded-lg bg-n-brand px-4 text-sm font-medium text-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
            @click="saveChanges"
          >
            {{ t('AI_LEAD_EMPLOYEE.SETTINGS.SAVE') }}
          </button>
        </div>
      </header>

      <div class="grid min-h-0 flex-1 overflow-auto lg:grid-cols-[1fr_22rem]">
        <article class="min-w-0 p-4 md:p-6">
          <div class="mb-4 md:hidden">
            <label
              class="mb-1 block text-xs font-medium uppercase text-n-slate-11"
              for="ai-lead-settings-section"
            >
              {{ t('AI_LEAD_EMPLOYEE.SETTINGS.SECTION_NAV') }}
            </label>
            <select
              id="ai-lead-settings-section"
              class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
              :value="activeSection.routeName"
              @change="$router.push(accountScopedRoute($event.target.value))"
            >
              <option
                v-for="item in sections"
                :key="item.key"
                :value="item.routeName"
              >
                {{ item.label }}
              </option>
            </select>
          </div>

          <div class="max-w-4xl">
            <h2 class="text-lg font-semibold text-n-slate-12">
              {{ activeSection.label }}
            </h2>
            <p class="mt-1 text-sm text-n-slate-11">
              {{ activeSection.description }}
            </p>
            <section
              class="mt-5 rounded-lg border border-n-weak bg-n-solid-1 p-4"
            >
              <div
                v-for="row in detailRows"
                :key="row"
                class="flex min-h-11 items-center justify-between gap-3 border-b border-n-weak py-2 text-sm last:border-b-0"
              >
                <span class="min-w-0 truncate text-n-slate-12">{{ row }}</span>
                <button
                  type="button"
                  class="rounded-lg border border-n-weak px-3 py-1.5 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
                >
                  {{ t('AI_LEAD_EMPLOYEE.SETTINGS.CONFIGURE') }}
                </button>
              </div>
            </section>
          </div>
        </article>

        <aside
          class="border-t border-n-weak bg-n-solid-1 p-4 lg:border-l lg:border-t-0 md:p-6"
        >
          <h2 class="text-base font-semibold text-n-slate-12">
            {{ t('AI_LEAD_EMPLOYEE.SETTINGS.PREVIEW_TITLE') }}
          </h2>
          <p class="mt-2 text-sm text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.SETTINGS.PREVIEW_DESCRIPTION') }}
          </p>
          <div class="mt-4 rounded-lg border border-n-weak bg-n-background p-4">
            <p class="text-sm font-medium text-n-slate-12">
              {{ t('AI_LEAD_EMPLOYEE.SETTINGS.SAMPLE_LEAD') }}
            </p>
            <p class="mt-3 text-4xl font-semibold text-n-teal-11">
              {{ t('AI_LEAD_EMPLOYEE.SETTINGS.SAMPLE_SCORE') }}
            </p>
            <p class="mt-1 text-sm text-n-slate-11">
              {{ t('AI_LEAD_EMPLOYEE.SETTINGS.SAMPLE_RESULT') }}
            </p>
          </div>
        </aside>
      </div>
    </section>
  </main>
</template>

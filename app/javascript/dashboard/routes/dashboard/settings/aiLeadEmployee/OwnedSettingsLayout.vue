<script setup>
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { accountScopedRoute } = useAccount();
const sections = [
  {
    key: 'business',
    route: 'ai_lead_employee_settings_offers_qualification',
    matches: ['offers_qualification', 'general_settings'],
    children: ['general_settings_index'],
  },
  {
    key: 'team',
    route: 'agent_list',
    matches: [
      'agent_list',
      'settings_teams',
      'team_assignment',
      'settings_alerts',
    ],
    children: ['settings_teams_list', 'ai_lead_employee_settings_alerts'],
  },
  {
    key: 'booking',
    route: 'ai_lead_employee_settings_booking_business_hours',
    matches: ['booking_business_hours'],
  },
  {
    key: 'followups',
    route: 'ai_lead_employee_settings_follow_ups',
    matches: ['follow_ups'],
  },
  {
    key: 'whatsapp',
    route: 'settings_inbox_list',
    matches: ['settings_inbox', 'whatsapp_connection'],
  },
  {
    key: 'ai',
    route: 'ai_lead_employee_settings_ai_testing',
    matches: ['ai_testing', 'ai_provider', 'test_center'],
    children: ['owned_ai_provider_settings', 'owned_test_center_index'],
  },
];
const active = computed(
  () =>
    sections.find(section =>
      section.matches.some(name => String(route.name).includes(name))
    ) || sections[0]
);
const selectSection = key =>
  router.push(
    accountScopedRoute(sections.find(section => section.key === key).route)
  );
</script>

<template>
  <div class="flex min-h-0 min-w-0 flex-1 flex-col bg-n-background lg:flex-row">
    <aside
      class="hidden w-56 shrink-0 overflow-y-auto border-r border-n-weak p-4 lg:block"
    >
      <h1 class="mb-4 text-xl font-semibold">
        {{ t('AI_LEAD_EMPLOYEE.NAV.SETTINGS') }}
      </h1>
      <nav
        class="grid gap-1"
        :aria-label="t('AI_LEAD_EMPLOYEE.SETTINGS_NAV.LABEL')"
      >
        <RouterLink
          v-for="section in sections"
          :key="section.key"
          :to="accountScopedRoute(section.route)"
          class="flex min-h-11 items-center rounded-lg px-3 py-2 text-sm font-medium hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
          :class="
            active.key === section.key
              ? 'bg-n-blue-2 text-n-blue-11'
              : 'text-n-slate-12'
          "
          :aria-current="active.key === section.key ? 'page' : undefined"
        >
          {{ t(`AI_LEAD_EMPLOYEE.SETTINGS_NAV.${section.key}`) }}
        </RouterLink>
      </nav>
    </aside>
    <div class="flex min-h-0 min-w-0 flex-1 flex-col">
      <div class="shrink-0 border-b border-n-weak px-4 py-3 lg:hidden">
        <label for="settings-section" class="mb-1 block text-sm font-medium">{{
          t('AI_LEAD_EMPLOYEE.SETTINGS_NAV.LABEL')
        }}</label>
        <select
          id="settings-section"
          :value="active.key"
          class="h-11 w-full rounded-lg border border-n-weak bg-n-background px-3 text-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
          @change="selectSection($event.target.value)"
        >
          <option
            v-for="section in sections"
            :key="section.key"
            :value="section.key"
          >
            {{ t(`AI_LEAD_EMPLOYEE.SETTINGS_NAV.${section.key}`) }}
          </option>
        </select>
      </div>
      <nav
        v-if="active.children"
        class="flex shrink-0 flex-wrap gap-2 border-b border-n-weak px-4 py-2"
        :aria-label="t('AI_LEAD_EMPLOYEE.SETTINGS_NAV.RELATED')"
      >
        <RouterLink
          v-for="name in [active.route, ...active.children]"
          :key="name"
          :to="accountScopedRoute(name)"
          class="inline-flex min-h-10 items-center rounded-lg px-3 text-sm hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
          :class="
            route.name === name
              ? 'bg-n-blue-2 text-n-blue-11'
              : 'text-n-slate-11'
          "
          :aria-current="route.name === name ? 'page' : undefined"
        >
          {{ t(`AI_LEAD_EMPLOYEE.SETTINGS_NAV.${name}`) }}
        </RouterLink>
      </nav>
      <div class="flex min-h-0 min-w-0 flex-1 overflow-auto"><slot /></div>
    </div>
  </div>
</template>

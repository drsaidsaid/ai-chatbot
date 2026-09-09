<script setup>
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
const { t } = useI18n();
const { accountScopedRoute } = useAccount();
</script>

<template>
  <section class="w-full p-4 sm:p-6">
    <h1 class="text-2xl font-semibold">
      {{ t('AI_LEAD_EMPLOYEE.SETTINGS_NAV.ai') }}
    </h1>
    <p class="mt-2 max-w-2xl text-sm text-n-slate-11">
      {{ t('AI_LEAD_EMPLOYEE.SETTINGS_NAV.AI_DESCRIPTION') }}
    </p>
    <div class="mt-6 grid max-w-3xl gap-4 md:grid-cols-2">
      <RouterLink
        v-for="name in [
          'owned_ai_provider_settings',
          'owned_test_center_index',
        ]"
        :key="name"
        :to="accountScopedRoute(name)"
        class="rounded-xl border border-n-weak p-5 text-base font-medium hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
      >
        {{ t(`AI_LEAD_EMPLOYEE.SETTINGS_NAV.${name}`) }}
      </RouterLink>
    </div>
  </section>
</template>

<script setup>
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
const { t } = useI18n();
const { accountScopedRoute } = useAccount();
</script>

<template>
  <section class="p-6">
    <h1 class="text-2xl font-semibold">
      {{ t('AI_LEAD_EMPLOYEE.UNAVAILABLE.TITLE') }}
    </h1>
    <p class="mt-3 text-sm text-n-slate-11">
      {{ t('AI_LEAD_EMPLOYEE.UNAVAILABLE.DESCRIPTION') }}
    </p>
    <RouterLink
      :to="accountScopedRoute('home')"
      class="mt-6 inline-flex min-h-11 items-center rounded-lg border border-n-weak px-4 text-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
    >
      {{ t('AI_LEAD_EMPLOYEE.NAV.INBOX') }}
    </RouterLink>
  </section>
</template>

<script setup>
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import Avatar from 'next/avatar/Avatar.vue';
import Icon from 'next/icon/Icon.vue';
import Policy from 'dashboard/components/policy.vue';
import {
  buildAILeadEmployeeMobileNavItems,
  buildAILeadEmployeeMoreNavItems,
} from './aiLeadEmployeeNavigation';
import ConversationCockpitQueueChips from './ConversationCockpitQueueChips.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { accountScopedRoute } = useAccount();
const currentUser = useMapGetter('getCurrentUser');
const currentUserAvailability = useMapGetter('getCurrentUserAvailability');

const isMoreOpen = ref(false);
const mobileItems = computed(() =>
  buildAILeadEmployeeMobileNavItems({ t, accountScopedRoute })
);
const moreItems = computed(() =>
  buildAILeadEmployeeMoreNavItems({ t, accountScopedRoute })
);

const isInboxRoute = computed(() =>
  [
    'home',
    'inbox_conversation',
    'inbox_dashboard',
    'conversation_through_inbox',
    'inbox_view',
    'inbox_view_conversation',
  ].includes(route.name)
);

const resolveMeta = item => router.resolve(item.to)?.meta || {};

const isItemActive = item => {
  const resolvedPath = router.resolve(item.to)?.path;
  return (
    item.activeOn?.includes(route.name) ||
    route.path === resolvedPath ||
    route.path.startsWith(`${resolvedPath}/`)
  );
};

const isMoreActive = computed(() =>
  moreItems.value.some(item => isItemActive(item))
);

watch(
  () => route.fullPath,
  () => {
    isMoreOpen.value = false;
  }
);
</script>

<template>
  <div class="lg:hidden">
    <header
      class="fixed inset-x-0 top-0 z-40 border-b border-n-weak bg-n-background/95 backdrop-blur"
    >
      <div class="flex h-16 items-center gap-3 px-4">
        <RouterLink
          :to="accountScopedRoute('home')"
          class="grid size-10 shrink-0 place-items-center rounded-xl bg-n-brand text-base font-semibold text-white shadow-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
          :aria-label="t('AI_LEAD_EMPLOYEE.PRODUCT_NAME')"
        >
          {{ t('AI_LEAD_EMPLOYEE.MARK') }}
        </RouterLink>
        <RouterLink
          :to="accountScopedRoute('home')"
          class="min-w-0 flex-1 truncate text-base font-semibold text-n-slate-12"
        >
          {{ t('AI_LEAD_EMPLOYEE.PRODUCT_NAME') }}
        </RouterLink>
        <RouterLink
          :to="{ name: 'search' }"
          class="grid size-10 place-items-center rounded-lg text-n-slate-12 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
          :aria-label="t('COMBOBOX.SEARCH_PLACEHOLDER')"
        >
          <Icon icon="i-lucide-search" class="size-5" />
        </RouterLink>
        <RouterLink
          :to="accountScopedRoute('inbox_view')"
          class="relative grid size-10 place-items-center rounded-lg text-n-slate-12 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
          :aria-label="t('AI_LEAD_EMPLOYEE.NAV.NOTIFICATIONS')"
        >
          <Icon icon="i-lucide-bell" class="size-5" />
          <span
            class="absolute end-2 top-2 size-2.5 rounded-full bg-n-ruby-9 ring-2 ring-n-background"
          />
        </RouterLink>
        <Avatar
          :size="40"
          :name="currentUser.available_name"
          :src="currentUser.avatar_url"
          :status="currentUserAvailability"
          class="shrink-0"
        />
      </div>
      <ConversationCockpitQueueChips v-if="isInboxRoute" mobile />
    </header>

    <div
      v-if="isMoreOpen"
      class="fixed inset-0 z-40 bg-n-slate-12/20"
      @click="isMoreOpen = false"
    />
    <section
      v-if="isMoreOpen"
      class="fixed inset-x-4 bottom-24 z-50 rounded-lg border border-n-weak bg-n-solid-1 p-2 shadow-lg"
      :aria-label="t('AI_LEAD_EMPLOYEE.NAV.MORE')"
    >
      <Policy
        v-for="item in moreItems"
        :key="item.name"
        :permissions="resolveMeta(item).permissions"
        :feature-flag="resolveMeta(item).featureFlag"
        as="div"
      >
        <RouterLink
          :to="item.to"
          class="flex h-12 items-center gap-3 rounded-lg px-3 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
        >
          <Icon :icon="item.icon" class="size-5 shrink-0 text-n-slate-11" />
          <span class="min-w-0 flex-1 truncate">{{ item.label }}</span>
          <Icon icon="i-lucide-chevron-right" class="size-4 text-n-slate-10" />
        </RouterLink>
      </Policy>
    </section>

    <nav
      class="fixed inset-x-0 bottom-0 z-50 border-t border-n-weak bg-n-background/95 backdrop-blur"
      :aria-label="t('AI_LEAD_EMPLOYEE.NAV.MOBILE_PRIMARY')"
    >
      <ul class="m-0 grid h-20 grid-cols-4 list-none">
        <Policy
          v-for="item in mobileItems"
          :key="item.name"
          :permissions="resolveMeta(item).permissions"
          :feature-flag="resolveMeta(item).featureFlag"
          as="li"
        >
          <RouterLink
            :to="item.to"
            class="flex h-full flex-col items-center justify-center gap-1 px-1 text-xs font-medium focus-visible:outline focus-visible:outline-2 focus-visible:outline-inset focus-visible:outline-n-brand"
            :class="
              isItemActive(item)
                ? 'text-n-blue-11'
                : 'text-n-slate-11 hover:text-n-slate-12'
            "
            :aria-current="isItemActive(item) ? 'page' : undefined"
          >
            <Icon :icon="item.icon" class="size-6" />
            <span class="truncate">{{ item.label }}</span>
          </RouterLink>
        </Policy>
        <li>
          <button
            type="button"
            class="flex h-full w-full flex-col items-center justify-center gap-1 px-1 text-xs font-medium focus-visible:outline focus-visible:outline-2 focus-visible:outline-inset focus-visible:outline-n-brand"
            :class="
              isMoreOpen || isMoreActive
                ? 'text-n-blue-11'
                : 'text-n-slate-11 hover:text-n-slate-12'
            "
            :aria-expanded="String(isMoreOpen)"
            :aria-label="t('AI_LEAD_EMPLOYEE.NAV.MORE')"
            @click="isMoreOpen = !isMoreOpen"
          >
            <Icon icon="i-lucide-menu" class="size-6" />
            <span>{{ t('AI_LEAD_EMPLOYEE.NAV.MORE') }}</span>
          </button>
        </li>
      </ul>
    </nav>
  </div>
</template>

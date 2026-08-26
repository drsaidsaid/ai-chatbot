<script setup>
import { ref, computed, onMounted } from 'vue';
import { useSidebarResize } from './provider';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useSidebarKeyboardShortcuts } from './useSidebarKeyboardShortcuts';
import { useWindowSize, useEventListener } from '@vueuse/core';
import { useRoute, useRouter } from 'vue-router';

import Icon from 'next/icon/Icon.vue';
import Policy from 'dashboard/components/policy.vue';
import SidebarProfileMenu from './SidebarProfileMenu.vue';
import { buildAILeadEmployeeMenuItems } from './aiLeadEmployeeNavigation';

defineProps({
  isMobileSidebarOpen: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['closeKeyShortcutModal', 'openKeyShortcutModal']);

const { accountScopedRoute } = useAccount();
const store = useStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const isRTL = useMapGetter('accounts/isRTL');

const { width: windowWidth } = useWindowSize();
const isMobile = computed(() => windowWidth.value < 1024);

const toggleShortcutModalFn = show => {
  if (show) {
    emit('openKeyShortcutModal');
  } else {
    emit('closeKeyShortcutModal');
  }
};

useSidebarKeyboardShortcuts(toggleShortcutModalFn);

const {
  sidebarWidth,
  isCollapsed,
  setSidebarWidth,
  saveWidth,
  snapToCollapsed,
  snapToExpanded,
  COLLAPSED_THRESHOLD,
} = useSidebarResize();

// On mobile, sidebar is always expanded (flyout mode)
const isEffectivelyCollapsed = computed(
  () => !isMobile.value && isCollapsed.value
);

// Resize handle logic
const isResizing = ref(false);
const startX = ref(0);
const startWidth = ref(0);

// Get clientX from mouse or touch event
const getClientX = event =>
  event.touches ? event.touches[0].clientX : event.clientX;

const onResizeStart = event => {
  isResizing.value = true;
  startX.value = getClientX(event);
  startWidth.value = sidebarWidth.value;
  Object.assign(document.body.style, {
    cursor: 'col-resize',
    userSelect: 'none',
  });
  // Prevent default to avoid scrolling on touch
  event.preventDefault();
};

const onResizeMove = event => {
  if (!isResizing.value) return;

  const delta = isRTL.value
    ? startX.value - getClientX(event)
    : getClientX(event) - startX.value;
  setSidebarWidth(startWidth.value + delta);
};

const onResizeEnd = () => {
  if (!isResizing.value) return;

  isResizing.value = false;
  Object.assign(document.body.style, { cursor: '', userSelect: '' });

  // Snap to collapsed state if below threshold
  if (sidebarWidth.value < COLLAPSED_THRESHOLD) {
    snapToCollapsed();
  } else {
    saveWidth();
  }
};

const onResizeHandleDoubleClick = () => {
  if (isCollapsed.value) snapToExpanded();
  else snapToCollapsed();
};

// Support both mouse and touch events
useEventListener(document, 'mousemove', onResizeMove);
useEventListener(document, 'mouseup', onResizeEnd);
useEventListener(document, 'touchmove', onResizeMove, { passive: false });
useEventListener(document, 'touchend', onResizeEnd);

onMounted(() => {
  store.dispatch('notifications/unReadCount');
});

const menuItems = computed(() =>
  buildAILeadEmployeeMenuItems({
    t,
    accountScopedRoute,
    isAdmin: store.getters.getCurrentRole === 'administrator',
  })
);

const resolvedMeta = item => router.resolve(item.to)?.meta || {};

const isItemActive = item => {
  const resolved = router.resolve(item.to);
  return (
    route.path === resolved.path ||
    route.path.startsWith(`${resolved.path}/`) ||
    item.activeOn?.includes(route.name)
  );
};
</script>

<template>
  <aside
    class="hidden bg-n-background lg:flex flex-col text-sm pb-px fixed top-0 ltr:left-0 rtl:right-0 h-full z-40 lg:w-auto lg:relative lg:flex-shrink-0 lg:ltr:translate-x-0 lg:rtl:translate-x-0 ltr:border-r rtl:border-l border-n-weak"
    :class="[
      {
        'shadow-lg lg:shadow-none': isMobileSidebarOpen,
        'ltr:-translate-x-full rtl:translate-x-full': !isMobileSidebarOpen,
        'transition-transform duration-200 ease-out lg:transition-[width]':
          !isResizing,
      },
    ]"
    :style="isMobile ? undefined : { width: `${sidebarWidth}px` }"
  >
    <section class="flex justify-center px-3 pt-5 pb-6">
      <RouterLink
        :to="accountScopedRoute('home')"
        class="grid place-items-center size-9 rounded-lg bg-n-brand text-sm font-semibold text-white shadow-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
        :aria-label="t('AI_LEAD_EMPLOYEE.PRODUCT_NAME')"
      >
        {{ t('AI_LEAD_EMPLOYEE.MARK') }}
      </RouterLink>
    </section>
    <nav
      class="flex flex-col items-center gap-2 overflow-y-auto flex-grow px-2 pb-5 no-scrollbar min-w-0"
      :aria-label="t('AI_LEAD_EMPLOYEE.NAV.PRIMARY')"
    >
      <ul class="flex w-full flex-col items-center gap-2 m-0 list-none min-w-0">
        <Policy
          v-for="item in menuItems"
          :key="item.name"
          :permissions="resolvedMeta(item).permissions"
          :feature-flag="resolvedMeta(item).featureFlag"
          as="li"
          class="w-full min-w-0"
        >
          <RouterLink
            :to="item.to"
            class="group flex min-h-14 w-full items-center justify-center rounded-lg px-1.5 py-2 text-center transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
            :class="[
              isEffectivelyCollapsed ? 'min-h-10' : 'flex-col gap-1',
              isItemActive(item)
                ? 'bg-n-blue-2 text-n-blue-11'
                : 'text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12',
            ]"
            :aria-current="isItemActive(item) ? 'page' : undefined"
            :title="item.label"
          >
            <Icon :icon="item.icon" class="size-5 shrink-0" />
            <span
              v-if="!isEffectivelyCollapsed"
              class="max-w-full truncate text-xs font-medium leading-4"
            >
              {{ item.label }}
            </span>
          </RouterLink>
        </Policy>
      </ul>
    </nav>
    <section
      class="flex relative flex-col flex-shrink-0 gap-1 justify-between items-center"
    >
      <div
        class="px-2 py-3 flex-shrink-0 flex w-full z-50 gap-2 items-center border-t border-n-weak shadow-[0px_-2px_4px_0px_rgba(27,28,29,0.02)]"
        :class="isEffectivelyCollapsed ? 'justify-center' : 'justify-between'"
      >
        <SidebarProfileMenu
          :is-collapsed="isEffectivelyCollapsed"
          @open-key-shortcut-modal="emit('openKeyShortcutModal')"
        />
      </div>
    </section>
    <!-- Resize Handle (desktop only) -->
    <div
      class="hidden lg:block absolute top-0 h-full w-1 cursor-col-resize z-40 ltr:right-0 rtl:left-0 group"
      @mousedown="onResizeStart"
      @touchstart="onResizeStart"
      @dblclick="onResizeHandleDoubleClick"
    >
      <div
        class="absolute top-0 h-full w-px ltr:right-0 rtl:left-0 bg-transparent group-hover:bg-n-brand transition-colors"
        :class="{ 'bg-n-brand': isResizing }"
      />
    </div>
  </aside>
</template>

import { flushPromises, mount } from '@vue/test-utils';
import { createMemoryHistory, createRouter } from 'vue-router';
import { ref } from 'vue';
import ConversationCockpitMobileShell from '../ConversationCockpitMobileShell.vue';

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    accountScopedRoute: (name, params = {}, query = {}) => ({
      name,
      params: { accountId: 1, ...params },
      query,
    }),
  }),
}));

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: key => {
    if (key === 'getCurrentUser') {
      return ref({
        available_name: 'John',
        avatar_url: '',
      });
    }
    return ref('online');
  },
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => {
      const labels = {
        'AI_LEAD_EMPLOYEE.MARK': 'AI',
        'AI_LEAD_EMPLOYEE.PRODUCT_NAME': 'AI Lead Employee',
        'AI_LEAD_EMPLOYEE.NAV.INBOX': 'Inbox',
        'AI_LEAD_EMPLOYEE.NAV.LEADS': 'Leads',
        'AI_LEAD_EMPLOYEE.NAV.BOOKINGS': 'Bookings',
        'AI_LEAD_EMPLOYEE.NAV.KNOWLEDGE': 'Knowledge',
        'AI_LEAD_EMPLOYEE.NAV.TEST_CENTER': 'Test Center',
        'AI_LEAD_EMPLOYEE.NAV.SETTINGS': 'Settings',
        'AI_LEAD_EMPLOYEE.NAV.MORE': 'More',
        'AI_LEAD_EMPLOYEE.NAV.NOTIFICATIONS': 'Notifications',
        'AI_LEAD_EMPLOYEE.NAV.MOBILE_PRIMARY': 'Mobile navigation',
        'COMBOBOX.SEARCH_PLACEHOLDER': 'Search',
      };
      return labels[key] || key;
    },
  }),
}));

const PolicyStub = {
  template: '<div><slot /></div>',
  props: ['as'],
};

const AvatarStub = {
  template: '<span class="avatar-stub" />',
};

const IconStub = {
  template: '<span class="icon-stub" />',
};

const QueueChipsStub = {
  template: '<div class="queue-chip-stub" />',
};

const routes = [
  { path: '/accounts/:accountId/dashboard', name: 'home', component: {} },
  {
    path: '/accounts/:accountId/leads',
    name: 'owned_leads_index',
    component: {},
  },
  {
    path: '/accounts/:accountId/bookings',
    name: 'owned_bookings_index',
    component: {},
  },
  {
    path: '/accounts/:accountId/knowledge',
    name: 'owned_knowledge_index',
    component: {},
  },
  {
    path: '/accounts/:accountId/test-center',
    name: 'owned_test_center_index',
    component: {},
  },
  {
    path: '/accounts/:accountId/settings/ai-lead-employee/offers-qualification',
    name: 'ai_lead_employee_settings_offers_qualification',
    component: {},
  },
  { path: '/search', name: 'search', component: {} },
  {
    path: '/accounts/:accountId/inbox-view',
    name: 'inbox_view',
    component: {},
  },
];

const mountShell = async routeName => {
  const router = createRouter({
    history: createMemoryHistory(),
    routes,
  });
  await router.push({ name: routeName, params: { accountId: 1 } });
  await router.isReady();

  const wrapper = mount(ConversationCockpitMobileShell, {
    global: {
      plugins: [router],
      stubs: {
        Avatar: AvatarStub,
        Icon: IconStub,
        Policy: PolicyStub,
        ConversationCockpitQueueChips: QueueChipsStub,
      },
    },
  });
  await flushPromises();
  return wrapper;
};

describe('ConversationCockpitMobileShell', () => {
  it('shows Inbox, Leads, Bookings, and More in the bottom navigation', async () => {
    const wrapper = await mountShell('home');

    expect(wrapper.text()).toContain('Inbox');
    expect(wrapper.text()).toContain('Leads');
    expect(wrapper.text()).toContain('Bookings');
    expect(wrapper.text()).toContain('More');
  });

  it('opens Knowledge, Test Center, and Settings from More', async () => {
    const wrapper = await mountShell('home');

    await wrapper.get('button[aria-label="More"]').trigger('click');

    expect(wrapper.text()).toContain('Knowledge');
    expect(wrapper.text()).toContain('Test Center');
    expect(wrapper.text()).toContain('Settings');
  });
});

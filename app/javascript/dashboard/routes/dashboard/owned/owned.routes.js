import { frontendURL } from 'dashboard/helper/URLHelper';
import OwnedWorkspacePage from './OwnedWorkspacePage.vue';
import AiProviderSettingsPage from './AiProviderSettingsPage.vue';
import { ROLES } from 'dashboard/constants/permissions.js';

const ownedSurfaceRoute = ({ path, name, surface }) => ({
  path: frontendURL(`accounts/:accountId/${path}`),
  name,
  component: OwnedWorkspacePage,
  props: { surface },
  meta: {
    permissions: ROLES,
  },
});

const redirectToInboxQueue = queue => to => ({
  name: 'home',
  params: to.params,
  query: { ...to.query, queue },
});

export const routes = [
  {
    path: frontendURL('accounts/:accountId/hot-leads'),
    name: 'owned_hot_leads_index',
    redirect: redirectToInboxQueue('hot'),
  },
  ownedSurfaceRoute({
    path: 'leads',
    name: 'owned_leads_index',
    surface: 'LEADS',
  }),
  {
    path: frontendURL('accounts/:accountId/reviews'),
    name: 'owned_reviews_index',
    redirect: redirectToInboxQueue('review'),
  },
  ownedSurfaceRoute({
    path: 'knowledge',
    name: 'owned_knowledge_index',
    surface: 'KNOWLEDGE',
  }),
  ownedSurfaceRoute({
    path: 'bookings',
    name: 'owned_bookings_index',
    surface: 'BOOKINGS',
  }),
  ownedSurfaceRoute({
    path: 'test-center',
    name: 'owned_test_center_index',
    surface: 'TEST_CENTER',
  }),
  {
    path: frontendURL('accounts/:accountId/settings/ai-provider'),
    name: 'owned_ai_provider_settings',
    component: AiProviderSettingsPage,
    meta: {
      permissions: ['administrator'],
    },
  },
];

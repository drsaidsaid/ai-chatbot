import { frontendURL } from 'dashboard/helper/URLHelper';
import OwnedWorkspacePage from './OwnedWorkspacePage.vue';
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

export const routes = [
  ownedSurfaceRoute({
    path: 'hot-leads',
    name: 'owned_hot_leads_index',
    surface: 'HOT_LEADS',
  }),
  ownedSurfaceRoute({
    path: 'leads',
    name: 'owned_leads_index',
    surface: 'LEADS',
  }),
  ownedSurfaceRoute({
    path: 'reviews',
    name: 'owned_reviews_index',
    surface: 'REVIEWS',
  }),
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
];

import { router, validateAuthenticateRoutePermission } from './index';
import store from '../store'; // This import will be mocked
import { vi } from 'vitest';

// Mock the store module
vi.mock('../store', () => ({
  default: {
    getters: {
      isLoggedIn: false,
      getCurrentUser: {
        account_id: null,
        id: null,
        accounts: [],
      },
      'accounts/getAccount': () => ({}),
    },
    dispatch: vi.fn(() => Promise.resolve()),
  },
}));

describe('#validateAuthenticateRoutePermission', () => {
  let next;

  beforeEach(() => {
    next = vi.fn(); // Mock the next function
  });

  describe('when user is not logged in', () => {
    it('should redirect to login', () => {
      const to = { name: 'some-protected-route', params: { accountId: 1 } };

      // Mock the store to simulate user not logged in
      store.getters.isLoggedIn = false;

      // Mock window.location.assign
      const mockAssign = vi.fn();
      delete window.location;
      window.location = { assign: mockAssign };

      validateAuthenticateRoutePermission(to, next);

      expect(mockAssign).toHaveBeenCalledWith('/app/login');
      expect(next).toHaveBeenCalledWith(false);
    });
  });

  describe('when user is logged in', () => {
    beforeEach(() => {
      // Mock the store's getter for a logged-in user
      store.getters.isLoggedIn = true;
      store.getters.getCurrentUser = {
        account_id: 1,
        id: 1,
        accounts: [
          {
            id: 1,
            role: 'agent',
            permissions: ['agent'],
            status: 'active',
          },
        ],
      };
    });

    describe('when route is not accessible to current user', () => {
      it('should redirect to dashboard', async () => {
        const to = {
          name: 'general_settings_index',
          params: { accountId: 1 },
          meta: { permissions: ['administrator'] },
        };

        await validateAuthenticateRoutePermission(to, next);

        expect(next).toHaveBeenCalledWith('/app/accounts/1/dashboard');
      });
    });

    describe('when route is accessible to current user', () => {
      beforeEach(() => {
        // Adjust store getters to reflect the user has admin permissions
        store.getters.getCurrentUser = {
          account_id: 1,
          id: 1,
          accounts: [
            {
              id: 1,
              role: 'administrator',
              permissions: ['administrator'],
              status: 'active',
            },
          ],
        };
      });

      it('should go to the intended route', async () => {
        const to = {
          name: 'general_settings_index',
          params: { accountId: 1 },
          meta: { permissions: ['administrator'] },
        };

        await validateAuthenticateRoutePermission(to, next);

        expect(next).toHaveBeenCalledWith();
      });
    });
  });
});

describe('V1 direct route availability', () => {
  beforeEach(() => {
    store.getters.isLoggedIn = true;
    store.getters.getCurrentUser = {
      account_id: 1,
      accounts: [{ id: 1, role: 'administrator', status: 'active' }],
    };
  });
  it('gates a retained generic Campaigns route for an administrator', async () => {
    const next = vi.fn();
    await validateAuthenticateRoutePermission(
      {
        name: 'campaigns_index',
        path: '/app/accounts/1/campaigns/ongoing',
        params: { accountId: 1 },
        meta: { permissions: ['administrator'] },
      },
      next
    );
    expect(next).toHaveBeenCalledWith({
      name: 'v1_unavailable',
      params: { accountId: 1 },
    });
  });
  it('gates a direct unsupported channel setup link', async () => {
    const next = vi.fn();
    await validateAuthenticateRoutePermission(
      {
        name: 'settings_inboxes_page_channel',
        path: '/app/accounts/1/settings/inboxes/new/email',
        params: { accountId: 1, sub_page: 'email' },
        meta: { permissions: ['administrator'] },
      },
      next
    );
    expect(next).toHaveBeenCalledWith({
      name: 'v1_unavailable',
      params: { accountId: 1 },
    });
  });
});

it('keeps the full Test Center under administrator Settings and redirects old links with their context', async () => {
  await router.push('/app/accounts/1/test-center?scenario=sensitive#report');
  expect(router.currentRoute.value.path).toBe(
    '/app/accounts/1/settings/ai-lead-employee/ai-testing/test-center'
  );
  expect(router.currentRoute.value.query).toEqual({ scenario: 'sensitive' });
  expect(router.currentRoute.value.hash).toBe('#report');
  expect(router.currentRoute.value.meta.permissions).toEqual(['administrator']);
  store.getters.getCurrentUser = {
    account_id: 1,
    accounts: [
      { id: 1, role: 'agent', permissions: ['agent'], status: 'active' },
    ],
  };
  const next = vi.fn();
  await validateAuthenticateRoutePermission(router.currentRoute.value, next);
  expect(next).toHaveBeenCalledWith('/app/accounts/1/dashboard');
});

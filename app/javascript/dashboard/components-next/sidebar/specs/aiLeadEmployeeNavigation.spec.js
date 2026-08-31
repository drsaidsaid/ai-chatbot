import {
  AI_LEAD_EMPLOYEE_TOP_LEVEL_NAVIGATION,
  buildAILeadEmployeeMenuItems,
} from '../aiLeadEmployeeNavigation';

describe('AI Lead Employee navigation', () => {
  const t = key => key;
  const accountScopedRoute = name => `/accounts/1/${name}`;
  const allowedTopLevelItems = [
    'Inbox',
    'Hot Leads',
    'Leads',
    'Reviews',
    'Knowledge',
    'Bookings',
    'Test Center',
    'Settings',
  ];

  it('exposes only the V1 top-level surfaces', () => {
    const menuItems = buildAILeadEmployeeMenuItems({ t, accountScopedRoute });

    expect(AI_LEAD_EMPLOYEE_TOP_LEVEL_NAVIGATION).toEqual(allowedTopLevelItems);
    expect(menuItems.map(item => item.name)).toEqual(allowedTopLevelItems);
  });

  it('routes owned workflow surfaces through account-scoped dashboard routes', () => {
    const menuItems = buildAILeadEmployeeMenuItems({ t, accountScopedRoute });

    expect(menuItems.slice(1, 7).map(item => item.to)).toEqual([
      '/accounts/1/owned_hot_leads_index',
      '/accounts/1/owned_leads_index',
      '/accounts/1/owned_reviews_index',
      '/accounts/1/owned_knowledge_index',
      '/accounts/1/owned_bookings_index',
      '/accounts/1/owned_test_center_index',
    ]);
  });

  it('keeps unrelated Community Edition surfaces out of top-level navigation', () => {
    const menuItems = buildAILeadEmployeeMenuItems({ t, accountScopedRoute });
    const topLevelItemNames = menuItems.map(item => item.name);

    ['Contacts', 'Reports', 'Campaigns', 'Help Center', 'Integrations'].forEach(
      forbiddenItem => {
        expect(topLevelItemNames).not.toContain(forbiddenItem);
      }
    );
  });

  it('shows AI provider settings only to administrators', () => {
    const adminMenu = buildAILeadEmployeeMenuItems({
      t,
      accountScopedRoute,
      isAdmin: true,
    });
    const agentMenu = buildAILeadEmployeeMenuItems({
      t,
      accountScopedRoute,
      isAdmin: false,
    });

    expect(adminMenu.at(-1).children.map(item => item.name)).toContain(
      'Settings AI Provider'
    );
    expect(agentMenu.at(-1).children.map(item => item.name)).not.toContain(
      'Settings AI Provider'
    );
  });
});

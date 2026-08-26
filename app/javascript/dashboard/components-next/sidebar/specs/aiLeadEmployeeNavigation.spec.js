import {
  AI_LEAD_EMPLOYEE_MOBILE_NAVIGATION,
  AI_LEAD_EMPLOYEE_MORE_NAVIGATION,
  AI_LEAD_EMPLOYEE_TOP_LEVEL_NAVIGATION,
  buildAILeadEmployeeMobileNavItems,
  buildAILeadEmployeeMoreNavItems,
  buildAILeadEmployeeMenuItems,
  conversationCockpitQueueFilters,
  conversationMatchesCockpitQueue,
  isConversationCockpitQueue,
  queueRouteQuery,
} from '../aiLeadEmployeeNavigation';

describe('AI Lead Employee navigation', () => {
  const t = key => key;
  const accountScopedRoute = name => `/accounts/1/${name}`;
  const allowedTopLevelItems = [
    'Inbox',
    'Leads',
    'Bookings',
    'Knowledge',
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

    expect(menuItems.map(item => item.to)).toEqual([
      '/accounts/1/home',
      '/accounts/1/owned_leads_index',
      '/accounts/1/owned_bookings_index',
      '/accounts/1/owned_knowledge_index',
      '/accounts/1/owned_test_center_index',
      '/accounts/1/ai_lead_employee_settings_offers_qualification',
    ]);
  });

  it('keeps Hot, Review, and Booked out of top-level navigation', () => {
    const menuItems = buildAILeadEmployeeMenuItems({ t, accountScopedRoute });
    const topLevelItemNames = menuItems.map(item => item.name);

    ['Hot Leads', 'Reviews', 'Booked'].forEach(forbiddenItem => {
      expect(topLevelItemNames).not.toContain(forbiddenItem);
    });
  });

  it('exposes Inbox, Leads, Bookings, and More for mobile navigation', () => {
    const mobileItems = buildAILeadEmployeeMobileNavItems({
      t,
      accountScopedRoute,
    });
    const moreItems = buildAILeadEmployeeMoreNavItems({
      t,
      accountScopedRoute,
    });

    expect(AI_LEAD_EMPLOYEE_MOBILE_NAVIGATION).toEqual([
      'Inbox',
      'Leads',
      'Bookings',
      'More',
    ]);
    expect(AI_LEAD_EMPLOYEE_MORE_NAVIGATION).toEqual([
      'Knowledge',
      'Test Center',
      'Settings',
    ]);
    expect(mobileItems.map(item => item.name)).toEqual([
      'Inbox',
      'Leads',
      'Bookings',
    ]);
    expect(moreItems.map(item => item.name)).toEqual([
      'Knowledge',
      'Test Center',
      'Settings',
    ]);
  });

  it('recognizes cockpit queue keys and matches owned conversation attributes', () => {
    expect(isConversationCockpitQueue('hot')).toBe(true);
    expect(isConversationCockpitQueue('review')).toBe(true);
    expect(isConversationCockpitQueue('booked')).toBe(true);
    expect(isConversationCockpitQueue('unknown')).toBe(false);

    expect(
      conversationMatchesCockpitQueue(
        { custom_attributes: { lead_quality: 'highly_qualified' } },
        'hot'
      )
    ).toBe(true);
    expect(
      conversationMatchesCockpitQueue(
        { custom_attributes: { follow_up_state: 'human_review' } },
        'review'
      )
    ).toBe(true);
    expect(
      conversationMatchesCockpitQueue(
        { custom_attributes: { booking_state: 'booked' } },
        'booked'
      )
    ).toBe(true);
  });

  it('builds Inbox queue query state and owned dashboard filters', () => {
    expect(queueRouteQuery('hot')).toEqual({ queue: 'hot' });
    expect(conversationCockpitQueueFilters).toEqual({
      hot: { quality: 'highly_qualified' },
      review: { unanswered: 'true' },
      booked: { booking_status: 'booked' },
    });
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

import { flushPromises, mount } from '@vue/test-utils';
import { createMemoryHistory, createRouter } from 'vue-router';
import LegacyReviewRedirect from '../LegacyReviewRedirect.vue';
import HumanReviewRequestsAPI from 'dashboard/api/humanReviewRequests';

vi.mock('dashboard/api/humanReviewRequests', () => ({
  default: { show: vi.fn() },
}));

describe('LegacyReviewRedirect', () => {
  it('opens the review request in its conversation, including resolved requests', async () => {
    HumanReviewRequestsAPI.show.mockResolvedValue({
      data: { id: 8, status: 'resolved', conversation_display_id: 42 },
    });
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [
        {
          path: '/app/accounts/:accountId/reviews/:reviewId',
          component: LegacyReviewRedirect,
        },
        {
          path: '/app/accounts/:accountId/conversations/:conversation_id',
          name: 'inbox_conversation',
          component: {},
        },
      ],
    });
    await router.push('/app/accounts/1/reviews/8');
    await router.isReady();
    mount(LegacyReviewRedirect, { global: { plugins: [router] } });
    await flushPromises();

    expect(HumanReviewRequestsAPI.show).toHaveBeenCalledWith('8');
    expect(router.currentRoute.value).toMatchObject({
      name: 'inbox_conversation',
      params: { accountId: '1', conversation_id: '42' },
      query: { queue: 'review', review_id: '8' },
    });
  });
});

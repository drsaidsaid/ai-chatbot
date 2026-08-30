import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import AIEmployeeControlPanel from '../AIEmployeeControlPanel.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const createWrapper = ({ chat = {} } = {}) => {
  const store = createStore({
    actions: { pauseAI: vi.fn(), resumeAI: vi.fn(), handoffAI: vi.fn() },
  });
  const dispatch = vi.spyOn(store, 'dispatch');
  const currentChat = {
    id: 42,
    control_state: 'ai_active',
    control_version: 7,
    meta: {
      assignee: { id: 3, name: 'Asha Said' },
      assignee_type: 'User',
    },
    control_events: [
      {
        id: 1,
        action: 'human_takeover',
        from: 'ai_active',
        to: 'human_active',
        actor_name: 'Asha Said',
        created_at: 1787740800,
      },
    ],
    meta_whatsapp_events: [
      {
        id: 2,
        event_kind: 'smb_message_echoes',
        provider_event_id: 'wamid.ECHO',
        created_at: 1787740900,
      },
    ],
    ...chat,
  };

  return {
    dispatch,
    wrapper: shallowMount(AIEmployeeControlPanel, {
      props: { currentChat },
      global: {
        plugins: [store],
        mocks: { $t: key => key },
      },
    }),
  };
};

describe('AIEmployeeControlPanel', () => {
  it('shows control state, owner, and recent authority events', () => {
    const { wrapper } = createWrapper();

    expect(wrapper.text()).toContain(
      'CONVERSATION_SIDEBAR.AI_EMPLOYEE.STATE.AI_ACTIVE'
    );
    expect(wrapper.text()).toContain('Asha Said');
    expect(wrapper.text()).toContain('human_takeover');
    expect(wrapper.text()).toContain('wamid.ECHO');
  });

  it('dispatches handoff, pause, and resume actions for available controls', async () => {
    const { dispatch, wrapper } = createWrapper();

    await wrapper.find('[data-testid="ai-control-handoff"]').trigger('click');
    await wrapper.find('[data-testid="ai-control-pause"]').trigger('click');

    expect(dispatch).toHaveBeenNthCalledWith(1, 'handoffAI', {
      conversationId: 42,
    });
    expect(dispatch).toHaveBeenNthCalledWith(2, 'pauseAI', {
      conversationId: 42,
    });

    const paused = createWrapper({
      chat: {
        control_state: 'ai_paused',
        meta: { assignee: null, assignee_type: null },
      },
    });
    const pausedWrapper = paused.wrapper;
    const pausedDispatch = paused.dispatch;
    await pausedWrapper
      .find('[data-testid="ai-control-resume"]')
      .trigger('click');

    expect(pausedDispatch).toHaveBeenCalledWith('resumeAI', {
      conversationId: 42,
    });
  });

  it('does not allow resume when the conversation is closed', async () => {
    const { dispatch, wrapper } = createWrapper({
      chat: {
        control_state: 'closed',
        meta: { assignee: null, assignee_type: null },
      },
    });

    const resumeButton = wrapper.find('[data-testid="ai-control-resume"]');
    expect(resumeButton.attributes('disabled')).toBeDefined();

    await resumeButton.trigger('click');
    expect(dispatch).not.toHaveBeenCalled();
  });
});

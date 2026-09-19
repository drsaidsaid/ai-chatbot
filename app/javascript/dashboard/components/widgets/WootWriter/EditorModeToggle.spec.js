import { mount } from '@vue/test-utils';
import EditorModeToggle from './EditorModeToggle.vue';
import { REPLY_EDITOR_MODES } from './constants';

describe('EditorModeToggle', () => {
  it('names the current recipient boundary and the mode a keyboard user will switch to', async () => {
    const wrapper = mount(EditorModeToggle, {
      props: { mode: REPLY_EDITOR_MODES.REPLY },
      global: {
        mocks: {
          $t: key =>
            ({
              'CONVERSATION.REPLYBOX.REPLY': 'Reply',
              'CONVERSATION.REPLYBOX.PRIVATE_NOTE': 'Private Note',
              'CONVERSATION.REPLYBOX.MODE.PUBLIC':
                'Public reply mode. Switch to Private Note.',
              'CONVERSATION.REPLYBOX.MODE.PRIVATE':
                'Private note mode. Switch to Reply.',
            })[key] || key,
        },
      },
    });

    expect(wrapper.get('button').attributes('aria-label')).toBe(
      'Public reply mode. Switch to Private Note.'
    );
    expect(wrapper.get('button').attributes('aria-pressed')).toBe('false');

    await wrapper.setProps({ mode: REPLY_EDITOR_MODES.NOTE });

    expect(wrapper.get('button').attributes('aria-label')).toBe(
      'Private note mode. Switch to Reply.'
    );
    expect(wrapper.get('button').attributes('aria-pressed')).toBe('true');
  });
});

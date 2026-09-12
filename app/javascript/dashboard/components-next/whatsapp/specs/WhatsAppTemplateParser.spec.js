import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';

import WhatsAppTemplateParser from '../WhatsAppTemplateParser.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const template = {
  id: 'meta-template-7',
  name: 'token_values',
  category: 'UTILITY',
  language: 'en',
  owned_revision_id: 42,
  owned_content_digest: 'digest-42',
  provider_template_id: 'meta-template-7',
  parameter_format: 'POSITIONAL',
  components: [
    {
      type: 'BODY',
      text: '{{1}} / {{2}}',
      example: {
        body_text: [['First', 'Second']],
      },
    },
  ],
};

describe('WhatsAppTemplateParser', () => {
  let wrapper;

  beforeEach(async () => {
    wrapper = shallowMount(WhatsAppTemplateParser, {
      props: { template },
      global: {
        mocks: {
          $t: key => key,
        },
      },
    });

    wrapper.vm.processedParams.body['1'] = '{{2}}';
    wrapper.vm.processedParams.body['2'] = 'Bob';
    await nextTick();
  });

  it('sends the original template body instead of the rendered preview', () => {
    expect(wrapper.vm.renderedTemplate).toBe('{{2}} / Bob');

    wrapper.vm.sendMessage();

    expect(wrapper.emitted('sendMessage')[0][0]).toMatchObject({
      message: '{{1}} / {{2}}',
      pendingMessageContent: '{{2}} / Bob',
      templateParams: {
        content_mode: 'raw_template',
        owned_revision_id: 42,
        owned_content_digest: 'digest-42',
        provider_template_id: 'meta-template-7',
        processed_params: {
          body: {
            1: '{{2}}',
            2: 'Bob',
          },
        },
      },
    });
  });

  it('sends rendered content when requested for an API inbox template', async () => {
    await wrapper.setProps({ sendRenderedContent: true });

    wrapper.vm.sendMessage();

    expect(wrapper.emitted('sendMessage')[0][0]).toMatchObject({
      message: '{{2}} / Bob',
      pendingMessageContent: '{{2}} / Bob',
      templateParams: {
        content_mode: 'rendered',
      },
    });
  });
});

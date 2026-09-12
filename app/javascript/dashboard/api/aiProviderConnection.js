import ApiClient from './ApiClient';

class AiProviderConnectionAPI extends ApiClient {
  constructor() {
    super('ai_provider_connection', { accountScoped: true });
  }
}

export default new AiProviderConnectionAPI();

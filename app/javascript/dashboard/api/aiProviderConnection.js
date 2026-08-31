/* global axios */

import ApiClient from './ApiClient';

class AiProviderConnectionAPI extends ApiClient {
  constructor() {
    super('ai_provider_connection', { accountScoped: true });
  }

  save(data) {
    return axios.patch(this.url, data);
  }

  disable() {
    return axios.delete(this.url);
  }

  healthCheck() {
    return axios.post(`${this.url}/health_check`);
  }
}

export default new AiProviderConnectionAPI();

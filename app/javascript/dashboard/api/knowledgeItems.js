/* global axios */

import ApiClient from './ApiClient';

class KnowledgeItemsAPI extends ApiClient {
  constructor() {
    super('knowledge_items', { accountScoped: true });
  }

  approve(id) {
    return axios.post(`${this.url}/${id}/approve`);
  }

  reject(id) {
    return axios.post(`${this.url}/${id}/reject`);
  }

  deactivate(id) {
    return axios.post(`${this.url}/${id}/deactivate`);
  }

  retryAlerts(id) {
    return axios.post(`${this.url}/${id}/retry_alerts`);
  }
}

export default new KnowledgeItemsAPI();

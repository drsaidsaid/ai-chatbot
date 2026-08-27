/* global axios */

import ApiClient from './ApiClient';

class KnowledgeDocumentsAPI extends ApiClient {
  constructor() {
    super('knowledge_documents', { accountScoped: true });
  }

  list(params = {}) {
    return axios.get(this.url, { params });
  }

  import(data) {
    return axios.post(`${this.url}/import`, data);
  }

  publish(id) {
    return axios.post(`${this.url}/${id}/publish`);
  }

  archive(id) {
    return axios.post(`${this.url}/${id}/archive`);
  }

  test(id, question) {
    return axios.post(`${this.url}/${id}/test`, { question });
  }
}

export default new KnowledgeDocumentsAPI();

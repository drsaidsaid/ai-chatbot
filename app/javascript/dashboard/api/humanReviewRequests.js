/* global axios */

import ApiClient from './ApiClient';

class HumanReviewRequestsAPI extends ApiClient {
  constructor() {
    super('human_review_requests', { accountScoped: true });
  }

  resolve(id, data) {
    return axios.post(`${this.url}/${id}/resolve`, data);
  }

  assign(id, data) {
    return axios.post(`${this.url}/${id}/assign`, data);
  }

  reject(id, data) {
    return axios.post(`${this.url}/${id}/reject`, data);
  }

  proposeKnowledge(id, data) {
    return axios.post(`${this.url}/${id}/propose_knowledge`, data);
  }

  proposeConfigurationSuggestion(id, data) {
    return axios.post(
      `${this.url}/${id}/propose_configuration_suggestion`,
      data
    );
  }

  reviewConfigurationSuggestion(id, data) {
    return axios.post(
      `${this.url}/${id}/review_configuration_suggestion`,
      data
    );
  }
}

export default new HumanReviewRequestsAPI();

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
}

export default new HumanReviewRequestsAPI();

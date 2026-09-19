/* global axios */

import ApiClient from './ApiClient';

class ReviewConfigurationSuggestionsAPI extends ApiClient {
  constructor() {
    super('review_configuration_suggestions', { accountScoped: true });
  }

  review(id, data) {
    return axios.post(`${this.url}/${id}/review`, data);
  }
}

export default new ReviewConfigurationSuggestionsAPI();

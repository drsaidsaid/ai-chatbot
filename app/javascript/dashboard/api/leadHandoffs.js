/* global axios */

import ApiClient from './ApiClient';

class LeadHandoffsAPI extends ApiClient {
  constructor() {
    super('lead_handoffs', { accountScoped: true });
  }

  proposeConfigurationSuggestion(id, data) {
    return axios.post(
      `${this.url}/${id}/propose_configuration_suggestion`,
      data
    );
  }
}

export default new LeadHandoffsAPI();

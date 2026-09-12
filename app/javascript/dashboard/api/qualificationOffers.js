/* global axios */
import ApiClient from './ApiClient';

class QualificationOffersAPI extends ApiClient {
  constructor() {
    super('qualification_offers', { accountScoped: true });
  }

  selectConversation(conversationId, offerId) {
    return axios.patch(
      `${this.baseUrl()}/conversations/${conversationId}/qualification_offer`,
      { offer_id: offerId }
    );
  }
}

export default new QualificationOffersAPI();

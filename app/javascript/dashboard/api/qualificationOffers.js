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

  saveCommercialTerms(offerId, data) {
    return axios.patch(`${this.url}/${offerId}/commercial_terms`, data);
  }

  publishCommercialTerms(offerId, draftVersion) {
    return axios.post(`${this.url}/${offerId}/commercial_terms/publish`, {
      draft_version: draftVersion,
    });
  }

  previewCommercialTerms(offerId, data = {}) {
    return axios.post(`${this.url}/${offerId}/commercial_terms/preview`, data);
  }

  reviewCommercialProposal(offerId, proposalId, action) {
    return axios.post(
      `${this.url}/${offerId}/commercial_proposals/${proposalId}/${action}`
    );
  }

  setupSources(offerId) {
    return axios.get(`${this.url}/${offerId}/setup_sources`);
  }

  createSetupSource(offerId, source) {
    return axios.post(`${this.url}/${offerId}/setup_sources`, { source });
  }

  updateSetupSource(offerId, sourceId, source) {
    const { expected_source_version, ...attributes } = source;
    return axios.patch(`${this.url}/${offerId}/setup_sources/${sourceId}`, {
      source: attributes,
      expected_source_version,
    });
  }

  publishSetupSource(offerId, sourceId, versions) {
    return axios.post(
      `${this.url}/${offerId}/setup_sources/${sourceId}/publish`,
      versions
    );
  }
}

export default new QualificationOffersAPI();

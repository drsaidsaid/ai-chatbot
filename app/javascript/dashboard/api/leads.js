/* global axios */

import ApiClient from './ApiClient';

class LeadsAPI extends ApiClient {
  constructor() {
    super('leads', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, data);
  }

  reconsent(id, data) {
    return axios.post(`${this.url}/${id}/reconsent`, data);
  }

  importLeads(file, { mode = 'preview', previewDigest } = {}) {
    const formData = new FormData();
    formData.append('import_file', file);
    formData.append('mode', mode);
    if (previewDigest) formData.append('preview_digest', previewDigest);
    return axios.post(`${this.url}/import`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  exportLeads(params = {}) {
    return axios.post(`${this.url}/export`, params, {
      responseType: 'blob',
    });
  }
}

export default new LeadsAPI();

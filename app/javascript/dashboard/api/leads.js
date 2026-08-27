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

  importLeads(file) {
    const formData = new FormData();
    formData.append('import_file', file);
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

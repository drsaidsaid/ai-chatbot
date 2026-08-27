import leads from '../leads';
import ApiClient from '../ApiClient';

describe('#LeadsAPI', () => {
  it('creates correct instance', () => {
    expect(leads).toBeInstanceOf(ApiClient);
    expect(leads).toHaveProperty('get');
  });

  describe('API calls', () => {
    const originalAxios = window.axios;
    const axiosMock = {
      get: vi.fn(() => Promise.resolve()),
      patch: vi.fn(() => Promise.resolve()),
      post: vi.fn(() => Promise.resolve()),
    };

    beforeEach(() => {
      window.axios = axiosMock;
    });

    afterEach(() => {
      window.axios = originalAxios;
      vi.clearAllMocks();
    });

    it('#get passes filters as query params', () => {
      leads.get({ q: 'jane', quality: 'qualified', page: 2 });

      expect(axiosMock.get).toHaveBeenCalledWith(leads.url, {
        params: { q: 'jane', quality: 'qualified', page: 2 },
      });
    });

    it('#update sends the lead payload', () => {
      leads.update(42, { lead: { name: 'Jane' } });

      expect(axiosMock.patch).toHaveBeenCalledWith(`${leads.url}/42`, {
        lead: { name: 'Jane' },
      });
    });

    it('#importLeads sends multipart form data', () => {
      const file = new File(['name'], 'leads.csv', { type: 'text/csv' });

      leads.importLeads(file);

      expect(axiosMock.post).toHaveBeenCalledWith(
        `${leads.url}/import`,
        expect.any(FormData),
        { headers: { 'Content-Type': 'multipart/form-data' } }
      );
    });

    it('#exportLeads requests a blob response', () => {
      leads.exportLeads({ quality: 'qualified' });

      expect(axiosMock.post).toHaveBeenCalledWith(
        `${leads.url}/export`,
        { quality: 'qualified' },
        { responseType: 'blob' }
      );
    });
  });
});

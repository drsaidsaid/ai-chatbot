import evaluationSandboxAPI from '../evaluationSandbox';
import ApiClient from '../ApiClient';

describe('#evaluationSandboxAPI', () => {
  const originalAxios = window.axios;
  const axiosMock = {
    get: vi.fn(() => Promise.resolve()),
    post: vi.fn(() => Promise.resolve()),
    patch: vi.fn(() => Promise.resolve()),
  };

  beforeEach(() => {
    window.axios = axiosMock;
  });

  afterEach(() => {
    window.axios = originalAxios;
    vi.clearAllMocks();
  });

  it('creates correct instance', () => {
    expect(evaluationSandboxAPI).toBeInstanceOf(ApiClient);
  });

  it('posts scenario runs, grades, and launch approval through account scoped URLs', () => {
    evaluationSandboxAPI.createRun({ scenario_key: 'approved_answer' });
    evaluationSandboxAPI.gradeRun(7, { grades: {} });
    evaluationSandboxAPI.approveLaunch({ approval_notes: 'Ready' });

    expect(axiosMock.post).toHaveBeenCalledWith(
      `${evaluationSandboxAPI.url}/runs`,
      { scenario_key: 'approved_answer' }
    );
    expect(axiosMock.post).toHaveBeenCalledWith(
      `${evaluationSandboxAPI.url}/runs/7/grade`,
      { grades: {} }
    );
    expect(axiosMock.post).toHaveBeenCalledWith(
      `${evaluationSandboxAPI.url}/approve_launch`,
      { approval_notes: 'Ready' }
    );
  });
});

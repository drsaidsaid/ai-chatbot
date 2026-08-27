import EvaluationSandboxAPI from '../evaluationSandbox';
import ApiClient from '../ApiClient';

describe('#EvaluationSandboxAPI', () => {
  it('creates correct instance', () => {
    expect(EvaluationSandboxAPI).toBeInstanceOf(ApiClient);
    expect(EvaluationSandboxAPI).toHaveProperty('runScenario');
    expect(EvaluationSandboxAPI).toHaveProperty('gradeRun');
    expect(EvaluationSandboxAPI).toHaveProperty('proposeKnowledge');
    expect(EvaluationSandboxAPI).toHaveProperty('updateLaunchGate');
    expect(EvaluationSandboxAPI).toHaveProperty('approveLaunch');
  });

  describe('API calls', () => {
    const originalAxios = window.axios;
    const originalPathname = window.location.pathname;
    const axiosMock = {
      get: vi.fn(() => Promise.resolve()),
      post: vi.fn(() => Promise.resolve()),
      patch: vi.fn(() => Promise.resolve()),
    };

    beforeEach(() => {
      window.axios = axiosMock;
      window.history.pushState({}, '', '/app/accounts/1/test-center');
    });

    afterEach(() => {
      window.axios = originalAxios;
      window.history.pushState({}, '', originalPathname);
      vi.clearAllMocks();
    });

    it('runs a scenario in the account-scoped sandbox', () => {
      EvaluationSandboxAPI.runScenario('audio_fallback');

      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/accounts/1/evaluation_sandbox/runs',
        { scenario_key: 'audio_fallback' }
      );
    });

    it('grades a run and updates launch gate checks', () => {
      EvaluationSandboxAPI.gradeRun(2, { safety: { passed: true } });
      EvaluationSandboxAPI.updateLaunchGate({
        team_roleplay_completed: true,
      });

      expect(axiosMock.patch).toHaveBeenNthCalledWith(
        1,
        '/api/v1/accounts/1/evaluation_sandbox/runs/2/grade',
        { grades: { safety: { passed: true } } }
      );
      expect(axiosMock.patch).toHaveBeenNthCalledWith(
        2,
        '/api/v1/accounts/1/evaluation_sandbox/launch_gate',
        { team_roleplay_completed: true }
      );
    });

    it('filters runs and proposes corrected knowledge', () => {
      EvaluationSandboxAPI.runs({ result: 'failed' });
      EvaluationSandboxAPI.proposeKnowledge(2, {
        question: 'Can you discount?',
        answer: 'Discounts require review.',
      });

      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v1/accounts/1/evaluation_sandbox/runs',
        { params: { result: 'failed' } }
      );
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/accounts/1/evaluation_sandbox/runs/2/propose_knowledge',
        {
          correction: {
            question: 'Can you discount?',
            answer: 'Discounts require review.',
          },
        }
      );
    });
  });
});

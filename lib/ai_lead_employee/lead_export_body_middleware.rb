# frozen_string_literal: true

# rubocop:disable Style/ClassAndModuleChildren -- this file defines the namespace during early application boot
module AiLeadEmployee
  class LeadExportBodyMiddleware
    ENV_KEY = 'ai_lead_employee.lead_export_artifact'

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      artifact = env.delete(ENV_KEY)
      return [status, headers, body] unless artifact

      [status, headers, AiLeadEmployee::LeadExportBody.new(artifact)]
    end
  end
end
# rubocop:enable Style/ClassAndModuleChildren

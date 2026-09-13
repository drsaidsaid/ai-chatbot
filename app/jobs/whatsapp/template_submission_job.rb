# frozen_string_literal: true

class Whatsapp::TemplateSubmissionJob < ApplicationJob
  queue_as :low

  def perform(revision, reconcile: false)
    Whatsapp::TemplateSubmissionService.new(revision: revision).perform(reconcile: reconcile)
  end
end

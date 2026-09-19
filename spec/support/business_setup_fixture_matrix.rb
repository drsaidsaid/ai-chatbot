# frozen_string_literal: true

# R19's approved, non-customer Test Center fixtures. These intentionally exercise
# the same published source/Offer revision admission used by the sandbox runtime.
module BusinessSetupFixtureMatrix
  FIXTURES = {
    online_profits_en: {
      language: 'en', business: 'Online Profits coaching', qualification_mode: 'enabled', next_step: 'sales_call',
      source: 'Online Profits helps founders. A sales call requires a current business registration number. Current prices are to be confirmed.',
      expected_unknown: 'current price'
    },
    product_no_qualification_sw: {
      language: 'sw', business: 'Duka la bidhaa', qualification_mode: 'disabled', next_step: 'purchase_link',
      next_step_url: 'https://example.test/nunua',
      commercial_terms: { amount: '25000', currency: 'TZS', quote_required: false, timezone: 'Africa/Dar_es_Salaam' },
      source: 'Tunauza bidhaa za nyumbani. Bei ipo kwenye kiungo cha ununuzi. Hakuna maswali ya ustahiki.',
      expected_unknown: nil
    },
    service_distinct_fit_en: {
      language: 'en', business: 'Bookkeeping service', qualification_mode: 'enabled', next_step: 'enquiry',
      source: 'We help registered small businesses. Enquiries need a current business registration number.',
      expected_unknown: 'current price'
    }
  }.freeze
end

# frozen_string_literal: true

require 'active_support/all'

module AiLeadEmployee
end

require_relative '../../../app/services/ai_lead_employee/language_detector'
require_relative '../../../app/services/ai_lead_employee/conversation_intent_classifier'

RSpec.describe AiLeadEmployee::ConversationIntentClassifier do
  it 'routes a complaint asking for a person to Review before sales qualification' do
    result = described_class.new(message: 'This is a scam. I want a human to handle my complaint.').perform

    expect(result.intent).to eq(:complaint)
    expect(result.review_reason).to eq('angry_question')
    expect(result).to be_risky
  end

  it 'recognizes a Swahili complaint and keeps its acknowledgment language' do
    result = described_class.new(message: 'Nina malalamiko. Huu ni utapeli.').perform

    expect(result.intent).to eq(:complaint)
    expect(result.review_reason).to eq('angry_question')
    expect(result.language).to eq(:swahili)
  end

  ['I am furious about this terrible service. I want to speak to a human.', "I'm upset about this service."].each do |message|
    it "routes a present first-person complaint before staff or sales policy: #{message}" do
      result = described_class.new(message: message).perform

      expect(result).to have_attributes(intent: :complaint, review_reason: 'angry_question')
    end
  end

  ['Siwezi kuingia kwenye kozi yangu.', 'Ningependa kuzungumza na mtu.', 'Nahitaji kuzungumza na mtu.'].each do |message|
    it "retains Swahili for a recognized request without a greeting or payment preface: #{message}" do
      result = described_class.new(message: message).perform

      expect(result.language).to eq(:swahili)
    end
  end

  it 'keeps informational complaint-policy questions in the knowledge path' do
    result = described_class.new(message: 'What is your complaint policy?').perform

    expect(result.intent).to eq(:business_question)
    expect(result.review_reason).to be_nil
  end

  {
    'Can you refund my course payment?' => :english,
    'Nimelipia kozi lakini nataka kurudishiwa fedha zangu.' => :swahili
  }.each do |message, language|
    it "routes a #{language} refund action to Review" do
      result = described_class.new(message: message).perform

      expect(result.intent).to eq(:refund_request)
      expect(result.review_reason).to eq('sensitive_question')
      expect(result.language).to eq(language)
    end
  end

  it 'keeps informational refund policy questions eligible for approved knowledge' do
    result = described_class.new(message: 'What is your refund policy?').perform

    expect(result).to be_requires_approved_knowledge
    expect(result.review_reason).to be_nil
  end

  it 'keeps an explicitly negated refund action in the informational knowledge path' do
    result = described_class.new(message: 'Please do not refund my payment. What is your refund policy?').perform

    expect(result.review_reason).to be_nil
    expect(result).to be_requires_approved_knowledge
  end

  ['What happens if I want a refund?', 'Does Student Support help people who cannot access courses?'].each do |message|
    it "keeps hypothetical or third-person questions in the knowledge path: #{message}" do
      result = described_class.new(message: message).perform

      expect(result.review_reason).to be_nil
      expect(result).to be_requires_approved_knowledge
    end
  end

  {
    'I paid but cannot access my course.' => :english,
    'Nimelipa lakini siwezi kufungua kozi yangu.' => :swahili
  }.each do |message, language|
    it "routes a #{language} personal access problem to customer-support Review" do
      result = described_class.new(message: message).perform

      expect(result.intent).to eq(:support_request)
      expect(result.review_reason).to eq('sensitive_question')
      expect(result.language).to eq(language)
    end
  end

  it 'does not treat a support programme definition as a personal support action' do
    result = described_class.new(message: 'What is Student Support?').perform

    expect(result.intent).to eq(:business_question)
    expect(result.review_reason).to be_nil
  end

  ['Why am I unable to access my course?', "Why can't I access my course?",
   'I paid yesterday. Please confirm my payment.', 'Nimelipa. Tafadhali thibitisha malipo yangu.'].each do |message|
    it "routes a personal access or payment request to support: #{message}" do
      result = described_class.new(message: message).perform

      expect(result.intent).to eq(:support_request)
      expect(result.review_reason).to eq('sensitive_question')
    end
  end

  ['Please let me speak to a human.', 'Nataka kuzungumza na mtu wa timu yenu.',
   'I want to speak to a sales representative.', 'Please connect me to a person.', 'I want a human.',
   'How can I speak to a human?'].each do |message|
    it "recognizes the actual staff request: #{message}" do
      result = described_class.new(message: message).perform

      expect(result.intent).to eq(:human_request)
      expect(result.review_reason).to be_nil
    end
  end

  ['This is unacceptable.', 'Your service is terrible.'].each do |message|
    it "recognizes the present complaint: #{message}" do
      result = described_class.new(message: message).perform

      expect(result.intent).to eq(:complaint)
      expect(result.review_reason).to eq('angry_question')
    end
  end

  it 'treats ordinary sales help as a qualification statement rather than a staff request' do
    result = described_class.new(message: 'I need help increasing sales.').perform

    expect(result.intent).to eq(:qualification_answer)
  end

  ['Tell me about your course.', 'Please explain your business.'].each do |message|
    it "keeps a direct factual request in the approved knowledge path: #{message}" do
      result = described_class.new(message: message).perform

      expect(result.intent).to eq(:business_question)
      expect(result).to be_requires_approved_knowledge
    end
  end

  ['Which plan fits me', 'Who teaches the course', 'Will you deliver to Zanzibar', 'May I pay by card',
   'Does Pulse include coaching', 'Does Pulse integrate with HubSpot', 'Can Growth Academy help me',
   'Is Pulse available', 'Are Growth Academy classes recorded',
   'Jinsi gani huduma hii inafanya kazi', 'Lini kozi inaanza', 'Ni lini kozi inaanza',
   'Mnasafirisha hadi Arusha', 'Mna huduma Zanzibar', 'Ninaweza kulipa kwa M-Pesa', 'Naweza kulipa kwa M-Pesa',
   'Wapi ofisi yenu', 'Ni wapi ofisi yenu', 'Growth Coaching inajumuisha nini', 'Kozi ya Pulse inaanza lini',
   'Kozi inaanza siku gani', 'Huduma hii ni ipi', 'Huduma yetu ya Growth Coaching inaanza lini',
   'Ofisi yenu iko wapi'].each do |message|
    it "recognizes an unpunctuated English or Swahili question clause: #{message}" do
      expect(described_class.new(message: message).perform.intent).to eq(:business_question)
    end
  end

  it 'recognizes an unpunctuated Swahili pricing question as risky' do
    expect(described_class.new(message: 'Bei ya Pulse ni nini').perform.intent).to eq(:risky_question)
  end

  ['I know how it works', 'I already explained what happened', 'They asked Pulse inajumuisha nini',
   'Alieleza Kozi ya Pulse inaanza lini', 'Walisema Pulse inajumuisha nini',
   'Amesema Pulse inajumuisha nini', 'Tumeeleza Kozi ya Pulse inaanza lini'].each do |message|
    it "does not treat an embedded question word as a request: #{message}" do
      expect(described_class.new(message: message).perform.intent).to eq(:generic_safe)
    end
  end

  ['Will Smith Academy opens tomorrow', 'May Consulting closes today', 'May Consulting will offer support',
   'May Consulting plans to offer support',
   'Unavailable seats are listed', 'Unable customers receive support'].each do |message|
    it "does not mistake a name or English declarative fragment for a modal question: #{message}" do
      expect(described_class.new(message: message).perform.intent).not_to eq(:business_question)
    end
  end

  it 'keeps an imperative unrelated request in the unrelated path' do
    expect(described_class.new(message: 'Tell me a football score').perform.intent).to eq(:unrelated)
  end

  it 'preserves the existing explicit request to be given a human' do
    result = described_class.new(message: 'Please give me a human. My budget is $50.').perform

    expect(result.intent).to eq(:human_request)
  end

  [
    'Please do not let me speak to a human. Just answer here.',
    'Never refund me.',
    'I do not want to speak to a human. I need help increasing sales.',
    'What does "please let me speak to a human" mean?',
    "What does 'please let me speak to a human' mean?",
    'The training phrase is ‘please let me speak to a human’.',
    'What is a sales representative?',
    'Sitaki kuzungumza na mtu wa timu yenu.'
  ].each do |message|
    it "does not mistake an informational, quoted or negated phrase for a staff request: #{message}" do
      result = described_class.new(message: message).perform

      expect(result.intent).not_to eq(:human_request)
      expect(result.review_reason).to be_nil
    end
  end

  it 'keeps a greeting-prefixed business question in the knowledge path' do
    result = described_class.new(message: 'Habari, biashara yenu inafanya nini?').perform

    expect(result.intent).to eq(:business_question)
  end

  ['Hello, is your course online', 'Hello, what happens if I want a refund?'].each do |message|
    it "preserves an informational question after a greeting: #{message}" do
      result = described_class.new(message: message).perform

      expect(result).to be_requires_approved_knowledge
      expect(result.review_reason).to be_nil
    end
  end

  it 'recognizes business details after a greeting as a qualification answer' do
    result = described_class.new(message: 'Hello, I run a coaching business.').perform

    expect(result.intent).to eq(:qualification_answer)
  end

  ['My budget is $500.', 'I am the owner and can spend $500.'].each do |message|
    it "recognizes a declarative qualification answer containing an auxiliary verb: #{message}" do
      result = described_class.new(message: message).perform

      expect(result.intent).to eq(:qualification_answer)
    end
  end

  it 'accepts a greeting-only question mark without treating it as a knowledge question' do
    result = described_class.new(message: 'Habari?').perform

    expect(result.intent).to eq(:greeting)
  end

  it 'classifies a Swahili language-support question as safe conversation' do
    result = described_class.new(message: 'unaongea kiswahili?').perform

    expect(result.intent).to eq(:language_question)
    expect(result.language).to eq(:swahili)
    expect(result).to be_safe_conversation
    expect(result).not_to be_requires_approved_knowledge
  end

  it 'classifies Swahili and English greetings as safe conversation' do
    swahili = described_class.new(message: 'habari').perform
    english = described_class.new(message: 'Hello there').perform

    expect(swahili.intent).to eq(:greeting)
    expect(swahili.language).to eq(:swahili)
    expect(swahili).to be_safe_conversation
    expect(english.intent).to eq(:greeting)
    expect(english.language).to eq(:english)
    expect(english).to be_safe_conversation
  end

  it 'classifies lead-detail statements as qualification answers' do
    result = described_class.new(message: 'I run an online course business and I need more qualified leads.').perform

    expect(result.intent).to eq(:qualification_answer)
    expect(result.language).to eq(:english)
    expect(result).to be_safe_conversation
  end

  it 'classifies Swahili requests for offer details as business questions' do
    result = described_class.new(message: 'naomba maelezo kuhusu Online Profits').perform

    expect(result.intent).to eq(:business_question)
    expect(result.language).to eq(:swahili)
    expect(result).to be_requires_approved_knowledge
    expect(result).not_to be_safe_conversation
  end

  it 'classifies controlled claims as risky questions' do
    result = described_class.new(message: 'What is your refund policy and guarantee?').perform

    expect(result.intent).to eq(:risky_question)
    expect(result.language).to eq(:english)
    expect(result).to be_risky
    expect(result).to be_requires_approved_knowledge
  end

  it 'distinguishes a short acknowledgment from an unclear statement' do
    result = described_class.new(message: 'sawa').perform

    expect(result.intent).to eq(:acknowledgment)
    expect(result.language).to eq(:swahili)
    expect(result).to be_safe_conversation
  end

  ['Who won the football match?', 'What is the weather today?', 'Nipe mapishi ya pilau.'].each do |message|
    it "recognizes an unrelated request without sending it to business Review: #{message}" do
      result = described_class.new(message: message).perform

      expect(result.intent).to eq(:unrelated)
      expect(result.review_reason).to be_nil
      expect(result).to be_safe_conversation
    end
  end

  ['Build a marketing strategy for my company.', 'Tell me exactly what I should do to grow my business.'].each do |message|
    it "recognizes a request for personalized strategy: #{message}" do
      result = described_class.new(message: message).perform

      expect(result.intent).to eq(:personalized_strategy)
      expect(result).to be_requires_approved_knowledge
    end
  end
end

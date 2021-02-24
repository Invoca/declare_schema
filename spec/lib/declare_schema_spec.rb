# frozen_string_literal: true

RSpec.describe DeclareSchema do
  describe '#default_text_limit' do
    subject { described_class.default_text_limit }

    context 'when not explicitly set' do
      it { should eq(0xffff_ffff) }
    end

    context 'when explicitly set' do
      before { described_class.default_text_limit = 0xffff }
      after  { described_class.default_text_limit = 0xffff_ffff }
      it     { should eq(0xffff) }
    end
  end
end

# frozen_string_literal: true

RSpec.describe DeclareSchema do
  describe '#default_charset' do
    subject { described_class.default_charset }

    context 'when not explicitly set' do
      it { should eq("utf8mb4") }
    end

    context 'when explicitly set' do
      before { described_class.default_charset = "utf8" }
      after  { described_class.default_charset = "utf8mb4" }
      it     { should eq("utf8") }
    end
  end

  describe '#default_collation' do
    subject { described_class.default_collation }

    context 'when not explicitly set' do
      it { should eq("utf8mb4_bin") }
    end

    context 'when explicitly set' do
      before { described_class.default_collation = "utf8mb4_general_ci" }
      after  { described_class.default_collation = "utf8mb4_bin" }
      it     { should eq("utf8mb4_general_ci") }
    end
  end

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

  describe '#default_string_limit' do
    subject { described_class.default_string_limit }

    context 'when not explicitly set' do
      it { should eq(nil) }
    end

    context 'when explicitly set' do
      before { described_class.default_string_limit = 225 }
      after  { described_class.default_string_limit = nil }
      it     { should eq(225) }
    end
  end

  describe '#default_null' do
    subject { described_class.default_null }

    context 'when not explicitly set' do
      it { should eq(false) }
    end

    context 'when explicitly set' do
      before { described_class.default_null = true }
      after  { described_class.default_null = false }
      it     { should eq(true) }
    end
  end

  describe '#default_generate_foreign_keys' do
    subject { described_class.default_generate_foreign_keys }

    context 'when not explicitly set' do
      it { should eq(true) }
    end

    context 'when explicitly set' do
      before { described_class.default_generate_foreign_keys = false }
      after  { described_class.default_generate_foreign_keys = true }
      it     { should eq(false) }
    end
  end

  describe '#default_generate_indexing' do
    subject { described_class.default_generate_indexing }

    context 'when not explicitly set' do
      it { should eq(true) }
    end

    context 'when explicitly set' do
      before { described_class.default_generate_indexing = false }
      after  { described_class.default_generate_indexing = true }
      it     { should eq(false) }
    end
  end
end

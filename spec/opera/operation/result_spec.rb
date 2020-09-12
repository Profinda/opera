# frozen_string_literal: true

require 'spec_helper'

module Opera
  RSpec.describe Operation::Result, type: :operation do
    subject { described_class.new }

    describe '#failure?' do
      before { subject.add_error(:example, 'Example') }

      it { is_expected.to be_failure }
    end

    describe '#success?' do
      it { is_expected.to be_success }
    end

    describe '#output=' do
      before { subject.output = :example }

      it { expect(subject.output).to eq(:example) }
    end

    describe '#add_error' do
      before { subject.add_error(:example, 'Example') }

      it { expect(subject.errors).to eq(example: ['Example']) }

      context 'when adding errors multiple times' do
        let(:result) do
          {
            example: ['Example'],
            example2: ['Example2']
          }
        end

        before { subject.add_error(:example2, 'Example2') }

        it { expect(subject.errors).to eq(result) }
      end
    end

    describe '#add_errors' do
      let(:result) do
        {
          example: ['Example'],
          example2: ['Example2']
        }
      end

      before { subject.add_errors(result) }

      it { expect(subject.errors).to eq(result) }

      context 'when errors already existed' do
        let(:result2) do
          {
            example3: ['Example3'],
            example4: ['Example4']
          }
        end

        before { subject.add_errors(result2) }

        it { expect(subject.errors).to include(result) }
        it { expect(subject.errors).to include(result2) }
      end
    end

    describe '#add_exception' do
      let(:params) { [:example, 'Example'] }

      before { subject.add_exception(*params) }

      it { expect(subject.exceptions).to eq('example' => ['Example']) }

      context 'when classname provided' do
        let(:params) { [:example, 'Example', classname: 'Foo'] }

        it { expect(subject.exceptions).to eq('Foo#example' => ['Example']) }
      end
    end

    describe '#add_information' do
      let(:result) do
        {
          example: ['Example'],
          example2: ['Example2']
        }
      end

      before { subject.add_information(result) }

      it { expect(subject.information).to eq(result) }

      context 'when information already existed' do
        let(:result2) do
          {
            example3: ['Example3'],
            example4: ['Example4']
          }
        end

        before { subject.add_information(result2) }

        it { expect(subject.information).to include(result) }
        it { expect(subject.information).to include(result2) }
      end
    end

    describe '#add_execution' do
      before do
        subject.add_execution(:step_1)
        subject.add_execution(:step_2)
      end

      it { expect(subject.executions).to eq(%i[step_1 step_2]) }
    end
  end
end

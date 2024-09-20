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

    describe '#failures' do
      before do
        subject.add_error(:foo1, :bar1)
        subject.add_exception(:foo2, :bar2)
      end

      it 'returns errors and exceptions combined' do
        expect(subject.failures).to eq(foo1: [:bar1], 'foo2' => [:bar2])
      end
    end

    describe '#output=' do
      before { subject.output = :example }

      it { expect(subject.output).to eq(:example) }
    end

    describe '#output!' do
      context 'with Success' do
        before { subject.output = :example }

        it { expect(subject.output!).to eq(:example) }
      end

      context 'with Failure' do
        before { subject.add_error(:example, 'Example') }

        it 'raises exception' do
          expect do
            subject.output!
          end.to raise_error(Opera::Operation::Result::OutputError, 'Cannot retrieve output from a Failure.')
        end
      end
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

      context 'when errors are ActiveModel::Errors instead of a hash' do
        let(:result3) do
          {
            example5: ['Example5'],
            example6: ['Example6']
          }
        end

        before do
          errors_object = double('ActiveRecord::Errors')

          allow(errors_object).to receive(:to_hash) { result3 }

          subject.add_errors(errors_object)
        end

        it { expect(subject.errors).to include(result3) }
      end
    end

    describe '#add_exception' do
      it do
        subject.add_exception(:example, 'Example')
        expect(subject.exceptions).to eq('example' => ['Example'])
      end

      context 'when classname provided' do
        it do
          subject.add_exception(:example, 'Example', classname: 'Foo')
          expect(subject.exceptions).to eq('Foo#example' => ['Example'])
        end
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

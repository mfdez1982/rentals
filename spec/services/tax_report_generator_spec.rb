require 'rails_helper'

RSpec.describe TaxReportGenerator do
  describe '#generate' do
    let(:user) { create(:user) }
    let(:landlord) { user.landlord }
    let(:property) { create(:property, landlord: landlord) }

    context 'Scenario 1: Tax Year 2025' do
      before do
        # Single agreement from 01/06/2025 to 31/05/2026
        @agreement = create(
          :rental_agreement,
          property: property,
          start_date: Date.new(2025, 6, 1),
          end_date: Date.new(2026, 5, 31),
          rent_amount: 80.00
        )

        # Create 7 payments for Jun-Dec 2025
        (6..12).each do |month|
          create(
            :payment,
            rental_agreement: @agreement,
            due_date: Date.new(2025, month, 1),
            amount: 80.00
          )
        end

        # Expenses in 2025
        create(
          :expense,
          property: property,
          date: Date.new(2025, 1, 1),
          category: :tax,
          description: 'IBI',
          amount: 82.63
        )

        create(
          :expense,
          property: property,
          date: Date.new(2025, 1, 1),
          category: :community_fees,
          description: 'Sociedad',
          amount: 384.00
        )
      end

      it 'calculates correct active rental days' do
        # 01/06/2025 to 31/12/2025 = 214 days
        report = TaxReportGenerator.new(property, 2025).generate
        expect(report[:active_rental_days]).to eq(214)
      end

      it 'calculates correct total days in year' do
        report = TaxReportGenerator.new(property, 2025).generate
        expect(report[:total_days]).to eq(365)
      end

      it 'calculates correct pro-rata ratio' do
        # 214 / 365 = 0.5863...
        report = TaxReportGenerator.new(property, 2025).generate
        expect(report[:pro_rata_ratio]).to eq(0.5863)
      end

      it 'calculates correct deductible expenses' do
        report = TaxReportGenerator.new(property, 2025).generate
        expenses = report[:expenses]

        expect(expenses.count).to eq(2)

        # IBI: 82.63 * 0.5863 = 48.45
        ibi = expenses.find { |e| e[:description] == 'IBI' }
        expect(ibi[:original_amount]).to eq(82.63)
        expect(ibi[:deductible_amount]).to eq(48.45)

        # Community fees: 384.00 * 0.5863 = 225.14
        community = expenses.find { |e| e[:description] == 'Sociedad' }
        expect(community[:original_amount]).to eq(384.00)
        expect(community[:deductible_amount]).to eq(225.14)
      end

      it 'calculates correct total gross income' do
        # 7 months * 80 = 560
        report = TaxReportGenerator.new(property, 2025).generate
        expect(report[:total_gross_income]).to eq(560.00)
      end
    end

    context 'Scenario 2: Tax Year 2026' do
      before do
        # Agreement #1: 01/06/2025 to 31/05/2026
        # Overlaps 2026 from 01/01 to 31/05 = 151 days
        agreement1 = create(
          :rental_agreement,
          property: property,
          start_date: Date.new(2025, 6, 1),
          end_date: Date.new(2026, 5, 31),
          rent_amount: 80.00
        )

        # Agreement #2: 01/06/2026 to 31/05/2027
        # Overlaps 2026 from 01/06 to 31/12 = 214 days
        agreement2 = create(
          :rental_agreement,
          property: property,
          start_date: Date.new(2026, 6, 1),
          end_date: Date.new(2027, 5, 31),
          rent_amount: 80.00
        )

        # Create 12 payments for 2026 (6 from agreement1, 6 from agreement2)
        (1..5).each do |month|
          create(
            :payment,
            rental_agreement: agreement1,
            due_date: Date.new(2026, month, 1),
            amount: 80.00
          )
        end

        (6..12).each do |month|
          create(
            :payment,
            rental_agreement: agreement2,
            due_date: Date.new(2026, month, 1),
            amount: 80.00
          )
        end

        # Expense in 2026
        create(
          :expense,
          property: property,
          date: Date.new(2026, 1, 1),
          category: :tax,
          description: 'IBI',
          amount: 82.63
        )
      end

      it 'calculates correct active rental days with overlapping agreements' do
        # Agreement 1: 151 days (Jan 1 to May 31)
        # Agreement 2: 214 days (Jun 1 to Dec 31)
        # Total: 365 days
        report = TaxReportGenerator.new(property, 2026).generate
        expect(report[:active_rental_days]).to eq(365)
      end

      it 'calculates correct total days in year' do
        report = TaxReportGenerator.new(property, 2026).generate
        expect(report[:total_days]).to eq(365)
      end

      it 'calculates correct pro-rata ratio when fully rented' do
        # 365 / 365 = 1.0000
        report = TaxReportGenerator.new(property, 2026).generate
        expect(report[:pro_rata_ratio]).to eq(1.0)
      end

      it 'calculates deductible expenses with 100% ratio' do
        report = TaxReportGenerator.new(property, 2026).generate
        expenses = report[:expenses]

        expect(expenses.count).to eq(1)

        # IBI: 82.63 * 1.0 = 82.63
        ibi = expenses.find { |e| e[:description] == 'IBI' }
        expect(ibi[:original_amount]).to eq(82.63)
        expect(ibi[:deductible_amount]).to eq(82.63)
      end

      it 'calculates correct total gross income from both agreements' do
        # 12 months * 80 = 960
        report = TaxReportGenerator.new(property, 2026).generate
        expect(report[:total_gross_income]).to eq(960.00)
      end
    end

    context 'Edge cases' do
      context 'when property has no agreements in the given year' do
        it 'returns zero active rental days' do
          report = TaxReportGenerator.new(property, 2025).generate
          expect(report[:active_rental_days]).to eq(0)
        end

        it 'returns zero pro-rata ratio' do
          report = TaxReportGenerator.new(property, 2025).generate
          expect(report[:pro_rata_ratio]).to eq(0.0)
        end

        it 'returns empty deductible expenses' do
          report = TaxReportGenerator.new(property, 2025).generate
          expect(report[:expenses]).to eq([])
        end

        it 'returns zero total gross income' do
          report = TaxReportGenerator.new(property, 2025).generate
          expect(report[:total_gross_income]).to eq(0.0)
        end
      end

      context 'when there are gaps between agreements' do
        before do
          # Agreement 1: May 1 to May 15
          agreement1 = create(
            :rental_agreement,
            property: property,
            start_date: Date.new(2025, 5, 1),
            end_date: Date.new(2025, 5, 15),
            rent_amount: 80.00
          )

          # Agreement 2: June 1 to June 30 (gap from May 16-31)
          agreement2 = create(
            :rental_agreement,
            property: property,
            start_date: Date.new(2025, 6, 1),
            end_date: Date.new(2025, 6, 30),
            rent_amount: 80.00
          )

          # Payments matching agreements
          create(:payment, rental_agreement: agreement1, due_date: Date.new(2025, 5, 1), amount: 80.00)
          create(:payment, rental_agreement: agreement2, due_date: Date.new(2025, 6, 1), amount: 80.00)
        end

        it 'does not count gap days as active rental days' do
          # May 1-15 = 15 days, June 1-30 = 30 days, total = 45 days
          report = TaxReportGenerator.new(property, 2025).generate
          expect(report[:active_rental_days]).to eq(45)
        end
      end

      context 'when property has a leap year agreement' do
        it 'correctly calculates days in a leap year (2024)' do
          property_2024 = create(:property, landlord: landlord)
          create(
            :rental_agreement,
            property: property_2024,
            start_date: Date.new(2024, 1, 1),
            end_date: Date.new(2024, 12, 31),
            rent_amount: 100.00
          )

          report = TaxReportGenerator.new(property_2024, 2024).generate
          expect(report[:total_days]).to eq(366)
          expect(report[:active_rental_days]).to eq(366)
          expect(report[:pro_rata_ratio]).to eq(1.0)
        end
      end

      context 'when expenses exist outside the given year' do
        before do
          create(
            :rental_agreement,
            property: property,
            start_date: Date.new(2025, 1, 1),
            end_date: Date.new(2025, 12, 31),
            rent_amount: 100.00
          )

          # Expense in 2024 (should not be included)
          create(
            :expense,
            property: property,
            date: Date.new(2024, 12, 31),
            category: :tax,
            description: 'Old IBI',
            amount: 100.00
          )

          # Expense in 2025 (should be included)
          create(
            :expense,
            property: property,
            date: Date.new(2025, 6, 1),
            category: :tax,
            description: 'Current IBI',
            amount: 100.00
          )

          # Expense in 2026 (should not be included)
          create(
            :expense,
            property: property,
            date: Date.new(2026, 1, 1),
            category: :tax,
            description: 'Future IBI',
            amount: 100.00
          )
        end

        it 'only includes expenses from the requested year' do
          report = TaxReportGenerator.new(property, 2025).generate
          expenses = report[:expenses]

          expect(expenses.count).to eq(1)
          expect(expenses.first[:description]).to eq('Current IBI')
        end
      end

      context 'when payments exist outside the given year' do
        before do
          agreement1 = create(
            :rental_agreement,
            property: property,
            start_date: Date.new(2024, 1, 1),
            end_date: Date.new(2024, 12, 31),
            rent_amount: 100.00
          )

          agreement2 = create(
            :rental_agreement,
            property: property,
            start_date: Date.new(2025, 1, 1),
            end_date: Date.new(2025, 12, 31),
            rent_amount: 100.00
          )

          agreement3 = create(
            :rental_agreement,
            property: property,
            start_date: Date.new(2026, 1, 1),
            end_date: Date.new(2026, 12, 31),
            rent_amount: 100.00
          )

          # Payment in 2024
          create(:payment, rental_agreement: agreement1, due_date: Date.new(2024, 12, 1), amount: 100.00)

          # Payment in 2025
          create(:payment, rental_agreement: agreement2, due_date: Date.new(2025, 6, 1), amount: 100.00)

          # Payment in 2026
          create(:payment, rental_agreement: agreement3, due_date: Date.new(2026, 1, 1), amount: 100.00)
        end

        it 'only includes payments from the requested year' do
          report = TaxReportGenerator.new(property, 2025).generate
          expect(report[:total_gross_income]).to eq(100.00)
        end
      end

      context 'when an expense is marked non-deductible' do
        before do
          create(
            :rental_agreement,
            property: property,
            start_date: Date.new(2025, 1, 1),
            end_date: Date.new(2025, 12, 31),
            rent_amount: 100.00
          )

          create(
            :expense,
            property: property,
            date: Date.new(2025, 6, 1),
            category: :tax,
            description: 'Deductible IBI',
            amount: 100.00,
            deductible: true
          )

          create(
            :expense,
            property: property,
            date: Date.new(2025, 6, 1),
            category: :other,
            description: 'Non-deductible expense',
            amount: 100.00,
            deductible: false
          )
        end

        it 'excludes non-deductible expenses and includes deductible ones' do
          report = TaxReportGenerator.new(property, 2025).generate
          expenses = report[:expenses]

          expect(expenses.count).to eq(1)
          expect(expenses.first[:description]).to eq('Deductible IBI')
        end
      end

      context 'with decimal precision on deductible amounts' do
        before do
          create(
            :rental_agreement,
            property: property,
            start_date: Date.new(2025, 1, 1),
            end_date: Date.new(2025, 12, 31),
            rent_amount: 100.00
          )

          # Expense that will have rounding
          create(
            :expense,
            property: property,
            date: Date.new(2025, 1, 1),
            category: :tax,
            description: 'IBI',
            amount: 100.00
          )
        end

        it 'rounds deductible amounts to 2 decimal places' do
          report = TaxReportGenerator.new(property, 2025).generate
          expenses = report[:expenses]

          expect(expenses.first[:deductible_amount]).to eq(100.00)
          # Verify it's rounded to 2 decimals, not more
          expect(expenses.first[:deductible_amount].to_s.split('.')[1]&.length || 0).to be <= 2
        end
      end
    end
  end
end

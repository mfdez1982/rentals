class TaxReportGenerator
  def initialize(property, year)
    @property = property
    @year = year
  end

  def generate
    {
      year: @year,
      total_days: days_in_year,
      active_rental_days: calculate_active_rental_days,
      pro_rata_ratio: calculate_pro_rata_ratio,
      expenses: calculate_deductible_expenses,
      total_gross_income: calculate_total_gross_income
    }
  end

  private

  def days_in_year
    Date.new(@year, 12, 31).yday
  end

  def year_start_date
    Date.new(@year, 1, 1)
  end

  def year_end_date
    Date.new(@year, 12, 31)
  end

  def overlapping_agreements_in_year
    @property.rental_agreements.select do |agreement|
      agreement.end_date >= year_start_date && agreement.start_date <= year_end_date
    end
  end

  def active_days_for_agreement(agreement)
    agreement_start = [agreement.start_date, year_start_date].max
    agreement_end = [agreement.end_date, year_end_date].min
    (agreement_end - agreement_start).to_i + 1
  end

  def calculate_active_rental_days
    overlapping_agreements_in_year.sum { |agreement| active_days_for_agreement(agreement) }
  end

  def calculate_pro_rata_ratio
    total = days_in_year
    return 0.0 if total.zero?

    active = calculate_active_rental_days
    (active.to_f / total).round(4)
  end

  def calculate_deductible_expenses
    ratio = calculate_pro_rata_ratio
    expenses_in_year.map do |expense|
      {
        date: expense.date,
        category: expense.category,
        description: expense.description,
        original_amount: expense.amount,
        deductible_amount: (expense.amount * ratio).round(2)
      }
    end
  end

  def calculate_total_gross_income
    payments_in_year.sum(&:amount)
  end

  def expenses_in_year
    @property.expenses.select do |expense|
      expense.date >= year_start_date && expense.date <= year_end_date
    end
  end

  def payments_in_year
    @property.rental_agreements.flat_map(&:payments).select do |payment|
      payment.due_date >= year_start_date && payment.due_date <= year_end_date
    end
  end
end

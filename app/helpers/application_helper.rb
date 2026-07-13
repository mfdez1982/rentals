module ApplicationHelper
    include Heroicons::Helper

    def format_date(date)
      l(date, format: :numeric) if date.present?
    end
end

module ApplicationHelper
    include Heroicons::Helper

    def format_date(date)
      date.strftime("%d/%m/%Y") if date.present?
    end
end

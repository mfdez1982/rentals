module RentalAgreementsHelper
  def agreement_status(agreement)
    if agreement.active?
      t("rental_agreements.status_active")
    elsif agreement.upcoming?
      t("rental_agreements.status_upcoming")
    else
      t("rental_agreements.status_expired")
    end
  end

  def agreement_status_badge_class(agreement)
    if agreement.active?
      "badge-success"
    elsif agreement.upcoming?
      "badge-info"
    else
      "badge-ghost"
    end
  end
end

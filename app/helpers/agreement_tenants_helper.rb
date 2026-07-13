module AgreementTenantsHelper
  def agreement_tenant_status_badge_class(agreement_tenant)
    case agreement_tenant.status
    when "pending"
      "badge-info"
    when "accepted"
      "badge-success"
    when "rejected"
      "badge-error"
    when "removed"
      "badge-ghost"
    end
  end
end

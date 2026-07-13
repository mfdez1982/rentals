class AgreementTenantsController < ApplicationController
  before_action :set_property
  before_action :set_agreement
  before_action :set_agreement_tenant, only: [:destroy, :retry, :acknowledge]

  def create
    email = params.dig(:agreement_tenant, :invited_email)

    if email.blank?
      redirect_to property_rental_agreement_path(@property, @agreement),
                  alert: t("agreement_tenants.errors.email_blank")
      return
    end

    result = TenantInviter.call(rental_agreement: @agreement, email: email)

    redirect_to property_rental_agreement_path(@property, @agreement), **flash_for(result.outcome)
  end

  def destroy
    if @agreement_tenant.accepted?
      @agreement_tenant.update!(status: :removed, responded_at: Time.current, tenant_acknowledged_at: nil)
      AgreementTenantMailer.removed(@agreement_tenant).deliver_later
      notice = t("agreement_tenants.removed")
    else
      @agreement_tenant.destroy
      notice = t("agreement_tenants.invite_killed")
    end

    redirect_to property_rental_agreement_path(@property, @agreement), notice: notice
  end

  def retry
    result = TenantInviter.call(rental_agreement: @agreement, email: @agreement_tenant.invited_email)

    redirect_to property_rental_agreement_path(@property, @agreement), **flash_for(result.outcome)
  end

  def acknowledge
    @agreement_tenant.update!(landlord_acknowledged_at: Time.current)
    redirect_back fallback_location: property_rental_agreement_path(@property, @agreement),
                  notice: t("agreement_tenants.acknowledged")
  end

  private

  def set_agreement
    @agreement = @property.rental_agreements.find(params[:rental_agreement_id])
  end

  def set_agreement_tenant
    @agreement_tenant = @agreement.agreement_tenants.find(params[:id])
  end

  def flash_for(outcome)
    case outcome
    when :invited
      { notice: t("agreement_tenants.invited") }
    when :already_pending
      { alert: t("agreement_tenants.already_pending") }
    when :already_accepted
      { alert: t("agreement_tenants.already_accepted") }
    else
      {}
    end
  end
end

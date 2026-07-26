class LeaseDocumentsController < ApplicationController
  include AgreementShowLoadable

  before_action :set_property
  before_action :set_agreement
  # Downloading is not plan-gated: the document is the landlord's own data, so a
  # downgraded (free) landlord keeps access to it. Only attaching and deleting —
  # the managing capability — require a paid plan.
  before_action :ensure_lease_document_allowed, only: [:create, :destroy]

  # Streams the lease through the app, scoped to this landlord's agreement,
  # rather than exposing a raw ActiveStorage URL — so the file stays behind
  # the tenancy boundary.
  def show
    unless @agreement.lease_document.attached?
      redirect_to property_rental_agreement_path(@property, @agreement),
        alert: t("rental_agreements.lease_document.errors.missing")
      return
    end

    send_data @agreement.lease_document.download,
      filename: @agreement.lease_document.filename.to_s,
      content_type: @agreement.lease_document.content_type,
      disposition: "attachment"
  end

  # A document must be deleted before a different one can be uploaded, so there
  # is never a silent replace.
  def create
    if @agreement.lease_document.attached?
      redirect_to property_rental_agreement_path(@property, @agreement),
        alert: t("rental_agreements.lease_document.errors.already_present")
      return
    end

    if @agreement.update(lease_document_params)
      redirect_to property_rental_agreement_path(@property, @agreement),
        notice: t("rental_agreements.lease_document.uploaded")
    else
      load_agreement_show_data
      render template: "rental_agreements/show", status: :unprocessable_entity
    end
  end

  def destroy
    @agreement.lease_document.purge
    redirect_to property_rental_agreement_path(@property, @agreement),
      notice: t("rental_agreements.lease_document.deleted")
  end

  private

  def lease_document_params
    params.require(:rental_agreement).permit(:lease_document)
  end

  def ensure_lease_document_allowed
    require_landlord_feature(
      allowed: current_landlord.lease_document_allowed?,
      fallback: property_rental_agreement_path(@property, @agreement),
      message_key: "rental_agreements.lease_document.errors.plan_limit"
    )
  end
end

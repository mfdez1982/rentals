require "rails_helper"

RSpec.describe "LeaseDocuments", type: :request do
  let(:user) { create(:user) }
  let(:landlord) { user.landlord }
  let(:property) { create(:property, landlord: landlord) }
  let(:agreement) { create(:rental_agreement, property: property) }
  let(:pdf) { fixture_file_upload("lease.pdf", "application/pdf") }

  before do
    Flipper.enable_group(:lease_document, :pro_and_up)
    landlord.update!(plan: :pro)
    sign_in user
  end

  after { Flipper.remove(:lease_document) }

  describe "POST create" do
    it "attaches a PDF lease document" do
      post property_rental_agreement_lease_document_path(property, agreement),
           params: { rental_agreement: { lease_document: pdf } }

      expect(agreement.reload.lease_document).to be_attached
      expect(response).to redirect_to(property_rental_agreement_path(property, agreement))
    end

    it "rejects an upload when a document is already attached" do
      original = agreement.lease_document.attach(pdf) && agreement.lease_document.blob.id
      post property_rental_agreement_lease_document_path(property, agreement),
           params: { rental_agreement: { lease_document: fixture_file_upload("lease.pdf", "application/pdf") } }

      expect(agreement.reload.lease_document.blob.id).to eq(original)
      expect(response).to redirect_to(property_rental_agreement_path(property, agreement))
      expect(flash[:alert]).to be_present
    end

    it "rejects a non-PDF file and re-renders with an error" do
      post property_rental_agreement_lease_document_path(property, agreement),
           params: { rental_agreement: { lease_document: fixture_file_upload("not_a_pdf.txt", "text/plain") } }

      expect(agreement.reload.lease_document).not_to be_attached
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "cannot upload to another landlord's agreement" do
      other_agreement = create(:rental_agreement)
      expect {
        post property_rental_agreement_lease_document_path(other_agreement.property, other_agreement),
             params: { rental_agreement: { lease_document: pdf } }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "is blocked for a free landlord" do
      landlord.update!(plan: :free)
      post property_rental_agreement_lease_document_path(property, agreement),
           params: { rental_agreement: { lease_document: pdf } }

      expect(agreement.reload.lease_document).not_to be_attached
      expect(response).to redirect_to(property_rental_agreement_path(property, agreement))
      expect(flash[:alert]).to be_present
    end
  end

  describe "GET show (download)" do
    it "streams the attached lease as a PDF attachment" do
      agreement.lease_document.attach(pdf)
      get property_rental_agreement_lease_document_path(property, agreement)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
      expect(response.headers["Content-Disposition"]).to include("attachment")
    end

    it "redirects when nothing is attached" do
      get property_rental_agreement_lease_document_path(property, agreement)
      expect(response).to redirect_to(property_rental_agreement_path(property, agreement))
    end

    it "still lets a downgraded free landlord download their own document" do
      agreement.lease_document.attach(pdf)
      landlord.update!(plan: :free)
      get property_rental_agreement_lease_document_path(property, agreement)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
    end

    it "cannot download another landlord's lease" do
      other_agreement = create(:rental_agreement)
      other_agreement.lease_document.attach(pdf)
      expect {
        get property_rental_agreement_lease_document_path(other_agreement.property, other_agreement)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "DELETE destroy" do
    it "purges the lease document" do
      agreement.lease_document.attach(pdf)
      delete property_rental_agreement_lease_document_path(property, agreement)

      expect(agreement.reload.lease_document).not_to be_attached
      expect(response).to redirect_to(property_rental_agreement_path(property, agreement))
    end
  end
end

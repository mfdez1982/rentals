require 'rails_helper'

RSpec.describe Note, type: :model do
  let(:landlord) { create(:landlord) }
  let(:property) { create(:property, landlord: landlord) }
  let(:rental_agreement) { create(:rental_agreement, property: property) }

  describe "associations" do
    it "belongs to landlord" do
      note = build(:note, landlord: landlord)
      expect(note.landlord).to eq(landlord)
    end

    it "has optional noteable association" do
      note = build(:note, landlord: landlord, noteable: nil)
      expect(note.noteable).to be_nil
    end
  end

  describe "validations" do
    it "requires landlord_id" do
      note = build(:note, landlord: nil)
      expect(note).not_to be_valid
    end

    it "requires title" do
      note = build(:note, landlord: landlord, title: nil)
      expect(note).not_to be_valid
    end

    it "requires description" do
      note = build(:note, landlord: landlord, description: nil)
      expect(note).not_to be_valid
    end

    it "requires status" do
      note = build(:note, landlord: landlord)
      expect(note.status).to eq("active")
    end

    it "is valid with all required attributes" do
      note = build(:note, landlord: landlord)
      expect(note).to be_valid
    end
  end

  describe "enums" do
    it "has active and completed statuses" do
      expect(Note.statuses).to eq({ "active" => 0, "completed" => 1 })
    end
  end

  describe "#activity?" do
    it "returns true when due_date is set" do
      note = build(:note, landlord: landlord, due_date: 1.day.from_now)
      expect(note.activity?).to be true
    end

    it "returns false when due_date is nil" do
      note = build(:note, landlord: landlord, due_date: nil)
      expect(note.activity?).to be false
    end
  end

  describe "#overdue?" do
    it "returns true when due_date is in the past and status is active" do
      note = build(:note, landlord: landlord, due_date: 1.day.ago, status: :active)
      expect(note.overdue?).to be true
    end

    it "returns false when due_date is in the future" do
      note = build(:note, landlord: landlord, due_date: 1.day.from_now, status: :active)
      expect(note.overdue?).to be false
    end

    it "returns false when status is completed" do
      note = build(:note, landlord: landlord, due_date: 1.day.ago, status: :completed)
      expect(note.overdue?).to be false
    end

    it "returns false when due_date is nil" do
      note = build(:note, landlord: landlord, due_date: nil, status: :active)
      expect(note.overdue?).to be false
    end
  end

  describe "#mark_complete!" do
    it "sets status to completed and sets completed_at" do
      note = create(:note, landlord: landlord, status: :active)
      note.mark_complete!
      expect(note.status).to eq("completed")
      expect(note.completed_at).to be_present
    end
  end

  describe "scopes" do
    before do
      @active_note = create(:note, landlord: landlord, status: :active)
      @completed_note = create(:note, landlord: landlord, status: :completed)
      @overdue_note = create(:note, landlord: landlord, status: :active, due_date: 1.day.ago)
    end

    describe ".active" do
      it "returns only active notes" do
        expect(Note.active).to contain_exactly(@active_note, @overdue_note)
      end
    end

    describe ".completed" do
      it "returns only completed notes" do
        expect(Note.completed).to contain_exactly(@completed_note)
      end
    end

    describe ".overdue" do
      it "returns only overdue active notes" do
        expect(Note.overdue).to contain_exactly(@overdue_note)
      end
    end
  end

  describe "polymorphic associations" do
    it "can be associated with a Landlord" do
      note = create(:note, landlord: landlord, noteable: landlord)
      expect(note.noteable).to eq(landlord)
      expect(note.noteable_type).to eq("Landlord")
    end

    it "can be associated with a Property" do
      note = create(:note, landlord: landlord, noteable: property)
      expect(note.noteable).to eq(property)
      expect(note.noteable_type).to eq("Property")
    end

    it "can be associated with a RentalAgreement" do
      note = create(:note, landlord: landlord, noteable: rental_agreement)
      expect(note.noteable).to eq(rental_agreement)
      expect(note.noteable_type).to eq("RentalAgreement")
    end

    it "can be created without a noteable (general note)" do
      note = create(:note, landlord: landlord, noteable: nil)
      expect(note.noteable).to be_nil
    end
  end
end

require 'rails_helper'

RSpec.describe NotesController, type: :controller do
  include Devise::Test::ControllerHelpers

  let(:user) { create(:user, :landlord) }
  let(:landlord) { user.landlord }
  let(:note) { create(:note, landlord: landlord) }

  before do
    Flipper.enable_group(:notes, :pro_and_up)
    landlord.update!(plan: :premium)
    sign_in user
  end

  after { Flipper.remove(:notes) }

  describe "GET #index" do
    it "returns success" do
      get :index
      expect(response).to have_http_status(:success)
    end

    it "returns all notes by default" do
      active_note = create(:note, landlord: landlord, status: :active)
      completed_note = create(:note, landlord: landlord, status: :completed)

      get :index
      notes = Note.where(landlord: landlord)
      expect(notes).to include(active_note)
      expect(notes).to include(completed_note)
    end

    it "filters by active notes when filter param is set" do
      active_note = create(:note, landlord: landlord, status: :active)
      create(:note, landlord: landlord, status: :completed)

      get :index, params: { filter: "active" }
      notes = Note.where(landlord: landlord).active
      expect(notes).to include(active_note)
    end

    it "filters by completed notes when param is set" do
      create(:note, landlord: landlord, status: :active)
      completed_note = create(:note, landlord: landlord, status: :completed)

      get :index, params: { filter: "completed" }
      notes = Note.where(landlord: landlord).completed
      expect(notes).to include(completed_note)
    end

    it "does not show other landlords' notes" do
      other_user = create(:user, :landlord)
      other_note = create(:note, landlord: other_user.landlord)

      all_notes = Note.where(landlord: landlord)
      expect(all_notes).not_to include(other_note)
    end
  end

  describe "POST #create" do
    let(:valid_params) do
      {
        note: {
          title: "New Note",
          description: "This is a new note"
        }
      }
    end

    it "creates a new note for current landlord" do
      expect {
        post :create, params: valid_params
      }.to change { Note.where(landlord: landlord).count }.by(1)
    end

    it "redirects to notes path" do
      post :create, params: valid_params
      expect(response).to redirect_to(notes_path)
    end

    it "does not create note without title" do
      invalid_params = valid_params.merge(note: { description: "Test" })
      expect {
        post :create, params: invalid_params
      }.not_to change(Note, :count)
    end
  end

  describe "GET #edit" do
    it "redirects when not a turbo frame request" do
      get :edit, params: { id: note.id }
      expect(response).to redirect_to(notes_path)
    end

    it "raises error for other landlords' notes" do
      other_user = create(:user, :landlord)
      other_note = create(:note, landlord: other_user.landlord)

      expect {
        get :edit, params: { id: other_note.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "PATCH #update" do
    let(:update_params) do
      {
        id: note.id,
        note: {
          title: "Updated Title",
          description: "Updated description"
        }
      }
    end

    it "updates the note" do
      patch :update, params: update_params
      note.reload
      expect(note.title).to eq("Updated Title")
    end

    it "redirects to notes path" do
      patch :update, params: update_params
      expect(response).to redirect_to(notes_path)
    end
  end

  describe "PATCH #mark_complete" do
    let(:active_note) { create(:note, landlord: landlord, status: :active) }

    it "marks note as completed" do
      patch :mark_complete, params: { id: active_note.id }
      active_note.reload
      expect(active_note).to be_completed
      expect(active_note.completed_at).to be_present
    end

    it "redirects to notes path" do
      patch :mark_complete, params: { id: active_note.id }
      expect(response).to redirect_to(notes_path)
    end
  end

  describe "DELETE #destroy" do
    it "deletes the note" do
      note_to_delete = create(:note, landlord: landlord)
      note_id = note_to_delete.id
      delete :destroy, params: { id: note_id }
      expect(Note.where(id: note_id)).not_to exist
    end

    it "redirects to notes path" do
      delete :destroy, params: { id: note.id }
      expect(response).to redirect_to(notes_path)
    end
  end

  describe "authorization" do
    it "requires user to be signed in" do
      sign_out user
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context "when the landlord is on the free plan" do
    before { landlord.update!(plan: :free) }

    it "still lists notes" do
      note
      get :index
      expect(response).to have_http_status(:success)
    end

    it "blocks creating a note" do
      expect {
        post :create, params: { note: { title: "New Note", description: "desc" } }
      }.not_to change(Note, :count)
      expect(response).to redirect_to(notes_path)
    end

    it "blocks updating a note" do
      patch :update, params: { id: note.id, note: { title: "Updated" } }
      expect(note.reload.title).not_to eq("Updated")
      expect(response).to redirect_to(notes_path)
    end

    it "blocks marking a note complete" do
      patch :mark_complete, params: { id: note.id }
      expect(note.reload).not_to be_completed
      expect(response).to redirect_to(notes_path)
    end

    it "blocks deleting a note" do
      note_id = note.id
      expect {
        delete :destroy, params: { id: note_id }
      }.not_to change(Note, :count)
      expect(response).to redirect_to(notes_path)
    end
  end
end

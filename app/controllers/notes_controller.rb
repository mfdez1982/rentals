class NotesController < ApplicationController
  before_action :set_note, only: [:edit, :update, :mark_complete, :destroy]
  before_action :ensure_notes_allowed, only: [:create, :edit, :update, :mark_complete, :destroy]
  before_action -> { redirect_unless_turbo_frame_request(notes_path) }, only: [:edit]

  def index
    @notes = current_landlord.notes.order(due_date: :asc, created_at: :desc)
    @new_note = Note.new(landlord: current_landlord)
  end

  def create
    @note = Note.new(note_params.merge(landlord: current_landlord))
    if @note.save
      redirect_back_or_to notes_path
    else
      redirect_back_or_to notes_path, alert: t("notes.creation_failed")
    end
  end

  def edit
    @return_frame = params[:frame]
  end

  def update
    if @note.update(note_params)
      redirect_back_or_to notes_path, notice: t("notes.updated")
    else
      # The edit form's own turbo_frame target (set from @return_frame) only
      # covers the success/redirect path. On failure we patch the edit modal
      # directly via a turbo stream so it works regardless of which page
      # (the /notes index, a property page, or an agreement page) the note
      # was opened from.
      render turbo_stream: turbo_stream.replace(
        "note_edit_frame",
        partial: "notes/edit_modal_content",
        locals: { note: @note, return_frame: params[:frame] }
      ), status: :unprocessable_entity
    end
  end

  def mark_complete
    @note.mark_complete!
    redirect_back_or_to notes_path, notice: t("notes.marked_complete")
  end

  def destroy
    @note.destroy
    redirect_back_or_to notes_path, notice: t("notes.deleted")
  end

  private

  def set_note
    @note = current_landlord.notes.find(params[:id])
  end

  def ensure_notes_allowed
    unless current_landlord.notes_allowed?
      redirect_back_or_to notes_path, alert: t("notes.errors.plan_limit")
    end
  end


  def note_params
    params.require(:note).permit(:title, :description, :due_date, :noteable_type, :noteable_id)
  end
end

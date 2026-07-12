class NotesController < ApplicationController
  before_action :set_note, only: [:edit, :update, :mark_complete, :destroy]

  def index
    @notes = Note.where(landlord: current_landlord).order(due_date: :asc, created_at: :desc)
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
    redirect_unless_turbo_frame_request(notes_path)
  end

  def update
    if @note.update(note_params)
      redirect_back_or_to notes_path, notice: t("notes.updated")
    else
      render :edit, status: :unprocessable_entity
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
    @note = Note.where(landlord: current_landlord).find(params[:id])
  end


  def note_params
    params.require(:note).permit(:title, :description, :due_date, :noteable_type, :noteable_id)
  end
end

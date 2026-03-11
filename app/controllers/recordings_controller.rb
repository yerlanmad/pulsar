class RecordingsController < ApplicationController
  def index
    authorize Recording
    @recordings = Recording.includes(call_record: %i[agent queue_config]).recent

    if params[:search].present?
      @recordings = @recordings.joins(:call_record)
        .where("call_records.caller_number LIKE :q OR call_records.destination_number LIKE :q",
               q: "%#{params[:search]}%")
    end

    if params[:agent_id].present?
      @recordings = @recordings.joins(:call_record).where(call_records: { agent_id: params[:agent_id] })
    end

    if params[:date_from].present?
      @recordings = @recordings.where(created_at: Date.parse(params[:date_from]).beginning_of_day..)
    end
    if params[:date_to].present?
      @recordings = @recordings.where(created_at: ..Date.parse(params[:date_to]).end_of_day)
    end

    @recordings = @recordings.limit(100)
    @agents = Agent.order(:name)
  end

  def show
    @recording = Recording.includes(call_record: %i[agent queue_config]).find(params[:id])
    authorize @recording
  end

  def stream
    recording = Recording.find(params[:id])
    authorize recording, :show?

    if recording.file_path.present? && File.exist?(recording.file_path)
      send_file recording.file_path, type: "audio/wav", disposition: "inline"
    else
      head :not_found
    end
  end
end

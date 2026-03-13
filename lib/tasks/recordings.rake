namespace :recordings do
  desc "Import existing recording files that have no database records"
  task import: :environment do
    recordings_path = ENV.fetch("ASTERISK_RECORDINGS_PATH", "/rails/recordings")

    unless Dir.exist?(recordings_path)
      puts "Recordings directory not found: #{recordings_path}"
      next
    end

    imported = 0
    skipped = 0

    Dir.glob(File.join(recordings_path, "*.wav")).each do |file_path|
      filename = File.basename(file_path, ".wav")
      file_size = File.size(file_path)

      # Skip empty recordings (44 bytes = WAV header only)
      if file_size <= 44
        skipped += 1
        next
      end

      # Check if recording already exists
      next if Recording.joins(:call_record).exists?(call_records: { uniqueid: filename })

      # Create call record if missing
      call_record = CallRecord.find_or_create_by!(uniqueid: filename) do |r|
        r.status = :completed
        r.started_at = File.birthtime(file_path) rescue File.mtime(file_path)
        r.ended_at = File.mtime(file_path)
        r.caller_number = "unknown"
        r.destination_number = "unknown"
      end

      # Calculate duration from file size (8kHz, 16-bit mono PCM = 16000 bytes/sec)
      duration = (file_size - 44) / 16_000

      Recording.create!(
        call_record: call_record,
        file_path: file_path,
        file_size: file_size,
        duration: duration
      )

      imported += 1
      puts "Imported: #{filename} (#{(file_size / 1024.0).round(1)} KB, #{duration}s)"
    end

    puts "\nDone: #{imported} imported, #{skipped} skipped (empty)"
  end
end

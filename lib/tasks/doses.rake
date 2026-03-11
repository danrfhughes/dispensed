namespace :doses do
  desc "Generate doses for today (and optionally catch up from a given date)"
  task :generate, [:from_date] => :environment do |_, args|
    from = args[:from_date] ? Date.parse(args[:from_date]) : Date.current
    to   = Date.current

    (from..to).each do |date|
      puts "Generating doses for #{date}..."
      GenerateDailyDosesJob.new.perform(date)
    end

    puts "Done."
  end
end

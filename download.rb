require 'json'
require 'parallel'

puts 'Please input your document.cookie. You can do this by opening your browser console on in tmc.mooc.fi and typing "document.cookie". Please paste the content of the cookie here without the surrounding quotes.'
cookie = gets.strip

puts 'Course id?'
course_id = gets.strip

folder = "#{course_id}-submissions"

`mkdir -p "#{folder}"`

Dir.chdir folder.to_s do
  current_dir = `pwd`
  puts "Downloading all submissions to #{current_dir}"
  puts 'Fetching list of submissions...'
  info = `curl -s 'https://tmc.mooc.fi/api/v8/courses/#{course_id}/submissions' -H  'Accept: application/json' -H 'Cookie: #{cookie}'`
  submissions = JSON.parse(info)
  File.write('submissions.json', JSON.pretty_generate(submissions))
  puts 'Fetching exercise information...'
  exercise_info = `curl -s 'https://tmc.mooc.fi/api/v8/courses/#{course_id}/exercises' -H  'Accept: application/json' -H 'Cookie: #{cookie}'`
  exercises = JSON.parse(exercise_info)
  File.write('exercises.json', JSON.pretty_generate(exercises))
  submissions.group_by { |o| o['exercise_name'] }.each do |exercise_name, exercise_submissions|
    if File.exist? "#{exercise_name}/done"
      puts "Skipping download for #{exercise_name}"
      next
    end
    puts "Downloading submissions for #{exercise_name}"
    exercise_submissions.group_by { |o| o['user_id'] }.each do |user_id, user_submissions|
      download_folder = "#{exercise_name}/user-#{user_id}"
      Parallel.each(user_submissions, in_processes: 8) do |submission|
        if File.exist? "#{download_folder}/submission-#{submission['id']}.zip"
          print '#'
          next
        end
        `mkdir -p "#{download_folder}"`
        Dir.chdir(download_folder) do
          `curl -s 'https://tmc.mooc.fi/api/v8/core/submissions/#{submission['id']}/download' -H  'Accept: application/json' -H 'Cookie: #{cookie}' --output "submission-#{submission['id']}.zip.tmp"`
          # Use the below for full zip
          # `curl -s 'https://tmc.mooc.fi/submissions/#{submission['id']}/full_zip' -H  'Accept: application/json' -H 'Cookie: #{cookie}' --output "submission-#{submission['id']}.zip.tmp"`
          File.rename("submission-#{submission['id']}.zip.tmp", "submission-#{submission['id']}.zip")
          print('.')
        end
      end
    end
    File.write("#{exercise_name}/done", "")
  end
end

puts "All done!"

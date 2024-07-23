require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def clean_phonenumber(phonenumber)
  p = phonenumber.to_s.scan(/\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/).map { |num| num.gsub(/\D/, '') }[0]
  n = p != nil && p.length
  return p if n == 10
  return p.slice(1,n) if n == 11 && p[0] == "1"
  "bad number"
  
end 


class OptimumTime
  
  def initialize
    @regdates = Array.new
  end  

  def add_regdate(regdate)
    @regdates << regdate
  end

  def peak_hours
    hourly_counts = count_hour_frequency
    hourly_counts.select { |hour,count| count == hourly_counts.values.max }
  end 

  def peak_days
    daily_counts = count_day_frequency
    daily_counts.select { |day,count| count == daily_counts.values.max }
  end 

  private
  def parsed_regdates
    @regdates.map do |regdate|
      Time.strptime(regdate, "%m/%d/%y %H:%M")
    end
  end
  def count_hour_frequency
    hours = parsed_regdates.map(&:hour)
    hours.reduce(Hash.new(0)) do |hash,hour|
      hash[hour] += 1
      hash
    end   
  end 

  def count_day_frequency
    days = parsed_regdates.map(&:wday)
    days.reduce(Hash.new(0)) do |hash,day|
      hash[day] += 1
      hash
    end 
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

optimum_time = OptimumTime.new

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)



template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  phonenumber = clean_phonenumber(row[:homephone])
  puts phonenumber
  optimum_time.add_regdate(row[:regdate])
  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)
end


puts "Peak registration hours: #{optimum_time.peak_hours.keys} with #{optimum_time.peak_hours.values.first} registrations each"
puts "Peak registration days: #{optimum_time.peak_days.keys} with #{optimum_time.peak_days.values.first} registrations each"

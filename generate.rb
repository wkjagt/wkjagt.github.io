require 'erb'
require 'rmagick'
require 'pry'
require 'ostruct'

TEMPLATE_FILE_NAME = 'index.html.erb'
OUTPUT_FILE_NAME = 'generated.html'
RESIZE=false

title="Willem's Photos"
fulls = Dir["./images/fulls/*"]

files = fulls.map.with_index do |file, i|
  base_name = File.basename(file)
  if RESIZE
    puts("#{i+1} of #{fulls.size}")
  	img = Magick::Image.read(file).first
    resized = img.resize_to_fit(200)
    resized.write("./images/thumbs/#{base_name}")
  end
  OpenStruct.new(
    name: base_name
  )
end


template = ERB.new(File.read(TEMPLATE_FILE_NAME))
output = template.result(binding)

File.open(OUTPUT_FILE_NAME, 'w') { |file| file.write(output) }
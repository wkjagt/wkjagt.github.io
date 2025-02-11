require 'erb'
require 'rmagick'
require 'pry'
require 'ostruct'

TEMPLATE_FILE_NAME = 'index.html.erb'
OUTPUT_FILE_NAME = 'index.html'
RESIZE=true

title="willems.photos"
fulls = Dir["./images/fulls/*"]


files = fulls.map.with_index do |file, i|
  base_name = File.basename(file)
  img = Magick::Image.read(file).first
  orientation = img.columns > img.rows ? "horizontal" : "vertical"
  if RESIZE
    puts("#{i+1} of #{fulls.size}")
    resized = img.resize_to_fit(200)
    resized.write("./images/thumbs/#{base_name}")
  end
  OpenStruct.new(
    name: base_name,
    orientation: orientation
  )
end.sort_by do |f|
  Integer(f.name.split("-").first.to_i)
end.reverse

template = ERB.new(File.read(TEMPLATE_FILE_NAME))
output = template.result(binding)

File.open(OUTPUT_FILE_NAME, 'w') { |file| file.write(output) }
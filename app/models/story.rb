class Story < ApplicationRecord
  
  IMAGE_STYLES = {
     thumb:    { resize: "240x135" }
   }.freeze

  validates_presence_of    :headline,
                           :description,
                           :link,
                           :image

  image_accessor :image

  def image_url(style = :thumb)
    if style == :original
      self.image.remote_url
    else
      process_image(style).url
    end
  end
  
  private
    def process_image(style) 
      self.image.process(:auto_orient).thumb(Story::IMAGE_STYLES[style][:resize])
    end

end

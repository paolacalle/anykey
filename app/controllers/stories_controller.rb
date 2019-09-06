class StoriesController < ApplicationController
  
  layout "backstage"
  
  before_action :authenticate_user!,        only: [ :new, :create, :edit, :update ]
  before_action :ensure_staff,              only: [ :new, :create, :edit, :update ]
  before_action :find_story,                only: [ :edit, :update ]
  
  def index
    @stories = Story.all
    
    if public_view?
      render action: "public_index", layout: "application"
    else
      authenticate_user!
      ensure_staff
    end  
  end
  
  def new
    @story = Story.new
  end
  
  def create
    @story = Story.new(story_params)
  
    if @story.save
      flash[:notice] = "You've added a new story."
      redirect_to stories_path
    else      
      flash.now[:alert] ||= ""
      @story.errors.full_messages.each do |message|
        flash.now[:alert] << message + ". "
      end      
      render(action: :new)
    end
  end
  
  def edit
  end
  
  def update
    if @story.update_attributes(story_params)
      flash[:notice] = "Your successfully updated the story."
      redirect_to edit_story_path(@story)
    else
      flash.now[:alert] ||= ""
      @story.errors.full_messages.each do |message|
        flash.now[:alert] << message + ". "
      end
      render(action: :edit)
    end
  end
  
  protected
    def find_story
      @story = Story.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to staff_index_path
    end
    
    def public_view?
      current_user == nil
    end

  private
    def ensure_staff
      unless current_user.is_moderator? || current_user.is_admin?
        redirect_to root_url
      end
    end
    
    def story_params
      params.require(:story).permit(:headline, :description, :link, :image)
    end
    
end

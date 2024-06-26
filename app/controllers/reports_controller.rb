class ReportsController < ApplicationController
  include RateLimitable
  require 'tf-idf-similarity'
  require 'matrix'

  layout "backstage",                       only: [ :index, :show ]
  
  skip_before_action :verify_authenticity_token, only: [ :watch, :unwatch, :twitch_lookup ]
  
  before_action :authenticate_user!,        only: [ :index, :show, :dismiss, :undismiss, :watch, :unwatch, :unspam, :spam]
  before_action :ensure_staff,              only: [ :index, :show, :dismiss, :undismiss, :watch, :unwatch, :unspam, :spam]
  before_action :find_report,               only: [ :show, :dismiss, :undismiss, :watch, :unwatch, :unspam, :spam]
  # after_action :check_report_matches, only: [ :create]
  around_action :display_timezone

  def index
    # f is used to filter reports by scope
    # q is used to search for keywords
    # o is used to toggle ordering
    if params[:f].present? && Report::SORT_FILTERS.key?(params[:f].to_sym)
      @filter_category = params[:f]
    elsif params[:q].present?
      @filter_category = "all"
    else
      @filter_category = "unresolved"
    end
    
    if params[:o].present? && params[:o] == "asc"
      @ordering = "asc"
    else
      @ordering = "desc"
    end
    
    if params[:q].present?
      @pagy, @reports = eval("pagy(Report.#{@filter_category}.search('#{params[:q]}').order(created_at: :#{@ordering}))")
    else
      @pagy, @reports = eval("pagy(Report.#{@filter_category}.order(created_at: :#{@ordering}))")
    end
  end
  
  def show
    @pledge = @report.reported_pledge
    @reporter_pledge = @report.reporter_pledge
    @related_reports = @report.related_reports
    @spam_reports = @report.related_spam_reports
  end
  
  def new
    @report = Report.new
  end

  def create
    @report = Report.new(report_params)

    # First check IP-based rate limiting
    return unless limit_request_by_ip('report_create', new_report_path)

    # Fallback to device signature-based limiting (may not be needed)
    return unless limit_request_by_signature('report_create', new_report_path)

    puts "here"
    # Lookup Twitch IDs (if not fetched via Ajax)
    if @report.reporter_twitch_name && @report.reporter_twitch_id.blank?
      @report.reporter_twitch_id = lookup_twitch_id(@report.reporter_twitch_name)
    end
    
    if @report.reported_twitch_name && @report.reported_twitch_id.blank?
      @report.reported_twitch_id = lookup_twitch_id(@report.reported_twitch_name)
    end
    
    if @report.incident_stream && @report.incident_stream_twitch_id.blank?
      @report.incident_stream_twitch_id = lookup_twitch_id(@report.incident_stream)
    end
    
    if @report.save
      # Email notification to staff
      StaffMailer.notify_staff_new_report(@report).deliver_now
      
      # Send confirmation receipt to reporter
      PledgeMailer.confirm_receipt(@report).deliver_now
      
      flash[:notice] = "You've successfully submitted the report. Thank you."
      check_report_matches()

      redirect_to root_path
    else      
      flash.now[:alert] ||= ""
      @report.errors.full_messages.each do |message|
        flash.now[:alert] << message + ". "
      end      
      render(action: :new)
    end
  end

  def dismiss
    @report.dismissed = true
    @report.reviewer = current_user
    if @report.save
      flash[:notice] = "You dismissed the report about #{@report.reported_twitch_name}."
    end
    redirect_to reports_path
  end
  
  def undismiss
    @report.dismissed = false
    @report.reviewer = nil
    if @report.save
      flash[:notice] = "You undismissed the report about #{@report.reported_twitch_name}. It can now be reviewed again."
      redirect_to report_path(@report)
    else    
      redirect_to reports_path
    end
  end
  
  def watch
    respond_to do |format|
      if @report.update(watched: true)
        format.js
      end
    end
  end

  def unwatch
    respond_to do |format|
      if @report.update(watched: false)
        format.js
      end
    end
  end

  def spam 
    if @report.update(spam: true)
      flash[:success] = "Report has been marked as spam."
    else
      flash[:error] = "Unable to update the report."
    end
    
    redirect_to report_path(@report)
  end 

  def unspam
    if @report.update(spam: false)
      flash[:success] = "Report has been marked as not spam."
    else
      flash[:error] = "Unable to update the report."
    end
    redirect_to report_path(@report)
  end

  
  def twitch_lookup
    if params[:twitch_username].blank?
      render :json => { error: 'The request must contain a Twitch username', code: '400' }, :status => 400
    else
      twitch_id = lookup_twitch_id(params[:twitch_username])
      if twitch_id.nil?
        render :json => { error: 'Twitch username not found', code: '404' }, :status => 404
      else
        render :json => { twitch_id: twitch_id }, :status => 200
      end
    end
  end
  
  protected
    def lookup_twitch_id(twitch_username)
      # Only lookup IDs for valid Twitch usernames (4-25 alphanumeric incl. underscore)
      if twitch_username.match? /^([A-Za-z0-9_]{4,25})$/
        url      = "#{ENV['TWITCH_API_BASE_URL']}/users?login=#{twitch_username}"
        headers  = {"Client-ID": ENV['TWITCH_CLIENT_ID'], "Authorization": "Bearer #{TwitchToken.first.valid_token!}"}
        response = HTTParty.get(URI::Parser.new.escape(url), headers: headers)
      
        if !response["data"].blank?
          return response["data"][0]["id"]
        end
      end
      return nil
    end
    
    def find_report
      @report = Report.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to staff_index_path
    end

    def check_report_matches
      time_threshold = 2.hour
      current_time = Time.current
      time_window_start = current_time - time_threshold
      time_window_end = current_time + time_threshold

      potential_matches = Report.where(
        reporter_email: @report.reporter_email,
        reported_twitch_id: @report.reported_twitch_id,
        created_at: time_window_start..time_window_end # time range
      )
      
      # mark as spam based on a similarity threshold
      spam_found = false
      potential_matches.find_each do |match|
        if match != @report
        score, spam_report = similarity_score(@report, match)

          if score >= 0.70
            if spam_report.save
              match.update(spam: true, dismissed: false, warned: false, revoked: false, watched: false)
              spam_found = true
              puts "SpamReport created successfully."
            else
              puts "Failed to create SpamReport: #{spam_report.errors.full_messages.join(", ")}"
            end

          end

        end
      end

      if spam_found
        @report.update(spam: true, dismissed: false, warned: false, revoked: false, watched: false)
      end
    end

    def similarity_score(report1, report2)
      description_similarity = text_similarity(report1.incident_description, report2.incident_description)
    
      # recommended_response_similarity based on whether the responses exist

      if report1.recommended_response.blank? && report2.recommended_response.blank?
        recommended_response_similarity = 1.0  # nil values as a perfect match

      elsif !report1.recommended_response.blank? && !report2.recommended_response.blank?
        recommended_response_similarity = text_similarity(report1.recommended_response, report2.recommended_response)
      else
        recommended_response_similarity = 0 
      end
    
      # weighted avg of both where required weighs more
      spam_info_value = "Description Simillarity of #{description_similarity} and Recommend Simillarity of #{recommended_response_similarity} for #{report1.id} & #{report2.id}"
      
      # flash[:notice] << spam_info_value

      spam_report = SpamReport.new(
        description: spam_info_value,
        report1: report1,
        report2: report2
      )
      

      return (description_similarity + recommended_response_similarity)/2, spam_report

    end

    def text_similarity(text1, text2)

      documents = [
        TfIdfSimilarity::Document.new(text1),
        TfIdfSimilarity::Document.new(text2)
      ]

      model = TfIdfSimilarity::TfIdfModel.new(documents)
      matrix = model.similarity_matrix

      return matrix[0, 1]
    end

  private          
    def ensure_staff
      unless current_user.is_moderator? || current_user.is_admin?
        redirect_to root_url
      end
    end
    
    def display_timezone
      timezone = Time.find_zone( cookies[:browser_timezone] )
      Time.use_zone(timezone) { yield }
    end
    
    def report_params
      params.require(:report).permit(:reporter_email, :reporter_twitch_name, :reporter_twitch_id, :reported_twitch_name, :reported_twitch_id, :incident_stream, :incident_stream_twitch_id, :incident_occurred, :incident_description, :recommended_response, :image,)
    end
end

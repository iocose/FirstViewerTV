#/usr/bin/ruby
require 'rubygems'
require 'google/api_client'
require 'trollop'
require 'open-uri'
require 'logger'

DEVELOPER_KEY = File.open('DEVELOPER_KEY', 'r') { |f| f.read }
YOUTUBE_API_SERVICE_NAME = 'youtube'
YOUTUBE_API_VERSION = 'v3'

APPLICATION_NAME = "yourub"
APPLICATION_VERSION = "0.1"

class FirstViewer
  def initialize ()
    @log = Logger.new('firstviewer.log','daily')		    
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    @nations =['AE','AR','AU','BD','BE','BR','CA','CL','CO','CZ','DE','DK',
                'DZ','EG','ES','ET','FR','GB','GH','GR','HK','HR','HU',
                'ID','IE','IL','IN','IS','IT','JO','JP','KE','KR','LT',
                'LV','MA','MX','MY','NG','NL','NZ','PE','PH','PK','PL',
                'RO','RU','SA','SE','SG','SK','SN','TN','TR','TW',
                'UA','UG','US','YE','ZA']
    #in the API v3 the regionCode seems to be ignored, we define US as default
    @nation = 'US'
    @categories = retrieve_categories
    @options = default_search_options
    @videos = Array.new
    self.search
  end

  def client
    @client ||= Google::APIClient.new(
      :key => DEVELOPER_KEY,
      :application_name => APPLICATION_NAME,
      :application_version => APPLICATION_VERSION, 
      :authorization => nil,
    )
  end

  def youtube
    youtube = self.client.discovered_api(YOUTUBE_API_SERVICE_NAME, YOUTUBE_API_VERSION)
  end

  def categories_request
    categories_list = self.client.execute!(
      :api_method => youtube.video_categories.list,
      :parameters => {"part" => "snippet","regionCode" => @nation }
    )
  end

  def retrieve_categories
    categories = []
    self.categories_request.data.items.each do |cat_result|
      categories.push cat_result["id"]
    end
    return categories
  end

  def default_search_options
    opts = Trollop::options do
      opt :maxResults, 'Max results', :type => :int, :default => 20
      opt :regionCode, 'Nation', :type => String, :default => 'US'
      opt :type, 'Type', :type => String, :default => 'video'
      opt :order, 'Order', :type => String, :default => 'date'
      opt :safeSearch, 'Safe Search', :type => String, :default => 'none'
      opt :videoCategoryId, 'Video Category Id', :type => String, :default => '10'
      #opt :publishedAfter, 'Start date, in YYYY-MM-DD format', :type => String, :default => one_day_ago
    end
  end

  def search
    @log.info('initialize') { "Starting research..." }
    #@nations.shuffle!
    #@nations.each do |n|
      @categories.each do |category_id|
        @options[:videoCategoryId] = category_id
        @options[:part] = 'id'
        search_response = client.execute!(
          :api_method => youtube.search.list,
          :parameters => @options
        )
        self.read_response search_response
      end
    #end
  end

  def read_response(search_response)
    search_response.data.items.each do |search_result|
      get_videos_info search_result.id.videoId
    end
  end

  def video_params(result_video_id)
    fields = 'items(snippet(title,thumbnails),statistics(viewCount))'
    parameters = {
      :id => result_video_id, 
      :part => 'statistics,snippet',
      :fields => URI::encode(fields)
    }
  end

  def get_videos_info(result_video_id)
    params = self.video_params(result_video_id)
    video_response = client.execute!(
      :api_method => youtube.videos.list,
      :parameters => params
    )
    store_video(result_video_id, video_response)
  end

  def store_video(video_id, video_response)
    begin
    result = JSON.parse(video_response.data.to_json) 
    entry = result['items'].first
    n_view = entry['statistics']['viewCount'].to_i
    if n_view == 0 || entry['statistics'].nil?
      puts video_id
      video_url = 'https://www.youtube.com/watch?v='<< video_id
      video_title = entry['snippet']['title']
      @videos.push({'title' => video_title, 'url' => video_url})
    end
    rescue
      @log.error "impossible to retrieve the video"
    end
  end

  def save_to_file(file_path)
    if File.exist?(file_path)
      @log.info "Found #{ @videos.length } videos."
      #adding tv callback for jsonp
      @videos = "tv(" + @videos.to_json + ")";
      File.open(file_path,"w") do |f|
        f.write(@videos)
      end
    else
      @log.error "the file doesnt exists"
    end
  end

end

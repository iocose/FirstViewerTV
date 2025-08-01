#/usr/bin/ruby
require 'rubygems'
require 'google/apis/youtube_v3'
require 'optimist'
require 'open-uri'
require 'logger'

DEVELOPER_KEY = File.open('DEVELOPER_KEY', 'r') { |f| f.read }

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
    @client ||= begin
      service = Google::Apis::YoutubeV3::YouTubeService.new
      service.key = DEVELOPER_KEY
      service
    end
  end

  def categories_request
    client.list_video_categories('snippet', region_code: @nation)
  end

  # def retrieve_categories
  #   categories = []
  #   self.categories_request.data.items.each do |cat_result|
  #     categories.push cat_result["id"]
  #   end
  #   return categories
  # end
  #

  def retrieve_categories
    cache_file = 'categories_cache.json'
    if File.exist?(cache_file)
      return JSON.parse(File.read(cache_file))
    end

    categories = []
    categories_request.items.each do |cat_result|
      categories << cat_result.id
    end
  
    File.write(cache_file, categories.to_json)
    categories
  end

  def default_search_options
    opts = Optimist::options do
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
      # we are getting out of usage quota. Sample just two categories
      #@categories.each do |category_id|
      @categories.sample(2).each do |category_id|
        @options[:videoCategoryId] = category_id
        @options[:part] = 'id'
        search_response = client.list_searches('id', @options)
        self.read_response search_response
      end
    #end
  end

  def read_response(search_response)
    search_response.items.each do |search_result|
      next unless search_result.id&.video_id
      get_videos_info search_result.id.video_id
    end
  end

  def video_params(result_video_id)
    {
      id: result_video_id,
      fields: 'items(snippet(title,thumbnails),statistics(viewCount))'
    }
  end

  def get_videos_info(result_video_id)
    params = video_params(result_video_id)
    video_response = client.list_videos('snippet,statistics', **params)
    store_video(result_video_id, video_response)
  end

  def store_video(video_id, video_response)
    begin
    result = JSON.parse(video_response.to_json)
    entry = result['items'].first

    if entry['statistics'].nil?
      return
    end

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

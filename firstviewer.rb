#/usr/bin/ruby
require 'rubygems'
require 'json'
require 'logger'
require 'open-uri'

class FirstViewer
  def initialize ()
    #logger
    @log = Logger.new('/yourpath/firstview.log','daily')		    
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    #youtube API standard feed
    @api_url = "https://gdata.youtube.com/feeds/api/standardfeeds/"
    #most recent feed 
    @most_recent = "/most_recent_"
    #path of the json output file
    @output_path = '/yourpath/apis/firstview.json'
    #API version 2, output in json format
    @json = "?v=2&alt=json&prettyprint=true"
    @nations =['AE','AR','AU','BD','BE','BG','BR','CA','CL','CO','CZ','DE','DK',
                'DZ','EE','EG','ES','ET','FI','FR','GB','GH','GR','HK','HR','HU',
                'ID','IE', 'IL','IN','IR','IS','IT','JO','JP','KE','KR','LT',
                'LV','MA','MX','MY','NG','NL','NO','NZ','PE','PH','PK','PL','PT',
                'RO','RS','RU','SA','SE',' SG','SI','SK','SN','TH','TN','TR','TW',
                'TZ','UA','UG','US','VN','YE','ZA']
    #categories available for the standard feed
    @categories = ['Comedy', 'People', 'Entertainment', 'Music', 'Howto',
                  'Sports', 'Autos', 'Education', 'Film', 'News', 'Animals',
                  'Tech', 'Travel','Games']
    #take only title and youtube url
    #https://developers.google.com/youtube/2.0/developers_guide_protocol#Fields_Formatting_Rules
    @required_fields = "(title,media:group(media:player(@url)))"
    @videos = Array.new
  end

  def search
    @log.info('initialize') { "Starting research..." }
    @nations.shuffle!
    @nations.each do |n|
      @categories.each do |c|
        url = "#{@api_url}" + n + "#{@most_recent}" + c + "#{@json}#{@select_zero_views}#{@required_fields}"
        self.readUrl(url)
      end
    end
  end

  def readUrl(url)
    url = URI.encode(url)
    begin
      page = open(url, :read_timeout => 6).read
      json = JSON.parse(page)
      json['feed']['entry'].each do |v|
        #videos with 0views have no tags <yt:statistics>
        #https://developers.google.com/youtube/2.0/reference#youtube_data_api_tag_yt:statistics
        zero_view = v['yt$statistics'] 
        if (zero_view.nil?)
          self.storeVideo(v)
        end
    end

    rescue Timeout::Error => e
      @log.warn e.to_s + url 
    rescue OpenURI::HTTPError => e
      @log.warn e.to_s + url 
    end
  end

  def storeVideo(entry)
    #check if there is media player tag
    if entry['media$group'].has_key?('media$player')
      videourl = entry['media$group']['media$player']['url']
      videotitle = entry['title']['$t']
      @videos.push({'title' => videotitle, 'url' => videourl})
    end
  end

  def saveToFile
    if File.exist?(@output_path)
      @log.info "Found #{ @videos.length } videos."
      #adding tv callback for jsonp
      @videos = "tv(" + @videos.to_json + ")";
      File.open(@output_path,"w") do |f|
        f.write(@videos)
      end
    else
      @log.error "the file doesnt exists"
    end
  end
end

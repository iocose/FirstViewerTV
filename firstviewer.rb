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
    #available nations on the youtube standard feed    		
    @nations = ['JP', 'MX', 'NL', 'NZ', 'PL', 'RU', 'ZA', 'KR', 'ES', 'SE', 'TW',
               'US','AR','AU','BR','CA','CZ','FR','DE','GB','HK','IN','IE','IL',
               'IT']
    #categories available for the standard feed
    @categories = ['Comedy', 'People', 'Entertainment', 'People', 'Music', 'Howto',
                  'Sports', 'Autos', 'Education', 'Film', 'News', 'Animals',
                  'Tech', 'Travel','Games']
    #take only video with 0views
    #http://code.google.com/apis/youtube/2.0/developers_guide_protocol.html#Submitting_Partial_Feed_Request
    @select_zero_views = "&fields=entry[yt:statistics/@viewCount = 0]"
    #take only title and youtube url
    #http://code.google.com/apis/youtube/2.0/developers_guide_protocol.html#Fields_Formatting_Rules
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
      if json['feed'].has_key?('entry')
        self.storeVideo(json['feed']['entry'])
      end
    rescue Exception => e
      @log.warn e.to_s + url 
    end
  end

  def storeVideo(entry)
    videourl = entry.first['media$group']['media$player']['url']
    videotitle = entry.first['title']['$t']
    @videos.push({'title' => videotitle, 'url' => videourl})
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

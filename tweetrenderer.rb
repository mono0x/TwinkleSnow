
require 'uri'
require 'erubis'

class TweetRenderer

  REPLY_RE = /@([A-Za-z0-9_]+)/
  HASHTAG_RE = /#([A-Za-z0-9_]+)/
  URI_RE = /(#{URI.regexp([ 'http', 'https' ])})/
  BREAK_RE = /(\n)/

  TEXT_RE = /#{REPLY_RE}|#{HASHTAG_RE}|#{BREAK_RE}|#{URI_RE}/

  def initialize
    @eruby = Erubis::Eruby.new(open('view/content.rhtml').read)
  end

  def render(data)
    retweet = data['retweeted_status']
    status = retweet || data

    id = status['id']
    user = status['user']
    screen_name = user['screen_name']
    text = status['text']
    created_at = Time.parse(status['created_at'])
    in_reply_to_status_id = status['in_reply_to_status_id']
    in_reply_to_screen_name = status['in_reply_to_screen_name']

    image_preview = case text
      when %r!http://twitpic\.com/(\w+)!
        create_image_preview(
          "http://twitpic.com/#$1",
          "http://twitpic.com/show/thumb/#$1") 
      when %r!http://yfrog\.com/(\w+)!
        create_image_preview(
          "http://yfrog.com/#$1",
          "http://yfrog.com/#$1.th.jpg")
      when %r!http://movapic\.com/pic/(\w+)!
        create_image_preview(
          "http://movapic.com/pic/#$1",
          "http://image.movapic.com/pic/m_#$1.jpeg",
          :width => 200, :height => 150)
      when %r!http://f\.hatena\.ne\.jp/([A-Za-z0-9])([A-Za-z0-9\-]*)/(\d{8})(\d+)!
        create_image_preview(
          "http://f.hatena.ne.jp/#$1#$2/#$3#$4",
          "http://img.f.hatena.ne.jp/images/fotolife/#$1/#$1#$2/#$3/#$3#{$4}_120.jpg")
      when %r!(http://tweetphoto\.com/\d+)!
        create_image_preview(
          "#$1",
          "http://tweetphotoapi.com/api/TPAPI.svc/imagefromurl?size=thumbnail&url=#$1")
      when %r!http://(?:www\.nicovideo\.jp/watch/|nico\.ms/)sm(\d+)!
        create_image_preview(
          "http://www.nicovideo.jp/watch/sm#$1",
          "http://tn-skr2.smilevideo.jp/smile?i=#$1",
          :width => 200, :height => 150)
      when %r!http://(?:www\.youtube\.com/watch\?.*v=|youtu\.be/)([A-Za-z0-9_-]+)!
        create_image_preview(
          "http://www.youtube.com/watch?v=#$1",
          "http://i.ytimg.com/vi/#$1/3.jpg",
          :width => 200, :height => 150)
    end

    content = text.gsub(TEXT_RE) do
      case
      when $1 then %!@<a target="_blank" href="http://twitter.com/#$1">#$1</a>!
      when $2 then %!<a target="_blank" href="http://search.twitter.com/search?q=%23#$2">\##$2</a>!
      when $3 then '<br />'
      when $4 then %!<a target="_blank" class="external" href="#$4">#$4</a>!
      end
    end

    source = status['source'].gsub(%r!^<a href="(.+)" rel="nofollow">(.+)</a>$!) {
      %!<a target="_blank" href="#$1">#$2</a>!
    }

    @eruby.result(binding)
  end

  private

  def create_image_preview(href, thumbnail, size = {})
    <<-"EOS"
    <a target="_blank" href="#{href}">
      <img src="#{thumbnail}"
      #{ %!width="#{size[:width]}"! if size[:width] }
      #{ %!width="#{size[:height]}"! if size[:height] } />
    </a>
    EOS
  end

end

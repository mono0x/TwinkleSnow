
require 'uri'
require 'rack'
require 'erubis'

class TweetRenderer

  TEXT_RE = Regexp.union([
    %r{@([A-Za-z0-9_]+)},
    %r{#([A-Za-z0-9_]+)},
    %r{(s?https?://[-_.!~*'()a-zA-Z0-9;\/?:\@&=+\$,%#]+)},
    %r{(\n)},
    %r{(\")},
    %r{(\&)},
    %r{(\<)},
    %r{(\>)},
  ])

  def initialize
    @eruby = Erubis::Eruby.new(open('view/content.rhtml').read)
  end

  def render(data)
    retweet = data['retweeted_status']
    status = retweet || data

    id = status['id']
    user = status['user']
    screen_name = user['screen_name']
    text = unescape_html(status['text'])
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
          "http://tweetphotoapi.com/api/TPAPI.svc/imagefromurl?size=thumbnail&amp;url=#$1")
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
      when %r!co(\d+)!
        create_image_preview(
          "http://com.nicovideo.jp/community/co#$1",
          "http://icon.nimg.jp/community/s/co#$1",
          :width => 64, :height => 64)
      when %r!http://instagr.am/p/([A-Za-z0-9-]+)/!
        create_image_preview(
          "http://instagr.am/p/#$1",
          "http://instagr.am/p/#$1/media/?size=t",
          :width => 150, :height => 150)
      when %r!http://p.twipple.jp/(\w)(\w)(\w)(\w)(\w)!
        create_image_preview(
          "http://p.twipple.jp/#$1#$2#$3#$4#$5",
          "http://p.twipple.jp/data/#$1/#$2/#$3/#$4/#$5_m.jpg",
          :width => 200)
    end

    content = text.gsub(TEXT_RE) do
      case
      when reply = $1 then %!@<a target="_blank" href="http://twitter.com/#{reply}">#{reply}</a>!
      when hashtag = $2 then %!<a target="_blank" href="http://search.twitter.com/search?q=%23#{hashtag}">\##{hashtag}</a>!
      when uri = $3 then %!<a target="_blank" rel="noreferrer" class="external" href="#{Rack::Utils.escape_html uri}">#{Rack::Utils.escape_html uri}</a>!
      when $4 then '<br />'
      when $5 then '&quot;'
      when $6 then '&amp;'
      when $7 then '&lt;'
      when $8 then '&gt;'
      end
    end

    source = status['source'].gsub(%r!^<a href="(.+)" rel="nofollow">(.+)</a>$!) {
      %!<a target="_blank" href="#$1">#$2</a>!
    }

    @eruby.result(binding)
  end

  private

  UNESCAPE_HTML = {
    '&amp;' => '&',
    '&lt;' => '<',
    '&gt;' => '>',
    '&#39;' => "'",
    '&quot;' => '"',
  }

  UNESCAPE_HTML_PATTERN = Regexp.union(UNESCAPE_HTML.keys)

  def unescape_html(s)
    s.to_s.gsub(UNESCAPE_HTML_PATTERN) {|c| UNESCAPE_HTML[c] }
  end

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

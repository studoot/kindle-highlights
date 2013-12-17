require 'ostruct'

module KindleHighlights
  def KindleHighlights.get_agent
    agent = Mechanize.new
    agent.user_agent_alias = 'Windows Mozilla'
    agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    agent
  end

  class Books
    include Enumerable

    def initialize(email_address, password)
      @email_address = email_address
      @password = password
    end

    def each
      agent = KindleHighlights::get_agent
      signin_page = agent.get(KINDLE_LOGIN_PAGE)
      
      signin_form = signin_page.form(SIGNIN_FORM_IDENTIFIER)
      signin_form.email = @email_address
      signin_form.password = @password
      
      kindle_logged_in_page = agent.submit(signin_form)
      books_page = agent.click(kindle_logged_in_page.link_with(text: /Your Books/))

      loop do
        books_page.search(".//td[@class='titleAndAuthor']").each do |book|
          asin_and_title_element = book.search("a").first
          asin = asin_and_title_element.attributes["href"].value.split("/").last
          title = asin_and_title_element.inner_html
          author = book.search("span[@class='author']").first.content.gsub(/[[:space:]]+/, ' ').strip
          status = book.next_element.search(".//div[@class='statusText']/div[@class='text']").first.content.gsub(/[[:space:]]+/, ' ').strip.gsub(/ +/, '_')
          yield OpenStruct.new({ :title => title, :asin => asin, :author => author, :status => status })
        end
        break if books_page.link_with(text: /Next/).nil?
        books_page = agent.click(books_page.link_with(text: /Next/))
      end
    end

  end

  class Client
    attr_reader :books
        
    def initialize(email_address, password)
      @email_address = email_address
      @password      = password
      @books         = Hash.new
      
      load_books_from_kindle_account
    end
  
    def highlights_for(asin)
      highlights = get_agent("https://kindle.amazon.com/kcw/highlights?asin=#{asin}&cursor=0&count=1000")
      json = JSON.parse(highlights.body)
      json["items"]
    end
    
    private
   
    def load_books_from_kindle_account
      Books.new(@email_address, @password).each { |b| @books[b.asin] = b }
    end

  end
end

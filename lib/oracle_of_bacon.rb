require 'helpful'              # optional, may be helpful
require 'open-uri'              # allows open('http://...') to return body
require 'cgi'                   # for escaping URIs
require 'nokogiri'              # XML parser
require 'active_model'          # for validations

class OracleOfBacon

  class InvalidError < RuntimeError ; end
  class NetworkError < RuntimeError ; end
  class InvalidKeyError < RuntimeError ; end

  attr_accessor :from, :to
  attr_reader :api_key, :response, :uri
  
  include ActiveModel::Validations
  validates_presence_of :from
  validates_presence_of :to
  validates_presence_of :api_key
  validate :from_does_not_equal_to

  def from_does_not_equal_to
     @errors.add :from, 'From cannot be the same as To' if @from == @to 
  end

  def initialize(api_key='38b99ce9ec87')
    @api_key = api_key
    @from = "Kevin Bacon"
    @to = "Kevin Bacon"
    @errors = ActiveModel::Errors.new(self)
  end

  def find_connections
    make_uri_from_arguments
    begin
      xml = URI.parse(uri).read
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
      Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
      Net::ProtocolError => e
      # convert all of these into a generic OracleOfBacon::NetworkError,
      #  but keep the original error message
      # your code here
    end
    @response = Response.new(xml)
  end

  def make_uri_from_arguments
    @uri = "http://oracleofbacon.org/p=#{@api_key}&a=#{CGI.escape(@from)}&b=#{CGI.escape(@to)}"
  end
      
  class Response
    attr_reader :type, :data
    def initialize(xml)
      @doc = Nokogiri::XML(xml)
      parse_response
    end

    private

    def parse_response
      if ! @doc.xpath('/error').empty?
        parse_error_response
      elsif @doc.xpath('/spellcheck').any?
        parse_spellcheck
      elsif @doc.xpath('/link').any?
        parse_graph
      else 
        @type = :unknown
        @data = "unknown response"        
      end
    end
    def parse_graph
      @type = :graph
      actors = @doc.xpath('//actor').map{ |node| node.text}
      movies = @doc.xpath('//movie').map{ |node| node.text}
      @data = actors.zip(movies).flatten.compact
    end
    def parse_spellcheck
      @type = :spellcheck
      @data = @doc.xpath('//match').map{ |node| node.text}
    end
    def parse_error_response
      @type = :error
      @data = 'Unauthorized access'
    end
  end
end

#Esto no debería ir aquí...
oob = OracleOfBacon.new('38b99ce9ec87')

# connect Laurence Olivier to Kevin Bacon
oob.from = 'Laurence Olivier'
oob.find_connections
oob.response.type      # => :graph
oob.response.data      # => ['Kevin Bacon', 'The Big Picture (1989)', 'Eddie Albert (I)', 'Carrie (1952)', 'Laurence Olivier']

# connect Carrie Fisher (I) to Ian McKellen
oob.from = 'Carrie Fisher (I)'
oob.to = 'Ian McKellen'
oob.find_connections
oob.response.data      # => ['Ian McKellen', 'Doogal (2006)', ...etc]

# with multiple matches
oob.to = 'Anthony Perkins'
oob.find_connections
oob.response.type      # => :spellcheck
oob.response.data      # => ['Anthony Perkins (I)', ...33 more variations of the name]
# with bad key
oob = OracleOfBacon.new('known_bad_key')
oob.find_connections
oob.response.type      # => :error
oob.response.data      # => 'Unauthorized access'

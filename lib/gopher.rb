require 'yaml'

require 'word_wrap'
require 'eventmachine'

require_relative 'ext/module'

module Gopher
  VERSION = '0.7.1'

  class Application
    dsl_accessor :host, :port, :bindto
    attr_accessor :selectors, :root

    def initialize(&block)
      reset!
      self.instance_eval(&block)
    end

    def reload(*f); Gopher.reload(*f) end

    def use(mod)
      extend(mod)
    end

    def mount(selector, path)
      add_handler "#{selector}/?(.*)",
        DirectoryHandler.new(path, selector).with(self)
    end

    def map(selector, &block)
      add_handler selector.gsub(/:(.+)/, '(.+)'),
        MapHandler.new(&block).with(self)
    end

    def text(selector, &block)
      add_handler selector.gsub(/:(.+)/, '(.+)'),
        TextHandler.new(&block).with(self)
    end

    def helpers(&block)
      MapContext.class_eval(&block)
      TextContext.class_eval(&block)
    end

    def app(selector, handler)
      add_handler selector, handler
    end
    alias_method :application, :app

    def request(selector)
      handler, *args = lookup(selector)
      handler.call(*args)
    end

    def lookup(selector)
      selectors.find do |k, v|
        return v, *$~[1..-1] if k =~ Gopher.sanitize_selector(selector)
      end
      raise NotFound
    end

    def add_handler(selector, handler)
      selector = Gopher.sanitize_selector(selector)
      selector.sub!(/^\/*/, '')
      selectors[/^\/?#{selector}$/] = handler
    end

    private
    def reset!
      @selectors = {}
    end
  end

  class Handler
    attr_accessor :app

    def with(app)
      @app = app
      self
    end

    def host; app.respond_to?(:host) ? app.host : 'localhost' end
    def port; app.respond_to?(:port) ? app.port : 70 end
    def bindto; app.respond_to?(:bindto) ? app.bindto : '0.0.0.0' end

    def call(*args); end
  end

  class MapHandler < Handler
    attr_accessor :block, :result

    def initialize(&block)
      @block = block
    end

    def call(*args)
      context = MapContext.new(host, port)
      context.instance_exec(*args, &block)
      context.result
    end
  end

  class TextHandler < Handler
    attr_accessor :block, :result

    def initialize(&block)
      @block = block
    end

    def call(*args)
      context = TextContext.new
      context.instance_exec(*args, &block)
      context.result
    end
  end

  class DirectoryHandler < Handler
    attr_accessor :base, :selector, :index

    def initialize(path, selector = '')
      raise DirectoryNotFound unless File.directory? path
      @selector = selector
      @base = File.expand_path(path)
      @index = YAML.load_file(index_file) if File.exist?(index_file)
    end

    def call(*args)
      path = File.join(base, *args)
      if File.directory? path
        DirectoryHandler.new(path, File.join(selector, args)).with(app).to_map
      elsif File.file? path
        File.open(path)
      else
        raise NotFound
      end
    end

    def to_map
      MapContext.with_block(host, port, self) do |handler|
        if handler.index
          paragraph handler.index['description']
          handler.index['entries'].each do |txt, path|
            link txt, File.join(handler.selector, path)
          end
        else
          Dir["#{handler.base}/*"].each do |path|
            basename = File.basename(path)
            if File.directory? path
              map basename, File.join(handler.selector, basename)
            else
              link basename, File.join(handler.selector, basename)
            end
          end
        end
        text Time.now
      end
    end

    private
    def index_file
      File.join(base, '.gopher')
    end
  end

  class TextContext
    attr_accessor :result

    def line(text)
      result << text
      result << "\r\n"
    end

    def text(text)
      line text
    end

    def paragraph(txt, width=70)
      txt.each_line do |line|
        WordWrap.ww(line, width).each_line { |chunk| text chunk.strip }
      end
    end

    def initialize
      @result = ""
    end
  end

  class MapContext
    attr_accessor :host, :port, :result

    def initialize(host, port)
      @host, @port = host, port
      @result = ""
    end

    def self.with_block(host, port, *args, &block)
      new(host, port).instance_exec(*args, &block)
    end

    def line(type, txt, selector, host = self.host, port = self.port)
      result << ["#{type}#{txt}", selector, host, port].join("\t")
      result << "\r\n"
    end

    def link(text, selector, *args)
      type = Gopher.determine_type(selector)
      line type, text, scrub(selector), *args
    end

    def map(text, selector, *args)
      line '1', text, scrub(selector), *args
    end
    
    def text(text)
      line 'i', text, 'false', '(NULL)', 0
    end

    def paragraph(txt, width=70)
      txt.each_line do |line|
        WordWrap.ww(line, width).each_line { |chunk| text chunk.strip }
      end
    end

    private
    def scrub(s)
      "/#{s.sub(/^\/+/,'')}"
    end
  end

  class GopherError < StandardError; end
  class DirectoryNotFound < GopherError; end
  class NotFound < GopherError; end
  class InvalidRequest < GopherError; end

  def self.sanitize_selector(selector)
    selector = selector.dup
    selector.strip!
    selector.gsub!(/\.+/, '.')
    selector
  end

  def self.determine_type(selector)
    case File.extname(selector).downcase
    when '.jpg', '.png' then 'I'
    when '.mp3' then 's'
    when '.gif' then 'g'
    else '0'
    end
  end

  class Connection < EM::Connection
    attr_accessor :app

    def receive_data(data)
      begin
        raise InvalidRequest if data.length > 255
        response = app.request(data)        
        case response
        when String then send_data(response)
        when StringIO then send_data(response.read)
        when File
          while chunk = response.read(8192) do
            send_data(chunk)
          end
        end
        close_connection_after_writing
      rescue Gopher::NotFound
        send_data "not found"
        close_connection_after_writing
      rescue => e
        close_connection
        raise e
      end
    end
  end

  class <<self
    def app(&block)
      @app = Application.new(&block)
    end
    alias_method :application, :app

    def reload(*files)
      @last_reload = Time.now
      @reloadables = files
    end

    def reloadables
      @reloadables ||= []
    end

    def run
      return if EM.reactor_running?
      EM.run do
        EM.start_server(@app.bindto, @app.port, Gopher::Connection) do |c|
          c.app = @app
          reloadables.each do |f|
            load f if File.mtime(f) > @last_reload
          end
          @last_reload = Time.now
        end        
      end
    end

    def stop
      return unless EM.reactor_running?
      EM.stop_server
    end
  end
end


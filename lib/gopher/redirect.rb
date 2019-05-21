require 'erubis'

module Gopher
  module Redirect
    def self.extended(application)
      application.add_handler "URL:(.+)", RedirectHandler.new.with(application)
      application.class.dsl_accessor :redirect_template
      application.redirect_template File.join(File.dirname(__FILE__), 'redirect.erb')

      application.helpers do
        def url(text, url, *args)
          line 'h', text, "/URL:#{url}", *args
        end
      end
    end

    class RedirectHandler < Handler
      def call(*url)
        input = File.read(application.redirect_template)
        eruby = Erubis::Eruby.new(input)
        return eruby.result(binding())
      end
    end
  end
end

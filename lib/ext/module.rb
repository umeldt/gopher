class Module
  def dsl_accessor(*accessors)
    accessors.each do |accessor|
      class_eval %{
        attr_writer :#{accessor}

        def #{accessor}(value=nil)
          send "#{accessor}=", value if value
          @#{accessor}
        end
      }
    end
  end
end

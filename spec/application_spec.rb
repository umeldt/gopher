require_relative 'spec_helper'

RSpec.describe Gopher::Application do
  before do
     @app = Gopher::Application.new do
       host 'localhost'
       port 7000
 
       helpers do
         def ruler
           text("=-" * 40)
         end
       end
 
       mount 'documents', File.dirname(__FILE__)
     end
  end

  it 'should set the host' do
    expect(@app.host).to eq 'localhost'
  end

  it 'should set the port' do
    expect(@app.port).to eq 7000
  end

  it 'should mount directories' do
    expect(@app.lookup('/documents')).to be_instance_of(Array)
  end

  it 'should route properly to directories and their children' do
    expect(@app.lookup('/documents/tasty')).to include("tasty")
  end

  it 'should sanitize lookups' do
    expect(@app.lookup('/documents/.././tasty...html')).to include("././tasty.html")
  end

  it 'should add helpers' do
    expect(Gopher::MapContext.public_instance_methods).to include(:ruler)
  end
end


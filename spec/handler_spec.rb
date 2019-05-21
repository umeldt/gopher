require File.join(File.dirname(__FILE__), '/spec_helper')

describe Gopher::TextHandler do
  before(:all) do
    @handler = Gopher::TextHandler.new do
      line "just a line of text"
    end
  end

  it 'should print text' do
    expect(@handler.call).to include("just a line of text")
  end
end

describe Gopher::DirectoryHandler do
  before(:all) do
    path = File.join(File.dirname(__FILE__), 'sandbox')
    @handler = Gopher::DirectoryHandler.new(path)
  end

  it 'should barf on non-existent directories' do
    expect { Gopher::DirectoryHandler.new(__FILE__) }.to raise_error(Gopher::DirectoryNotFound)
  end

  it 'should serve files under the directory' do
    expect(@handler.call('recipe.txt')).to be_instance_of(File)
  end

  it 'should raise a NotFound when files do not exist' do
    expect { @handler.call('recipe.tx') }.to raise_error(Gopher::NotFound)
  end

  it 'should serve directory indexes when applicable' do
    expect(@handler.call).to include("0recipe.txt\t/recipe.txt\t0.0.0.0\t70\r\n")
  end
end

describe Gopher::MapHandler do
  before(:all) do
    @handler = Gopher::MapHandler.new do
      text 'Cake recipes'
      link 'Image', 'cake.jpg'
    end
  end

  it 'should add text' do
    expect(@handler.call).to include "iCake recipes\tfalse\t(NULL)\t0\r\n"
  end

  it 'should add links and figure out the types' do
    expect(@handler.call).to include "IImage\t/cake.jpg\t0.0.0.0\t70\r\n"
  end
end

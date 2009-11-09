require 'rack/test'
require 'nokogiri'

class Webcat::Driver::RackTest
  class Node < Struct.new(:session, :node)
    def text
      node.text
    end
    
    def [](name)
      value = node[name.to_s]
      return value.to_s if value
    end

    def value
      node['value'].to_s
    end

    def value=(value)
      node['value'] = value.to_s
    end

    def click
      if tag_name == 'a'
        session.visit(self[:href])
      elsif tag_name == 'input' and self[:type] == 'submit'
        Form.new(session, form).submit(self)
      end
    end
    
    def tag_name
      node.node_name
    end

  private

    def form
      node.ancestors('form').first
    end
  end

  class Form < Node
    def params(button)
      params = []
      params = node.xpath("//input[@type='text']").inject(params) do |agg, input|
        agg << param(input['name'].to_s, input['value'].to_s)
        agg
      end
      params = node.xpath("//textarea").inject(params) do |agg, textarea|
        agg << param(textarea['name'].to_s, textarea.text.to_s)
        agg
      end
      params = node.xpath("//input[@type='radio']").inject(params) do |agg, input|
        agg << param(input['name'].to_s, input['value'].to_s) if input['checked']
        agg
      end
      params = node.xpath("//input[@type='checkbox']").inject(params) do |agg, input|
        agg << param(input['name'].to_s, input['value'].to_s) if input['checked']
        agg
      end
      params = node.xpath("//select").inject(params) do |agg, select|
        option = select.xpath("option[@selected]").first
        option ||= select.xpath('option').first
        agg << param(select['name'].to_s, (option['value'] || option.text).to_s) if option 
        agg
      end
      params << param(button[:name], button.value) if button[:name]
      params.join('&')
    end

    def submit(button)
      session.submit(node['action'].to_s, params(button)) 
    end

  private

    def param(key, value)
      "#{key}=#{value}"
    end
  end
  
  include ::Rack::Test::Methods
  attr_reader :app, :html, :body

  alias_method :response, :last_response
  alias_method :request, :last_request
  
  def initialize(app)
    @app = app
  end
  
  def visit(path)
    get(path)
    cache_body
  end

  def submit(path, attributes)
    post(path, attributes)
    cache_body  
  end
  
  def find(selector)
    html.xpath(selector).map { |node| Node.new(self, node) }
  end

  private

  def cache_body
    @body = response.body
    @html = Nokogiri::HTML(body)
  end

end

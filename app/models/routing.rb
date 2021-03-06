class Routing
  include Concerns::Enum

  def self.attributes
    [
      :id, :name, :cluster_id, :strategy, :traffic_rate, :status, :api, :conditions
    ]
  end

  def self.attribute_names
    attributes.map(&:to_s)
  end

  attr_accessor *attributes

  def initialize(args = {})
    args ||= {}
    self.class.attributes.each do |x|
      self.public_send("#{x}=", args[x])
    end
  end

  [:id, :cluster_id, :strategy, :traffic_rate, :status, :api].each do |x|
    define_method "#{x}=".to_sym do |v|
      instance_variable_set("@#{x}", v.try(:to_i))
    end
  end

  def cluster=(v)
    return @cluster = nil if v.nil?

    self.cluster_id = v.id
    @cluster = v
  end

  def cluster(rel = false)
    return nil if self.cluster_id.blank?
    return @cluster if !rel && @cluster && @cluster.id == self.cluster_id

    @cluster = Cluster.find_by(id: self.cluster_id)
  end

  def api_i=(v)
    if v.nil?
      @api_i = nil
      self.api = nil
      return
    end

    self.api = v.id
    @api_i = v
  end

  def api_i(rel = false)
    return nil if self.api.blank?
    return @api_i if !rel && @api_i && @api_i.id == self.api

     @api_i = Api.find_by(id: self.api)
  end

  def strategy_name
    key_of_rs(self.strategy)
  end

  def status_name
    key_of_status(self.status)
  end

  def update(options = {})
    options.each_pair do |k, v|
      public_send("#{k}=", v) if respond_to?("#{k}=")
    end
    result = HttpRequest.put('/routings', self.as_json)

    result.ok?
  end

  def destroy!
    result = HttpRequest.delete("/routings/#{id}")
    !result.ok? && raise(result.error)
    result.ok?
  end

  class << self
    def all(options)
      result = HttpRequest.get('/routings', options)

      return [] unless result.ok?

      (result.data || []).map{|x| self.new(x)}
    end

    def find_by(options)
      result = HttpRequest.get("/routings/#{options[:id]}")

      return nil unless result.ok?

      self.new(result.data)
    end

    def create(options = {})
      routing = self.new(options)
      result = HttpRequest.put('/routings', routing.as_json)

      return routing unless result.ok?

      routing.id = result.data.to_i

      routing
    end

    def include_cluster_id?(cluster_id)
      last_id = 0
      loop do
        routings = self.all(after: last_id, limit: 10)

        break if routings.blank?

        last_id = routings.max{|x| x.id}
        has_use = routings.any? do |routing|
          routing.cluster_id.to_i == cluster_id.to_i
        end

        return true if has_use
      end

      false
    end

    def include_api_id?(api_id)
      last_id = 0
      loop do
        routings = self.all(after: last_id, limit: 10)

        break if routings.blank?

        last_id = routings.max{|x| x.id}
        has_use = routings.any? do |routing|
          routing.api.to_i == api_id.to_i
        end

        return true if has_use
      end

      false
    end
  end
end

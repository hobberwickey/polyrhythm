module Api
  extend ActiveSupport::Concern

  #TODO: move everything into this namespace
  class Api
    DEFAULT_CONFIG = {
      ignore_self: false,
      records_per_page: 30,

      api_callbacks: {
        before_create: nil,
        after_create: nil,
        before_update: nil,
        after_update: nil,
        before_destroy: nil,
        after_destroy: nil
      }, 

      ignored: {
      
      },

      restrictions: {
        # :user => {
        #   :actions => [ standard or custom action role has access to],
        #   :attributes => [ standard or custom attributes for role],
        #   :serializers => [ serializers for role ],
        #   :associations => [ ass]
        #   :scope => Proc.new { |user, action, params| Widget.where(:used_id => user.id) } 
        # }
      },

      custom_actions: { },
      custom_serializers: { },
      custom_attributes: { }
    }

    def initialize(obj, *args)
      @obj = obj
      @config = DEFAULT_CONFIG.merge(args[0] || {})
    end

    def role_restrictions(roles)
      restricted = @config[:restrictions].select { |k,v| roles.include? k }
      ignored = @config[:ignored]

      restricted_actions = ( restricted.map { |k,v| v[:actions] || [] } + (ignored[:actions] || []) ).flatten
      restricted_attributes = ( restricted.map { |k,v| v[:attributes] || [] } + (ignored[:attributes] || []) ).flatten
      restricted_associations = ( restricted.map { |k,v| v[:associations] || [] } + (ignored[:associations] || []) ).flatten

      return restricted_actions, restricted_attributes, restricted_associations
    end

    def customizations
      return @config[:custom_actions], @config[:custom_attributes], @config[:custom_serializers]
    end

    def default_actions
      @default_actions ||= {
        :index => {
          :calls => :index,
          :for => "collection",
          :method => "GET",
          :href => "/#{@obj.table_name.downcase}",
          :name => "#{@obj.table_name.downcase}-index",
          :title => "#{@obj.class.name} Index",
          :type => "application/x-www-form-urlencoded",
          :fields => [
            { :name => "page", :type => "integer" },
            { :name => "per_page", :type => "integer" }
          ]
        },
        :show => {
          :calls => :show,
          :for => "item",
          :method => "GET",
          :href => "/#{@obj.table_name.downcase}/:id",
          :name => "#{@obj.table_name.downcase}-show",
          :title => "#{@obj.class.name} show",
          :type => "application/x-www-form-urlencoded",
          :fields => [
            { :name => "id", :type => "integer", :required => true },
          ]
        },
        :create => {
          :calls => :create,
          :for => "collection",
          :method => "POST",
          :href => "/#{@obj.table_name.downcase}",
          :name => "#{@obj.table_name.downcase}-create",
          :title => "Create a #{@obj.class.name}",
          :type => "application/x-www-form-urlencoded",
          :fields => nil
        },
        :update => {
          :calls => :update,
          :for => "item",
          :method => "PUT",
          :href => "/#{@obj.table_name.downcase}/:id",
          :name => "#{@obj.table_name.downcase}-update",
          :title => "#Update a {@obj.class.name}",
          :type => "application/x-www-form-urlencoded",
          :fields => nil
        },
        :destroy  => {
          :calls => :destroy,
          :for => "item",
          :method => "DELETE",
          :href => "/#{@obj.table_name.downcase}/:id",
          :name => "#{@obj.table_name.downcase}-delete",
          :title => "Delete a #{@obj.class.name}",
          :type => "application/x-www-form-urlencoded",
          :fields => [
            { :name => "id", :type => "integer", :required => true },
          ]
        }
      }
    end
  end

  module ClassMethods
    #Not sure about this syntax, but it sure is handy.
    def api(*args)
      if args.blank?
        @api ||= Api.new(self)
      else
        @api = Api.new(self, args[0])
      end
    end
  end
end

ActiveRecord::Base.send(:include, Api)


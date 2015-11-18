class Authorization < Sinatra::Base
  module Api
    extend ActiveSupport::Concern

    # custom action example

    # :example => {
    #   :method => string - the http request method,
    #   :href => string - the url ,
    #   :name => string - siren action name,
    #   :title => string - siren action description,
    #   :type => string - valid media type eg. "application/x-www-form-urlencoded",
    #   :fields => array - storm structure [
    #     { :name => "keyword", :type => "string" },
    #   ],
    #   :action => string - the model's method to call,
    #   :for => string - either "collection" or "resource" for what type of resource this should be included on
    # }
    #
    # A note on custom action. The method called must be a method on the class itself
    # (so `def self.search` not `def search`) and them must accept 1 argument (params)


    # @build_nested_forms_for - A list of keys for which to include nested attributes on
    # create / update routes. Important to note that if you want deeply nested forms,
    # for example beverages -> products -> store_products, you have to include :store_products
    # in this as well. This prevents crazy levels of recursion

    #Class containing private methods

    class Utils
      def self.format_actions(actions, obj, instance=nil)
        return actions.map do |k, v|
          unless obj.ignored_actions.include? k
            href = self.process_string(v[:href], obj, instance)

            action = {
              :name => self.process_string(v[:name], obj, instance),
              :title => self.process_string(v[:title], obj, instance),
              :method => v[:method],
              :type => v[:type],
              :href => "/#{self.process_string(v[:href], obj, instance)}",
              :fields => v[:fields] ||= obj.get_fields(instance)
            }
          end
        end
      end

      def self.process_string(str, obj, instance)
        match = str[/:+\w+/]
        unless match.blank?
          method = match.gsub(":", "")
          replaced = (instance.present? and instance.respond_to? method) ? str.gsub(/:+\w+/, instance.send(method).to_s) : str
        else
          replaced = str
        end

        return replaced
      end

      def self.get_href(item)
        item.try(:href).nil? ? "/#{item.class.table_name}/#{item.id}" : self.process_string(item.href, item.class, item)
      end
    end

    #########################
      # Utility Functions
    #########################

    def get_actions(user=nil)
      actions = self.class.default_actions.select { |k,v| [ :show, :update, :destroy ].include? k }
      actions.to_hash.merge!( self.class.custom_actions.select { |k,v| v[:for] == "resource" } )

      model = self.class

      if user.nil?
        actions.select! { |k,v| !model.restricted_actions[k.to_sym].present? }
      else
        actions.select! do |k,v|
          roles = model.restricted_actions[k.to_sym]
          !(roles.present? && (roles & user.roles.map { |r| r.name.to_sym }).blank?)
        end
      end

      return Utils::format_actions( actions, self.class, self )
    end

    def role_attributes(user=nil)
      model = self.class
      if user.nil?
        self.attributes.select { |k,v| !model.restricted_attributes[k.to_sym].present? }
      else
        self.attributes.select do |k,v|
          roles = model.restricted_attributes[k.to_sym]
          !(roles.present? && (roles & user.roles.map { |r| r.name.to_sym }).blank?)
        end
      end
    end

    def role_reflections(user=nil)
      model = self.class

      if user.nil?
        self.class.reflections.select { |k,v| !model.restricted_associations[k.to_sym].present? }
      else
        self.class.reflections.select do |k,v|
          roles = model.restricted_associations[k.to_sym]
          !(roles.present? && (roles & user.roles.map { |r| r.name.to_sym }).blank?)
        end
      end
    end

    #TODO: move everything into this namespace
    class Api
      DEFAULT_CONFIG = {
        ignore_self: false,
        records_per_page: 30,

        callbacks: {
          before_create: nil,
          after_create: nil,
          before_update: nil,
          after_update: nil,
          before_destroy: nil,
          after_destroy: nil
        }, 

        # actions
        custom_actions: { },
        restricted_actions: { },

        #serializers
        custom_serializers: { },

        # attributes
        restricted_attributes: { },
        custom_attributes: { },

        # associations
        restricted_associations: { }
      }

      def initialize(obj, *args)
        @obj = obj
        @config = DEFAULT_CONFIG.merge(args[0] || {})
        @actions = {}
        @attributes = {}
      end

      module ClassMethods

        def actions_for_role(user=nil)
          user_roles = user.nil? ? ["public"] : user.roles.pluck(:name)
          all_actions = default_actions.merge(@config.custom_actions)
          
          user_roles.each do |role|
            
          end
        end

        def default_actions
          @default_actions ||= {
            :index => {
              :method => "GET",
              :href => "/#{@obj.table_name.downcase}",
              :name => "#{@obj.table_name.downcase}-index",
              :title => "#{model.name} Index",
              :type => "application/x-www-form-urlencoded",
              :fields => [
                { :name => "page", :type => "integer" },
                { :name => "per_page", :type => "integer" }
              ]
            },
            :show => {
              :method => "GET",
              :href => "/#{@obj.table_name.downcase}/:id",
              :name => "#{@obj.table_name.downcase}-show",
              :title => "#{model.name} show",
              :type => "application/x-www-form-urlencoded",
              :fields => [
                { :name => "id", :type => "integer", :required => true },
              ]
            },
            :create => {
              :method => "POST",
              :href => "/#{@obj.table_name.downcase}",
              :name => "#{@obj.table_name.downcase}-create",
              :title => "Create a #{model.name}",
              :type => "application/x-www-form-urlencoded",
              :fields => nil
            },
            :update => {
              :method => "PUT",
              :href => "/#{@obj.table_name.downcase}/:id",
              :name => "#{@obj.table_name.downcase}-update",
              :title => "#Update a {model.name}",
              :type => "application/x-www-form-urlencoded",
              :fields => nil
            },
            :destroy  => {
              :method => "DELETE",
              :href => "/#{@obj.table_name.downcase}/:id",
              :name => "#{@obj.table_name.downcase}-delete",
              :title => "Delete a #{model.name}",
              :type => "application/x-www-form-urlencoded",
              :fields => [
                { :name => "id", :type => "integer", :required => true },
              ]
            }
          }
        end

        # def callbacks
        #   @config[:callbacks]
        # end

        # def ignore_self
        #   @config[:ignore_self]
        # end

        # def custom_actions
        #   @config[:custom_actions]
        # end

        # def restricted_actions
        #   @config[:restricted_actions]
        # end

        # def custom_serializers
        #   @config[:custom_serializers]
        # end

        # def restricted_attributes
        #   @config[:restricted_attributes]
        # end

        # def custom_attributes
        #   @config[:custom_attributes]
        # end

        # def restricted_attributes
        #   @config[:restricted_attributes]
        # end
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

      def ignore_self(*args)
        if args.blank?
          @ignore_self ||= false
        else
          @ignore_self = args[0]
        end
      end

      def api_records_per_page(*args)
        if args.blank?
          @api_records_per_page ||= 100
        else
          @api_records_per_page = args[0]
        end
      end

      def ignored_associations(*args)
        if args.blank?
          @ignored_associations ||= []
        else
          @ignored_associations = args
        end
      end

      def build_nested_forms_for(*args)
        if args.blank?
          @build_nested_forms_for ||= {}
        else
          @build_nested_forms_for = args
        end
      end

      def custom_actions(*args)
        if args.blank?
          @custom_actions ||= {}
        else
          @custom_actions = args[0]
        end
      end

      def default_actions
        @default_actions = {
          :index => {
            :method => "GET",
            :href => ":table_name_downcase",
            :name => ":table_name_downcase-index",
            :title => ":table_name_capitalize Index",
            :type => "application/x-www-form-urlencoded",
            :fields => [
              { :name => "page", :type => "integer" },
              { :name => "per_page", :type => "integer" }
            ]
          },
          :show => {
            :method => "GET",
            :href => ":table_name_downcase/:id",
            :name => ":table_name_downcase-show",
            :title => ":model_name_capitalize Item",
            :type => "application/x-www-form-urlencoded",
            :fields => [
              { :name => "id", :type => "integer", :required => true },
            ]
          },
          :create => {
            :method => "POST",
            :href => ":table_name_downcase",
            :name => ":table_name_downcase-create",
            :title => "Create A :model_name_capitalize",
            :type => "application/x-www-form-urlencoded",
            :fields => nil
          },
          :update => {
            :method => "PUT",
            :href => ":table_name_downcase/:id",
            :name => ":table_name_downcase-update",
            :title => "Update A :model_name_capitalize",
            :type => "application/x-www-form-urlencoded",
            :fields => nil
          },
          :destroy  => {
            :method => "DELETE",
            :href => ":table_name_downcase/:id",
            :name => ":table_name_downcase-delete",
            :title => "Delete A :model_name_capitalize",
            :type => "application/x-www-form-urlencoded",
            :fields => [
              { :name => "id", :type => "integer", :required => true },
            ]
          }
        }
      end

      def custom_serializers(*args)
        if args.blank?
          @custom_serializers ||= {}
        else
          @custom_serializers = args[0]
        end
      end

      #Ignores default actions
      def ignored_actions(*args)
        if args.blank?
          @ignored_actions ||= []
        else
          @ignored_actions = args
        end
      end


      #Ignore attributes in the serialization process.
      def ignored_attributes(*args)
        if args.blank?
          @ignored_attributes ||= [:created_at, :updated_at]
        else
          @ignored_attributes = args
        end
      end

      #for including methods in the objects properties
      def included_methods(*args)
        if args.blank?
          @included_methods ||= {}
        else
          @included_methods = args[0]
        end
      end

      #########################
      # Access Restrictions
      #########################

      def restricted_associations(*args)
        if args.blank?
          @restricted_associations ||= { }
        else
          @restricted_associations = args[0]
        end

      end

      def restricted_actions(*args)
        if args.blank?
          @restricted_actions ||= { }
        else
          #@restricted_actions = { } if @restricted_actions.blank?
          @restricted_actions = args[0]
        end
      end

      def restricted_attributes(*args)
        if args.blank?
          @restricted_attributes ||= { }
        else
          @restricted_attributes = args[0]
        end
      end

      #########################
      # Scoping Functions
      #########################

      def api_scope(user, action)
        return self
      end

      def api_associations(id, association, user)
        return self.find(id).send(association)
      end


      #########################
      # Utility Functions
      #########################

      def get_actions(user=nil)
        actions = self.default_actions.select { |k,v| [ :index, :create ].include? k }
        actions.merge!( self.custom_actions.select { |k,v| v[:for] == "collection" } )

        model = self
        if user.nil?
          actions.select! { |k,v| !model.restricted_actions[k.to_sym].present? }
        else
          actions.select! do |k,v|
            roles = model.restricted_actions[k.to_sym]
            !(roles.present? && (roles & user.roles.map { |r| r.name.to_sym }).blank?)
          end
        end

        return Utils::format_actions( actions, self )
      end

      # TODO: Does't recognize paperclip... which makes sense since it's not a column but a method
      def get_fields( obj = nil )
        fields = fields ||= []
        self.columns_hash.each do |k, v|
          fields << { name: k, type: v.type, value: (obj.blank? or not obj.respond_to?(k)) ? nil : obj.send(k) } unless self.ignored_attributes.include? k.to_sym
        end

        self.build_nested_forms_for.each do |k|
          reflection = self.reflect_on_association(k)

          if reflection.present? and self.build_nested_forms_for.include? ( k )
            model = self.reflect_on_association(k).class_name.constantize
            instance = obj.blank? ? nil : obj.send(k)
            fields << { name: k, type: "nest", structure: model.get_fields( instance ) }
          end
        end

        return fields
      end

      def serialize(config, action, data)
        klass = Class.new do
          def initialize(config, obj)
              @config = config

              @obj = obj
              @obj.each do |k, v|
                role_attributes[k] = v
                self.class.send(:define_method, k) { @obj[k] }
              end
          end

          def id
            nil
          end

          def href
            @config[:href]
          end

          def role_attributes(user=nil, *args)
            if args.blank?
              @role_attributes ||= {}
            else
              @role_attributes = args
            end
          end

          def role_reflections(user)
            []
          end

          def get_actions(user)
            []
          end

          def self.table_name
            name.downcase.pluralize
          end
        end

        if (action == :collection)
          Object.const_set config[:item][:model], klass

          serializer = Serializer.new(config[:collection], klass)

          data.each do |obj|
            serializer << config[:item][:model].constantize.new(config[:item], obj)
          end
        else
          Object.const_set config[:item][:model], klass
          serializer = config[:item][:model].constantize.new(config[:item], data)
        end

        serializer
      end
    end
  end

  #Equivalent to and Active Record relations
  class Serializer
    ARRAY_METHODS = [ :to_xml, :to_yaml, :length, :collect, :map, :each, :<<, :[], :all?, :include?, :to_ary, :join ]

    attr_accessor :klass, :members, :config

    def initialize(config, klass, *members)
      self.config = config
      self.klass = klass
      self.members = members
    end

    def method_missing(method, *args, &block)
      if ARRAY_METHODS.include? method
        members.send(method, *args, &block)
      else
        super
      end
    end

    def get_actions(user)
      []
    end

    def ignored_attributes
      []
    end

    def included_methods
      []
    end

    def table_name
      @config[:model].downcase.pluralize
    end

    def name
      @config[:model]
    end
  end

  ActiveRecord::Base.send(:include, Api)
end
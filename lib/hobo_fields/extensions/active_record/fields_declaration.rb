# frozen_string_literal: true

ActiveRecord::Base.class_eval do

    def self.fields(&b)
      # Any model that calls 'fields' gets a bunch of other
      # functionality included automatically, but make sure we only
      # include it once
      include HoboFields::Model unless HoboFields::Model.in?(included_modules)
      #@include_in_migration = false #||= options.fetch(:include_in_migration, true); options.delete(:include_in_migration)
      @include_in_migration = true

      if b
        dsl = HoboFields::FieldDeclarationDsl.new(self, {:null => false})
        if b.arity == 1
          yield dsl
        else
          dsl.instance_eval(&b)
        end
      end
    end


end

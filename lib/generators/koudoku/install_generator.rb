# this generator based on rails_admin's install generator.
# https://www.github.com/sferik/rails_admin/master/lib/generators/rails_admin/install_generator.rb

require 'rails/generators'

# http://guides.rubyonrails.org/generators.html
# http://rdoc.info/github/wycats/thor/master/Thor/Actions.html

module Koudoku
  class InstallGenerator < Rails::Generators::Base

    def self.source_paths
      [Koudoku::Engine.root, File.expand_path("../templates", __FILE__)]
    end

    include Rails::Generators::Migration

    argument :subscription_owner_model, :type => :string, :required => true, :desc => "Owner of the subscription"
    desc "Koudoku installation generator"

    # Override the attr_accessor generated by 'argument' so that
    # subscription_owner_model is always returned lowercase.
    def subscription_owner_model
      @subscription_owner_model.downcase
    end


    def install

      unless defined?(Koudoku)
        gem("koudoku")
      end

      require "securerandom"
      template "config/initializers/koudoku.rb"

      # Generate subscription.
      generate("model", "subscription stripe_id:string plan_id:integer last_four:string coupon_id:integer card_type:string current_price:float #{subscription_owner_model}_id:integer")
      template "app/models/subscription.rb"

      # Add the plans.
      generate("model", "plan name:string stripe_id:string price:float interval:string features:text highlight:boolean display_order:integer")
      template "app/models/plan.rb"

      # Add coupons.
      generate("model coupon code:string amount_off:float percent_off:integer redeem_by:datetime max_redemptions:integer duration:string duration_in_months:integer")
      template "app/models/coupon.rb"

      # Update the owner relationship.
      inject_into_class "app/models/#{subscription_owner_model}.rb", subscription_owner_model.camelize.constantize,
                        "# Added by Koudoku.\n  has_one :subscription\n\n"

      # Install the pricing table.
      copy_file "app/views/koudoku/subscriptions/_social_proof.html.erb"

      # Add webhooks to the route.

      route <<-RUBY

  # Added by Koudoku.
  mount Koudoku::Engine, at: 'koudoku'
  scope module: 'koudoku' do
    get 'pricing' => 'subscriptions#index', as: 'pricing'
  end

RUBY

      # Show the user the API key we generated.
      say "\nTo enable support for Stripe webhooks, point it to \"/koudoku/events\"."

    end

  end
end

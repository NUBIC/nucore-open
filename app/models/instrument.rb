class Instrument < Product
  include Products::RelaySupport
  include Products::SchedulingSupport

  RESERVE_INTERVALS = [ 1, 5, 10, 15, 30, 60 ]


  # Associations
  # -------

  has_many :instrument_price_policies, :foreign_key => 'product_id'
  has_many :product_access_groups, :foreign_key => 'product_id'

  # Validations
  # --------

  validates :initial_order_status_id, presence: true
  validates :reserve_interval, inclusion: { in: RESERVE_INTERVALS }
  validates :facility_account_id, presence: true if SettingsHelper.feature_on? :recharge_accounts
  validates :min_reserve_mins,
            :max_reserve_mins,
            :auto_cancel_mins,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }

  validate :minimum_reservation_is_interval,
           :maximum_reservation_is_interval,
           :max_reservation_not_less_than_min

  # Callbacks
  # --------

  after_create :set_default_pricing

  # Instance methods
  # -------

  # calculate the last possible reservation date based on all current price policies associated with this instrument
  def last_reserve_date
    (Time.zone.now.to_date + max_reservation_window.days).to_date
  end

  def max_reservation_window
    days = price_group_products.collect{|pgp| pgp.reservation_window }.max.to_i
  end

  def restriction_levels_for(user)
    product_access_groups.joins(:product_users).where(:product_users => {:user_id => user.id})
  end

  def set_default_pricing
    PriceGroup.globals.all.each do |pg|
      PriceGroupProduct.create!(:product => self, :price_group => pg, :reservation_window => PriceGroupProduct::DEFAULT_RESERVATION_WINDOW)
    end
  end

  def reservation_only?
    control_mechanism == Relay::CONTROL_MECHANISMS[:manual]
  end


  private

  def minimum_reservation_is_interval
    interval? :min_reserve_mins
  end

  def maximum_reservation_is_interval
    interval? :max_reserve_mins
  end

  def interval?(attribute)
    if send(attribute).to_i > 0 && send(attribute) % reserve_interval != 0
      self.errors.add attribute, :not_interval, reserve_interval: reserve_interval
    end
  end

  def max_reservation_not_less_than_min
    if max_reserve_mins && min_reserve_mins && max_reserve_mins < min_reserve_mins
      self.errors.add :max_reserve_mins, :max_less_than_min
    end
  end

end

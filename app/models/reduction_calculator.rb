class ReductionCalculator
  attr_reader :original_debt_hash, :debt_hash, :accounts

  def initialize(debt_hash)
    @original_debt_hash = debt_hash
    @debt_hash = self.class.marshal_and_normalize_debt_data(debt_hash)

    @accounts = @debt_hash[:accounts]

    self
  end

  def monthly_reduction
    if @monthly_reduction.nil?
      @monthly_reduction = []

      debt = debt_hash
      accounts = debt[:accounts]

      payment_date = Time.now.to_date.at_beginning_of_month
      payment_date = payment_date.prev_month if debt[:start_this_month] == true

      reduction = {
        date: payment_date,
        accounts: accounts.collect{|a| a[:name]},
        payments: accounts.inject({}){|p, a| p[a[:name]] = {balance: a[:balance]}; p }
      }
      total_balance = 0.0
      reduction[:payments].each_value{|payment| total_balance += payment[:balance] }
      reduction[:totals] = {balance: total_balance.round(2)}
      @monthly_reduction << reduction
      payment_date = payment_date.next_month

      while !accounts.collect{|d| d[:balance] if d[:balance] > 0 }.compact.empty?
        reduction = {date: payment_date, accounts: [], payments: {}}

        amount_for_debt = debt[:amount_for_debt]

        accounts.each do |account|
          if account[:balance] > 0
            interest = (account[:balance] * (account[:rate] / 100 / 12)).round(2)

            payment = account[:min_payment].round(2)

            proposed_balance = account[:balance] + interest - payment
            if proposed_balance < 0
              payment = (account[:balance] + interest).round(2)
              proposed_balance = account[:balance] + interest - payment
            end

            account[:balance] = proposed_balance.round(2)

            amount_for_debt = (amount_for_debt - payment).round(2)

            reduction[:accounts] << account[:name]
            reduction[:payments][account[:name]] = {interest: interest, payment: payment, rate: account[:rate], balance: account[:balance]}
          end
        end

        if amount_for_debt > 0
          accounts.each do |account|
            break if amount_for_debt <= 0
            next if account[:balance] <= 0

            reduction_payment = reduction[:payments][account[:name]]

            additional_payment = if reduction_payment[:balance] - amount_for_debt < 0
              reduction_payment[:balance]
            else
              amount_for_debt
            end

            reduction_payment[:payment] = (reduction_payment[:payment] + additional_payment).round(2)
            account[:balance] = (reduction_payment[:balance] - additional_payment).round(2)
            reduction_payment[:balance] = account[:balance]

            amount_for_debt -= additional_payment
          end
        end

        reduction[:totals] = {interest: 0.0, payment: 0.0, balance: 0.0}
        reduction[:payments].each_value do |payment|
          reduction[:totals][:interest] = (reduction[:totals][:interest] + payment[:interest]).round(2)
          reduction[:totals][:payment] = (reduction[:totals][:payment] + payment[:payment]).round(2)
          reduction[:totals][:balance] = (reduction[:totals][:balance] + payment[:balance]).round(2)
        end

        @monthly_reduction << reduction

        payment_date = payment_date.next_month
      end
    end
    @monthly_reduction
  end


  class << self

    def debt_file_name
      debt_file_name = Rails.root.join('db', 'debt.json')
      FileUtils.touch(debt_file_name) unless File.exists?(debt_file_name)
      debt_file_name
    end

    def debt_hash
      @debt_hash ||= JSON.parse(File.read(debt_file_name))
    end

    def marshal_and_normalize_debt_data(debt_hash)
      debt = Marshal.load(Marshal.dump(debt_hash))
      debt.symbolize_keys!
      debt[:accounts].each{|account| account.symbolize_keys! }

      debt[:amount_for_debt] = debt[:amount_for_debt].to_f.round(2)
      debt[:accounts].each do |account|
        account[:balance] = account[:balance].to_f.round(2)
        account[:rate] = account[:rate].to_f.round(2)
        account[:min_payment] = account[:min_payment].to_f.round(2)
      end

      debt
    end

  end

end

require 'matrix'

module Statleboncoin
  class Analysis
    attr_reader :r_squared

    HOME_PREDICT_MAX_MILEAGE = 300_000.0
    HOME_PREDICT_MAX_AGE_DAYS = 365.0 * 15

    def initialize(items)
      @items = items
    end

    MAX_MILEAGE = 500_000.0
    MAX_AGE_DAYS = 3650.0 * 2

    def self.normalized_x(item)
      [1, item.mileage / MAX_MILEAGE, (Date.today - item.issuance_date.to_date).to_i / MAX_AGE_DAYS]
    end

    def linear_regression
      # find the coefficient of the linear regression of the price over the mileage and car age (days between issuance_date and now)
      # return the coefficient and the R^2 of the regression

      # 1. Prepare the data
      x = @items.map { |item| self.class.normalized_x(item) }
      y = @items.map(&:price).map(&:to_f)

      # 2. Compute the regression
      x_matrix = Matrix.rows(x)
      y_matrix = Matrix.column_vector(y)
      @beta = (x_matrix.t * x_matrix).inv * x_matrix.t * y_matrix

      # 3. Compute the R^2
      y_mean = y.sum / y.size.to_f
      y_mean_matrix = Matrix.column_vector([y_mean] * y.size)
      y_hat = x_matrix * @beta
      ss_tot = (y_matrix - y_mean_matrix).t * (y_matrix - y_mean_matrix)
      ss_res = (y_matrix - y_hat).t * (y_matrix - y_hat)
      @r_squared = 1 - ss_res[0, 0] / ss_tot[0, 0]

      [@beta, @r_squared]
    end

    def explain(output = $stdout)
      raise 'You must call linear_regression before calling explain' unless @beta

      output.puts format('Linear regression: price = %0.2f + %0.2f * mileage_kkms + %0.2f * age_years', base_price,
                         cost_per_kms * 1_000, cost_per_day * 365.0)
      output.puts format('max_mileage = %0.2f, max_age = %0.2f', -base_price / cost_per_kms,
                         -base_price / (cost_per_day * 365))
      output.puts format('R^2 = %0.2f', @r_squared)
    end

    def explain2(output = $stdout)
      raise 'You must call linear_regression before calling explain' unless @beta

      output.puts format(
        "Prediction (#{HOME_PREDICT_MAX_MILEAGE} kms, #{(HOME_PREDICT_MAX_AGE_DAYS / 365).to_i} years): price = %0.2f - %0.2f * mileage_kkms - %0.2f * age_years",
        base_price,
        base_price * 1_000 / HOME_PREDICT_MAX_MILEAGE,
        base_price / (HOME_PREDICT_MAX_AGE_DAYS / 365.0)
      )
    end

    def base_price
      raise 'You must call linear_regression before calling base_price' unless @beta

      @beta[0, 0]
    end

    def cost_per_kms
      raise 'You must call linear_regression before calling cost_per_kms' unless @beta

      @beta[1, 0] / MAX_MILEAGE
    end

    def cost_per_day
      raise 'You must call linear_regression before calling cost_per_day' unless @beta

      @beta[2, 0] / MAX_AGE_DAYS
    end

    def predict_price(item)
      x = self.class.normalized_x(item)
      x_matrix = Matrix.rows([x])
      (x_matrix * @beta)[0, 0]
    end

    def predict_price2(item)
      base_price * (1 - item.mileage / 200_000.0 - (Date.today - item.issuance_date.to_date).to_i / (365 * 14.0))
    end
  end
end

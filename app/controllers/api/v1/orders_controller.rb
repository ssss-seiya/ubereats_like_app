module Api
  module V1
    class OrdersController < ApplicationController
      def create
        # 複数の仮注文をposted_line_foodsに格納
        posted_line_foods = LineFood.where(id: params[:line_food_ids])
        # 複数の仮注文の合計金額とそれらの店のidを引数に、本注文インスタンスを作成する
        order = Order.new(
          total_price: total_price(posted_line_foods),
          restaurant_id: posted_line_foods.first.restaurant_id
        )
        # 作成した本注文インスタンスはトランザクション保存をする
        ## 成功すると、空データを返す
        ## 失敗すると、サーバーエラーを返す
        if order.save_with_update_line_foods!(posted_line_foods)
          render json: {}, status: :no_content
        else
          render json: {}, status: :internal_server_error
        end
      end

      private

      # 本注文の合計金額を計上する
      def total_price(posted_line_foods)
        # それぞれの仮注文に紐付いた商品の金額×個数の合計+仮注文の店の料金(手数料？)
        posted_line_foods.sum {|line_food| line_food.total_amount } + posted_line_foods.first.restaurant.fee
      end
    end
  end
end

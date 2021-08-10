module Api
  module V1
    class LineFoodsController < ApplicationController
      before_action :set_food, only: %i[create replace]

      def index
        line_foods = LineFood.active
        if line_foods.exists?
          render json: {
            line_food_ids: line_foods.map { |line_food| line_food.id },
            restaurant: line_foods[0].restaurant,
            count: line_foods.sum { |line_food| line_food[:count] },
            amount: line_foods.sum { |line_food| line_food.total_amount },
          }, status: :ok
        else
          render json: {}, status: :no_content
        end
      end

      def create
        # 仮注文がアクティブな商品の店以外の店舗が存在する場合
        ## その店舗の名前(existing_restaurant)と
        ## 選択中の商品の店の名前(new_restaurant)を
        ## json形式、ステータスは406で返す
        if LineFood.active.other_restaurant(@ordered_food.restaurant.id).exists?
          return render json: {
            existing_restaurant: LineFood.other_restaurant(@ordered_food.restaurant.id).first.restaurant.name,
            new_restaurant: Food.find(params[:food_id]).restaurant.name,
          }, status: :not_acceptable
        end

        # 選択中の商品についてactive状態及び個数を更新する => @line_foodに格納
        set_line_food(@ordered_food)

        # 更新された@line_foodを保存し、
        # 成功した場合はline_foodを、
        # 失敗した場合はinternal_server_errorを
        # json形式で返す
        if @line_food.save
          render json: {
            line_food: @line_food
          }, status: :created
        else
          render json: {}, status: :internal_server_error
        end
      end

      # 既にある古い仮注文を論理削除する
      def replace
        LineFood.active.other_restaurant(@ordered_food.restaurant.id).each do |line_food|
          line_food.update_attribute(:active, false)
        end

        # 選択中の商品についてactive状態及び個数を更新し直す => @line_foodに格納
        set_line_food(@ordered_food)

        # 更新された@line_foodを保存し、
        # 成功した場合はline_foodを、
        # 失敗した場合はinternal_server_errorを
        # json形式で返す
        if @line_food.save
          render json: {
            line_food: @line_food
          }, status: :created
        else
          render json: {}, status: :internal_server_error
        end
      end

      private

      # 選択中の商品を@ordered_foodとする
      def set_food
        @ordered_food = Food.find(params[:food_id])
      end


      # 選択中の商品をactiveとした@line_foodを作成する
      def set_line_food(ordered_food)
        # 選択中の商品が仮注文されている場合
          # 商品の個数のとアクティブ状態を更新する
          # そうでない場合は新規に商品と仮注文を関連付ける
        if ordered_food.line_food.present?
          @line_food = ordered_food.line_food
          @line_food.attributes = {
            count: ordered_food.line_food.count + params[:count],
            active: true
          }
        else
          @line_food = ordered_food.build_line_food(
            count: params[:count],
            restaurant: ordered_food.restaurant,
            active: true
          )
        end
      end
    end
  end
end

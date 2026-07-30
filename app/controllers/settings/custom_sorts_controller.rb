module Settings
  class CustomSortsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_custom_sort, only: [ :edit, :update, :destroy ]

    def new
      @custom_sort = current_user.custom_sorts.build
      @sort_matrix = {}
    end

    def create
      @custom_sort = current_user.custom_sorts.build(name: params.dig(:custom_sort, :name))

      if save_with_criteria
        redirect_to settings_sorting_path, notice: "Custom sort created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @sort_matrix = matrix_from_criteria(@custom_sort.criteria)
    end

    def update
      @custom_sort.name = params.dig(:custom_sort, :name)

      if save_with_criteria
        redirect_to settings_sorting_path, notice: "Custom sort updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @custom_sort.destroy!
      redirect_to settings_sorting_path, notice: "Custom sort deleted."
    end

    private

    def set_custom_sort
      @custom_sort = current_user.custom_sorts.find(params[:id])
    end

    # Build criteria from the composer matrix (validating it), then save.
    def save_with_criteria
      @sort_matrix = (params.dig(:custom_sort, :criteria) || {}).to_unsafe_h
      @custom_sort.criteria = build_criteria(@sort_matrix)

      @sort_errors.empty? && @custom_sort.save
    end

    # Turn the { field => { "rank" =>, "direction" => } } matrix into an ordered
    # criteria list, surfacing conflicts as errors rather than resolving them.
    def build_criteria(matrix)
      @sort_errors = []
      entries = []

      CollectibleSearch::SORT_FIELDS.each_key do |field|
        rank = matrix.dig(field, "rank").presence
        next if rank.blank? # fields without a rank are ignored

        entries << { field: field, direction: matrix.dig(field, "direction"), rank: rank.to_i }
      end

      duplicate_ranks = entries.map { |entry| entry[:rank] }.tally.select { |_, count| count > 1 }.keys
      @sort_errors << "rank #{duplicate_ranks.sort.to_sentence} is used more than once" if duplicate_ranks.any?

      entries.sort_by { |entry| entry[:rank] }
             .map { |entry| { "field" => entry[:field], "direction" => entry[:direction] } }
    end

    def matrix_from_criteria(criteria)
      Array(criteria).each_with_index.each_with_object({}) do |(entry, index), matrix|
        matrix[entry["field"]] = { "rank" => (index + 1).to_s, "direction" => entry["direction"] }
      end
    end
  end
end

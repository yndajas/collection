module Settings
  class LabelsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_label, only: [ :edit, :update, :destroy, :confirm_delete ]

    def index
      @labels = current_user.labels.ordered
      @label = current_user.labels.build(colour: Label::COLOURS.sample)
    end

    def create
      @label = current_user.labels.build(label_params)

      if @label.save
        redirect_to settings_labels_path, notice: "Label created."
      else
        @labels = current_user.labels.ordered
        render :index, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @label.update(label_params)
        redirect_to settings_labels_path, notice: "Label updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def confirm_delete
      @collectibles = @label.collectibles.ordered
    end

    def destroy
      @label.destroy!
      redirect_to settings_labels_path, notice: "Label deleted."
    end

    private

    def set_label
      @label = current_user.labels.find(params[:id])
    end

    def label_params
      permitted = params.require(:label).permit(:name, :colour, collectible_types: [])
      permitted[:collectible_types] = Array(permitted[:collectible_types]) & Collectible::TYPES
      permitted
    end
  end
end

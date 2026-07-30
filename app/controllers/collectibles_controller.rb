class CollectiblesController < ApplicationController
  before_action :authenticate_user!, except: [ :show ]
  before_action :require_own_profile, except: [ :show ]
  before_action :set_collectible, only: [ :show ]
  before_action :set_owned_collectible, only: [ :edit, :update, :destroy, :confirm_delete ]

  def show
    @link_keys = viewer_link_keys(@profile)
  end

  def new
    @collectible = build_collectible
  end

  def create
    @collectible = build_collectible(collectible_params)

    if @collectible.save
      redirect_to profile_collectible_path(current_user.username, @collectible),
                  notice: "#{@collectible.type_label} added to your collection."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    attributes = collectible_params.to_h.symbolize_keys
    if attributes.key?(:label_ids)
      attributes[:label_ids] = applicable_label_ids(@collectible.type, attributes[:label_ids])
    end

    if @collectible.update(attributes)
      redirect_to profile_collectible_path(current_user.username, @collectible),
                  notice: "#{@collectible.type_label} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def confirm_delete
  end

  def destroy
    @collectible.destroy!
    redirect_to profile_path(current_user.username), notice: "Removed from your collection."
  end

  IMPORT_FORMATS = %w[titles csv json].freeze

  # Step 1: GET /collectibles/import
  # Paste titles, CSV, or JSON (or upload a file) and pick a default type.
  def import
    @type = requested_type
    @format = "titles"
  end

  # GET /collectibles/import_template
  # Download a blank CSV carrying just the import headers.
  def import_template
    send_data CollectibleExporter.new([]).to_csv,
              filename: "collectibles.csv",
              type: "text/csv"
  end

  # Step 2: POST /collectibles/import_review
  # Parse the input into an editable fieldset per item.
  def import_review
    @type = requested_type
    @format = import_format.to_s
    importer = CollectibleImporter.new(
      import_content,
      format: @format,
      default_type: @type.sti_name,
      user: current_user
    )
    rows = importer.rows

    if rows.empty?
      flash.now[:alert] = "Nothing to import. Check your #{@format.upcase} and try again."
      return render :import, status: :unprocessable_entity
    end

    if importer.unknown_labels.any?
      flash.now[:notice] = "Ignored unknown labels: #{importer.unknown_labels.uniq.to_sentence}."
    end

    @collectibles = rows.map { |attributes| build_collectible(attributes) }
    render :review
  end

  # Step 3: POST /collectibles/import_create
  # Save every reviewed item, or bounce back to the review step with errors.
  def import_create
    @type = requested_type
    @collectibles = import_items_params.map { |attributes| build_collectible(attributes) }

    if @collectibles.all?(&:valid?)
      Collectible.transaction { @collectibles.each(&:save!) }
      redirect_to profile_path(current_user.username),
                  notice: "Imported #{@collectibles.size} #{"item".pluralize(@collectibles.size)}."
    else
      flash.now[:alert] = "Fix the highlighted items below, then import again."
      render :review, status: :unprocessable_entity
    end
  end

  private

  def import_format
    IMPORT_FORMATS.include?(params[:data_format]) ? params[:data_format].to_sym : infer_format
  end

  # Fall back to the uploaded file's extension, else plain titles.
  def infer_format
    case params[:file]&.original_filename.to_s.downcase
    when /\.csv\z/ then :csv
    when /\.json\z/ then :json
    else :titles
    end
  end

  # Prefer an uploaded file over the pasted textarea.
  def import_content
    file = params[:file]
    file.respond_to?(:read) ? file.read : params[:content]
  end

  # Permitted attributes for each reviewed item, submitted as items[0][...],
  # items[1][...], and so on. Each carries its own STI type.
  def import_items_params
    params.fetch(:items, {}).values.map do |item|
      item.permit(
        :type, :title, :notes, :completed, :evergreen,
        :system, :local_multiplayer, :online_multiplayer, :cooperative, :competitive,
        :min_players, :max_players, :author,
        label_ids: []
      )
    end
  end

  # For #show: a collectible within a named owner's collection, if the viewer
  # may see that owner's profile.
  def set_collectible
    @profile = User.find_by!(username: params[:username])
    @collectible = @profile.collectibles.find(params[:id])
    @token = params[:token]
    @owner = current_user == @profile

    return if @profile.visible_to?(current_user, token: @token)

    @user = @profile
    store_location_for(:user, request.fullpath) unless user_signed_in?
    render "profiles/private_profile", status: :forbidden
  end

  # Owner-only actions are nested under the owner's username; make sure the path
  # actually belongs to the signed-in user.
  def require_own_profile
    raise ActiveRecord::RecordNotFound unless current_user&.username == params[:username]
  end

  # For #edit/#update/#destroy: only the owner's own collectibles.
  def set_owned_collectible
    @collectible = current_user.collectibles.find(params[:id])
    @profile = current_user
    @owner = true
  end

  def requested_type
    Collectible.model_for(params[:type]) || VideoGame
  end

  def build_collectible(attributes = {})
    attributes = attributes.to_h.symbolize_keys if attributes.is_a?(ActionController::Parameters)
    attributes = attributes.dup
    klass = Collectible.model_for(attributes.delete(:type)) || requested_type
    if attributes.key?(:label_ids)
      attributes[:label_ids] = applicable_label_ids(klass.sti_name, attributes[:label_ids])
    end
    klass.new(attributes).tap { |collectible| collectible.user = current_user }
  end

  # Keep only the submitted label ids that opt in to +type+, so a label can
  # never be attached to a collectible type it doesn't apply to.
  def applicable_label_ids(type, ids)
    allowed = current_user.labels.select { |label| label.applies_to_type?(type) }.map { |label| label.id.to_s }
    Array(ids).map(&:to_s) & allowed
  end

  def collectible_params
    params.require(:collectible).permit(
      :title, :notes, :completed, :evergreen,
      :system, :local_multiplayer, :online_multiplayer, :cooperative, :competitive,
      :min_players, :max_players, :author,
      label_ids: []
    )
  end
end

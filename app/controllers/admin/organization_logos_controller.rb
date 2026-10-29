module Admin
  class OrganizationLogosController < BaseController
    before_action { authorize :system, :manage_organization_logos?, policy_class: SystemPolicy }
    before_action :set_organization_logo, only: [ :show, :approve, :decline ]

    def index
      @status = params[:status].presence || "pending"
      @organization_logos = OrganizationLogo.includes(:organization, :uploaded_by).with_attached_image.order(created_at: :desc)
      @organization_logos = @organization_logos.where(status: @status) unless @status == "all"
    end

    def show
    end

    def approve
      @organization_logo.approve!(reviewed_by: current_user)
      log_audit(:organization_logo_approved, resource: @organization_logo, organization: @organization_logo.organization,
        metadata: { organization_logo_id: @organization_logo.id })

      respond_to do |format|
        format.turbo_stream do
          flash.now[:toast] = { message: "Logo approved.", type: "success" }
          render turbo_stream: [
            turbo_stream.replace(dom_id(@organization_logo, :status_badge), partial: "admin/organization_logos/status_badge", locals: { organization_logo: @organization_logo }),
            turbo_stream.replace(dom_id(@organization_logo, :review_panel), partial: "admin/organization_logos/review_panel", locals: { organization_logo: @organization_logo }),
            turbo_stream.update("flash_messages", partial: "shared/flash")
          ]
        end
        format.html { redirect_to admin_organization_logo_path(@organization_logo), notice: "Logo approved." }
      end
    end

    def decline
      reason = decline_params[:decline_reason].to_s.strip

      if reason.blank?
        @organization_logo.errors.add(:decline_reason, "can't be blank")
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(dom_id(@organization_logo, :decline_dialog), partial: "admin/organization_logos/decline_dialog_content", locals: { organization_logo: @organization_logo }),
                   status: :unprocessable_entity
          end
          format.html { render :show, status: :unprocessable_entity }
        end
        return
      end

      @organization_logo.decline!(reviewed_by: current_user, reason: reason)
      log_audit(:organization_logo_declined, resource: @organization_logo, organization: @organization_logo.organization,
        metadata: { organization_logo_id: @organization_logo.id, reason: reason })

      respond_to do |format|
        format.turbo_stream do
          flash.now[:toast] = { message: "Logo declined.", type: "success" }
          render turbo_stream: [
            turbo_stream.replace(dom_id(@organization_logo, :status_badge), partial: "admin/organization_logos/status_badge", locals: { organization_logo: @organization_logo }),
            turbo_stream.replace(dom_id(@organization_logo, :review_panel), partial: "admin/organization_logos/review_panel", locals: { organization_logo: @organization_logo }),
            turbo_stream.update("flash_messages", partial: "shared/flash")
          ]
        end
        format.html { redirect_to admin_organization_logo_path(@organization_logo), notice: "Logo declined." }
      end
    end

    private

    def set_organization_logo
      @organization_logo = OrganizationLogo.includes(:organization, :uploaded_by, :reviewed_by).find(params[:id])
    end

    def decline_params
      params.permit(organization_logo: [ :decline_reason ]).fetch(:organization_logo, {})
    end
  end
end

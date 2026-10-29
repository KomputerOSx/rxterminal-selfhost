# frozen_string_literal: true

module Org
  class DevicesController < BaseController
    before_action :authorize_manage
    before_action :set_device, only: [ :show, :edit, :update, :regenerate_key, :clear_ip, :set_status ]

    def index
      @devices = scoped_devices.order(created_at: :desc).page(params[:page]).per(20)
    end

    def show
    end

    def new
      @device = Current.organization.devices.build(status: "active")
    end

    def create
      return if block_unless_kiosk_enabled!

      raw_key = SecureRandom.hex(32)
      @device = Current.organization.devices.build(device_params)
      @device.api_key = raw_key

      if @device.save
        log_audit(:device_created, resource: @device, metadata: {
          device_id: @device.device_id,
          status: @device.status
        })
        flash[:api_key] = raw_key
        redirect_to org_device_path(@device), notice: "Device created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @device.update(update_params)
        log_audit(:device_updated, resource: @device, metadata: {
          device_id: @device.device_id,
          changed_fields: @device.saved_changes.except("updated_at").keys
        })
        redirect_to org_device_path(@device), notice: "Device updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def regenerate_key
      raw_key = @device.regenerate_api_key!
      log_audit(:device_key_regenerated, resource: @device, metadata: { device_id: @device.device_id })
      flash[:api_key] = raw_key
      redirect_to org_device_path(@device),
        notice: "API key regenerated. All active sessions for this device have been invalidated."
    end

    def clear_ip
      old_ip = @device.registered_ip
      @device.update!(registered_ip: nil)
      log_audit(:device_ip_cleared, resource: @device, metadata: {
        device_id: @device.device_id,
        cleared_ip: old_ip
      })
      redirect_to org_device_path(@device),
        notice: "Registered IP cleared. The device will re-register its IP on next authentication."
    end

    def set_status
      new_status = params[:status]
      unless Device::STATUSES.include?(new_status)
        redirect_to org_device_path(@device), alert: "Invalid status."
        return
      end

      if @device.status == "revoked" && new_status != "revoked"
        redirect_to org_device_path(@device), alert: "A revoked device cannot be reactivated."
        return
      end

      old_status = @device.status
      if new_status == "revoked"
        @device.revoke!
      else
        @device.update!(status: new_status)
      end

      log_audit(:device_updated, resource: @device, metadata: {
        device_id: @device.device_id,
        changed_fields: [ "status" ],
        old_status: old_status,
        new_status: @device.status
      })
      redirect_to org_device_path(@device), notice: "Device #{@device.status.humanize.downcase}."
    end

    private

    def authorize_manage
      authorize Current.organization, :manage?, policy_class: DevicePolicy
    end

    def set_device
      @device = Current.organization.devices.find(params[:id])
    end

    def scoped_devices
      scope = Current.organization.devices

      if params[:search].present?
        q = "%#{params[:search].strip.downcase}%"
        scope = scope.where("LOWER(device_id) LIKE ? OR LOWER(name) LIKE ?", q, q)
      end

      if params[:status].present? && Device::STATUSES.include?(params[:status])
        scope = scope.where(status: params[:status])
      else
        scope = scope.where.not(status: "revoked")
      end

      scope
    end

    def device_params
      params.require(:device).permit(:device_id, :name, :serial_number, :status, :registered_ip)
    end

    def update_params
      keys = [ :name, :serial_number, :registered_ip ]
      keys << :status unless @device.status == "revoked"
      params.require(:device).permit(*keys)
    end
  end
end

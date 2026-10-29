# 8. Kiosk

The kiosk is a touch-friendly, self-service screen for customers to join the queue on their own. It requires the Business plan and a registered device.

## Registering a device

1. Go to Devices and click New Device.
2. Give it a device ID, name, and optional serial number. You can also set its registered IP and status here, or leave IP blank to lock it on first connection.
3. Click Create Device. RxTerminal shows you an API key once. Copy it, since it can't be viewed again.
4. On the kiosk's browser, open the kiosk setup page and enter the device ID and API key.

The device locks to the IP address it first authenticates from. If you move the kiosk to a new network, clear the registered IP from the device's page in RxTerminal, then reconnect.

## Managing devices

- **Regenerate key** if it's been compromised. This signs out the device immediately, and you'll need to re-enter the new key on it.
- **Clear the registered IP** to allow the device to re-register from a new location.
- **Activate or deactivate** a device to control whether it can connect, without revoking it.
- **Revoke device** to permanently disable it. A revoked device can't be reactivated. Register a new one instead.

## Kiosk settings

Go to Kiosk in the sidebar. Under Home screen buttons, configure:

- Featured service, and which one.
- Browse services, showing the full service list.
- Check in for appointment.

You can also set the theme and, per service, whether it's featured or active and which icon it shows.

Use Live preview to see changes as you make them, or Open full preview to try the kiosk itself in a new view.

## What customers see

At the kiosk, a customer chooses a service (or the featured one), enters their details, and receives a queue number. If an upsell rule matches, they see the upsell prompt first. If online appointment check-in is enabled, they can also check in for a booked appointment.

Booking an appointment at the kiosk follows your appointment booking settings, including blocked dates and openings. See Appointments.

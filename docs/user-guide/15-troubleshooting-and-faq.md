# 15. Troubleshooting and FAQ

**The kiosk says "Invalid API key."**
Re-enter the device ID and API key on the kiosk setup page. If that doesn't work, regenerate the key from the device's page and enter the new one.

**The kiosk says "Device not found."**
The device ID doesn't match any registered device. Check it against the Devices page.

**The kiosk says "Device is inactive" or "Device is revoked."**
Reactivate the device from its page in RxTerminal. A revoked device can't be reactivated. Register a new one instead.

**The kiosk won't authenticate after moving it to a new location.**
Devices lock to the first IP address they authenticate from. Clear the registered IP from the device's page in RxTerminal, then reconnect the kiosk.

**I can't remove or demote an owner.**
Owners can't be removed or demoted directly. Demote them to admin first, which requires their own email confirmation, then remove them if needed.

**A member invite isn't arriving.**
On the Starter plan, invites beyond your one member slot are blocked outright with a plan-limit message. Otherwise, check the address for typos and ask them to check spam. Revoke and resend the invitation from the Members page if needed.

**I'm locked out after too many failed logins.**
5 failed attempts locks your account for 30 minutes. Wait, then try again.

**The custom domain won't verify.**
Confirm the DNS record matches exactly what RxTerminal shows you, then use the status check on the Custom Domain page. DNS changes can take time to propagate.

**Customers can't book appointments online.**
Confirm your plan includes appointments, and that Public Booking Portal and Online Appointment Booking are both on under Features. Then check Appointment Booking. In Rolling dates mode, make sure the day has bookable windows and isn't blocked. In Set openings mode, make sure an opening covers that date and calendar, and that the day has bookable windows in that opening. Blocked dates apply in both modes.

**A public holiday is missing after importing.**
Add it yourself under Add blocked date. See Appointments.

**Average wait time shows "N/A."**
Turn on the Waiting Time feature under Features. If it's already on, wait times need recent queue activity to calculate an average.

**I hit a plan limit.**
Starter plans cap staff, services, upsell rules, and monthly requests. Upgrade to Business from the Billing page to remove these limits.

**My logo is still pending review.**
Logos are reviewed before they can be used, and review can take up to 48 hours. If it's taking longer, contact support at support@strixon.co.uk.

**I can't upload another logo.**
You can have up to 3 logos pending review or approved at a time. Remove one you don't need from Your submissions in Settings, or wait for a decision on the ones pending.

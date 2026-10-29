// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "confirm"
import { installKioskPageTransitions } from "kiosk/page_transitions"

installKioskPageTransitions()

# lego-renew-with-slack

A simple, reusable shell script that wraps [`lego`](https://github.com/go-acme/lego) to automate Let's Encrypt SSL certificate renewal.  
It supports sending status notifications to Slack with visual indicators and certificate expiration details.

---

## Features

- Renews Let's Encrypt certificates using the `http.webroot` method
- Sends success or failure notifications to Slack
  - Green bar for success, red for failure
  - Includes expiration date of the renewed certificate
- Designed to be run from cron
- Reusable across multiple servers with minimal changes

---

## Usage

```bash
sudo /usr/local/bin/lego-renew-with-slack \
  --domains "example.com" \
  --http.webroot "/var/www/example.com/public"
```

You must set the following values using environment variables or a configuration file:

LEGO_EMAIL: Email address used for Let's Encrypt registration

SLACK_WEBHOOK_URL: Slack Incoming Webhook URL for notifications


## Installation

```bash
# Clone the repository
cd /usr/local/src
git clone https://github.com/irukasano/lego-renew-with-slack.git

# Make the script executable
chmod +x lego-renew-with-slack/lego-renew-with-slack.sh

# Create a symlink for easy execution
sudo ln -s /usr/local/src/lego-renew-with-slack/lego-renew-with-slack.sh /usr/local/bin/lego-renew-with-slack
```

## Configuration

Create the config file:

```bash
sudo mkdir -p /etc/lego-renew-with-slack
sudo vi /etc/lego-renew-with-slack/.env
```

Contents:

```bash
LEGO_EMAIL="your-email@example.com"
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/XXX/YYY/ZZZ"

# Optional overrides
LEGO_BIN="/usr/local/bin/lego"
LEGO_PATH="/etc/lego"
RENEW_HOOK="systemctl reload nginx"
```

If .env is not found, the script will fall back to default settings:

* LEGO_BIN=/root/go/bin/lego
* LEGO_PATH=/etc/lego
* RENEW_HOOK=systemctl restart httpd

## Cron Setup

To renew the certificate daily, create a cron job like:

```bash
# /etc/cron.daily/letsencrypt-update-example.sh

#!/bin/sh
/usr/local/bin/lego-renew-with-slack.sh \
  --domains "example.com" \
  --http.webroot "/var/www/example.com/public"
```

Make sure the script is executable.

## Dependencies

* lego
* curl (for sending Slack messages)
* openssl (to read certificate expiration)

## Notes

* The script uses the --http + --http.webroot method. If you need DNS challenge or other methods, you can modify the script accordingly.
* The Slack notification uses attachments with colored sidebars for better visual feedback.

## License

MIT License


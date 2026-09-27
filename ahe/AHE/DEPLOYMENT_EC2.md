# AHE Global demo on AWS EC2 (Ubuntu)

These steps run the site on an Ubuntu EC2 instance so a reviewer can open it in a browser. They assume MySQL and the Flask app run on the same instance.

## Automated install

After copying the project to `~/ahe-global`, run:

```bash
bash install_ec2_ubuntu.sh
```

The script installs Ubuntu packages and Python requirements, creates the local MySQL database/user, generates a Flask secret and database password, writes a private `.env`, and starts the app as a persistent systemd service on port 8000. It can be rerun; the app password and secret are retained from the existing `.env`.

Then allow inbound TCP port 8000 in the EC2 security group and open `http://EC2_PUBLIC_IP:8000`. The automated setup uses the `ahe_app` database user and local database.

## 1. Copy the project

From the project directory on your computer, copy the source files to the instance. Do not copy `.venv`, `.env`, or `__pycache__`.

```bash
rsync -av --exclude='.venv' --exclude='.env' --exclude='__pycache__' ./ ubuntu@EC2_PUBLIC_IP:~/ahe-global/
```

Replace `ubuntu` if your EC2 image uses a different login name. You can also copy the project folder with VS Code Remote SSH.

## 2. Install Python and MySQL

SSH into the instance, then run:

```bash
sudo apt update
sudo apt install -y python3-venv python3-pip mysql-server
sudo systemctl enable --now mysql
cd ~/ahe-global
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

Create the application database and a local database user:

```bash
sudo mysql
```

At the MySQL prompt, run the following, replacing the sample password:

```sql
CREATE DATABASE ahe_global CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'ahe_app'@'localhost' IDENTIFIED BY 'REPLACE_WITH_A_STRONG_PASSWORD';
GRANT ALL PRIVILEGES ON ahe_global.* TO 'ahe_app'@'localhost';
EXIT;
```

## 3. Configure and start the site

```bash
cp .env.example .env
nano .env
```

Set `SECRET_KEY` to a private random value, enter the MySQL password, and set `PORT=8000`. Keep `FLASK_DEBUG=false`.

Start the demo server:

```bash
.venv/bin/gunicorn --workers 2 --bind 0.0.0.0:8000 app:app
```

The contact form creates its `enquiries` table on its first successful submission.

## 4. Let the reviewer connect

In the EC2 security group's inbound rules, allow **TCP port 8000** from the reviewer’s public IP address. Then share:

```text
http://EC2_PUBLIC_IP:8000
```

For a short demo, the command above stays active while that SSH session remains open. Stop it with `Ctrl+C`. Before showing the site, replace the sample `hello@aheglobal.com` address in `templates/base.html` and `templates/contact.html` with AHE Global’s verified contact information, then copy the updated files and restart Gunicorn.

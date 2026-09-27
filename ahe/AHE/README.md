# AHE Global

A responsive Flask website for AHE Global's energy and international trade services.

## Run locally

1. Create and activate a virtual environment: `python3 -m venv .venv` then `source .venv/bin/activate`.
2. Install packages: `pip install -r requirements.txt`.
3. Create a MySQL database named `ahe_global` (or set `DB_NAME` to your database).
4. Copy `.env.example` to `.env` and set your database credentials and a private `SECRET_KEY`.
5. Run `python app.py` and open http://127.0.0.1:5000. Values from `.env` load automatically.

The contact form creates its `enquiries` table automatically on the first submission. Add the business's verified phone, email and address in `templates/contact.html` before publishing.

For an EC2 demo, follow [DEPLOYMENT_EC2.md](DEPLOYMENT_EC2.md).

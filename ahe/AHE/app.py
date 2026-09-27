import os
from datetime import datetime

from flask import Flask, flash, redirect, render_template, request, url_for
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "change-this-secret-before-deploying")
app.config["TEMPLATES_AUTO_RELOAD"] = True


def save_enquiry(name, email, phone, subject, message):
    """Save enquiries to MySQL when configured; otherwise leave a clear setup hint."""
    try:
        import mysql.connector

        connection = mysql.connector.connect(
            host=os.getenv("DB_HOST", "localhost"),
            user=os.getenv("DB_USER", "root"),
            password=os.getenv("DB_PASSWORD", ""),
            database=os.getenv("DB_NAME", "ahe_global"),
        )
        cursor = connection.cursor()
        cursor.execute(
            """CREATE TABLE IF NOT EXISTS enquiries (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(120) NOT NULL,
                email VARCHAR(190) NOT NULL,
                phone VARCHAR(40),
                subject VARCHAR(190),
                message TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )"""
        )
        cursor.execute(
            "INSERT INTO enquiries (name, email, phone, subject, message) VALUES (%s, %s, %s, %s, %s)",
            (name, email, phone, subject, message),
        )
        connection.commit()
        cursor.close()
        connection.close()
        return True
    except Exception as error:
        app.logger.warning("Could not store enquiry in MySQL: %s", error)
        return False


@app.context_processor
def inject_globals():
    return {"year": datetime.now().year}


@app.route("/")
def home():
    return render_template("index.html", page="home")


@app.route("/services")
def services():
    return render_template("services.html", page="services")


@app.route("/about")
def about():
    return render_template("about.html", page="about")


@app.route("/contact", methods=["GET", "POST"])
def contact():
    if request.method == "POST":
        name = request.form.get("name", "").strip()
        email = request.form.get("email", "").strip()
        message = request.form.get("message", "").strip()
        if not name or not email or not message:
            flash("Please complete your name, email and message.", "error")
        elif save_enquiry(name, email, request.form.get("phone", "").strip(), request.form.get("subject", "").strip(), message):
            flash("Thank you. Your enquiry is with our team, and we’ll be in touch shortly.", "success")
            return redirect(url_for("contact"))
        else:
            flash("Your message could not be saved just now. Please contact us by email or phone.", "error")
    return render_template("contact.html", page="contact")


if __name__ == "__main__":
    app.run(
        host=os.getenv("HOST", "127.0.0.1"),
        port=int(os.getenv("PORT", "5000")),
        debug=os.getenv("FLASK_DEBUG", "false").lower() == "true",
    )

from flask import Blueprint, render_template

frontend_blueprint = Blueprint('frontend', __name__)

@frontend_blueprint.route('/')
def index():
    return render_template('index.html')

@frontend_blueprint.route('/dashboard')
def dashboard():
    return render_template('pages/dashboard.html')

@frontend_blueprint.route('/record-label')
def record_label():
    return render_template('pages/record_label.html')

@frontend_blueprint.route('/employee')
def employee():
    return render_template('pages/employee.html')

@frontend_blueprint.route('/song')
def song():
    return render_template('pages/song.html')

@frontend_blueprint.route('/contributor')
def contributor():
    return render_template('pages/contributor.html')

@frontend_blueprint.route('/collaboration')
def collaboration():
    return render_template('pages/collaboration.html')
